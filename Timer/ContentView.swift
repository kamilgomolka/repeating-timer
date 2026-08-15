//
//  ContentView.swift
//  Timer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: TimerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Picker("Interval", selection: $viewModel.selectedOption) {
                ForEach(IntervalOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Interval")
            .pickerStyle(.segmented)
            .disabled(viewModel.isRunning)
            .onChange(of: viewModel.selectedOption) { _, _ in
                viewModel.persistSelection()
            }

            if viewModel.selectedOption == .custom {
                TextField("Minutes", text: $viewModel.customMinutesText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .disabled(viewModel.isRunning)
                    .onChange(of: viewModel.customMinutesText) { _, newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(3))
                        if filtered != newValue {
                            viewModel.customMinutesText = filtered
                        }
                        viewModel.persistSelection()
                    }
            }

            Text(viewModel.formattedTimeRemaining)
                .font(.system(size: 56, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: viewModel.formattedTimeRemaining)

            Button {
                Task { await viewModel.toggle() }
            } label: {
                Text(viewModel.isRunning ? "Stop" : "Start")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRunning ? .red : .green)
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

            if viewModel.isNotificationDenied {
                VStack(spacing: 8) {
                    Text("App needs notifications permission.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)

                    Button("Enable in Settings") {
                        viewModel.openNotificationSettings()
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            Button("Quit application") {
                viewModel.stop()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.footnote)
        }
        .padding(16)
        .frame(width: 240)
        .onAppear {
            Task { await viewModel.handlePanelAppeared() }
        }
    }
}

#Preview {
    ContentView(viewModel: TimerViewModel(reminderScheduler: PreviewReminderScheduler()))
}

private struct PreviewReminderScheduler: ReminderScheduling {
    func currentAuthorizationState() async -> NotificationAuthorizationState { .authorized }
    func requestAuthorization() async -> NotificationAuthorizationState { .authorized }
    func scheduleReminder(intervalSeconds: TimeInterval, minutes: Int) async throws {}
    func cancelReminder() {}
    func openSystemNotificationSettings() {}
}
