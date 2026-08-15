//
//  NotificationManager.swift
//  Timer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import AppKit
import Foundation
import UserNotifications

enum NotificationAuthorizationState {
    case notDetermined
    case denied
    case authorized
}

/// Abstraction over `UNUserNotificationCenter` so `TimerViewModel` can be
/// unit-tested without touching the real notification system.
protocol ReminderScheduling {
    func currentAuthorizationState() async -> NotificationAuthorizationState
    func requestAuthorization() async -> NotificationAuthorizationState
    func scheduleReminder(intervalSeconds: TimeInterval, minutes: Int) async throws
    func cancelReminder()
    func openSystemNotificationSettings()
}

/// Schedules one-shot local notifications for the interval reminder, one per
/// cycle, each with a fresh, unique identifier.
///
/// A single `UNTimeIntervalNotificationTrigger(repeats: true)` would be
/// simpler, but macOS's Notification Center coalesces repeat deliveries that
/// reuse the same request identifier: if the previous banner from that
/// identifier hasn't been dismissed yet, the next occurrence silently updates
/// it in place instead of alerting again (no banner, no sound). Rescheduling
/// a brand-new request every cycle — driven by `TimerViewModel.tick()` on
/// each rollover — sidesteps that entirely, since every occurrence is a
/// distinct notification as far as the system is concerned.
///
/// The previous cycle's request is intentionally left alone at rollover.
/// Clearing it in the same second it fires removes the banner (the sound
/// can still play) and can cancel a pending request that hasn't fired yet.
@MainActor
final class NotificationManager: NSObject, ReminderScheduling, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Identifiers used by earlier builds, cleaned up defensively so a stale
    /// pending/delivered notification from a previous version doesn't linger.
    private let legacyReminderIdentifiers = [
        "kamil.gomolka.Timer.interval-reminder",
        "com.kamil.timer.interval-reminder",
    ]
    private let center = UNUserNotificationCenter.current()
    private var currentIdentifier: String?

    private override init() {
        super.init()
        center.delegate = self
    }

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        Self.map(await center.notificationSettings().authorizationStatus)
    }

    func requestAuthorization() async -> NotificationAuthorizationState {
        NSApp.activate()

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Fall through to whatever the current settings report.
        }
        return await currentAuthorizationState()
    }

    func scheduleReminder(intervalSeconds: TimeInterval, minutes: Int) async throws {
        // Do not cancel or remove the previous cycle's notification here.
        // Rollover happens in the same second the current request fires, so
        // clearing it would swallow the banner (sound can still play) and
        // cancel a still-pending next request scheduled slightly after endDate.
        let delay = max(intervalSeconds, 0.1)
        let identifier = UUID().uuidString

        let content = UNMutableNotificationContent()
        content.title = "Repeating Timer"
        content.body = "\(minutes) min passed."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await center.add(request)
        currentIdentifier = identifier
    }

    func cancelReminder() {
        clearCurrentIdentifier()
        center.removePendingNotificationRequests(withIdentifiers: legacyReminderIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: legacyReminderIdentifiers)
    }

    func openSystemNotificationSettings() {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleId)",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func clearCurrentIdentifier() {
        guard let identifier = currentIdentifier else { return }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        currentIdentifier = nil
    }

    private static func map(_ status: UNAuthorizationStatus) -> NotificationAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional, .ephemeral:
            .authorized
        @unknown default:
            .authorized
        }
    }
}
