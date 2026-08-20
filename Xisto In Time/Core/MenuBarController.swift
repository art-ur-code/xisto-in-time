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

/// Owns the actual `NSStatusItem`. Left click toggles the popover panel — the
/// popover's own "Hoje" header opens the main window, and Preferências/Sair
/// live in the main window's sidebar. Right click shows a small context menu
/// ("Abrir janela" / "Sair") instead of the popover.
///
/// The popover is a plain `NSPanel`, not an `NSPopover` — an `NSPopover`
/// occasionally recomputed its position from a stale size while this view's
/// content was resizing (mode legend, Pomodoro config, task picker),
/// landing off-screen. A panel we position ourselves sidesteps that:
/// position is either the last place the user dragged it to
/// (`isMovableByWindowBackground`, persisted via `Preferences.setPopoverOrigin`)
/// or freshly computed under the status item — never a leftover value.
@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    private let mainWindowController: MainWindowController
    private var labelHostingView: NSHostingView<AnyView>?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

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

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        self.panel = panel

        super.init()

        panel.delegate = self
        panel.contentViewController = NSHostingController(
            rootView: PopoverView(onOpenMainWindow: { [weak panel, weak windowController] in
                panel?.orderOut(nil)
                windowController?.show()
            })
            .environment(timerEngine)
            .environment(pomodoro)
            .environment(\.modelContext, modelContext)
        )

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
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(for: button)
            return
        }
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel(relativeTo: button)
        }
    }

    private func showPanel(relativeTo button: NSStatusBarButton) {
        guard let contentView = panel.contentViewController?.view else { return }
        contentView.layoutSubtreeIfNeeded()
        let size = contentView.fittingSize
        let origin = validOrigin(for: size) ?? defaultOrigin(for: button, size: size)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.makeKeyAndOrderFront(nil)
        installClickOutsideMonitors()
    }

    private func hidePanel() {
        panel.orderOut(nil)
        removeClickOutsideMonitors()
    }

    /// The saved drag position, discarded if it no longer falls on any
    /// connected screen (e.g. a monitor was unplugged since).
    private func validOrigin(for size: NSSize) -> NSPoint? {
        guard let saved = Preferences.popoverOrigin() else { return nil }
        let frame = NSRect(origin: saved, size: size)
        guard NSScreen.screens.contains(where: { $0.frame.intersects(frame) }) else { return nil }
        return saved
    }

    private func defaultOrigin(for button: NSStatusBarButton, size: NSSize) -> NSPoint {
        guard let buttonWindow = button.window else { return .zero }
        let buttonFrameOnScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let x = buttonFrameOnScreen.midX - size.width / 2
        let y = buttonFrameOnScreen.minY - size.height - 4
        return NSPoint(x: x, y: y)
    }

    /// Replicates `NSPopover`'s "click outside to dismiss" — a plain
    /// `NSPanel` has no such behavior built in. The status item's own
    /// button is excluded so this never races with `togglePopover`'s own
    /// show/hide decision (which already handles clicks on the icon).
    private func installClickOutsideMonitors() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissIfClickedOutside()
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissIfClickedOutside()
            return event
        }
    }

    private func removeClickOutsideMonitors() {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        globalClickMonitor = nil
        localClickMonitor = nil
    }

    /// A click inside the panel itself must never dismiss it — that
    /// includes the mouseDown that starts an `isMovableByWindowBackground`
    /// drag, which otherwise got treated as an "outside" click and hid the
    /// panel the instant a drag began.
    private func dismissIfClickedOutside() {
        let location = NSEvent.mouseLocation
        if panel.frame.contains(location) { return }
        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonFrameOnScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if buttonFrameOnScreen.contains(location) { return }
        }
        hidePanel()
    }

    func windowDidMove(_ notification: Notification) {
        guard (notification.object as? NSPanel) === panel else { return }
        Preferences.setPopoverOrigin(panel.frame.origin)
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Abrir janela", action: #selector(openMainWindowFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Sair", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func openMainWindowFromMenu() {
        showMainWindow()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    /// Used by `AppDelegate.applicationShouldHandleReopen` so relaunching the
    /// app (e.g. via Spotlight) while it's already running shows the main
    /// window, even though it has no Dock icon (`LSUIElement`).
    func showMainWindow() {
        mainWindowController.show()
    }
}
