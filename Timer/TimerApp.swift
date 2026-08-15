//
//  TimerApp.swift
//  Timer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import SwiftUI

@main
struct TimerApp: App {
    @State private var viewModel = TimerViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
        } label: {
            Label {
                if viewModel.isRunning {
                    Text(viewModel.formattedTimeRemaining)
                        .monospacedDigit()
                }
            } icon: {
                Image(systemName: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
