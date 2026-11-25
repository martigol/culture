//
//  NearbySiteAlerts.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import CoreLocation
import Foundation
import Observation
import UserNotifications

/// "You're 2 km from the Parthenon" — a local notification the moment the
/// user comes within reach of a historical site, written to make the detour
/// irresistible.
///
/// Uses `UNLocationNotificationTrigger`: iOS itself watches a circle around
/// each site and posts the alert on entry, even when the app isn't running.
/// That needs only "While Using" location access, and nothing leaves the
/// device. Actions: open the story, or get directions.
@Observable
@MainActor
final class NearbySiteAlerts: NSObject {
    /// User preference (Settings / permissions screen). Remembered.
    private(set) var isEnabled: Bool

    /// Distance from a site at which the alert fires.
    static let radius: CLLocationDistance = 2_000

    static let category = "nearby-site"
    static let readAction = "read-story"
    static let directionsAction = "directions"
    private static let idPrefix = "nearby."
    private static let enabledKey = "nearbyAlertsEnabled"

    /// Set by the app to handle a tapped notification (open the story).
    @ObservationIgnored var onOpenStory: ((Story.ID) -> Void)?
    /// Set by the app to handle "Take me there".
    @ObservationIgnored var onDirections: ((Story.ID) -> Void)?

    private var center: UNUserNotificationCenter { .current() }

    override init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        super.init()
    }

    /// Registers the actions and becomes the notification delegate. Call once at launch.
    func configure() {
        let read = UNNotificationAction(identifier: Self.readAction, title: "Tell me the story", options: [.foreground])
        let go = UNNotificationAction(identifier: Self.directionsAction, title: "Take me there", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [go, read], intentIdentifiers: [], options: []),
        ])
        center.delegate = self
    }

    func setEnabled(_ enabled: Bool, sites: [Story]) async {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        await refresh(sites: sites)
    }

    /// (Re)schedules one alert per site, or clears them when off / not permitted.
    func refresh(sites: [Story]) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let settings = await center.notificationSettings()
        let location = CLLocationManager().authorizationStatus
        guard isEnabled,
              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
              location == .authorizedWhenInUse || location == .authorizedAlways else { return }

        // iOS allows 64 pending local notifications; 20 regions is plenty here.
        for story in sites.prefix(20) {
            let region = CLCircularRegion(center: story.location.coordinate, radius: Self.radius,
                                          identifier: Self.idPrefix + story.id)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
            let request = UNNotificationRequest(identifier: region.identifier,
                                                content: Self.content(for: story), trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                Log.app.error("Couldn't schedule nearby alert: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Copy

    /// The alert itself: distance up front, then a hook that makes going feel urgent.
    static func content(for story: Story) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let distance = radius.distanceLabel
        let walk = Int((radius / 80).rounded()) // ~80 m a minute on foot
        content.title = "\(story.title) is \(distance) away"
        content.subtitle = "About \(walk) minutes on foot · \(story.era)"
        content.body = hooks[story.id] ?? fallbackHook(for: story)
        content.sound = .default
        content.categoryIdentifier = category
        content.threadIdentifier = "nearby-sites"
        content.userInfo = ["storyID": story.id]
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 0.9
        return content
    }

    private static func fallbackHook(for story: Story) -> String {
        "You may never be this close again. \(story.summary) Go and stand where it happened — the story is waiting in your pocket."
    }

    /// One irresistible reason per site to change plans right now.
    private static let hooks: [Story.ID: String] = [
        "parthenon": "Twenty-five centuries of history, just up the hill. Catch the marble turning gold at sunset — you'll remember it long after this trip.",
        "delphi": "The navel of the world is right here. Kings crossed seas to hear Apollo's oracle; you only need to cross the road.",
        "sounion": "This is the cliff where King Aegeus watched for white sails. Sunset over Poseidon's temple is one of the most beautiful sights in Greece — and it starts soon.",
        "knossos": "The Labyrinth of the Minotaur is minutes away. Walk the palace where Theseus followed Ariadne's thread out of the dark.",
        "zeus": "A god pulled from the sea after 2,000 years is waiting nearby. Stand in front of him and decide: Zeus or Poseidon?",
        "agamemnon": "Gold that has outlived empires is just around the corner. Look into the face Schliemann swore was Agamemnon's.",
        "mycenae": "The Lion Gate has guarded this citadel for 3,000 years. Walk through it, the way Agamemnon did on his last homecoming.",
        "nike": "Winged Victory landed here first. See the island that gave the world one of its most famous statues.",
        "epidaurus": "Drop a coin on the stage and hear it from the top row. You're close enough to try it today.",
        "charioteer": "The bronze charioteer still holds his reins after 2,500 years. His glass eyes are waiting to meet yours.",
        "medusa": "Meet Medusa's gaze — safely. She's closer than you think, and she's been waiting a very long time.",
        "olympia": "Run the stadium where the very first Olympians raced in 776 BC. Your sprint will join one of history's oldest finish lines.",
    ]

    // MARK: Preview / test

    /// Posts the alert for `story` in 3 seconds — to try the copy without travelling.
    func sendTest(for story: Story) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "test.\(story.id)", content: Self.content(for: story), trigger: trigger)
        try? await center.add(request)
    }
}

extension NearbySiteAlerts: UNUserNotificationCenterDelegate {
    /// Show the banner even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let storyID = response.notification.request.content.userInfo["storyID"] as? String else { return }
        let action = response.actionIdentifier
        await MainActor.run {
            if action == Self.directionsAction {
                onDirections?(storyID)
            } else {
                onOpenStory?(storyID)
            }
        }
    }
}
