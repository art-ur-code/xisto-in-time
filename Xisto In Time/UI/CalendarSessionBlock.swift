//
//  CalendarSessionBlock.swift
//  Xisto In Time
//

import SwiftUI
import SwiftData

/// Static presentation of one session segment: color, break/unassigned/edited
/// styling, and double-click to open the full editor. Drag-to-move and
/// drag-to-resize are added on top of this in later tasks.
struct CalendarSessionBlock: View {
    let segment: CalendarSessionSegment
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    let onOpenEditor: (Session) -> Void

    private var baseY: CGFloat {
        CalendarLayoutMath.yOffset(for: segment.segmentStart, day: segment.day, hourHeight: hourHeight)
    }

    private var baseHeight: CGFloat {
        max(4, CalendarLayoutMath.yOffset(for: segment.segmentEnd, day: segment.day, hourHeight: hourHeight) - baseY)
    }

    private var laneWidth: CGFloat {
        (columnWidth - 4) / CGFloat(segment.laneCount)
    }

    private var isUnassignedWork: Bool {
        segment.session.kind == .work && segment.session.task == nil
    }

    private var fillColor: Color {
        if segment.session.kind == .break { return Color.gray.opacity(0.35) }
        return (segment.session.task?.project?.color ?? .secondary).opacity(0.55)
    }

    private var borderColor: Color {
        segment.session.task?.project?.color ?? .secondary
    }

    private var title: String {
        if let taskTitle = segment.session.task?.title { return taskTitle }
        return segment.session.kind == .break ? "Pausa" : "Sem atribuição"
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(borderColor, style: StrokeStyle(lineWidth: isUnassignedWork ? 1 : 0, dash: isUnassignedWork ? [4, 3] : []))
            )
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.caption2)
                    .italic(segment.session.editedAt != nil)
                    .lineLimit(1)
                    .padding(3)
            }
            .frame(width: max(20, laneWidth - 2), height: baseHeight)
            .offset(x: CGFloat(segment.lane) * laneWidth + 2, y: baseY)
            .onTapGesture(count: 2) {
                onOpenEditor(segment.session)
            }
    }
}
