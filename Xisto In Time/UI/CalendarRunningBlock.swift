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

    private var y: CGFloat {
        CalendarLayoutMath.yOffset(for: startedAt, day: day, hourHeight: hourHeight)
    }

    private var height: CGFloat {
        max(4, CalendarLayoutMath.yOffset(for: now, day: day, hourHeight: hourHeight) - y)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill((projectColor ?? .accentColor).opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(projectColor ?? .accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            )
            .overlay(alignment: .topLeading) {
                Text(taskTitle ?? (kind == .break ? "Pausa a decorrer" : "A decorrer…"))
                    .font(.caption2)
                    .padding(3)
            }
            .padding(.horizontal, 2)
            .frame(height: height)
            .offset(y: y)
    }
}
