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
    let path: Binding<NavigationPath>
    @Query private var sessions: [Session]

    init(task: TaskItem, path: Binding<NavigationPath>) {
        self.task = task
        self.path = path
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
                        SessionRow(session: session, showsTask: false, path: path)
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
