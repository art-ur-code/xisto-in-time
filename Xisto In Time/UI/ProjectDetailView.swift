//
//  ProjectDetailView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project

    @Query private var tasks: [TaskItem]
    @Query(sort: \Session.startedAt, order: .reverse) private var allSessions: [Session]

    @State private var showingEditSheet = false
    @State private var editName = ""
    @State private var editColor = Color.accentColor

    init(project: Project) {
        self.project = project
        let projectID = project.persistentModelID
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.project?.persistentModelID == projectID },
            sort: \TaskItem.title
        )
    }

    private var sessions: [Session] {
        let projectID = project.persistentModelID
        return allSessions.filter { $0.task?.project?.persistentModelID == projectID }
    }

    private var todayTotal: TimeInterval {
        ReportBuilder.dailyReport(sessions: sessions, day: Date()).total
    }

    private var weekTotal: TimeInterval {
        let days = ReportBuilder.weekDays(containing: Date(), showWeekend: true)
        return ReportBuilder.weeklyReport(sessions: sessions, days: days).grandTotal
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

            Section("Tarefas") {
                if tasks.isEmpty {
                    Text("Ainda sem tarefas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasks) { task in
                        NavigationLink(value: TaskRoute(id: task.persistentModelID)) {
                            Text(task.title)
                                .foregroundStyle(task.archived ? .secondary : .primary)
                                .strikethrough(task.archived)
                        }
                    }
                }
            }

            Section("Sessões") {
                if sessions.isEmpty {
                    Text("Ainda sem sessões")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(value: SessionRoute(id: session.persistentModelID)) {
                            HStack {
                                Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                                Text(session.task?.title ?? "Sem tarefa")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(TimerEngine.format(session.endedAt.timeIntervalSince(session.startedAt)))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem {
                Button("Editar") {
                    editName = project.name
                    editColor = project.color
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ProjectFormSheet(title: "Editar projecto", name: $editName, color: $editColor) {
                let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                project.name = trimmed
                project.colorHex = editColor.toHex()
                showingEditSheet = false
            } onCancel: {
                showingEditSheet = false
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
}
