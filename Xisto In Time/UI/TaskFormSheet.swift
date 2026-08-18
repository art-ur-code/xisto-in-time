//
//  TaskFormSheet.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI

/// Shared create/edit form for a task's title and project — used by
/// `TasksBrowserView` (create) and `TaskDetailView` (edit).
struct TaskFormSheet: View {
    let title: String
    @Binding var taskTitle: String
    @Binding var project: Project?
    let projects: [Project]
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Título", text: $taskTitle)
                Picker("Projecto", selection: $project) {
                    ForEach(projects) { p in
                        projectLabel(p).tag(Project?.some(p))
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: onSave)
                        .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || project == nil)
                }
            }
        }
        .frame(width: 360, height: 220)
    }

    private func projectLabel(_ project: Project) -> some View {
        Label {
            Text(project.name)
        } icon: {
            Circle().fill(project.color).frame(width: 10, height: 10)
        }
    }
}
