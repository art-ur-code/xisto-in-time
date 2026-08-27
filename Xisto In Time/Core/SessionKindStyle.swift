//
//  SessionKindStyle.swift
//  Xisto In Time
//

import SwiftUI

/// Shared visual identity for each session kind — one source of truth for
/// the color/label used across the calendar and the sessions list, so the
/// two never drift apart.
extension SessionKind {
    var label: String {
        switch self {
        case .work: "Trabalho"
        case .break: "Pausa"
        case .plan: "Plano"
        }
    }

    /// Full-strength identity color.
    var color: Color {
        switch self {
        case .work: Color(hex: "007AFF")
        case .break: Color(hex: "A0A0A6")
        case .plan: Color(hex: "E8A300")
        }
    }

    /// Light/tinted background variant.
    var lightColor: Color {
        switch self {
        case .work: Color(hex: "DFEEFF")
        case .break: Color(hex: "EEEEF1")
        case .plan: Color(hex: "FFF4D6")
        }
    }

    /// Text color for the small type badge (only ever shown for Pausa/Plano).
    var chipTextColor: Color {
        switch self {
        case .work: color
        case .break: Color(hex: "71717A")
        case .plan: Color(hex: "A87000")
        }
    }
}
