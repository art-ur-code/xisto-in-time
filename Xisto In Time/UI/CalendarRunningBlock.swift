//
//  CalendarRunningBlock.swift
//  Xisto In Time
//

import SwiftUI

/// Not backed by a `Session` — the running session only becomes one when it
/// stops (`SessionStore.recordFinishedSession`). Rendered from `TimerEngine`'s
/// live state instead, growing until "now". Never draggable.
struct CalendarRunningBlock: View {
    let day: Date
    let startedAt: Date
    let kind: SessionKind
    let taskTitle: String?
    let projectColor: Color?
    let now: Date
    let hourHeight: CGFloat
    let startHour: Int

    private var y: CGFloat {
        CalendarLayoutMath.yOffset(for: startedAt, day: day, hourHeight: hourHeight, startHour: startHour)
    }

    private var height: CGFloat {
        max(4, CalendarLayoutMath.yOffset(for: now, day: day, hourHeight: hourHeight, startHour: startHour) - y)
    }

    /// Mirrors `CalendarSessionBlock.fillColor`'s `.break` special-case so a
    /// running pause doesn't visibly flip from project/accent color to gray
    /// the instant it's saved as a real session.
    private var strokeColor: Color {
        kind == .break ? SessionKind.break.color : (projectColor ?? .accentColor)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.sm)
            .fill(kind == .break ? SessionKind.break.color.opacity(0.35) : (projectColor ?? .accentColor).opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .strokeBorder(strokeColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            )
            .overlay(alignment: .topLeading) {
                Text(taskTitle ?? (kind == .break ? "Pausa a decorrer" : "A decorrer…"))
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(3)
            }
            .padding(.horizontal, 2)
            .frame(height: height)
            .offset(y: y)
    }
}
