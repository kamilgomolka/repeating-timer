//
//  RepeatingTimerTests.swift
//  RepeatingTimerTests
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import Foundation
import Testing
@testable import RepeatingTimer

@MainActor
private final class MockReminderPresenter: ReminderPresenting {
    private(set) var shownMinutes: [Int] = []
    private(set) var dismissCount = 0

    func showReminder(minutes: Int) {
        shownMinutes.append(minutes)
    }

    func dismissReminder() {
        dismissCount += 1
    }
}

@MainActor
private enum IsolatedDefaults {
    private static var pendingSuiteNames: [String] = []

    static func makeStore() -> UserDefaults {
        reap()
        let suiteName = "RepeatingTimerTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suiteName)!
        store.removePersistentDomain(forName: suiteName)
        pendingSuiteNames.append(suiteName)
        return store
    }

    static func reap() {
        for suiteName in pendingSuiteNames {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }

        pendingSuiteNames.removeAll()
    }
}

@MainActor
private func makeViewModel(
    presenter: MockReminderPresenter? = nil,
    defaults: UserDefaults? = nil,
    now: @escaping () -> Date = Date.init
) -> TimerViewModel {
    let store = defaults ?? IsolatedDefaults.makeStore()
    return TimerViewModel(reminderPresenter: presenter ?? MockReminderPresenter(), defaults: store, now: now)
}

@Suite(.serialized)
@MainActor
struct RepeatingTimerTests {

    @Test func defaultsToThirtyMinutesAndFortyFiveCustomMinutes() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectedOption == .thirty)
        #expect(viewModel.customMinutesText == "45")
        #expect(IntervalOption.allCases == [.ten, .fifteen, .thirty, .sixty, .custom])
    }

    @Test func startingWithFixedIntervalSetsRemainingWithoutShowingAlertImmediately() {
        let presenter = MockReminderPresenter()
        let viewModel = makeViewModel(presenter: presenter)
        viewModel.selectedOption = .thirty

        viewModel.start()

        let expectedSeconds: TimeInterval = 30 * 60
        #expect(viewModel.isRunning)
        #expect(viewModel.timeRemaining == expectedSeconds)
        #expect(presenter.shownMinutes.isEmpty)
    }

    @Test func stopResetsStateAndDismissesReminder() {
        let presenter = MockReminderPresenter()
        let viewModel = makeViewModel(presenter: presenter)
        viewModel.selectedOption = .fifteen

        viewModel.start()
        viewModel.stop()

        #expect(!viewModel.isRunning)
        #expect(viewModel.timeRemaining == 0)
        #expect(presenter.dismissCount == 1)
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

        currentDate.addTimeInterval(15 * 60 + 20)
        viewModel.tick()

        #expect(viewModel.isRunning)
        #expect(viewModel.timeRemaining == 15 * 60 - 20)
    }

    @Test func tickWithoutRolloverDoesNotShowReminder() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let presenter = MockReminderPresenter()
        let viewModel = makeViewModel(presenter: presenter, now: { currentDate })
        viewModel.selectedOption = .fifteen

        viewModel.start()
        currentDate.addTimeInterval(10)
        viewModel.tick()

        #expect(presenter.shownMinutes.isEmpty)
    }

    @Test func tickRolloverShowsReminderForActiveInterval() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let presenter = MockReminderPresenter()
        let viewModel = makeViewModel(presenter: presenter, now: { currentDate })
        viewModel.selectedOption = .fifteen

        viewModel.start()
        currentDate.addTimeInterval(15 * 60 + 5)
        viewModel.tick()

        #expect(presenter.shownMinutes == [15])
    }

    @Test func tickSkippingMultipleIntervalsShowsSingleReminder() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let presenter = MockReminderPresenter()
        let viewModel = makeViewModel(presenter: presenter, now: { currentDate })
        viewModel.selectedOption = .custom
        viewModel.customMinutesText = "1"

        viewModel.start()
        currentDate.addTimeInterval(30 * 60 + 15)
        viewModel.tick()

        #expect(presenter.shownMinutes == [1])
        #expect(viewModel.timeRemaining == 45)
    }

    @Test func persistedSelectionIsRestoredOnNextLaunch() {
        let store = IsolatedDefaults.makeStore()

        let first = makeViewModel(defaults: store)
        first.selectedOption = .custom
        first.customMinutesText = "20"
        first.persistSelection()

        let second = makeViewModel(defaults: store)
        #expect(second.selectedOption == .custom)
        #expect(second.customMinutesText == "20")
    }
}
