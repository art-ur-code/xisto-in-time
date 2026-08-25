//
//  AllSessionsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

private struct DaySessionGroup: Identifiable {
    let day: Date
    let sessions: [Session]

    var id: Date { day }

    var total: TimeInterval {
        sessions.reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
    }
}

struct AllSessionsView: View {
    let path: Binding<NavigationPath>

    @Environment(\.modelContext) private var modelContext
    @Environment(TimerEngine.self) private var timerEngine
    @Environment(PomodoroController.self) private var pomodoro
    @AppStorage(PreferencesKey.notePreviewSize)
    private var notePreviewSize = PreferencesDefault.notePreviewSize

    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var showingNewSessionEditor = false
    @State private var sessionPendingDeletion: Session?

    private static let weekdayNames = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
    private static let monthAbbreviations = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]

    private var todayTotal: TimeInterval {
        ReportBuilder.dailyReport(sessions: sessions, day: Date()).total
    }

    private var weekTotal: TimeInterval {
        let days = ReportBuilder.weekDays(containing: Date(), showWeekend: true)
        return ReportBuilder.weeklyReport(sessions: sessions, days: days).grandTotal
    }

    private var groupedSessions: [DaySessionGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
        return byDay.keys.sorted(by: >).map { day in
            DaySessionGroup(day: day, sessions: byDay[day]!.sorted { $0.startedAt > $1.startedAt })
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    statCard(title: "Hoje", total: todayTotal)
                    statCard(title: "Esta semana", total: weekTotal)
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }

            if sessions.isEmpty {
                Section("Histórico") {
                    Text("Ainda sem sessões")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(groupedSessions) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            sessionCard(session)
                        }
                    } header: {
                        dayHeader(for: group)
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
        .confirmationDialog(
            "Apagar esta sessão?",
            isPresented: Binding(get: { sessionPendingDeletion != nil }, set: { if !$0 { sessionPendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                if let session = sessionPendingDeletion {
                    modelContext.delete(session)
                    modelContext.saveAndCheckpoint()
                }
                sessionPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) {
                sessionPendingDeletion = nil
            }
        }
    }

    private func statCard(title: String, total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(ReportBuilder.formatHoursMinutes(total)) (\(ReportBuilder.formatDecimalHours(total)))")
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func dayHeader(for group: DaySessionGroup) -> some View {
        HStack {
            Text(dayTitle(for: group.day))
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Spacer()
            Text("\(group.sessions.count) sessões · \(TimerEngine.format(group.total))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private func dayTitle(for day: Date) -> String {
        let calendar = Calendar.current
        let weekday = Self.weekdayNames[calendar.component(.weekday, from: day) - 1]
        let dayNumber = calendar.component(.day, from: day)
        let month = Self.monthAbbreviations[calendar.component(.month, from: day) - 1]
        let year = calendar.component(.year, from: day)
        return "\(weekday), \(dayNumber) \(month) \(year)"
    }

    private func isRunningThisSessionsTask(_ session: Session) -> Bool {
        guard let task = session.task else { return false }
        return timerEngine.isRunning && timerEngine.currentTask?.persistentModelID == task.persistentModelID
    }

    private func startFreeSession(for session: Session) {
        if timerEngine.isRunning {
            pomodoro.cancel()
        }
        timerEngine.start(kind: .work, task: session.task)
    }

    private func sessionCard(_ session: Session) -> some View {
        HStack(spacing: 12) {
            if let project = session.task?.project {
                Circle()
                    .fill(project.color)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.task?.title ?? "Sem atribuição")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    if let project = session.task?.project {
                        Text(project.name)
                    }
                    Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if notePreviewSize != .icon, let note = session.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(notePreviewSize == .oneLine ? 1 : 2)
                }
            }

            Spacer()

            if session.interrupted {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.secondary)
            }
            if notePreviewSize == .icon, let note = session.note, !note.isEmpty {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
            }

            Text(TimerEngine.format(session.endedAt.timeIntervalSince(session.startedAt)))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                startFreeSession(for: session)
            } label: {
                Label("Começar", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .tint(session.task?.project?.color ?? .accentColor)
            .disabled(isRunningThisSessionsTask(session))

            RowDisclosureChevron()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .openOnDoubleClick {
            path.wrappedValue.append(SessionRoute(id: session.persistentModelID))
        }
        .contextMenu {
            Button("Apagar sessão", role: .destructive) {
                sessionPendingDeletion = session
            }
        }
    }
}
