//
//  AllSessionsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct AllSessionsView: View {
    let path: Binding<NavigationPath>

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
                        SessionRow(session: session, path: path)
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
