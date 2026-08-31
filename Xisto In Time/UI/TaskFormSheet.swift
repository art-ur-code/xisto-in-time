//
//  TaskFormSheet.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

/// Shared create/edit form for a task's title and project — used by
/// `TasksBrowserView` (create) and `TaskDetailView` (edit).
struct TaskFormSheet: View {
    let title: String
    @Binding var taskTitle: String
    @Binding var link: String
    @Binding var project: Project?
    let projects: [Project]
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var newProjectColor = Color.accentColor

    var body: some View {
        NavigationStack {
            Form {
                TextField("Título", text: $taskTitle)
                TextField("Link da tarefa", text: $link)
                HStack {
                    Picker("Projecto", selection: $project) {
                        if projects.isEmpty {
                            Text("Nenhum").tag(Project?.none)
                        }
                        ForEach(projects) { p in
                            projectLabel(p).tag(Project?.some(p))
                        }
                    }
                    Button {
                        newProjectName = ""
                        newProjectColor = .accentColor
                        showingNewProjectSheet = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Novo projecto")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let parsed = Self.splitMarkdownLink(taskTitle) {
                            taskTitle = parsed.title
                            link = parsed.url
                        }
                        onSave()
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || project == nil)
                }
            }
        }
        .frame(width: 360, height: 220)
        .sheet(isPresented: $showingNewProjectSheet) {
            ProjectFormSheet(title: "Novo projecto", name: $newProjectName, color: $newProjectColor) {
                let trimmed = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let newProject = Project(name: trimmed, colorHex: newProjectColor.toHex())
                modelContext.insert(newProject)
                modelContext.saveAndCheckpoint()
                project = newProject
                showingNewProjectSheet = false
            } onCancel: {
                showingNewProjectSheet = false
            }
        }
    }

    /// Splits a title pasted as a Markdown link (`[title](url)`) into its
    /// parts, so pasting a link straight into "Título" fills both fields.
    static func splitMarkdownLink(_ text: String) -> (title: String, url: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix(")") else { return nil }
        guard let separatorRange = trimmed.range(of: "](", options: .backwards) else { return nil }
        let titlePart = trimmed[trimmed.index(after: trimmed.startIndex)..<separatorRange.lowerBound]
        let urlPart = trimmed[separatorRange.upperBound..<trimmed.index(before: trimmed.endIndex)]
        let trimmedTitle = titlePart.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let url = URL(string: trimmedURL), url.scheme != nil else { return nil }
        return (trimmedTitle, trimmedURL)
    }

    private func projectLabel(_ project: Project) -> some View {
        Label {
            Text(project.name)
        } icon: {
            Circle().fill(project.color).frame(width: 10, height: 10)
        }
    }
}
