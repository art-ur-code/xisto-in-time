//
//  SessionControlView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

/// Start/stop control for the shared `TimerEngine`/`PomodoroController` —
/// the same live timer, usable from both the popover and the main window.
struct SessionControlView: View {
    @Environment(TimerEngine.self) private var timerEngine
    @Environment(PomodoroController.self) private var pomodoro
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Session.startedAt, order: .reverse)
    private var sessions: [Session]

    @State private var selectedTask: TaskItem?
    @State private var showingPicker = false
    @AppStorage(PreferencesKey.lastSessionMode) private var mode = PreferencesDefault.lastSessionMode
    @AppStorage(PreferencesKey.pomodoroWorkMinutes) private var focusMinutes = PreferencesDefault.pomodoroWorkMinutes
    @AppStorage(PreferencesKey.pomodoroCyclesBeforeLongBreak) private var blocks = PreferencesDefault.pomodoroCyclesBeforeLongBreak
    @State private var pomodoroWorkOverride: TimeInterval?
    @State private var pulseOpacity: Double = 1

    @State private var isEditingElapsed = false
    @State private var elapsedEditText = ""
    @FocusState private var elapsedFieldFocused: Bool

    private let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    private var accentColor: Color {
        activeTask?.project?.color ?? .accentColor
    }

    /// The task to display for the current/upcoming session. While running, this must come
    /// from the shared `TimerEngine` — not the local `selectedTask` — because the session may
    /// have been started from a different `SessionControlView` instance (popover vs. main
    /// window sidebar) or from elsewhere entirely (`TaskDetailView`, `SessionRow`), none of
    /// which touch this view's local selection state.
    private var activeTask: TaskItem? {
        timerEngine.isRunning ? timerEngine.currentTask : selectedTask
    }

    var body: some View {
        Group {
            if showingPicker {
                TaskPickerView(
                    currentTask: selectedTask,
                    onSelect: { task in
                        selectedTask = task
                        withAnimation(.easeInOut(duration: 0.25)) { showingPicker = false }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.25)) { showingPicker = false }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                normalContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingPicker)
    }

    private var normalContent: some View {
        VStack(alignment: .leading, spacing: compact ? Theme.Spacing.md : 14) {
            if timerEngine.isRunning {
                runningIndicatorRow
            }

            timerCard

            if timerEngine.interrupted {
                Label("Sessão interrompida por sleep", systemImage: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if timerEngine.isPaused {
                Label("Sessão em pausa", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !timerEngine.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    modeSelector
                        .onChange(of: mode) { _, newMode in
                            if newMode == .pomodoro {
                                pomodoroWorkOverride = nil
                            }
                        }

                    Text(modeLegend)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if mode == .pomodoro {
                    focusBlocksConfig
                }
            }

            contextCell

            if timerEngine.isRunning {
                HStack(spacing: 8) {
                    Button {
                        if timerEngine.isPaused {
                            timerEngine.resume()
                        } else {
                            timerEngine.pause()
                        }
                    } label: {
                        Label(
                            timerEngine.isPaused ? "Retomar" : "Pausar",
                            systemImage: timerEngine.isPaused ? "play.fill" : "pause.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColor)
                    .controlSize(compact ? .regular : .large)

                    Button {
                        stopCurrentPhase()
                    } label: {
                        Label("Parar", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(compact ? .regular : .large)
                }
            } else {
                Button {
                    startCurrentPhase()
                } label: {
                    Label(startButtonTitle, systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(compact ? .regular : .large)
            }

            if !timerEngine.isRunning {
                lastTaskFooter
            }

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
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.2), value: timerEngine.isRunning)
        .frame(maxWidth: compact ? .infinity : 420, alignment: .leading)
    }

    private var timerCard: some View {
        VStack(spacing: 8) {
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
                    Text(formattedTimerText(displayedInterval))
                        .font(.system(compact ? .title2 : .largeTitle, design: .monospaced, weight: .semibold))
                        .help("Clica para editar o tempo decorrido")
                        .onTapGesture {
                            elapsedEditText = formattedTimerText(displayedInterval)
                            isEditingElapsed = true
                            elapsedFieldFocused = true
                        }
                }
            }

            if mode == .pomodoro {
                blockBars(completed: timerEngine.isRunning ? pomodoro.completedWorkCycles : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? Theme.Spacing.md : 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor.opacity(timerEngine.isRunning ? 0.16 : 0.08))
        )
        .foregroundStyle(timerEngine.isRunning ? accentColor : .primary)
    }

    /// Two independent, fully-rounded toggle buttons with a gap between them —
    /// deliberately not `.pickerStyle(.segmented)`, whose native macOS look
    /// joins the segments into one piece (round only at the outer ends,
    /// straight where they meet).
    private var modeSelector: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(TimerMode.allCases) { m in
                Button {
                    mode = m
                } label: {
                    Text(m.label)
                        .font(.system(size: Theme.Font.callout, weight: m == mode ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .fill(m == mode ? accentColor : Color.gray.opacity(0.18))
                )
                .foregroundStyle(m == mode ? .white : .primary)
            }
        }
    }

    private var runningIndicatorRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 7, height: 7)
                    .opacity(pulseOpacity)
                    .onAppear {
                        pulseOpacity = 1
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseOpacity = 0.15
                        }
                    }
                Text(runningStatusText)
                    .font(.caption.weight(.semibold))
            }
            Spacer()
            Text(runningTimeHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func blockBars(completed: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<blocks, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor(for: index, completed: completed))
                    .frame(width: 22, height: 5)
            }
        }
    }

    private func barColor(for index: Int, completed: Int) -> Color {
        if index < completed {
            accentColor
        } else if index == completed && timerEngine.isRunning {
            accentColor.opacity(0.5)
        } else {
            Color(nsColor: .quaternaryLabelColor)
        }
    }

    private var runningStatusText: String {
        if mode == .pomodoro {
            switch pomodoro.phase {
            case .work: return "Foco \(pomodoro.completedWorkCycles + 1) de \(blocks)"
            case .shortBreak: return "Pausa curta"
            case .longBreak: return "Pausa longa"
            }
        }
        return "A contar · Livre"
    }

    private var runningTimeHint: String {
        if mode == .pomodoro, let remaining = timerEngine.remaining {
            let endsAt = Date().addingTimeInterval(remaining)
            let label = pomodoro.phase == .work ? "pausa às" : "volta às"
            return "\(label) \(endsAt.formatted(date: .omitted, time: .shortened))"
        }
        let startedAt = Date().addingTimeInterval(-timerEngine.elapsed)
        return "desde \(startedAt.formatted(date: .omitted, time: .shortened))"
    }

    private func formattedTimerText(_ interval: TimeInterval) -> String {
        guard mode == .pomodoro else { return TimerEngine.format(interval) }
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var modeLegend: String {
        switch mode {
        case .free:
            return "Conta para cima até parares. Sem pausas automáticas."
        case .pomodoro:
            let endsAt = Date().addingTimeInterval(pomodoroEstimatedDuration)
            let endsAtText = endsAt.formatted(date: .omitted, time: .shortened)
            return "\(blocks) blocos de foco com \(Preferences.pomodoroShortBreakMinutes()) min de pausa. Termina às \(endsAtText)."
        }
    }

    private var pomodoroEstimatedDuration: TimeInterval {
        let focusSeconds = TimeInterval(focusMinutes * 60 * blocks)
        let breakSeconds = TimeInterval(Preferences.pomodoroShortBreakMinutes() * 60 * max(0, blocks - 1))
        return focusSeconds + breakSeconds
    }

    private var startButtonTitle: String {
        mode == .pomodoro ? "Começar foco 1 de \(blocks)" : "Começar"
    }

    private var focusBlocksConfig: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Foco")
                Spacer()
                Picker("", selection: $focusMinutes) {
                    ForEach([15, 25, 45, 50], id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .padding(.vertical, 6)

            Divider()

            HStack {
                Text("Blocos")
                Spacer()
                Picker("", selection: $blocks) {
                    ForEach(2...8, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    /// The value shown when not actively editing: the running countdown/count-up while a
    /// session is live, or a preview of what Começar will use while idle.
    private var displayedInterval: TimeInterval {
        if mode == .pomodoro {
            if timerEngine.isRunning, let remaining = timerEngine.remaining {
                return remaining
            }
            if !timerEngine.isRunning {
                return pomodoroWorkOverride ?? TimeInterval(focusMinutes * 60)
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

    private var contextCell: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if let activeTask {
                    Text("A REGISTAR EM")
                        .font(.system(size: Theme.Font.caption, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Text(activeTask.title)
                        .font(.system(size: Theme.Font.callout, weight: .semibold))
                        .lineLimit(2)
                    if let project = activeTask.project {
                        Text(project.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("A REGISTAR EM")
                        .font(.system(size: Theme.Font.caption, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Text("Sem tarefa")
                        .font(.system(size: Theme.Font.callout, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !timerEngine.isRunning {
                Button("Mudar") { showingPicker = true }
                    .buttonStyle(.plain)
                    .font(.system(size: Theme.Font.body, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture {
            if !timerEngine.isRunning { showingPicker = true }
        }
    }

    @ViewBuilder
    private var lastTaskFooter: some View {
        if let lastTask {
            HStack {
                Text("Última: \(lastTask.title) · \(ReportBuilder.formatHoursMinutes(todayTotal(for: lastTask)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("Retomar") {
                    selectedTask = lastTask
                    startCurrentPhase()
                }
                .buttonStyle(.plain)
                .font(.system(size: Theme.Font.footnote, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var lastTask: TaskItem? {
        sessions.first(where: { $0.task != nil })?.task
    }

    private func todayTotal(for task: TaskItem) -> TimeInterval {
        let taskID = task.persistentModelID
        return ReportBuilder.dailyReport(sessions: sessions, day: Date()).sessions
            .filter { $0.task?.persistentModelID == taskID }
            .reduce(0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
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
