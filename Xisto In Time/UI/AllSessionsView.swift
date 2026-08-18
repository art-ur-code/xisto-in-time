//
//  AllSessionsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct AllSessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var showingNewSessionEditor = false

    var body: some View {
        List {
            Section("Nova sessão") {
                SessionControlView()
                    .listRowInsets(EdgeInsets())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }

            Section("Histórico") {
                if sessions.isEmpty {
                    Text("Ainda sem sessões")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        SessionHistoryRow(session: session)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(sessions[index])
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .navigationTitle("Sessões")
        .toolbar {
            ToolbarItem {
                Button {
                    showingNewSessionEditor = true
                } label: {
                    Label("Sessão manual", systemImage: "plus")
                }
                .help("Criar uma sessão passada, com início e fim escolhidos à mão")
            }
        }
        .sheet(isPresented: $showingNewSessionEditor) {
            NavigationStack {
                SessionEditorView()
            }
            .frame(width: 420, height: 520)
        }
    }
}

/// A history row: not itself tappable — editing and deleting are explicit
/// actions revealed on hover, so browsing the list never opens the editor
/// by accident.
private struct SessionHistoryRow: View {
    let session: Session

    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditor = false

    var body: some View {
        HStack(spacing: 10) {
            if let project = session.task?.project {
                Circle()
                    .fill(project.color)
                    .frame(width: 10, height: 10)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                Text(session.task?.title ?? "Sem atribuição")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.editedAt != nil {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if session.interrupted {
                Image(systemName: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note = session.note, !note.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(TimerEngine.format(session.endedAt.timeIntervalSince(session.startedAt)))
                .monospacedDigit()
                .font(.caption)
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
