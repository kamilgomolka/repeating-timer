//
//  TimerApp.swift
//  Timer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import AppKit
import SwiftUI

@MainActor
final class TimerAppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: TimerViewModel?

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stop()
    }
}

@main
struct TimerApp: App {
    @NSApplicationDelegateAdaptor(TimerAppDelegate.self) private var appDelegate
    @State private var viewModel = TimerViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
                .onAppear { appDelegate.viewModel = viewModel }
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
