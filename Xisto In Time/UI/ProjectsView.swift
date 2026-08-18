//
//  ProjectsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var newProjectColor = Color.accentColor

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView("Ainda sem projectos", systemImage: "folder", description: Text("Cria o primeiro com o botão + em cima."))
            } else {
                List {
                    ForEach(projects) { project in
                        NavigationLink(value: ProjectRoute(id: project.persistentModelID)) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(project.color)
                                    .frame(width: 12, height: 12)
                                Text(project.name)
                                    .foregroundStyle(project.archived ? .secondary : .primary)
                                    .strikethrough(project.archived)
                                Spacer()
                                if project.archived {
                                    Text("Arquivado")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .contextMenu {
                            Button(project.archived ? "Reactivar" : "Arquivar") {
                                project.archived.toggle()
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Projectos")
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
                showingNewProjectSheet = false
            } onCancel: {
                showingNewProjectSheet = false
            }
        }
    }
}
