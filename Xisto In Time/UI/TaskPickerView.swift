//
//  TaskPickerView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 20/08/2026.
//

import SwiftUI
import SwiftData

/// Search-driven task/project picker, pushed in place of `SessionControlView`'s
/// normal content (see `SessionControlView.showingPicker`) — not a separate
/// window or sheet, so the popover/mini-timer stays a single surface.
struct TaskPickerView: View {
    let currentTask: TaskItem?
    let onSelect: (TaskItem) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Project> { !$0.archived }, sort: \Project.name)
    private var projects: [Project]

    @Query(filter: #Predicate<TaskItem> { !$0.archived }, sort: \TaskItem.title)
    private var tasks: [TaskItem]

    @Query(sort: \Session.startedAt, order: .reverse)
    private var sessions: [Session]

    @State private var searchQuery = ""
    @State private var browsingProject: Project?
    @State private var highlightedIndex = 0

    @State private var showingCreateTaskSheet = false
    @State private var newTaskTitle = ""
    @State private var newTaskLink = ""
    @State private var newTaskProject: Project?

    @FocusState private var searchFieldFocused: Bool

    private enum Row: Identifiable {
        case recentTask(TaskItem)
        case project(Project)
        case backToProjects
        case scopedTask(TaskItem)
        case filteredTask(TaskItem)
        case createTask

        var id: String {
            switch self {
            case .recentTask(let t): "recent-\(t.persistentModelID)"
            case .project(let p): "project-\(p.persistentModelID)"
            case .backToProjects: "back"
            case .scopedTask(let t): "scoped-\(t.persistentModelID)"
            case .filteredTask(let t): "filtered-\(t.persistentModelID)"
            case .createTask: "create"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollViewReader { proxy in
                List {
                    content
                }
                .listStyle(.plain)
                .frame(minHeight: 280, maxHeight: 420)
                .onChange(of: highlightedIndex) { _, newValue in
                    if let row = navigableRows[safe: newValue] {
                        proxy.scrollTo(row.id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { searchFieldFocused = true }
        .onChange(of: searchQuery) { _, newValue in
            highlightedIndex = 0
            if !newValue.isEmpty { browsingProject = nil }
        }
        .onChange(of: browsingProject) { _, _ in highlightedIndex = 0 }
        .sheet(isPresented: $showingCreateTaskSheet) {
            TaskFormSheet(title: "Nova tarefa", taskTitle: $newTaskTitle, link: $newTaskLink, project: $newTaskProject, projects: projects) {
                let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let newTaskProject else { return }
                let trimmedLink = newTaskLink.trimmingCharacters(in: .whitespacesAndNewlines)
                let task = TaskItem(title: trimmed, link: trimmedLink.isEmpty ? nil : trimmedLink, project: newTaskProject)
                modelContext.insert(task)
                modelContext.saveAndCheckpoint()
                showingCreateTaskSheet = false
                onSelect(task)
            } onCancel: {
                showingCreateTaskSheet = false
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Procurar tarefa ou projecto", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .focused($searchFieldFocused)
                    .onKeyPress(.downArrow) { moveHighlight(by: 1); return .handled }
                    .onKeyPress(.upArrow) { moveHighlight(by: -1); return .handled }
                    .onKeyPress(.return) { activateHighlighted(); return .handled }
            }
            .padding(Theme.Spacing.md)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))

            Button("Cancelar", action: onCancel)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .onExitCommand(perform: onCancel)
    }

    @ViewBuilder
    private var content: some View {
        if let browsingProject {
            Section {
                Label(browsingProject.name, systemImage: "chevron.left")
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                    .onTapGesture { self.browsingProject = nil }
                    .id(Row.backToProjects.id)
            }
            let scoped = tasksIn(browsingProject)
            Section("\(scoped.count) tarefas") {
                ForEach(scoped) { task in
                    taskRow(task, query: "", row: .scopedTask(task))
                }
            }
        } else if searchQuery.isEmpty {
            if !recentTasks.isEmpty {
                Section("RECENTES") {
                    ForEach(recentTasks) { task in
                        recentRow(task)
                    }
                }
            }
            Section("PROJECTOS") {
                ForEach(projects) { project in
                    projectRow(project)
                }
            }
        } else {
            Section("\(filteredTasks.count) tarefas") {
                ForEach(filteredTasks) { task in
                    taskRow(task, query: searchQuery, row: .filteredTask(task))
                }
                if showsCreateRow {
                    Button {
                        startCreatingTask()
                    } label: {
                        Label("Criar tarefa «\(searchQuery)»", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .frame(minHeight: 28)
                    .id(Row.createTask.id)
                }
            }
        }
    }

    private func recentRow(_ task: TaskItem) -> some View {
        let row = Row.recentTask(task)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: Theme.Font.callout, weight: .semibold))
                    .lineLimit(2)
                if let project = task.project {
                    Text("\(project.name) · \(ReportBuilder.formatHoursMinutes(todayTotal(for: task)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if task.persistentModelID == currentTask?.persistentModelID {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 28)
        .contentShape(Rectangle())
        .listRowBackground(isHighlighted(row) ? Color.accentColor.opacity(0.12) : Color.clear)
        .onTapGesture { onSelect(task) }
        .id(row.id)
    }

    private func projectRow(_ project: Project) -> some View {
        let row = Row.project(project)
        return HStack {
            Label {
                Text(project.name)
            } icon: {
                Circle().fill(project.color).frame(width: 10, height: 10)
            }
            Spacer()
            Text("\(taskCount(for: project))")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 28)
        .contentShape(Rectangle())
        .listRowBackground(isHighlighted(row) ? Color.accentColor.opacity(0.12) : Color.clear)
        .onTapGesture { browsingProject = project }
        .id(row.id)
    }

    private func taskRow(_ task: TaskItem, query: String, row: Row) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                highlightedTitle(task.title, query: query)
                    .font(.system(size: Theme.Font.callout))
                    .lineLimit(2)
                if let project = task.project {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .frame(minHeight: 28)
        .contentShape(Rectangle())
        .listRowBackground(isHighlighted(row) ? Color.accentColor.opacity(0.12) : Color.clear)
        .onTapGesture { onSelect(task) }
        .id(row.id)
    }

    // MARK: - Data

    private var recentTasks: [TaskItem] {
        var seen = Set<PersistentIdentifier>()
        var result: [TaskItem] = []
        for session in sessions {
            guard let task = session.task, !task.archived else { continue }
            if seen.insert(task.persistentModelID).inserted {
                result.append(task)
                if result.count == 5 { break }
            }
        }
        return result
    }

    private var filteredTasks: [TaskItem] {
        tasks.filter { matches($0, query: searchQuery) }
    }

    private var showsCreateRow: Bool {
        guard !searchQuery.isEmpty else { return false }
        return !tasks.contains { $0.title.compare(searchQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    private func matches(_ task: TaskItem, query: String) -> Bool {
        guard !query.isEmpty else { return false }
        if task.title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil { return true }
        if let ref = task.externalRef, ref.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil { return true }
        return false
    }

    private func tasksIn(_ project: Project) -> [TaskItem] {
        tasks.filter { $0.project?.persistentModelID == project.persistentModelID }
    }

    private func taskCount(for project: Project) -> Int {
        tasksIn(project).count
    }

    private func todayTotal(for task: TaskItem) -> TimeInterval {
        let taskID = task.persistentModelID
        return ReportBuilder.dailyReport(sessions: sessions, day: Date()).sessions
            .filter { $0.task?.persistentModelID == taskID }
            .reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
    }

    private func highlightedTitle(_ title: String, query: String) -> Text {
        guard !query.isEmpty,
              let range = title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return Text(title)
        }
        var attributed = AttributedString(title)
        if let attrRange = Range(range, in: attributed) {
            attributed[attrRange].backgroundColor = Color.yellow.opacity(0.35)
        }
        return Text(attributed)
    }

    private func startCreatingTask() {
        newTaskTitle = searchQuery
        newTaskLink = ""
        newTaskProject = browsingProject ?? projects.first
        showingCreateTaskSheet = true
    }

    // MARK: - Keyboard navigation

    private var navigableRows: [Row] {
        if let browsingProject {
            return [.backToProjects] + tasksIn(browsingProject).map { .scopedTask($0) }
        }
        if searchQuery.isEmpty {
            return recentTasks.map { .recentTask($0) } + projects.map { .project($0) }
        }
        var rows = filteredTasks.map { Row.filteredTask($0) }
        if showsCreateRow { rows.append(.createTask) }
        return rows
    }

    private func isHighlighted(_ row: Row) -> Bool {
        navigableRows[safe: highlightedIndex]?.id == row.id
    }

    private func moveHighlight(by delta: Int) {
        let rows = navigableRows
        guard !rows.isEmpty else { return }
        highlightedIndex = max(0, min(rows.count - 1, highlightedIndex + delta))
    }

    private func activateHighlighted() {
        switch navigableRows[safe: highlightedIndex] {
        case .recentTask(let task), .scopedTask(let task), .filteredTask(let task):
            onSelect(task)
        case .project(let project):
            browsingProject = project
        case .backToProjects:
            browsingProject = nil
        case .createTask:
            startCreatingTask()
        case nil:
            break
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
