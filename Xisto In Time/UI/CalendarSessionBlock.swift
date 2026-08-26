//
//  CalendarSessionBlock.swift
//  Xisto In Time
//

import SwiftUI
import SwiftData

struct CalendarSessionBlock: View {
    let segment: CalendarSessionSegment
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    let snapMinutes: Int
    let overlapCheck: (Date, Date, PersistentIdentifier?) -> Session?
    let onCommit: (Session, Date, Date) -> Void
    let onOpenEditor: (Session) -> Void

    @State private var moveTranslation: CGSize = .zero
    @State private var isOverlapping = false
    @State private var showingOverlapAlert = false
    @State private var overlapDescription = ""
    @State private var showingLongDurationAlert = false
    @State private var pendingStart = Date()
    @State private var pendingEnd = Date()

    /// Multi-day sessions only move vertically within their own segment —
    /// moving one horizontally would be ambiguous about which day "wins".
    private var canMoveAcrossDays: Bool { segment.isSessionStart && segment.isSessionEnd }

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
        isOverlapping ? .red : (segment.session.task?.project?.color ?? .secondary)
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
                    .strokeBorder(borderColor, style: StrokeStyle(lineWidth: isOverlapping ? 2 : (isUnassignedWork ? 1 : 0), dash: (!isOverlapping && isUnassignedWork) ? [4, 3] : []))
            )
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.caption2)
                    .italic(segment.session.editedAt != nil)
                    .lineLimit(1)
                    .padding(3)
            }
            .frame(width: max(20, laneWidth - 2), height: baseHeight)
            .offset(x: CGFloat(segment.lane) * laneWidth + 2 + (canMoveAcrossDays ? moveTranslation.width : 0), y: baseY + moveTranslation.height)
            .onTapGesture(count: 2) {
                onOpenEditor(segment.session)
            }
            .gesture(moveGesture)
            .alert("Sobreposição de sessões", isPresented: $showingOverlapAlert) {
                Button("Cancelar", role: .cancel) { resetTranslation() }
                Button("Continuar mesmo assim") { checkDurationThenCommit() }
            } message: {
                Text("Esta sessão sobrepõe-se a: \(overlapDescription)")
            }
            .alert("Sessão muito longa", isPresented: $showingLongDurationAlert) {
                Button("Cancelar", role: .cancel) { resetTranslation() }
                Button("Continuar mesmo assim") { commit() }
            } message: {
                Text("Esta sessão passaria a durar mais de 12 horas. Tens a certeza?")
            }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                moveTranslation = canMoveAcrossDays ? value.translation : CGSize(width: 0, height: value.translation.height)
                let (start, end) = candidateRange()
                isOverlapping = overlapCheck(start, end, segment.session.persistentModelID) != nil
            }
            .onEnded { _ in
                let (start, end) = candidateRange()
                finishDrag(newStart: start, newEnd: end)
            }
    }

    /// Translation → candidate (start, end), snapped and clamped to never land in the future.
    private func candidateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let dayDelta = canMoveAcrossDays ? Int((moveTranslation.width / columnWidth).rounded()) : 0
        let timeDeltaSeconds = Double(moveTranslation.height / hourHeight) * 3600
        let duration = segment.session.endedAt.timeIntervalSince(segment.session.startedAt)

        let shifted = segment.session.startedAt.addingTimeInterval(timeDeltaSeconds)
        let dayShifted = calendar.date(byAdding: .day, value: dayDelta, to: shifted) ?? shifted
        let snapped = CalendarLayoutMath.snap(dayShifted, toMinutes: snapMinutes, calendar: calendar)
        let clampedStart = min(snapped, Date().addingTimeInterval(-duration))
        return (clampedStart, clampedStart.addingTimeInterval(duration))
    }

    private func finishDrag(newStart: Date, newEnd: Date) {
        guard newStart != segment.session.startedAt || newEnd != segment.session.endedAt else {
            resetTranslation()
            return
        }
        pendingStart = newStart
        pendingEnd = newEnd
        if let overlapping = overlapCheck(newStart, newEnd, segment.session.persistentModelID) {
            overlapDescription = SessionStore.describe(overlapping)
            showingOverlapAlert = true
            return
        }
        checkDurationThenCommit()
    }

    private func checkDurationThenCommit() {
        if pendingEnd.timeIntervalSince(pendingStart) > 12 * 3600 {
            showingLongDurationAlert = true
            return
        }
        commit()
    }

    private func commit() {
        onCommit(segment.session, pendingStart, pendingEnd)
        resetTranslation()
    }

    private func resetTranslation() {
        moveTranslation = .zero
        isOverlapping = false
    }
}
