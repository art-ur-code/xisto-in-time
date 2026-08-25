//
//  TasksBrowserView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

private struct ProjectTaskGroup: Identifiable {
    let id: String
    let project: Project?
    let tasks: [TaskItem]
}

struct TasksBrowserView: View {
    let path: Binding<NavigationPath>

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.title) private var tasks: [TaskItem]
    @Query(filter: #Predicate<Project> { !$0.archived }, sort: \Project.name)
    private var projects: [Project]

    @State private var showingNewTaskSheet = false
    @State private var newTaskTitle = ""
    @State private var newTaskLink = ""
    @State private var newTaskProject: Project?

    private var groupedTasks: [ProjectTaskGroup] {
        var groups: [String: (project: Project?, tasks: [TaskItem])] = [:]
        for task in tasks {
            let key = task.project.map { "p:\($0.persistentModelID)" } ?? "none"
            var entry = groups[key] ?? (task.project, [])
            entry.tasks.append(task)
            groups[key] = entry
        }
        return groups.map { key, value in
            ProjectTaskGroup(id: key, project: value.project, tasks: value.tasks.sorted { $0.title < $1.title })
        }.sorted { lhs, rhs in
            guard let lp = lhs.project, let rp = rhs.project else { return lhs.project != nil }
            return lp.name < rp.name
        }
    }

    var body: some View {
        Group {
            if tasks.isEmpty {
                ContentUnavailableView("Ainda sem tarefas", systemImage: "checklist", description: Text("Cria a primeira com o botão + em cima."))
            } else {
                List {
                    ForEach(groupedTasks) { group in
                        Section {
                            ForEach(group.tasks) { task in
                                TaskCard(task: task, showsProject: false, path: path)
                            }
                        } header: {
                            projectHeader(for: group)
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
            }
        }
        .navigationTitle("Tarefas")
        .toolbar {
            ToolbarItem {
                Button {
                    newTaskTitle = ""
                    newTaskLink = ""
                    newTaskProject = projects.first
                    showingNewTaskSheet = true
                } label: {
                    Label("Nova tarefa", systemImage: "plus")
                }
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

    private func projectHeader(for group: ProjectTaskGroup) -> some View {
        HStack {
            if let project = group.project {
                Circle().fill(project.color).frame(width: 10, height: 10)
                Text(project.name).font(.subheadline.bold())
            } else {
                Text("Sem projecto").font(.subheadline.bold()).foregroundStyle(.secondary)
            }
            Spacer()
            Text(group.tasks.count == 1 ? "1 tarefa" : "\(group.tasks.count) tarefas")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }
}
