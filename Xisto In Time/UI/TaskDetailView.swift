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
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerEngine.self) private var timerEngine
    @Environment(PomodoroController.self) private var pomodoro
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

    private var isRunningThisTask: Bool {
        timerEngine.isRunning && timerEngine.currentTask?.persistentModelID == task.persistentModelID
    }

    var body: some View {
        List {
            Section {
                Button {
                    startSession()
                } label: {
                    Label(
                        isRunningThisTask ? "Sessão desta tarefa a decorrer" : "Começar sessão desta tarefa",
                        systemImage: isRunningThisTask ? "record.circle.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(task.project?.color ?? .accentColor)
                .controlSize(.large)
                .disabled(isRunningThisTask)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }

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
                modelContext.saveAndCheckpoint()
                showingEditSheet = false
            } onCancel: {
                showingEditSheet = false
            }
        }
    }

    private func startSession() {
        if timerEngine.isRunning {
            pomodoro.cancel()
        }
        timerEngine.start(kind: .work, task: task)
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
