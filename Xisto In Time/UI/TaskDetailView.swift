//
//  TaskDetailView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
    let task: TaskItem
    let path: Binding<NavigationPath>
    @Query private var sessions: [Session]
    @Query(filter: #Predicate<Project> { !$0.archived }, sort: \Project.name)
    private var projects: [Project]

    @State private var showingEditSheet = false
    @State private var editTitle = ""
    @State private var editProject: Project?

    init(task: TaskItem, path: Binding<NavigationPath>) {
        self.task = task
        self.path = path
        let taskID = task.persistentModelID
        _sessions = Query(
            filter: #Predicate<Session> { $0.task?.persistentModelID == taskID },
            sort: \Session.startedAt,
            order: .reverse
        )
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

            Section("Sessões") {
                if sessions.isEmpty {
                    Text("Ainda sem sessões")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        SessionRow(session: session, showsTask: false, path: path)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .navigationTitle(task.title)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let project = task.project {
                    Label {
                        Text(project.name)
                    } icon: {
                        Circle().fill(project.color).frame(width: 8, height: 8)
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            ToolbarItem {
                Button("Editar") {
                    editTitle = task.title
                    editProject = task.project
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskFormSheet(title: "Editar tarefa", taskTitle: $editTitle, project: $editProject, projects: projects) {
                let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let editProject else { return }
                task.title = trimmed
                task.project = editProject
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
