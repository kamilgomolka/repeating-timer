//
//  NotificationManager.swift
//  Timer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import Foundation
import UserNotifications

/// Abstraction over `UNUserNotificationCenter` so `TimerViewModel` can be
/// unit-tested without touching the real notification system.
protocol ReminderScheduling {
    func requestAuthorizationIfNeeded()
    func scheduleRepeatingReminder(intervalSeconds: TimeInterval, minutes: Int)
    func cancelReminder()
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

    func requestAuthorizationIfNeeded() {
        Task {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func scheduleRepeatingReminder(intervalSeconds: TimeInterval, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Timer"
        content.body = "Upłynęło \(minutes) min."
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
}
