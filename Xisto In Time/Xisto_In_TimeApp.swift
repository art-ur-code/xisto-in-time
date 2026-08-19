//
//  Xisto_In_TimeApp.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

@main
struct Xisto_In_TimeApp: App {
    private let sharedModelContainer: ModelContainer
    private let overlayController = OverlayController()
    private let idleMonitor: IdleMonitor
    private let menuBarController: MenuBarController

    @State private var timerEngine: TimerEngine
    @State private var pomodoro: PomodoroController

    init() {
        let schema = Schema([Session.self, TaskItem.self, Project.self])
        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration()])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        let engine = TimerEngine()
        let controller = PomodoroController(timerEngine: engine, modelContext: sharedModelContainer.mainContext)
        _timerEngine = State(initialValue: engine)
        _pomodoro = State(initialValue: controller)

        let overlay = overlayController
        engine.onTargetReached = { [weak controller] in
            guard let controller else { return }
            overlay.show {
                PomodoroDecisionView(
                    phase: controller.phase,
                    onAdvance: { controller.advance(); overlay.hide() },
                    onSnooze: { controller.snooze(); overlay.hide() },
                    onTerminate: { controller.cancel(); overlay.hide() }
                )
            }
        }

        let modelContext = sharedModelContainer.mainContext
        let idle = IdleMonitor(timerEngine: engine)
        idleMonitor = idle
        idle.onIdleDetected = { [weak engine] idleStartedAt in
            guard let engine else { return }
            switch Preferences.idleResolutionMode() {
            case .autoDiscard:
                engine.discardInterval(Date().timeIntervalSince(idleStartedAt))
            case .notifyOnly:
                IdleMonitor.notifyIdleDetected(thresholdMinutes: Preferences.idleThresholdMinutes())
            case .ask:
                overlay.show {
                    IdleResolutionView(
                        idleStartedAt: idleStartedAt,
                        onDiscard: {
                            engine.discardInterval(Date().timeIntervalSince(idleStartedAt))
                            overlay.hide()
                        },
                        onKeep: { overlay.hide() },
                        onEndSession: {
                            if let finished = engine.stop(endedAt: idleStartedAt) {
                                SessionStore.recordFinishedSession(finished, in: modelContext)
                            }
                            overlay.hide()
                        }
                    )
                }
            }
        }

        menuBarController = MenuBarController(timerEngine: engine, pomodoro: controller, modelContext: modelContext)
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
