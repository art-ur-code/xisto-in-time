//
//  Theme.swift
//  Xisto In Time
//

import AppKit
import SwiftUI

/// App-wide design tokens — the single source of truth for color, type
/// size, spacing and corner radius. Colors are semantic roles (not raw hex
/// names), resolved dynamically against the current system appearance, so
/// every call site gets dark mode for free and, later, a swappable accent
/// color without touching call sites again.
enum Theme {
    enum Color {
        // MARK: Accent

        private static var accentHex: String {
            UserDefaults.standard.string(forKey: "themeAccentColorHex") ?? "007AFF"
        }

        /// The app's brand color. Reads a persisted preference that no UI
        /// writes yet — a future accent-color picker only needs to write
        /// that one key for this (and `sessionWork`, which mirrors it) to
        /// follow.
        static var accent: SwiftUI.Color { dynamic(light: accentHex, dark: "0A84FF") }

        /// Tinted background variant of `accent`, derived by opacity rather
        /// than a separate hex — inherits `accent`'s light/dark behavior
        /// automatically instead of needing its own dark value maintained
        /// by hand.
        static var accentSubtle: SwiftUI.Color { accent.opacity(0.12) }

        // MARK: Surfaces

        static var surfacePrimary: SwiftUI.Color { dynamic(light: "FFFFFF", dark: "1C1C1E") }
        static var surfaceHover: SwiftUI.Color { dynamic(light: "FAFAFC", dark: "242426") }
        static var fillSubtle: SwiftUI.Color { dynamic(light: "F1F1F4", dark: "2C2C2E") }
        static var divider: SwiftUI.Color { dynamic(light: "ECECF0", dark: "38383A") }

        // MARK: Text

        static var textMuted: SwiftUI.Color { dynamic(light: "8A8A90", dark: "98989F") }
        static var textSecondary: SwiftUI.Color { dynamic(light: "6A6A70", dark: "B4B4BA") }
        static var textFaint: SwiftUI.Color { dynamic(light: "C4C4C9", dark: "48484A") }
        static var inkStrong: SwiftUI.Color { dynamic(light: "2A2A2F", dark: "F0F0F2") }

        /// Active/selected filter-chip fill and its matching text — kept as
        /// their own pair (rather than reusing `inkStrong` for the
        /// background and `surfacePrimary`/white for the text separately)
        /// because `inkStrong` intentionally *flips* in dark mode (near-
        /// black → near-white); a text color picked to contrast in light
        /// mode would stop contrasting the moment the background flips.
        static var chipActiveBackground: SwiftUI.Color { inkStrong }
        static var chipActiveText: SwiftUI.Color { dynamic(light: "FFFFFF", dark: "1C1C1E") }

        // MARK: "Hoje" badge

        static var badgeTodayText: SwiftUI.Color { dynamic(light: "B05800", dark: "FFB454") }
        static var badgeTodayBackground: SwiftUI.Color { dynamic(light: "FFD6D6", dark: "4A2020") }

        // MARK: Session kinds

        static var sessionWork: SwiftUI.Color { accent }
        static var sessionWorkLight: SwiftUI.Color { sessionWork.opacity(0.12) }
        static var sessionBreak: SwiftUI.Color { dynamic(light: "A0A0A6", dark: "8E8E93") }
        static var sessionBreakLight: SwiftUI.Color { sessionBreak.opacity(0.15) }
        static var sessionBreakText: SwiftUI.Color { textSecondary }
        static var sessionPlan: SwiftUI.Color { dynamic(light: "E8A300", dark: "E8A300") }
        static var sessionPlanLight: SwiftUI.Color { sessionPlan.opacity(0.13) }
        static var sessionPlanText: SwiftUI.Color { dynamic(light: "A87000", dark: "D4A64C") }

        /// Resolves against the current effective appearance at render
        /// time — works anywhere a `Color` is used, including outside a
        /// `View` body (unlike `@Environment(\.colorScheme)`, which only
        /// resolves inside one).
        private static func dynamic(light: String, dark: String) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return NSColor(SwiftUI.Color(hex: isDark ? dark : light))
            })
        }
    }

    enum Font {
        static let micro: CGFloat = 9
        static let badge: CGFloat = 10
        static let caption: CGFloat = 11.5
        static let footnote: CGFloat = 12.5
        static let subheadline: CGFloat = 13
        static let body: CGFloat = 14
        static let callout: CGFloat = 15
        static let title3: CGFloat = 19
        static let statLarge: CGFloat = 20
        static let title2: CGFloat = 30
        static let largeTitle: CGFloat = 34
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let base: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 22
    }

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 20
    }
}
