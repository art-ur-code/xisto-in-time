//
//  SessionControlView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

private enum TimerMode: String, CaseIterable, Identifiable {
    case free = "Livre"
    case pomodoro = "Pomodoro"
    var id: String { rawValue }
}

/// Start/stop control for the shared `TimerEngine`/`PomodoroController` —
/// the same live timer, usable from both the popover and the main window.
struct SessionControlView: View {
    @Environment(TimerEngine.self) private var timerEngine
    @Environment(PomodoroController.self) private var pomodoro
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Project> { !$0.archived }, sort: \Project.name)
    private var projects: [Project]

    @Query(filter: #Predicate<TaskItem> { !$0.archived }, sort: \TaskItem.title)
    private var tasks: [TaskItem]

    @State private var selectedProject: Project?
    @State private var selectedTask: TaskItem?
    @State private var mode: TimerMode = .free
    @State private var pomodoroWorkOverride: TimeInterval?

    @State private var isEditingElapsed = false
    @State private var elapsedEditText = ""
    @FocusState private var elapsedFieldFocused: Bool

    private let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    private var tasksForSelectedProject: [TaskItem] {
        guard let selectedProject else { return [] }
        return tasks.filter { $0.project?.persistentModelID == selectedProject.persistentModelID }
    }

    private var accentColor: Color {
        selectedProject?.color ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            timerCard

            if timerEngine.interrupted {
                Label("Sessão interrompida por sleep", systemImage: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if mode == .pomodoro && timerEngine.isRunning {
                Text(pomodoroPhaseLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Picker("Modo", selection: $mode) {
                    ForEach(TimerMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(timerEngine.isRunning)
                .onChange(of: mode) { _, newMode in
                    if newMode == .pomodoro {
                        pomodoroWorkOverride = nil
                    }
                }

                Picker("Projecto", selection: $selectedProject) {
                    Text("Nenhum").tag(Project?.none)
                    ForEach(projects) { project in
                        projectLabel(project).tag(Project?.some(project))
                    }
                }
                .onChange(of: selectedProject) { selectedTask = nil }

                Picker("Tarefa", selection: $selectedTask) {
                    Text("Nenhuma").tag(TaskItem?.none)
                    ForEach(tasksForSelectedProject) { task in
                        Text(task.title).tag(TaskItem?.some(task))
                    }
                }
                .disabled(selectedProject == nil)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button {
                if timerEngine.isRunning {
                    stopCurrentPhase()
                } else {
                    startCurrentPhase()
                }
            } label: {
                Label(
                    timerEngine.isRunning ? "Parar" : "Começar",
                    systemImage: timerEngine.isRunning ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(timerEngine.isRunning ? .red : accentColor)
            .controlSize(compact ? .regular : .large)

            if timerEngine.isRunning {
                TextEditor(text: Binding(
                    get: { timerEngine.currentNote },
                    set: { timerEngine.updateNote($0) }
                ))
                .font(.callout)
                .frame(height: compact ? 50 : 70)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: compact ? .infinity : 420, alignment: .leading)
    }

    private var timerCard: some View {
        Group {
            if isEditingElapsed {
                TextField("H:MM:SS", text: $elapsedEditText)
                    .font(.system(compact ? .title2 : .largeTitle, design: .monospaced, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($elapsedFieldFocused)
                    .onSubmit(commitElapsedEdit)
                    .onExitCommand { isEditingElapsed = false }
                    .onChange(of: elapsedFieldFocused) { _, focused in
                        if !focused { commitElapsedEdit() }
                    }
            } else {
                Text(TimerEngine.format(displayedInterval))
                    .font(.system(compact ? .title2 : .largeTitle, design: .monospaced, weight: .semibold))
                    .help("Clica para editar o tempo decorrido")
                    .onTapGesture {
                        elapsedEditText = TimerEngine.format(displayedInterval)
                        isEditingElapsed = true
                        elapsedFieldFocused = true
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 8 : 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor.opacity(timerEngine.isRunning ? 0.16 : 0.08))
        )
        .foregroundStyle(timerEngine.isRunning ? accentColor : .primary)
    }

    /// The value shown when not actively editing: the running countdown/count-up while a
    /// session is live, or a preview of what Começar will use while idle.
    private var displayedInterval: TimeInterval {
        if mode == .pomodoro {
            if timerEngine.isRunning, let remaining = timerEngine.remaining {
                return remaining
            }
            if !timerEngine.isRunning {
                return pomodoroWorkOverride ?? TimeInterval(Preferences.pomodoroWorkMinutes() * 60)
            }
        }
        return timerEngine.elapsed
    }

    private func commitElapsedEdit() {
        guard isEditingElapsed else { return }
        isEditingElapsed = false
        guard let parsed = TimerEngine.parseDuration(elapsedEditText) else { return }

        if mode == .pomodoro {
            if timerEngine.isRunning {
                timerEngine.setRemaining(parsed)
            } else {
                pomodoroWorkOverride = parsed
            }
        } else {
            if !timerEngine.isRunning {
                startCurrentPhase()
            }
            timerEngine.setElapsed(parsed)
        }
    }

    private func projectLabel(_ project: Project) -> some View {
        Label {
            Text(project.name)
        } icon: {
            Circle().fill(project.color).frame(width: 10, height: 10)
        }
    }

    private var pomodoroPhaseLabel: String {
        switch pomodoro.phase {
        case .work: "Trabalho"
        case .shortBreak: "Pausa curta"
        case .longBreak: "Pausa longa"
        }
    }

    private func startCurrentPhase() {
        if mode == .pomodoro {
            pomodoro.startWork(task: selectedTask, workDuration: pomodoroWorkOverride)
            pomodoroWorkOverride = nil
        } else {
            timerEngine.start(kind: .work, task: selectedTask)
        }
    }

    private func stopCurrentPhase() {
        if mode == .pomodoro {
            pomodoro.cancel()
        } else if let finished = timerEngine.stop() {
            SessionStore.recordFinishedSession(finished, in: modelContext)
        }
    }
}
