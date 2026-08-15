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
    func scheduleRepeatingReminder(intervalSeconds: TimeInterval, minutes: Int) async throws
    func cancelReminder()
    func openSystemNotificationSettings()
}

/// Schedules a single, system-repeating local notification for the interval
/// reminder. Using `repeats: true` on `UNTimeIntervalNotificationTrigger`
/// means the OS keeps firing the reminder on its own, independent of whether
/// the app is actively ticking (e.g. right after the Mac wakes from sleep).
@MainActor
final class NotificationManager: NSObject, ReminderScheduling, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let reminderIdentifier = "com.kamil.timer.interval-reminder"
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        Self.map(await center.notificationSettings().authorizationStatus)
    }

    func requestAuthorization() async -> NotificationAuthorizationState {
        // Menu-bar apps (LSUIElement) are never frontmost on their own.
        // Activating first makes the system permission alert actually appear.
        NSApp.activate()

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Fall through to whatever the current settings report.
        }
        return await currentAuthorizationState()
    }

    func scheduleRepeatingReminder(intervalSeconds: TimeInterval, minutes: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Timer"
        content.body = "\(minutes) min have passed."
        content.sound = .default

        // UNTimeIntervalNotificationTrigger requires >= 60s when repeating,
        // which every selectable interval (min. 1 custom minute) satisfies.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: intervalSeconds, repeats: true)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        try await center.add(request)
    }

    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
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
