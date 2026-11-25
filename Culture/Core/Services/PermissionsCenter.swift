//
//  PermissionsCenter.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import AVFoundation
import CoreLocation
import FoundationModels
import Observation
import UIKit
import UserNotifications

/// Every permission the app relies on, its live status, and how to ask for it.
/// Drives the "Get the full experience" screen.
@Observable
@MainActor
final class PermissionsCenter {
    enum Feature: String, CaseIterable, Identifiable {
        case camera, location, notifications, intelligence
        var id: String { rawValue }

        var title: String {
            switch self {
            case .camera: "Camera"
            case .location: "Location"
            case .notifications: "Nearby alerts"
            case .intelligence: "Apple Intelligence"
            }
        }

        var reason: String {
            switch self {
            case .camera: "Scan statues, temples and relics to hear their story, and take photos at each site."
            case .location: "Pin your photos where you took them and show the sites closest to you."
            case .notifications: "Get a nudge when you're near a historical site worth the detour."
            case .intelligence: "Ask questions about any story and hear it in your language, all on device."
            }
        }

        var symbol: String {
            switch self {
            case .camera: "camera.viewfinder"
            case .location: "location"
            case .notifications: "bell.badge"
            case .intelligence: "sparkles"
            }
        }
    }

    enum Status: Equatable {
        case notAsked, granted, denied
        /// Can't be requested in-app (e.g. Apple Intelligence off) — needs Settings.
        case needsSettings(String)
        case unavailable(String)
    }

    private(set) var statuses: [Feature: Status] = [:]

    /// Shown once on first launch; can be reopened from Library.
    var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "permissionsOnboarded") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "permissionsOnboarded") }
    }

    var allGranted: Bool { Feature.allCases.allSatisfy { status(of: $0) == .granted } }

    func status(of feature: Feature) -> Status { statuses[feature] ?? .notAsked }

    // MARK: Refresh

    func refresh() async {
        statuses[.camera] = Self.camera()
        statuses[.location] = Self.location()
        statuses[.notifications] = await Self.notifications()
        statuses[.intelligence] = Self.intelligence()
    }

    private static func camera() -> Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    private static func location() -> Status {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    private static func notifications() async -> Status {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    private static func intelligence() -> Status {
        guard #available(iOS 26.0, *) else { return .unavailable("Needs iOS 26 or later") }
        switch SystemLanguageModel.default.availability {
        case .available: return .granted
        case .unavailable(.appleIntelligenceNotEnabled): return .needsSettings("Turn on in Settings")
        case .unavailable(.modelNotReady): return .unavailable("Downloading…")
        case .unavailable: return .unavailable("Not supported on this device")
        }
    }

    // MARK: Requests

    /// Asks for `feature` (or opens Settings if it was refused before).
    func request(_ feature: Feature, location provider: LocationProvider) async {
        switch status(of: feature) {
        case .denied, .needsSettings:
            openSettings()
            return
        case .granted, .unavailable:
            return
        case .notAsked:
            break
        }
        switch feature {
        case .camera:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        case .location:
            await provider.requestAuthorizationIfNeeded()
        case .notifications:
            // Time-sensitive so nearby-site alerts can break through Focus when allowed.
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        case .intelligence:
            openSettings()
        }
        await refresh()
    }

    /// Asks for everything not yet decided, one system prompt after another.
    func requestAll(location provider: LocationProvider) async {
        for feature in [Feature.camera, .location, .notifications] where status(of: feature) == .notAsked {
            await request(feature, location: provider)
        }
        await refresh()
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
