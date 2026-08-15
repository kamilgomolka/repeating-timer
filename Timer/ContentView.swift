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
                viewModel.toggle()
            } label: {
                Text(viewModel.isRunning ? "Stop" : "Start")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRunning ? .red : .green)
            .controlSize(.large)
            .disabled(!viewModel.isRunning && !viewModel.isCustomInputValid)

            Divider()

            Button("Zamknij aplikację") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.footnote)
        }
        .padding(16)
        .frame(width: 240)
    }
}

#Preview {
    ContentView(viewModel: TimerViewModel())
}
