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
        case .work: Theme.Color.sessionWork
        case .break: Theme.Color.sessionBreak
        case .plan: Theme.Color.sessionPlan
        }
    }

    /// Light/tinted background variant.
    var lightColor: Color {
        switch self {
        case .work: Theme.Color.sessionWorkLight
        case .break: Theme.Color.sessionBreakLight
        case .plan: Theme.Color.sessionPlanLight
        }
    }

    /// Text color for the small type badge (only ever shown for Pausa/Plano).
    var chipTextColor: Color {
        switch self {
        case .work: color
        case .break: Theme.Color.sessionBreakText
        case .plan: Theme.Color.sessionPlanText
        }
    }
}
