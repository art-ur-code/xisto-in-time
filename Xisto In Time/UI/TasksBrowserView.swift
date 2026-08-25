//
//  TasksBrowserView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

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
    @State private var taskPendingDeletion: TaskItem?

    var body: some View {
        Group {
            if tasks.isEmpty {
                ContentUnavailableView("Ainda sem tarefas", systemImage: "checklist", description: Text("Cria a primeira com o botão + em cima."))
            } else {
                List {
                    ForEach(tasks) { task in
                        taskCard(task)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
            }
        }
        .navigationTitle("Tarefas")
        .confirmationDialog(
            "Apagar \"\(taskPendingDeletion?.title ?? "")\"?",
            isPresented: Binding(
                get: { taskPendingDeletion != nil },
                set: { if !$0 { taskPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Apagar tudo", role: .destructive) {
                if let task = taskPendingDeletion {
                    SessionStore.delete(task, in: modelContext)
                }
                taskPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) { taskPendingDeletion = nil }
        } message: {
            if let task = taskPendingDeletion {
                Text(cascadingDeletionWarning(for: task))
            }
        }
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

    private func taskCard(_ task: TaskItem) -> some View {
        HStack(spacing: 10) {
            if let project = task.project {
                Circle()
                    .fill(project.color)
                    .frame(width: 12, height: 12)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(task.archived ? .secondary : .primary)
                    .strikethrough(task.archived)
                if let project = task.project {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let url = task.linkURL {
                Link(destination: url) {
                    Image(systemName: "link")
                }
                .buttonStyle(.bordered)
                .tint(task.project?.color ?? .accentColor)
                .help(task.link ?? "")
            }
            RowDisclosureChevron()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .openOnDoubleClick {
            path.wrappedValue.append(TaskRoute(id: task.persistentModelID))
        }
        .contextMenu {
            Button(task.archived ? "Reactivar" : "Arquivar") {
                task.archived.toggle()
                modelContext.saveAndCheckpoint()
            }
            Button("Apagar", role: .destructive) {
                taskPendingDeletion = task
            }
        }
    }

    private func cascadingDeletionWarning(for task: TaskItem) -> String {
        let sessionCount = SessionStore.sessions(for: task, context: modelContext).count
        let sessionPart = sessionCount == 1 ? "1 sessão" : "\(sessionCount) sessões"
        return "Isto apaga também \(sessionPart) associadas. Não pode ser desfeito."
    }
}
