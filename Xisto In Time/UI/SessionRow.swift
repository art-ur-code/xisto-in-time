//
//  SessionRow.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftData
import SwiftUI

/// A session card: not itself editable in place — a double click opens the
/// same `SessionEditorView`, pushed onto the page, wherever this is used
/// (Sessões, dentro de uma Tarefa, dentro de um Projecto). The "Começar"
/// button starts a new free-mode session with the same task, stopping
/// whatever is currently running first.
struct SessionRow: View {
    let session: Session
    var showsTask: Bool = true
    let path: Binding<NavigationPath>

    @Environment(\.modelContext) private var modelContext
    @Environment(TimerEngine.self) private var timerEngine
    @Environment(PomodoroController.self) private var pomodoro
    @AppStorage(PreferencesKey.notePreviewSize)
    private var notePreviewSize = PreferencesDefault.notePreviewSize
    @State private var showingDeleteConfirmation = false

    private var isRunningThisTask: Bool {
        guard let task = session.task else { return false }
        return timerEngine.isRunning && timerEngine.currentTask?.persistentModelID == task.persistentModelID
    }

    var body: some View {
        HStack(spacing: 12) {
            if showsTask, let project = session.task?.project {
                Circle()
                    .fill(project.color)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 4) {
                if showsTask {
                    Text(session.task?.title ?? "Sem atribuição")
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                HStack(spacing: 6) {
                    if showsTask, let project = session.task?.project {
                        Text(project.name)
                    }
                    Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

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
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                startFreeSession()
            } label: {
                Label("Começar", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .tint(session.task?.project?.color ?? .accentColor)
            .disabled(isRunningThisTask)

            RowDisclosureChevron()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
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

    private func startFreeSession() {
        if timerEngine.isRunning {
            pomodoro.cancel()
        }
        timerEngine.start(kind: .work, task: session.task)
    }
}
