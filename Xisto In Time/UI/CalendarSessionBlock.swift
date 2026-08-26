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
    let days: [Date]
    let overlapCheck: (Date, Date, PersistentIdentifier?) -> Session?
    let onCommit: (Session, Date, Date) -> Void
    let onOpenEditor: (Session) -> Void

    @State private var moveTranslation: CGSize = .zero
    @State private var resizeTopTranslation: CGFloat = 0
    @State private var resizeBottomTranslation: CGFloat = 0
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
            .frame(width: max(20, laneWidth - 2), height: max(4, baseHeight - resizeTopTranslation + resizeBottomTranslation))
            .overlay(alignment: .top) {
                if segment.isSessionStart {
                    resizeHandle(gesture: topResizeGesture, blockHeight: max(4, baseHeight - resizeTopTranslation + resizeBottomTranslation))
                }
            }
            .overlay(alignment: .bottom) {
                if segment.isSessionEnd {
                    resizeHandle(gesture: bottomResizeGesture, blockHeight: max(4, baseHeight - resizeTopTranslation + resizeBottomTranslation))
                }
            }
            .offset(x: CGFloat(segment.lane) * laneWidth + 2 + (canMoveAcrossDays ? moveTranslation.width : 0), y: baseY + resizeTopTranslation + moveTranslation.height)
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
    ///
    /// Horizontal movement operates on the *visible* column index, not a raw
    /// calendar-day delta: when weekends are hidden, "one column right" of
    /// Friday must land on next Monday, not the (invisible) Saturday, and the
    /// target day is always clamped into the currently-visible range so a
    /// drag can never place a session on a day the calendar isn't showing.
    private func candidateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let columnDelta = canMoveAcrossDays ? Int((moveTranslation.width / columnWidth).rounded()) : 0
        let timeDeltaSeconds = Double(moveTranslation.height / hourHeight) * 3600
        let duration = segment.session.endedAt.timeIntervalSince(segment.session.startedAt)

        let shifted = segment.session.startedAt.addingTimeInterval(timeDeltaSeconds)

        let currentIndex = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: segment.day) }) ?? 0
        let targetIndex = max(0, min(days.count - 1, currentIndex + columnDelta))
        let targetDay = days.isEmpty ? segment.day : days[targetIndex]

        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: shifted)
        let dayShifted = calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: timeComponents.second ?? 0,
            of: targetDay
        ) ?? shifted

        let snapped = CalendarLayoutMath.snap(dayShifted, toMinutes: snapMinutes, calendar: calendar)
        let clampedStart = min(snapped, Date().addingTimeInterval(-duration))
        return (clampedStart, clampedStart.addingTimeInterval(duration))
    }

    private func resizeHandle(gesture: some Gesture, blockHeight: CGFloat) -> some View {
        let handleHeight = max(2, min(8, blockHeight / 3))
        return Rectangle()
            .fill(Color.clear)
            .frame(height: handleHeight)
            .contentShape(Rectangle())
            .overlay(Capsule().fill(Color.primary.opacity(0.25)).frame(width: 24, height: 3))
            .gesture(gesture)
    }

    private var topResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                resizeTopTranslation = value.translation.height
                let (start, end) = topCandidateRange()
                isOverlapping = overlapCheck(start, end, segment.session.persistentModelID) != nil
            }
            .onEnded { _ in
                let (start, end) = topCandidateRange()
                finishDrag(newStart: start, newEnd: end)
            }
    }

    private var bottomResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                resizeBottomTranslation = value.translation.height
                let (start, end) = bottomCandidateRange()
                isOverlapping = overlapCheck(start, end, segment.session.persistentModelID) != nil
            }
            .onEnded { _ in
                let (start, end) = bottomCandidateRange()
                finishDrag(newStart: start, newEnd: end)
            }
    }

    private func topCandidateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let timeDeltaSeconds = Double(resizeTopTranslation / hourHeight) * 3600
        let raw = segment.session.startedAt.addingTimeInterval(timeDeltaSeconds)
        let snapped = CalendarLayoutMath.snap(raw, toMinutes: snapMinutes, calendar: calendar)
        let latestAllowedStart = segment.session.endedAt.addingTimeInterval(-TimeInterval(max(snapMinutes, 1) * 60))
        return (min(snapped, latestAllowedStart), segment.session.endedAt)
    }

    private func bottomCandidateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let timeDeltaSeconds = Double(resizeBottomTranslation / hourHeight) * 3600
        let raw = segment.session.endedAt.addingTimeInterval(timeDeltaSeconds)
        let snapped = CalendarLayoutMath.snap(raw, toMinutes: snapMinutes, calendar: calendar)
        let earliestAllowedEnd = segment.session.startedAt.addingTimeInterval(TimeInterval(max(snapMinutes, 1) * 60))
        let clamped = max(snapped, earliestAllowedEnd)
        return (segment.session.startedAt, min(clamped, Date()))
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
        resizeTopTranslation = 0
        resizeBottomTranslation = 0
        isOverlapping = false
    }
}
