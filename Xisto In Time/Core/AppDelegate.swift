//
//  AppDelegate.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 20/08/2026.
//

import AppKit

/// `applicationShouldHandleReopen` is AppKit's hook for "the app is already
/// running and something (Finder, Dock, Spotlight) tried to open it again" —
/// it fires regardless of `LSUIElement` hiding the Dock icon, which is why
/// relaunching via Spotlight can still bring the main window forward.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onReopen: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        onReopen?()
        return true
    }
}
