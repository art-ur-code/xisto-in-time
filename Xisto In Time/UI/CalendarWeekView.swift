//
//  CalendarWeekView.swift
//  Xisto In Time
//

import SwiftData
import SwiftUI

struct CalendarWeekView: View {
    @Binding var path: NavigationPath

    @Query(sort: \Session.startedAt) private var allSessions: [Session]

    @AppStorage(PreferencesKey.reportsShowWeekend)
    private var showWeekend = PreferencesDefault.reportsShowWeekend
    @AppStorage(PreferencesKey.calendarSnapMinutes)
    private var snapMinutes = PreferencesDefault.calendarSnapMinutes

    @State private var referenceDate = Date()

    private let hourHeight: CGFloat = 56
    private let dayColumnWidth: CGFloat = 130
    private let gutterWidth: CGFloat = 44
    private let headerHeight: CGFloat = 22

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
        VStack(alignment: .leading, spacing: 12) {
            weekNavigator

            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: 0) {
                    timeGutter
                    HStack(alignment: .top, spacing: 1) {
                        ForEach(days, id: \.self) { day in
                            VStack(spacing: 0) {
                                dayHeader(for: day)
                                dayColumn(for: day)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Calendário")
    }

    private var weekNavigator: some View {
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
            Button("Esta semana") { referenceDate = Date() }
                .font(.caption)
        }
    }

    private var timeGutter: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: headerHeight)
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: gutterWidth, height: hourHeight, alignment: .top)
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
                    onOpenEditor: { session in
                        path.append(SessionRoute(id: session.persistentModelID))
                    }
                )
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
