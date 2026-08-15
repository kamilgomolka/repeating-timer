//
//  TimerViewModel.swift
//  Timer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class TimerViewModel {
    private enum DefaultsKey {
        static let selectedOption = "selectedIntervalOption"
        static let customMinutes = "customIntervalMinutes"
    }

    static let customMinutesRange = 1...600

    var selectedOption: IntervalOption
    var customMinutesText: String

    private(set) var isRunning = false
    private(set) var timeRemaining: TimeInterval = 0

    /// The moment the current cycle ends. Recomputing `timeRemaining` from this
    /// date (rather than decrementing a counter every tick) keeps the display
    /// correct even after the Mac wakes from sleep.
    private var endDate: Date?
    private var intervalSeconds: TimeInterval = 0
    private var tickTask: Task<Void, Never>?

    private let reminderScheduler: ReminderScheduling
    private let defaults: UserDefaults
    private let now: () -> Date

    init(
        reminderScheduler: ReminderScheduling = NotificationManager.shared,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.reminderScheduler = reminderScheduler
        self.defaults = defaults
        self.now = now

        if let rawValue = defaults.object(forKey: DefaultsKey.selectedOption) as? Int,
           let savedOption = IntervalOption(rawValue: rawValue) {
            selectedOption = savedOption
        } else {
            selectedOption = .thirty
        }

        if let savedMinutes = defaults.object(forKey: DefaultsKey.customMinutes) as? Int {
            customMinutesText = String(savedMinutes)
        } else {
            customMinutesText = "45"
        }

        reminderScheduler.requestAuthorizationIfNeeded()
        // Clear any reminder left scheduled from a previous session (e.g. the
        // app was force-quit while running) so state stays consistent with UI,
        // which always starts stopped.
        reminderScheduler.cancelReminder()
    }

    var customMinutes: Int? {
        guard let value = Int(customMinutesText), Self.customMinutesRange.contains(value) else { return nil }
        return value
    }

    var isCustomInputValid: Bool {
        selectedOption != .custom || customMinutes != nil
    }

    private var previewSeconds: TimeInterval {
        let minutes = selectedOption == .custom ? (customMinutes ?? 0) : selectedOption.rawValue
        return TimeInterval(minutes * 60)
    }

    var formattedTimeRemaining: String {
        let total = max(0, Int((isRunning ? timeRemaining : previewSeconds).rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    func persistSelection() {
        defaults.set(selectedOption.rawValue, forKey: DefaultsKey.selectedOption)
        if let minutes = Int(customMinutesText) {
            defaults.set(minutes, forKey: DefaultsKey.customMinutes)
        }
    }

    func start() {
        guard !isRunning, isCustomInputValid else { return }

        let minutes = selectedOption == .custom ? (customMinutes ?? 30) : selectedOption.rawValue
        intervalSeconds = TimeInterval(minutes * 60)
        endDate = now().addingTimeInterval(intervalSeconds)
        timeRemaining = intervalSeconds
        isRunning = true

        reminderScheduler.scheduleRepeatingReminder(intervalSeconds: intervalSeconds, minutes: minutes)
        startTicking()
    }

    func stop() {
        isRunning = false
        tickTask?.cancel()
        tickTask = nil
        endDate = nil
        timeRemaining = 0
        reminderScheduler.cancelReminder()
    }

    /// Recomputes the remaining time from `endDate`. When a cycle elapses,
    /// rolls `endDate` forward by whole intervals to stay in phase with the
    /// repeating system notification, then keeps counting down to the next one.
    func tick() {
        guard let currentEndDate = endDate else { return }

        var nextEndDate = currentEndDate
        while nextEndDate.timeIntervalSince(now()) <= 0 {
            nextEndDate = nextEndDate.addingTimeInterval(intervalSeconds)
        }
        endDate = nextEndDate
        timeRemaining = nextEndDate.timeIntervalSince(now())
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
