//
//  GeoPoint.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import CoreLocation
import MapKit

/// A latitude/longitude pair that is `Hashable`, `Codable` and `Sendable`
/// (unlike `CLLocationCoordinate2D`), so it can live in models and on disk.
struct GeoPoint: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    init(_ latitude: Double, _ longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(coordinate.latitude, coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Great-circle distance in metres.
    func distance(to other: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    /// "37.9715° N · 23.7267° E"
    var formatted: String {
        let lat = String(format: "%.4f° %@", abs(latitude), latitude >= 0 ? "N" : "S")
        let lon = String(format: "%.4f° %@", abs(longitude), longitude >= 0 ? "E" : "W")
        return "\(lat) · \(lon)"
    }

    /// Apple Maps link (opens the Maps app on device).
    func appleMapsURL(name: String) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: name),
        ]
        return components?.url
    }
}

extension MKCoordinateRegion {
    /// Smallest region showing every point, padded, never tighter than `minimumSpan` degrees.
    static func fitting(_ points: [GeoPoint], padding: Double = 1.6, minimumSpan: Double = 0.02) -> MKCoordinateRegion? {
        guard let first = points.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for p in points.dropFirst() {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: min(max((maxLat - minLat) * padding, minimumSpan), 170),
            longitudeDelta: min(max((maxLon - minLon) * padding, minimumSpan), 350)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

extension CLLocationDistance {
    /// "312 km away" / "850 m away", in the user's units.
    var awayLabel: String { "\(distanceLabel) away" }

    /// "312 km" / "850 m", in the user's units.
    var distanceLabel: String {
        Measurement(value: self, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
