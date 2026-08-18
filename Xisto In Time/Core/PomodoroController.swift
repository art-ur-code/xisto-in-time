//
//  PomodoroController.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import Foundation
import Observation
import SwiftData

enum PomodoroPhase {
    case work
    case shortBreak
    case longBreak
}

@Observable
final class PomodoroController {
    private(set) var phase: PomodoroPhase = .work
    private(set) var completedWorkCycles = 0
    private(set) var currentTask: TaskItem?

    private let timerEngine: TimerEngine
    private let modelContext: ModelContext

    init(timerEngine: TimerEngine, modelContext: ModelContext) {
        self.timerEngine = timerEngine
        self.modelContext = modelContext
    }

    func startWork(task: TaskItem?) {
        phase = .work
        completedWorkCycles = 0
        currentTask = task
        timerEngine.start(targetDuration: TimeInterval(Preferences.pomodoroWorkMinutes() * 60), kind: .work, task: task)
    }

    /// Manual abandon (user pressed Parar mid-phase, not via the decision).
    func cancel() {
        if let finished = timerEngine.stop() {
            SessionStore.recordFinishedSession(finished, in: modelContext)
        }
        completedWorkCycles = 0
        currentTask = nil
    }

    /// Finish the current phase and auto-start the next one (work -> break -> work...).
    func advance() {
        guard let finished = timerEngine.stop() else { return }
        SessionStore.recordFinishedSession(finished, in: modelContext)
        if phase == .work {
            completedWorkCycles += 1
            let isLong = completedWorkCycles % Preferences.pomodoroCyclesBeforeLongBreak() == 0
            phase = isLong ? .longBreak : .shortBreak
            let minutes = isLong ? Preferences.pomodoroLongBreakMinutes() : Preferences.pomodoroShortBreakMinutes()
            timerEngine.start(targetDuration: TimeInterval(minutes * 60), kind: .break, task: nil)
        } else {
            phase = .work
            timerEngine.start(targetDuration: TimeInterval(Preferences.pomodoroWorkMinutes() * 60), kind: .work, task: currentTask)
        }
    }

    /// Keep the current phase running past its target (no phase change).
    func snooze() {
        timerEngine.snoozeTarget()
    }
}
