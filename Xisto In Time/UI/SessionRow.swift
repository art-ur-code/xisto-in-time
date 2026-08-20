//
//  SessionRow.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftData
import SwiftUI

/// A session row: not itself editable in place — a double click opens the
/// same `SessionEditorView`, pushed onto the page, wherever this row is used
/// (Sessões, dentro de uma Tarefa, dentro de um Projecto).
struct SessionRow: View {
    let session: Session
    var showsTask: Bool = true
    let path: Binding<NavigationPath>

    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferencesKey.notePreviewSize)
    private var notePreviewSize = PreferencesDefault.notePreviewSize
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 10) {
            if showsTask, let project = session.task?.project {
                Circle()
                    .fill(project.color)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                    if showsTask {
                        Text(session.task?.title ?? "Sem atribuição")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                if notePreviewSize != .icon, let note = session.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(notePreviewSize == .oneLine ? 1 : 2)
                }
            }

            Spacer()

            if session.interrupted {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.secondary)
            }
            if notePreviewSize == .icon, let note = session.note, !note.isEmpty {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
            }
            Text(TimerEngine.format(session.endedAt.timeIntervalSince(session.startedAt)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            RowDisclosureChevron()
        }
        .font(.caption)
        .padding(.vertical, 2)
        .openOnDoubleClick {
            path.wrappedValue.append(SessionRoute(id: session.persistentModelID))
        }
        .contextMenu {
            Button("Apagar sessão", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
        .confirmationDialog("Apagar esta sessão?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) {
                modelContext.delete(session)
                modelContext.saveAndCheckpoint()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}
