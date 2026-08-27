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
        case .work: "Trabalho"
        case .break: "Pausa"
        case .plan: "Plano"
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

struct AllSessionsView: View {
    let path: Binding<NavigationPath>

    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var showingNewSessionEditor = false
    @State private var kindFilter: SessionKindFilter = .all

    private var filteredSessions: [Session] {
        guard let kind = kindFilter.sessionKind else { return sessions }
        return sessions.filter { $0.kind == kind }
    }

    private var todayTotal: TimeInterval {
        ReportBuilder.dailyReport(sessions: sessions, day: Date()).total
    }

    private var weekTotal: TimeInterval {
        let days = ReportBuilder.weekDays(containing: Date(), showWeekend: true)
        return ReportBuilder.weeklyReport(sessions: sessions, days: days).grandTotal
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

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    statCard(title: "Hoje", total: todayTotal)
                    statCard(title: "Esta semana", total: weekTotal)
                    statCard(title: "Planos hoje", total: total(for: .plan, on: Date()), accent: Color(hex: "FAE588"))
                    statCard(title: "Planos esta semana", total: total(for: .plan, inWeekOf: Date()), accent: Color(hex: "FAE588"))
                    statCard(title: "Pausas hoje", total: total(for: .break, on: Date()), accent: .gray)
                    statCard(title: "Pausas esta semana", total: total(for: .break, inWeekOf: Date()), accent: .gray)
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }

            Section {
                Picker("Filtro", selection: $kindFilter) {
                    ForEach(SessionKindFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }

            if filteredSessions.isEmpty {
                Section("Histórico") {
                    Text("Ainda sem sessões")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(ReportBuilder.groupedByDay(sessions: filteredSessions)) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            SessionRow(session: session, path: path)
                        }
                    } header: {
                        SessionDayHeader(group: group)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
        .navigationTitle("Sessões")
        .toolbar {
            ToolbarItem {
                Button {
                    showingNewSessionEditor = true
                } label: {
                    Label("Sessão manual", systemImage: "plus")
                }
                .help("Criar uma sessão passada, com início e fim escolhidos à mão")
            }
        }
        .sheet(isPresented: $showingNewSessionEditor) {
            NavigationStack {
                SessionEditorView()
            }
            .frame(width: 420, height: 520)
        }
    }

    private func statCard(title: String, total: TimeInterval, accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let accent {
                    Circle().fill(accent).frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(ReportBuilder.formatHoursMinutes(total)) (\(ReportBuilder.formatDecimalHours(total)))")
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
