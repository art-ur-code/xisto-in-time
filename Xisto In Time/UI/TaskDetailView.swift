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
                        NavigationLink(value: SessionRoute(id: session.persistentModelID)) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    Spacer()
                                    Text(TimerEngine.format(session.endedAt.timeIntervalSince(session.startedAt)))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
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
                        }
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
