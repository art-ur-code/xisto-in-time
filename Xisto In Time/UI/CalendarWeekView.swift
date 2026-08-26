//
//  CalendarWeekView.swift
//  Xisto In Time
//

import Combine
import SwiftData
import SwiftUI

private struct CalendarScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CalendarWeekView: View {
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @Environment(TimerEngine.self) private var timerEngine
    @Query(sort: \Session.startedAt) private var allSessions: [Session]

    @AppStorage(PreferencesKey.reportsShowWeekend)
    private var showWeekend = PreferencesDefault.reportsShowWeekend
    @AppStorage(PreferencesKey.calendarSnapMinutes)
    private var snapMinutes = PreferencesDefault.calendarSnapMinutes

    @State private var referenceDate = Date()
    @State private var runningTick = Date()
    @State private var horizontalOffset: CGFloat = 0

    private let hourHeight: CGFloat = 56
    private let dayColumnWidth: CGFloat = 130
    private let gutterWidth: CGFloat = 44
    private let headerHeight: CGFloat = 22

    /// Hoisted so the 30s refresh interval isn't restarted on every `body`
    /// re-evaluation — `Timer.publish(...).autoconnect()` inline would create
    /// (and reconnect) a fresh publisher on every render.
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var days: [Date] {
        ReportBuilder.weekDays(containing: referenceDate, showWeekend: showWeekend)
    }

    private var visibleSessions: [Session] {
        guard let first = days.first, let last = days.last else { return [] }
        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: first)
        guard let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) else { return [] }
        return allSessions.filter { $0.startedAt < rangeEnd && $0.endedAt > rangeStart }
    }

    private var segmentsByDay: [TimeInterval: [CalendarSessionSegment]] {
        Dictionary(grouping: CalendarLayoutMath.segments(for: visibleSessions, days: days)) { $0.day.timeIntervalSinceReferenceDate }
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                weekNavigator(proxy: proxy)
                fixedHeaderRow

                ScrollView([.vertical, .horizontal]) {
                    HStack(alignment: .top, spacing: 0) {
                        timeGutter
                        HStack(alignment: .top, spacing: 1) {
                            ForEach(days, id: \.self) { day in
                                dayColumn(for: day)
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: CalendarScrollOffsetKey.self,
                                    value: geo.frame(in: .named("calendarScroll")).minX
                                )
                            }
                        )
                    }
                }
                .coordinateSpace(name: "calendarScroll")
                .onPreferenceChange(CalendarScrollOffsetKey.self) { horizontalOffset = $0 - gutterWidth }
            }
            .onAppear {
                scrollToNow(proxy: proxy)
            }
        }
        .padding()
        .navigationTitle("Calendário")
        .onReceive(ticker) { date in
            runningTick = date
        }
    }

    private func weekNavigator(proxy: ScrollViewProxy) -> some View {
        HStack {
            Button {
                referenceDate = Calendar.current.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
            } label: {
                Image(systemName: "chevron.left")
            }
            if let first = days.first, let last = days.last {
                Text("Semana de \(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.bold())
                    .frame(minWidth: 220)
            }
            Button {
                referenceDate = Calendar.current.date(byAdding: .day, value: 7, to: referenceDate) ?? referenceDate
            } label: {
                Image(systemName: "chevron.right")
            }
            Button("Agora") {
                referenceDate = Date()
                Task { @MainActor in
                    scrollToNow(proxy: proxy)
                }
            }
            .font(.caption)
        }
    }

    /// Scrolls to today's current-time marker (both axes at once, since it's
    /// positioned inside today's column) when today is in the visible week;
    /// falls back to a fixed ~07:00 anchor when viewing a week without today.
    private func scrollToNow(proxy: ScrollViewProxy) {
        if days.contains(where: { Calendar.current.isDateInToday($0) }) {
            withAnimation {
                proxy.scrollTo("now", anchor: .center)
            }
        } else {
            proxy.scrollTo(7, anchor: .top)
        }
    }

    /// Day-name headers, kept outside the scrollable grid so they stay fixed
    /// while scrolling vertically. Tracks the grid's horizontal scroll offset
    /// (via `CalendarScrollOffsetKey`) so it still moves in sync with the day
    /// columns when scrolling horizontally.
    private var fixedHeaderRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth)
            HStack(alignment: .top, spacing: 1) {
                ForEach(days, id: \.self) { day in
                    dayHeader(for: day)
                        .frame(width: dayColumnWidth)
                }
            }
            .offset(x: horizontalOffset)
        }
        .frame(height: headerHeight)
        .clipped()
    }

    private var timeGutter: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: gutterWidth, height: hourHeight, alignment: .top)
                    .id(hour)
            }
        }
    }

    private func dayHeader(for day: Date) -> some View {
        Text(day.formatted(.dateTime.weekday(.abbreviated).day()))
            .font(.caption.bold())
            .frame(height: headerHeight)
    }

    private func dayColumn(for day: Date) -> some View {
        ZStack(alignment: .topLeading) {
            hourGridLines
            ForEach(segmentsByDay[day.timeIntervalSinceReferenceDate] ?? []) { segment in
                CalendarSessionBlock(
                    segment: segment,
                    hourHeight: hourHeight,
                    columnWidth: dayColumnWidth,
                    snapMinutes: snapMinutes,
                    days: days,
                    overlapCheck: { start, end, excluding in
                        SessionStore.overlappingSession(startedAt: start, endedAt: end, excluding: excluding, in: allSessions)
                    },
                    onCommit: { session, start, end in
                        SessionStore.rescheduleSession(session, startedAt: start, endedAt: end, in: modelContext)
                    },
                    onOpenEditor: { session in
                        path.append(SessionRoute(id: session.persistentModelID))
                    }
                )
            }
            if timerEngine.isRunning, let startedAt = timerEngine.currentStartedAt, Calendar.current.isDate(startedAt, inSameDayAs: day) {
                CalendarRunningBlock(
                    day: day,
                    startedAt: startedAt,
                    kind: timerEngine.currentKind,
                    taskTitle: timerEngine.currentTask?.title,
                    projectColor: timerEngine.currentTask?.project?.color,
                    now: runningTick,
                    hourHeight: hourHeight
                )
            }
            if Calendar.current.isDateInToday(day) {
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1.5)
                    .offset(y: CalendarLayoutMath.yOffset(for: runningTick, day: day, hourHeight: hourHeight))
                    .allowsHitTesting(false)
                    .id("now")
            }
        }
        .frame(width: dayColumnWidth, height: hourHeight * 24)
        .background(Color.primary.opacity(0.02))
    }

    private var hourGridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 1)
                    .frame(height: hourHeight, alignment: .top)
            }
        }
    }
}
