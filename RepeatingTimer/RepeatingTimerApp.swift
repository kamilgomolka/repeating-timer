//
//  RepeatingTimerApp.swift
//  RepeatingTimer
//
//  Created by Kamil Gomolka on 15/08/2026.
//

import AppKit
import SwiftUI

@MainActor
final class RepeatingTimerAppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: TimerViewModel?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Install UNUserNotificationCenterDelegate before any reminder can fire.
        _ = NotificationManager.shared
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { await viewModel?.handleAppForegrounded() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stop()
    }
}

@main
struct RepeatingTimerApp: App {
    @NSApplicationDelegateAdaptor(RepeatingTimerAppDelegate.self) private var appDelegate
    @State private var viewModel = TimerViewModel()

    var body: some Scene {
        WindowGroup("Repeating Timer") {
            ContentView(viewModel: viewModel)
                .onAppear { appDelegate.viewModel = viewModel }
        }
        .defaultSize(width: 320, height: 460)
    }
}
