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
                        NavigationLink(value: SessionRoute(id: session.persistentModelID)) {
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
                                Text(TimerEngine.format(session.endedAt.timeIntervalSince(session.startedAt)))
                                    .monospacedDigit()
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
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
