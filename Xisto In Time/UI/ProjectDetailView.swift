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
    let path: Binding<NavigationPath>

    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query(sort: \Session.startedAt, order: .reverse) private var allSessions: [Session]
    @Query(filter: #Predicate<Project> { !$0.archived }, sort: \Project.name)
    private var projects: [Project]

    @State private var showingEditSheet = false
    @State private var editName = ""
    @State private var editColor = Color.accentColor

    @State private var showingNewTaskSheet = false
    @State private var newTaskTitle = ""
    @State private var newTaskLink = ""
    @State private var newTaskProject: Project?

    init(project: Project, path: Binding<NavigationPath>) {
        self.project = project
        self.path = path
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
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.xs)
            }

            Section {
                Button {
                    newTaskTitle = ""
                    newTaskLink = ""
                    newTaskProject = project
                    showingNewTaskSheet = true
                } label: {
                    Label("Criar tarefa", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                if tasks.isEmpty {
                    Text("Ainda sem tarefas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasks) { task in
                        TaskCard(task: task, showsProject: false, path: path)
                    }
                }
            } header: {
                blockHeader(title: "Tarefas", count: tasks.count, singular: "tarefa", plural: "tarefas")
            }

            if sessions.isEmpty {
                Section {
                    Text("Ainda sem sessões")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    blockHeader(title: "Sessões", count: 0, singular: "sessão", plural: "sessões")
                }
            } else {
                ForEach(Array(ReportBuilder.groupedByDay(sessions: sessions).enumerated()), id: \.element.id) { index, group in
                    Section {
                        ForEach(group.sessions) { session in
                            SessionRow(session: session, path: path)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 6) {
                            if index == 0 {
                                blockHeader(title: "Sessões", count: sessions.count, singular: "sessão", plural: "sessões")
                            }
                            SessionDayHeader(group: group)
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
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
                modelContext.saveAndCheckpoint()
                showingEditSheet = false
            } onCancel: {
                showingEditSheet = false
            }
        }
        .sheet(isPresented: $showingNewTaskSheet) {
            TaskFormSheet(title: "Nova tarefa", taskTitle: $newTaskTitle, link: $newTaskLink, project: $newTaskProject, projects: projects) {
                let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let newTaskProject else { return }
                let trimmedLink = newTaskLink.trimmingCharacters(in: .whitespacesAndNewlines)
                modelContext.insert(TaskItem(title: trimmed, link: trimmedLink.isEmpty ? nil : trimmedLink, project: newTaskProject))
                modelContext.saveAndCheckpoint()
                showingNewTaskSheet = false
            } onCancel: {
                showingNewTaskSheet = false
            }
        }
    }

    private func blockHeader(title: String, count: Int, singular: String, plural: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Spacer()
            Text(count == 1 ? "1 \(singular)" : "\(count) \(plural)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.vertical, Theme.Spacing.xs)
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
        .padding(Theme.Spacing.lg)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }
}
