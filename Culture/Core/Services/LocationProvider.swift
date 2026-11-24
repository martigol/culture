//
//  LocationProvider.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import CoreLocation
import Observation

/// One-shot "where am I?" for pinning photos, plus the authorisation state the
/// map needs to show the user's dot. When-in-use only; nothing leaves the device.
@Observable
@MainActor
final class LocationProvider: NSObject {
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// Most recent fix, if any (used for "312 km away").
    private(set) var lastLocation: CLLocation?

    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var waiters: [UUID: CheckedContinuation<CLLocation?, Never>] = [:]
    @ObservationIgnored private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        authorization = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        lastLocation = manager.location
    }

    /// Shows the system prompt once; no-op after the user has answered.
    func requestAuthorizationIfNeeded() async {
        guard authorization == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    /// A current fix, or `nil` if location is off, denied, or nothing arrives in `timeout`.
    func currentLocation(timeout: Duration = .seconds(6)) async -> CLLocation? {
        if let recent = manager.location, recent.timestamp.timeIntervalSinceNow > -30, recent.horizontalAccuracy <= 100 {
            lastLocation = recent
            return recent
        }
        await requestAuthorizationIfNeeded()
        guard isAuthorized else { return nil }

        let id = UUID()
        return await withCheckedContinuation { continuation in
            waiters[id] = continuation
            manager.requestLocation()
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.resume(id, with: self?.manager.location)
            }
        }
    }

    private func resume(_ id: UUID, with location: CLLocation?) {
        // Removing first guarantees each continuation resumes exactly once.
        guard let continuation = waiters.removeValue(forKey: id) else { return }
        continuation.resume(returning: location)
    }

    private func resumeAll(with location: CLLocation?) {
        for id in Array(waiters.keys) { resume(id, with: location) }
    }

    fileprivate func handle(_ locations: [CLLocation]) {
        guard let best = locations.min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }) else { return }
        lastLocation = best
        resumeAll(with: best)
    }

    fileprivate func handleFailure(_ error: Error) {
        Log.app.error("Location failed: \(error.localizedDescription)")
        resumeAll(with: nil)
    }

    fileprivate func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorization = status
        guard status != .notDetermined else { return }
        let pending = authorizationWaiters
        authorizationWaiters.removeAll()
        pending.forEach { $0.resume() }
        if isAuthorized, lastLocation == nil { lastLocation = manager.location }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.handle(locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.handleFailure(error) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.handleAuthorizationChange(status) }
    }
}
