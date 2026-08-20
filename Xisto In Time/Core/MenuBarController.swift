//
//  MenuBarController.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import AppKit
import Observation
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
    private var labelHostingView: NSHostingView<AnyView>?

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
            let hosting = NSHostingView(rootView: AnyView(MenuBarLabel().environment(timerEngine)))
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

            labelHostingView = hosting
            refreshStatusItemWidth()
            observeLabelWidth(timerEngine: timerEngine)
        }

        if Preferences.openWindowOnLaunch() {
            windowController.show()
        }
    }

    /// `NSStatusItem.variableLength` only sizes the button from its own cell
    /// (title/image); it never re-measures an arbitrary hosted SwiftUI
    /// subview after the first layout. Without this, the button stays stuck
    /// at its initial (icon-only) width and any longer content (e.g. the
    /// running-session label) gets silently clipped instead of the item
    /// growing to fit it.
    private func observeLabelWidth(timerEngine: TimerEngine) {
        withObservationTracking {
            _ = timerEngine.isRunning
            _ = timerEngine.isPaused
            _ = timerEngine.currentTask?.project?.name
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.refreshStatusItemWidth()
                self?.observeLabelWidth(timerEngine: timerEngine)
            }
        }
    }

    private func refreshStatusItemWidth() {
        guard let labelHostingView else { return }
        labelHostingView.layoutSubtreeIfNeeded()
        statusItem.length = labelHostingView.fittingSize.width
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
