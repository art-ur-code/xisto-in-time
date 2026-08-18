//
//  MenuBarController.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import AppKit
import SwiftData
import SwiftUI

/// Owns the actual `NSStatusItem`. Any click toggles the popover — the
/// popover's own "Xisto" header opens the main window, and Preferências/Sair
/// live in the main window's sidebar, so there's no separate right-click menu.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let mainWindowController: MainWindowController

    init(timerEngine: TimerEngine, pomodoro: PomodoroController, modelContext: ModelContext) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let windowController = MainWindowController {
            AnyView(
                MainWindowView()
                    .environment(timerEngine)
                    .environment(pomodoro)
                    .environment(\.modelContext, modelContext)
            )
        }
        mainWindowController = windowController

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(onOpenMainWindow: { [weak popover, weak windowController] in
                popover?.performClose(nil)
                windowController?.show()
            })
            .environment(timerEngine)
            .environment(pomodoro)
            .environment(\.modelContext, modelContext)
        )
        self.popover = popover

        super.init()

        if let button = statusItem.button {
            let hosting = NSHostingView(rootView: MenuBarLabel().environment(timerEngine))
            hosting.sizingOptions = [.intrinsicContentSize]
            hosting.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: button.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if Preferences.openWindowOnLaunch() {
            windowController.show()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
