//
//  MainWindowController.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import AppKit
import SwiftUI

/// Owns the main ("Xisto") window as a plain AppKit window, shown on demand
/// from the menu bar's right-click menu. Kept alive (not released on close)
/// so re-showing it doesn't need to rebuild the SwiftUI hierarchy each time.
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let makeContent: () -> AnyView

    init(makeContent: @escaping () -> AnyView) {
        self.makeContent = makeContent
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: makeContent())
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "Xisto"
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.setContentSize(NSSize(width: 700, height: 480))
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        window = newWindow
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
    }
}
