//
//  MainWindowView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import AppKit
import SwiftData
import SwiftUI

/// Navigation values for `@Model` types themselves: `@Model`'s synthesized
/// `Hashable` conformance is MainActor-isolated, which `navigationDestination`
/// can't use directly. Route by `PersistentIdentifier` instead (a plain,
/// non-isolated `Hashable` struct) and re-fetch the model at the destination.
struct ProjectRoute: Hashable {
    let id: PersistentIdentifier
}

struct TaskRoute: Hashable {
    let id: PersistentIdentifier
}

struct SessionRoute: Hashable {
    let id: PersistentIdentifier
}

private struct ProjectDetailByIDView: View {
    let id: PersistentIdentifier
    let path: Binding<NavigationPath>
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let project = modelContext.model(for: id) as? Project {
            ProjectDetailView(project: project, path: path)
        } else {
            Text("Projecto não encontrado")
                .foregroundStyle(.secondary)
        }
    }
}

private struct TaskDetailByIDView: View {
    let id: PersistentIdentifier
    let path: Binding<NavigationPath>
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let task = modelContext.model(for: id) as? TaskItem {
            TaskDetailView(task: task, path: path)
        } else {
            Text("Tarefa não encontrada")
                .foregroundStyle(.secondary)
        }
    }
}

private struct SessionEditorByIDView: View {
    let id: PersistentIdentifier
    @Query private var sessions: [Session]

    init(id: PersistentIdentifier) {
        self.id = id
        _sessions = Query(filter: #Predicate<Session> { $0.persistentModelID == id })
    }

    var body: some View {
        if let session = sessions.first {
            SessionEditorView(session: session)
        } else {
            Text("Sessão não encontrada")
                .foregroundStyle(.secondary)
        }
    }
}

enum MainWindowSection: String, CaseIterable, Identifiable {
    case sessions = "Sessões"
    case projects = "Projectos"
    case tasks = "Tarefas"
    case reports = "Estatísticas"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .projects: "folder.fill"
        case .tasks: "checklist"
        case .sessions: "list.bullet.clipboard.fill"
        case .reports: "chart.bar.fill"
        }
    }

    var tint: Color {
        switch self {
        case .projects: .blue
        case .tasks: .green
        case .sessions: .orange
        case .reports: .purple
        }
    }
}

struct MainWindowView: View {
    @State private var selection: MainWindowSection? = .sessions
    @State private var path = NavigationPath()

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(MainWindowSection.allCases, selection: $selection) { section in
                    Label {
                        Text(section.rawValue)
                    } icon: {
                        Image(systemName: section.systemImage)
                            .foregroundStyle(section.tint)
                    }
                    .tag(section)
                }

                Divider()

                SettingsLink {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("Preferências")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("Sair")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            NavigationStack(path: $path) {
                detailContent
                    .navigationDestination(for: ProjectRoute.self) { route in
                        ProjectDetailByIDView(id: route.id, path: $path)
                    }
                    .navigationDestination(for: TaskRoute.self) { route in
                        TaskDetailByIDView(id: route.id, path: $path)
                    }
                    .navigationDestination(for: SessionRoute.self) { route in
                        SessionEditorByIDView(id: route.id)
                    }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .projects:
            ProjectsView(path: $path)
        case .tasks:
            TasksBrowserView(path: $path)
        case .sessions:
            AllSessionsView(path: $path)
        case .reports:
            ReportsView()
        case .none:
            Text("Selecciona uma secção")
                .foregroundStyle(.secondary)
        }
    }
}
