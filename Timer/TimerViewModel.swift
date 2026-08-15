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
    private(set) var isStarting = false
    private(set) var timeRemaining: TimeInterval = 0
    /// True only after the user has explicitly denied notification permission.
    private(set) var isNotificationDenied = false
    /// Set when `UNUserNotificationCenter` rejects the repeating reminder.
    private(set) var scheduleErrorMessage: String?

    /// The moment the current cycle ends. Recomputing `timeRemaining` from this
    /// date (rather than decrementing a counter every tick) keeps the display
    /// correct even after the Mac wakes from sleep.
    private var endDate: Date?
    private var intervalSeconds: TimeInterval = 0
    private var tickTask: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?

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

    func toggle() async {
        if isRunning {
            stop()
        } else {
            await start()
        }
    }

    /// Called when the menu-bar panel appears. Shows the denied banner
    /// immediately if permission was already refused; otherwise waits a
    /// second and then asks the system (only while status is still undetermined).
    func handlePanelAppeared() {
        authorizationTask?.cancel()
        authorizationTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshNotificationAuthorization(requestIfUndetermined: false)
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self.refreshNotificationAuthorization(requestIfUndetermined: true)
        }
    }

    func handlePanelDisappeared() {
        authorizationTask?.cancel()
        authorizationTask = nil
    }

    func refreshNotificationAuthorization(requestIfUndetermined: Bool = true) async {
        var state = await reminderScheduler.currentAuthorizationState()
        if requestIfUndetermined, state == .notDetermined {
            state = await reminderScheduler.requestAuthorization()
        }
        isNotificationDenied = (state == .denied)
    }

    func openNotificationSettings() {
        reminderScheduler.openSystemNotificationSettings()
    }

    func persistSelection() {
        defaults.set(selectedOption.rawValue, forKey: DefaultsKey.selectedOption)
        if let minutes = Int(customMinutesText) {
            defaults.set(minutes, forKey: DefaultsKey.customMinutes)
        }
    }

    func start() async {
        guard !isRunning, !isStarting, isCustomInputValid else { return }

        isStarting = true
        scheduleErrorMessage = nil
        defer { isStarting = false }

        let minutes = selectedOption == .custom ? (customMinutes ?? 30) : selectedOption.rawValue
        let seconds = TimeInterval(minutes * 60)

        do {
            try await reminderScheduler.scheduleRepeatingReminder(intervalSeconds: seconds, minutes: minutes)
        } catch {
            scheduleErrorMessage = "Couldn't schedule the notification."
            return
        }

        intervalSeconds = seconds
        endDate = now().addingTimeInterval(seconds)
        timeRemaining = seconds
        isRunning = true
        startTicking()
    }

    func stop() {
        isRunning = false
        isStarting = false
        tickTask?.cancel()
        tickTask = nil
        endDate = nil
        timeRemaining = 0
        scheduleErrorMessage = nil
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
