//
//  TimerTests.swift
//  TimerTests
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import Foundation
import Testing
@testable import Timer

@MainActor
private final class MockReminderScheduler: ReminderScheduling {
    var authorizationState: NotificationAuthorizationState = .authorized
    private(set) var scheduledIntervals: [(seconds: TimeInterval, minutes: Int)] = []
    private(set) var cancelCount = 0
    private(set) var requestCount = 0
    private(set) var openSettingsCount = 0

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        authorizationState
    }

    func requestAuthorization() async -> NotificationAuthorizationState {
        requestCount += 1
        return authorizationState
    }

    func scheduleRepeatingReminder(intervalSeconds: TimeInterval, minutes: Int) {
        scheduledIntervals.append((intervalSeconds, minutes))
    }

    func cancelReminder() {
        cancelCount += 1
    }

    func openSystemNotificationSettings() {
        openSettingsCount += 1
    }
}

@MainActor
private func makeViewModel(
    scheduler: MockReminderScheduler? = nil,
    defaults: UserDefaults? = nil,
    now: @escaping () -> Date = Date.init
) -> TimerViewModel {
    let suiteName = "TimerTests.\(UUID().uuidString)"
    let store = defaults ?? UserDefaults(suiteName: suiteName)!
    return TimerViewModel(reminderScheduler: scheduler ?? MockReminderScheduler(), defaults: store, now: now)
}

@Suite(.serialized)
@MainActor
struct TimerTests {

    @Test func startingWithFixedIntervalSchedulesReminderAndSetsRemaining() {
        let scheduler = MockReminderScheduler()
        let viewModel = makeViewModel(scheduler: scheduler)
        viewModel.selectedOption = .thirty

        viewModel.start()

        let expectedSeconds: TimeInterval = 30 * 60
        #expect(viewModel.isRunning)
        #expect(viewModel.timeRemaining == expectedSeconds)
        #expect(scheduler.scheduledIntervals.last?.seconds == expectedSeconds)
        #expect(scheduler.scheduledIntervals.last?.minutes == 30)
    }

    @Test func stopResetsStateAndCancelsReminder() {
        let scheduler = MockReminderScheduler()
        let viewModel = makeViewModel(scheduler: scheduler)
        viewModel.selectedOption = .fifteen
        // TimerViewModel.init() already cancels any stale reminder left over
        // from a previous session, so the baseline is not necessarily 0.
        let cancelCountBeforeStop = scheduler.cancelCount

        viewModel.start()
        viewModel.stop()

        #expect(!viewModel.isRunning)
        #expect(viewModel.timeRemaining == 0)
        #expect(scheduler.cancelCount == cancelCountBeforeStop + 1)
    }

    @Test func customIntervalRequiresValidNumberBeforeStart() {
        let viewModel = makeViewModel()
        viewModel.selectedOption = .custom
        viewModel.customMinutesText = ""

        #expect(!viewModel.isCustomInputValid)
        viewModel.start()
        #expect(!viewModel.isRunning)

        viewModel.customMinutesText = "45"
        #expect(viewModel.isCustomInputValid)
        viewModel.start()
        #expect(viewModel.isRunning)
    }

    @Test func customIntervalOutOfRangeIsInvalid() {
        let viewModel = makeViewModel()
        viewModel.selectedOption = .custom
        viewModel.customMinutesText = "0"
        #expect(!viewModel.isCustomInputValid)

        viewModel.customMinutesText = "601"
        #expect(!viewModel.isCustomInputValid)

        viewModel.customMinutesText = "600"
        #expect(viewModel.isCustomInputValid)
    }

    @Test func tickCountsDownUsingInjectedClock() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let viewModel = makeViewModel(now: { currentDate })
        viewModel.selectedOption = .fifteen

        viewModel.start()
        #expect(viewModel.timeRemaining == 15 * 60)

        currentDate.addTimeInterval(10)
        viewModel.tick()
        #expect(viewModel.timeRemaining == 15 * 60 - 10)
    }

    @Test func tickRollsOverToNextCycleWhenElapsed() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let viewModel = makeViewModel(now: { currentDate })
        viewModel.selectedOption = .fifteen

        viewModel.start()

        // Jump well past the first cycle's end.
        currentDate.addTimeInterval(15 * 60 + 20)
        viewModel.tick()

        #expect(viewModel.isRunning)
        #expect(viewModel.timeRemaining == 15 * 60 - 20)
    }

    @Test func persistedSelectionIsRestoredOnNextLaunch() {
        let suiteName = "TimerTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suiteName)!

        let first = makeViewModel(defaults: store)
        first.selectedOption = .custom
        first.customMinutesText = "20"
        first.persistSelection()

        let second = makeViewModel(defaults: store)
        #expect(second.selectedOption == .custom)
        #expect(second.customMinutesText == "20")
    }

    @Test func refreshRequestsAuthorizationWhenNotDetermined() async {
        let scheduler = MockReminderScheduler()
        scheduler.authorizationState = .notDetermined
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.refreshNotificationAuthorization()

        #expect(scheduler.requestCount == 1)
        #expect(!viewModel.isNotificationDenied)
    }

    @Test func refreshSkipsRequestWhenToldNotToAsk() async {
        let scheduler = MockReminderScheduler()
        scheduler.authorizationState = .notDetermined
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.refreshNotificationAuthorization(requestIfUndetermined: false)

        #expect(scheduler.requestCount == 0)
        #expect(!viewModel.isNotificationDenied)
    }

    @Test func refreshDoesNotRequestWhenAlreadyAuthorized() async {
        let scheduler = MockReminderScheduler()
        scheduler.authorizationState = .authorized
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.refreshNotificationAuthorization()

        #expect(scheduler.requestCount == 0)
        #expect(!viewModel.isNotificationDenied)
    }

    @Test func refreshMarksDeniedWithoutRequestingAgain() async {
        let scheduler = MockReminderScheduler()
        scheduler.authorizationState = .denied
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.refreshNotificationAuthorization()

        #expect(scheduler.requestCount == 0)
        #expect(viewModel.isNotificationDenied)
    }
}
