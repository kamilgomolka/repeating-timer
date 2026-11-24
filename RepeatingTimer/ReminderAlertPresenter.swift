//
//  ReminderAlertPresenter.swift
//  RepeatingTimer
//
//  Created by Kamil Gomolka on 24/11/2026.
//

import AppKit
import Observation
import SwiftUI

protocol ReminderPresenting {
    func showReminder(minutes: Int)
    func dismissReminder()
}

@Observable
private final class ReminderAlertContentModel {
    var minutes: Int

    init(minutes: Int) {
        self.minutes = minutes
    }

    var messageText: String {
        if minutes == 1 {
            return "1 minute passed."
        } else {
            return "\(minutes) minutes passed."
        }
    }
}

private struct ReminderAlertView: View {
    let model: ReminderAlertContentModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Repeating Timer")
                    .font(.headline)

                Text(model.messageText)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)
            }

            Button(action: onClose) {
                Text("Close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 280)
        .background {
            Button("") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

final class ReminderAlertPresenter: NSObject, ReminderPresenting, NSWindowDelegate {
    static let shared = ReminderAlertPresenter()

    private let contentModel = ReminderAlertContentModel(minutes: 15)
    private var panel: NSPanel?

    private override init() {
        super.init()
    }

    func showReminder(minutes: Int) {
        contentModel.minutes = minutes

        let alertPanel = existingOrNewPanel()

        if !alertPanel.isVisible {
            centerPanelOnActiveScreen(alertPanel)
        }

        NSApp.activate()
        alertPanel.makeKeyAndOrderFront(nil)
        alertPanel.orderFrontRegardless()
        NSSound(named: NSSound.Name("Glass"))?.play()
    }

    func dismissReminder() {
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }

    private func existingOrNewPanel() -> NSPanel {
        if let panel {
            return panel
        }

        let newPanel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 210),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        newPanel.title = "Repeating Timer"
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false
        newPanel.isReleasedWhenClosed = false
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true
        newPanel.delegate = self

        let rootView = ReminderAlertView(model: contentModel) { [weak self] in
            self?.dismissReminder()
        }

        newPanel.contentView = NSHostingView(rootView: rootView)
        panel = newPanel
        return newPanel
    }

    private func centerPanelOnActiveScreen(_ alertPanel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screenFrame = targetScreen?.visibleFrame else {
            alertPanel.center()
            return
        }

        let panelSize = alertPanel.frame.size
        let originX = screenFrame.midX - panelSize.width / 2
        let originY = screenFrame.midY - panelSize.height / 2
        alertPanel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
