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
    @Query private var sessions: [Session]

    init(task: TaskItem) {
        self.task = task
        let taskID = task.persistentModelID
        _sessions = Query(
            filter: #Predicate<Session> { $0.task?.persistentModelID == taskID },
            sort: \Session.startedAt,
            order: .reverse
        )
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView("Ainda sem sessões", systemImage: "clock", description: Text("As sessões desta tarefa vão aparecer aqui."))
            } else {
                List {
                    ForEach(sessions) { session in
                        TaskSessionRow(session: session)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
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
        }
    }
}

/// A history row: not itself tappable — editing and deleting are explicit
/// actions revealed on hover, so browsing the list never opens the editor
/// by accident.
private struct TaskSessionRow: View {
    let session: Session

    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                Spacer()
                if let note = session.note, !note.isEmpty {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                }
                Text(TimerEngine.format(session.endedAt.timeIntervalSince(session.startedAt)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help("Editar sessão")

                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(.red)
                    .help("Apagar sessão")
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
                .allowsHitTesting(isHovering)
            }
            .font(.caption)

            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .confirmationDialog("Apagar esta sessão?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) {
                modelContext.delete(session)
            }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                SessionEditorView(session: session)
            }
            .frame(width: 420, height: 520)
        }
    }
}
