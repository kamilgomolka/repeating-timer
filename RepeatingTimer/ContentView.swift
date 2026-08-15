//
//  ContentView.swift
//  RepeatingTimer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: TimerViewModel

    var body: some View {
        Group {
            if viewModel.isNotificationDenied {
                permissionDeniedView
            } else {
                timerView
            }
        }
        .padding(.horizontal, 28)
        .frame(width: 320)
        .onAppear {
            Task { await viewModel.handleWindowAppeared() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.handleAppForegrounded() }
        }
    }

    private var timerView: some View {
        VStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose repeat interval:")
                    .font(.title2).bold()
                    .foregroundStyle(viewModel.isRunning ? Color.secondary : Color.primary)

                Picker("Choose repeat interval", selection: $viewModel.selectedOption) {
                    ForEach(IntervalOption.allCases) { option in
                        Text(option.label).font(.title3).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
                .disabled(viewModel.isRunning)
                .onChange(of: viewModel.selectedOption) { _, _ in
                    viewModel.persistSelection()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.selectedOption == .custom {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom value (minutes):")
                        .font(.title2).bold()
                        .foregroundStyle(viewModel.isRunning ? Color.secondary : Color.primary)
                    
                    TextField("Minutes", text: $viewModel.customMinutesText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.leading)
                        .disabled(viewModel.isRunning)
                        .onChange(of: viewModel.customMinutesText) { _, newValue in
                            let filtered = String(newValue.filter(\.isNumber).prefix(3))
                            if filtered != newValue {
                                viewModel.customMinutesText = filtered
                            }
                            viewModel.persistSelection()
                        }
                }
            }

            Text(viewModel.formattedTimeRemaining)
                .font(.system(size: viewModel.isRunning ? 56 : 44, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(viewModel.isRunning ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 66.0)            
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: viewModel.isRunning)
                .animation(.default, value: viewModel.formattedTimeRemaining)

            Button {
                Task { await viewModel.toggle() }
            } label: {
                Label(
                    viewModel.isRunning ? "Stop" : "Start timer",
                    systemImage: viewModel.isRunning ? "stop.fill" : "play.fill"
                )
                .font(.title2)
                .bold()
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRunning ? .red : .blue)
            .controlSize(.large)
            .disabled(viewModel.isStarting || (!viewModel.isRunning && !viewModel.isCustomInputValid))

            if let scheduleErrorMessage = viewModel.scheduleErrorMessage {
                Text(scheduleErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 32)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.red)
                .accessibilityHidden(true)

            Text("This application needs \"Notifications\" permission in order to show timer pop-up.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Enable in Settings") {
                viewModel.openNotificationSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Repeating Timer") {
    ContentView(viewModel: TimerViewModel(reminderScheduler: PreviewReminderScheduler()))
}

#Preview("Permission denied") {
    ContentView(viewModel: TimerViewModel(reminderScheduler: DeniedPreviewReminderScheduler()))
}

private struct PreviewReminderScheduler: ReminderScheduling {
    func currentAuthorizationState() async -> NotificationAuthorizationState { .authorized }
    func requestAuthorization() async -> NotificationAuthorizationState { .authorized }
    func scheduleReminder(intervalSeconds: TimeInterval, minutes: Int) async throws {}
    func cancelReminder() {}
    func openSystemNotificationSettings() {}
}

private struct DeniedPreviewReminderScheduler: ReminderScheduling {
    func currentAuthorizationState() async -> NotificationAuthorizationState { .denied }
    func requestAuthorization() async -> NotificationAuthorizationState { .denied }
    func scheduleReminder(intervalSeconds: TimeInterval, minutes: Int) async throws {}
    func cancelReminder() {}
    func openSystemNotificationSettings() {}
}
