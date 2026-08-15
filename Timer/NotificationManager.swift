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
    func scheduleRepeatingReminder(intervalSeconds: TimeInterval, minutes: Int)
    func cancelReminder()
    func openSystemNotificationSettings()
}

/// Schedules a single, system-repeating local notification for the interval
/// reminder. Using `repeats: true` on `UNTimeIntervalNotificationTrigger`
/// means the OS keeps firing the reminder on its own, independent of whether
/// the app is actively ticking (e.g. right after the Mac wakes from sleep).
@MainActor
final class NotificationManager: ReminderScheduling {
    static let shared = NotificationManager()

    private let reminderIdentifier = "com.kamil.timer.interval-reminder"
    private let center = UNUserNotificationCenter.current()

    private init() {}

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

    func scheduleRepeatingReminder(intervalSeconds: TimeInterval, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Timer"
        content.body = "Minęło \(minutes) min."
        content.sound = .default

        // UNTimeIntervalNotificationTrigger requires >= 60s when repeating,
        // which every selectable interval (min. 1 custom minute) satisfies.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: intervalSeconds, repeats: true)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        center.add(request)
    }

    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
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
