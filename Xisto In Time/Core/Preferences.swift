//
//  Preferences.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import Foundation

enum PreferencesKey {
    static let openWindowOnLaunch = "openWindowOnLaunch"
    static let pomodoroWorkMinutes = "pomodoroWorkMinutes"
    static let pomodoroShortBreakMinutes = "pomodoroShortBreakMinutes"
    static let pomodoroLongBreakMinutes = "pomodoroLongBreakMinutes"
    static let pomodoroCyclesBeforeLongBreak = "pomodoroCyclesBeforeLongBreak"
    static let idleDetectionEnabled = "idleDetectionEnabled"
    static let idleThresholdMinutes = "idleThresholdMinutes"
    static let idleResolutionMode = "idleResolutionMode"
    static let reportsShowWeekend = "reportsShowWeekend"
    static let notePreviewSize = "notePreviewSize"
    static let lastSessionMode = "lastSessionMode"
    static let sidebarWidth = "sidebarWidth"
    static let popoverOriginX = "popoverOriginX"
    static let popoverOriginY = "popoverOriginY"
}

enum PreferencesDefault {
    static let openWindowOnLaunch = true
    static let pomodoroWorkMinutes = 25
    static let pomodoroShortBreakMinutes = 5
    static let pomodoroLongBreakMinutes = 15
    static let pomodoroCyclesBeforeLongBreak = 4
    static let idleDetectionEnabled = true
    static let idleThresholdMinutes = 10
    static let idleResolutionMode = IdleResolutionMode.ask
    static let reportsShowWeekend = true
    static let notePreviewSize = NotePreviewSize.oneLine
    static let lastSessionMode = TimerMode.free
    static let sidebarWidth = 190.0
}

enum TimerMode: String, CaseIterable, Identifiable {
    case free
    case pomodoro

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free: "Livre"
        case .pomodoro: "Pomodoro"
        }
    }
}

enum IdleResolutionMode: String, CaseIterable, Identifiable {
    case ask
    case autoDiscard
    case notifyOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ask: "Perguntar"
        case .autoDiscard: "Descartar automaticamente"
        case .notifyOnly: "Apenas notificar"
        }
    }
}

enum NotePreviewSize: String, CaseIterable, Identifiable {
    case icon
    case oneLine
    case twoLines

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon: "Ícone"
        case .oneLine: "1 linha"
        case .twoLines: "2 linhas"
        }
    }
}

/// Typed reads for code outside SwiftUI views (e.g. `PomodoroController`),
/// where `@AppStorage` isn't available. Reads the same `UserDefaults` keys
/// `SettingsView` writes to via `@AppStorage`.
enum Preferences {
    static func openWindowOnLaunch() -> Bool {
        guard let value = UserDefaults.standard.object(forKey: PreferencesKey.openWindowOnLaunch) as? Bool else {
            return PreferencesDefault.openWindowOnLaunch
        }
        return value
    }

    static func pomodoroWorkMinutes() -> Int {
        int(PreferencesKey.pomodoroWorkMinutes, default: PreferencesDefault.pomodoroWorkMinutes)
    }

    static func pomodoroShortBreakMinutes() -> Int {
        int(PreferencesKey.pomodoroShortBreakMinutes, default: PreferencesDefault.pomodoroShortBreakMinutes)
    }

    static func pomodoroLongBreakMinutes() -> Int {
        int(PreferencesKey.pomodoroLongBreakMinutes, default: PreferencesDefault.pomodoroLongBreakMinutes)
    }

    static func pomodoroCyclesBeforeLongBreak() -> Int {
        int(PreferencesKey.pomodoroCyclesBeforeLongBreak, default: PreferencesDefault.pomodoroCyclesBeforeLongBreak)
    }

    static func idleDetectionEnabled() -> Bool {
        guard let value = UserDefaults.standard.object(forKey: PreferencesKey.idleDetectionEnabled) as? Bool else {
            return PreferencesDefault.idleDetectionEnabled
        }
        return value
    }

    static func idleThresholdMinutes() -> Int {
        int(PreferencesKey.idleThresholdMinutes, default: PreferencesDefault.idleThresholdMinutes)
    }

    static func idleResolutionMode() -> IdleResolutionMode {
        guard let raw = UserDefaults.standard.string(forKey: PreferencesKey.idleResolutionMode),
              let mode = IdleResolutionMode(rawValue: raw) else {
            return PreferencesDefault.idleResolutionMode
        }
        return mode
    }

    static func notePreviewSize() -> NotePreviewSize {
        guard let raw = UserDefaults.standard.string(forKey: PreferencesKey.notePreviewSize),
              let size = NotePreviewSize(rawValue: raw) else {
            return PreferencesDefault.notePreviewSize
        }
        return size
    }

    static func lastSessionMode() -> TimerMode {
        guard let raw = UserDefaults.standard.string(forKey: PreferencesKey.lastSessionMode),
              let mode = TimerMode(rawValue: raw) else {
            return PreferencesDefault.lastSessionMode
        }
        return mode
    }

    /// `nil` until the popover panel has been dragged at least once.
    static func popoverOrigin() -> CGPoint? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: PreferencesKey.popoverOriginX) != nil,
              defaults.object(forKey: PreferencesKey.popoverOriginY) != nil else {
            return nil
        }
        return CGPoint(
            x: defaults.double(forKey: PreferencesKey.popoverOriginX),
            y: defaults.double(forKey: PreferencesKey.popoverOriginY)
        )
    }

    static func setPopoverOrigin(_ point: CGPoint) {
        UserDefaults.standard.set(point.x, forKey: PreferencesKey.popoverOriginX)
        UserDefaults.standard.set(point.y, forKey: PreferencesKey.popoverOriginY)
    }

    private static func int(_ key: String, default defaultValue: Int) -> Int {
        guard let value = UserDefaults.standard.object(forKey: key) as? Int else { return defaultValue }
        return value
    }
}
