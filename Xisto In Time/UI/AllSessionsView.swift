//
//  AllSessionsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

private enum SessionKindFilter: String, CaseIterable, Identifiable {
    case all, work, `break`, plan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "Todos"
        case .work: SessionKind.work.label
        case .break: SessionKind.break.label
        case .plan: SessionKind.plan.label
        }
    }

    var sessionKind: SessionKind? {
        switch self {
        case .all: nil
        case .work: .work
        case .break: .break
        case .plan: .plan
        }
    }
}

private enum SummaryScope: String, CaseIterable, Identifiable {
    case today = "Hoje"
    case week = "Esta semana"

    var id: String { rawValue }
}

struct AllSessionsView: View {
    let path: Binding<NavigationPath>

    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var showingNewSessionEditor = false
    @State private var kindFilter: SessionKindFilter = .all
    @State private var scope: SummaryScope = .today
    @State private var query = ""
    @State private var selectedSessionID: PersistentIdentifier?

    private var searchFilteredSessions: [Session] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sessions }
        return sessions.filter { session in
            let haystack = [session.task?.externalRef, session.task?.title, session.task?.project?.name]
                .compactMap { $0 }
                .joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var filteredSessions: [Session] {
        guard let kind = kindFilter.sessionKind else { return searchFilteredSessions }
        return searchFilteredSessions.filter { $0.kind == kind }
    }

    private var dayGroups: [DaySessionGroup] {
        ReportBuilder.groupedByDay(sessions: filteredSessions)
    }

    private func count(for filter: SessionKindFilter) -> Int {
        guard let kind = filter.sessionKind else { return searchFilteredSessions.count }
        return searchFilteredSessions.filter { $0.kind == kind }.count
    }

    private func total(for kind: SessionKind, on day: Date) -> TimeInterval {
        let calendar = Calendar.current
        return sessions
            .filter { $0.kind == kind && calendar.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
    }

    private func total(for kind: SessionKind, inWeekOf date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let days = ReportBuilder.weekDays(containing: date, showWeekend: true)
        guard let first = days.first, let last = days.last,
              let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) else {
            return 0
        }
        let rangeStart = calendar.startOfDay(for: first)
        return sessions
            .filter { $0.kind == kind && $0.startedAt >= rangeStart && $0.startedAt < rangeEnd }
            .reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
    }

    private func metricTotal(for kind: SessionKind) -> TimeInterval {
        switch scope {
        case .today: total(for: kind, on: Date())
        case .week: total(for: kind, inWeekOf: Date())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().foregroundStyle(Color(hex: "ECECF0"))
            summaryBar
            Divider().foregroundStyle(Color(hex: "ECECF0"))
            filterChips

            if dayGroups.isEmpty {
                emptyState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                        ForEach(dayGroups) { group in
                            Section {
                                dayBlock(for: group)
                            } header: {
                                SessionDayHeader(group: group, isToday: Calendar.current.isDateInToday(group.day))
                                    .background(.regularMaterial)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Color.white)
        .navigationTitle("Sessões")
        .sheet(isPresented: $showingNewSessionEditor) {
            NavigationStack {
                SessionEditorView()
            }
            .frame(width: 420, height: 520)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 14) {
            Text("Sessões")
                .font(.system(size: 19, weight: .bold))

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "9A9AA0"))
                TextField("Pesquisar tarefa, código ou projecto", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 268)
            .background(Color(hex: "F1F1F4"), in: RoundedRectangle(cornerRadius: 8))

            Button {
                showingNewSessionEditor = true
            } label: {
                HStack(spacing: 6) {
                    Text("+").font(.system(size: 15))
                    Text("Nova sessão").font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(Color(hex: "007AFF"), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .help("Criar uma sessão passada, com início e fim escolhidos à mão")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Summary bar

    private var summaryBar: some View {
        HStack(alignment: .center, spacing: 26) {
            Picker("", selection: $scope) {
                ForEach(SummaryScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 170)

            metric(label: "Trabalho", color: SessionKind.work.color, total: metricTotal(for: .work))
            metric(label: "Planeado", color: SessionKind.plan.color, total: metricTotal(for: .plan))
            metric(label: "Pausas", color: SessionKind.break.color, total: metricTotal(for: .break))

            Spacer()

            let worked = metricTotal(for: .work)
            let planned = metricTotal(for: .plan)
            VStack(alignment: .trailing, spacing: 2) {
                Text(scope == .today ? "Registado hoje vs. planeado" : "Registado esta semana")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: "7C7C82"))
                Text("\(ReportBuilder.formatHoursMinutes(worked)) de \(ReportBuilder.formatHoursMinutes(worked + planned))")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func metric(label: String, color: Color, total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(hex: "7C7C82"))
            }
            Text(TimerEngine.format(total))
                .font(.system(size: 20, design: .monospaced))
                .tracking(-0.5)
        }
        .frame(minWidth: 116, alignment: .leading)
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(SessionKindFilter.allCases) { filter in
                chip(for: filter)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    private func chip(for filter: SessionKindFilter) -> some View {
        let isActive = kindFilter == filter
        return Button {
            kindFilter = filter
        } label: {
            HStack(spacing: 7) {
                if let kind = filter.sessionKind {
                    Circle().fill(kind.color).frame(width: 7, height: 7)
                }
                Text(filter.label)
                Text("\(count(for: filter))")
                    .opacity(0.55)
                    .monospacedDigit()
            }
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(isActive ? Color(hex: "1C1C1E") : Color(hex: "F4F4F7"), in: Capsule())
        .foregroundStyle(isActive ? Color.white : Color(hex: "5A5A60"))
        .overlay(
            Capsule().stroke(isActive ? Color.clear : Color(hex: "E9E9EE"), lineWidth: 1)
        )
    }

    // MARK: - Listing

    private func dayBlock(for group: DaySessionGroup) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(group.sessions.enumerated()), id: \.element.persistentModelID) { index, session in
                SessionListRow(
                    session: session,
                    isFirstInGroup: index == 0,
                    isSelected: selectedSessionID == session.persistentModelID,
                    path: path,
                    onSelect: { selectedSessionID = session.persistentModelID }
                )
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "E7E7EB"), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Text("Sem sessões para este filtro")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "6A6A70"))
            Text("Ajusta a pesquisa ou escolhe \u{201C}Todos\u{201D}.")
                .font(.system(size: 12.5))
                .foregroundStyle(Color(hex: "9A9AA0"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }
}
