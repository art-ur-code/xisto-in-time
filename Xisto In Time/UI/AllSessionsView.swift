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
    let selection: Binding<MainWindowSection?>

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
            Divider().foregroundStyle(Theme.Color.divider)
            summaryBar
            Divider().foregroundStyle(Theme.Color.divider)
            filterChips

            if dayGroups.isEmpty {
                emptyState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl, pinnedViews: [.sectionHeaders]) {
                        ForEach(dayGroups) { group in
                            Section {
                                dayBlock(for: group)
                            } header: {
                                SessionDayHeader(group: group, isToday: Calendar.current.isDateInToday(group.day))
                                    .background(.regularMaterial)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Theme.Color.surfacePrimary)
        .navigationTitle("Sessões")
        .sheet(isPresented: $showingNewSessionEditor) {
            NavigationStack {
                SessionEditorView(path: path, selection: selection, onNavigateAway: { showingNewSessionEditor = false })
            }
            .frame(width: 420, height: 520)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 14) {
            Text("Sessões")
                .font(.system(size: Theme.Font.title3, weight: .bold))

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: Theme.Font.subheadline))
                    .foregroundStyle(Theme.Color.textMuted)
                TextField("Pesquisar tarefa, código ou projecto", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.Font.subheadline))
            }
            .padding(.horizontal, Theme.Spacing.base)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(width: 268)
            .background(Theme.Color.fillSubtle, in: RoundedRectangle(cornerRadius: Theme.Radius.md))

            Button {
                showingNewSessionEditor = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("+").font(.system(size: Theme.Font.callout))
                    Text("Nova sessão").font(.system(size: Theme.Font.subheadline, weight: .semibold))
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .foregroundStyle(.white)
            .help("Criar uma sessão passada, com início e fim escolhidos à mão")
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.xl)
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
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                Text(scope == .today ? "Registado hoje vs. planeado" : "Registado esta semana")
                    .font(.system(size: Theme.Font.caption))
                    .foregroundStyle(Theme.Color.textMuted)
                Text("\(ReportBuilder.formatHoursMinutes(worked)) de \(ReportBuilder.formatHoursMinutes(worked + planned))")
                    .font(.system(size: Theme.Font.subheadline, weight: .semibold))
            }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, 14)
    }

    private func metric(label: String, color: Color, total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: Theme.Font.caption, weight: .medium))
                    .foregroundStyle(Theme.Color.textMuted)
            }
            Text(TimerEngine.format(total))
                .font(.system(size: Theme.Font.statLarge, design: .monospaced))
                .tracking(-0.5)
        }
        .frame(minWidth: 116, alignment: .leading)
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(SessionKindFilter.allCases) { filter in
                chip(for: filter)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.lg)
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
            .font(.system(size: Theme.Font.footnote, weight: .semibold))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(isActive ? Theme.Color.chipActiveBackground : Theme.Color.fillSubtle, in: Capsule())
        .foregroundStyle(isActive ? Theme.Color.chipActiveText : Theme.Color.textSecondary)
        .overlay(
            Capsule().stroke(isActive ? Color.clear : Theme.Color.divider, lineWidth: 1)
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
        .background(Theme.Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Color.divider, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Text("Sem sessões para este filtro")
                .font(.system(size: Theme.Font.body, weight: .semibold))
                .foregroundStyle(Theme.Color.textSecondary)
            Text("Ajusta a pesquisa ou escolhe \u{201C}Todos\u{201D}.")
                .font(.system(size: Theme.Font.footnote))
                .foregroundStyle(Theme.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }
}
