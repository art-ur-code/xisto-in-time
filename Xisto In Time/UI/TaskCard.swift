//
//  TaskCard.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 25/08/2026.
//

import SwiftData
import SwiftUI

/// A task card, shared by "Tarefas" and the tasks section inside
/// `ProjectDetailView`. `showsProject: false` omits the project dot/name —
/// redundant inside a project's own page, where every card is the same
/// project.
struct TaskCard: View {
    let task: TaskItem
    var showsProject: Bool = true
    let path: Binding<NavigationPath>

    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false

    private var cascadingDeletionWarning: String {
        let sessionCount = SessionStore.sessions(for: task, context: modelContext).count
        let sessionPart = sessionCount == 1 ? "1 sessão" : "\(sessionCount) sessões"
        return "Isto apaga também \(sessionPart) associadas. Não pode ser desfeito."
    }

    var body: some View {
        HStack(spacing: 10) {
            if showsProject, let project = task.project {
                Circle()
                    .fill(project.color)
                    .frame(width: 12, height: 12)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(task.archived ? .secondary : .primary)
                    .strikethrough(task.archived)
                if showsProject, let project = task.project {
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
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
                showingDeleteConfirmation = true
            }
        }
        .confirmationDialog(
            "Apagar \"\(task.title)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Apagar tudo", role: .destructive) {
                SessionStore.delete(task, in: modelContext)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(cascadingDeletionWarning)
        }
    }
}
