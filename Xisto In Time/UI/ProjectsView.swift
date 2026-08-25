//
//  ProjectsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct ProjectsView: View {
    let path: Binding<NavigationPath>

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var newProjectColor = Color.accentColor
    @State private var projectPendingDeletion: Project?

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView("Ainda sem projectos", systemImage: "folder", description: Text("Cria o primeiro com o botão + em cima."))
            } else {
                List {
                    ForEach(projects) { project in
                        projectCard(project)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
            }
        }
        .navigationTitle("Projectos")
        .confirmationDialog(
            "Apagar \"\(projectPendingDeletion?.name ?? "")\"?",
            isPresented: Binding(
                get: { projectPendingDeletion != nil },
                set: { if !$0 { projectPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Apagar tudo", role: .destructive) {
                if let project = projectPendingDeletion {
                    SessionStore.delete(project, in: modelContext)
                }
                projectPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) { projectPendingDeletion = nil }
        } message: {
            if let project = projectPendingDeletion {
                Text(cascadingDeletionWarning(for: project))
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    newProjectName = ""
                    newProjectColor = .accentColor
                    showingNewProjectSheet = true
                } label: {
                    Label("Novo projecto", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewProjectSheet) {
            ProjectFormSheet(title: "Novo projecto", name: $newProjectName, color: $newProjectColor) {
                let trimmed = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                modelContext.insert(Project(name: trimmed, colorHex: newProjectColor.toHex()))
                modelContext.saveAndCheckpoint()
                showingNewProjectSheet = false
            } onCancel: {
                showingNewProjectSheet = false
            }
        }
    }

    private func projectCard(_ project: Project) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(project.color)
                .frame(width: 14, height: 14)
            Text(project.name)
                .font(.headline)
                .foregroundStyle(project.archived ? .secondary : .primary)
                .strikethrough(project.archived)
            Spacer()
            if project.archived {
                Text("Arquivado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            RowDisclosureChevron()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .openOnDoubleClick {
            path.wrappedValue.append(ProjectRoute(id: project.persistentModelID))
        }
        .contextMenu {
            Button(project.archived ? "Reactivar" : "Arquivar") {
                project.archived.toggle()
                modelContext.saveAndCheckpoint()
            }
            Button("Apagar", role: .destructive) {
                projectPendingDeletion = project
            }
        }
    }

    private func cascadingDeletionWarning(for project: Project) -> String {
        let tasks = SessionStore.tasks(in: project, context: modelContext)
        let sessionCount = tasks.reduce(0) { $0 + SessionStore.sessions(for: $1, context: modelContext).count }
        let taskPart = tasks.count == 1 ? "1 tarefa" : "\(tasks.count) tarefas"
        let sessionPart = sessionCount == 1 ? "1 sessão" : "\(sessionCount) sessões"
        return "Isto apaga também \(taskPart) e \(sessionPart) associadas. Não pode ser desfeito."
    }
}
