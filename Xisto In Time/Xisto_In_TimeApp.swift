//
//  Xisto_In_TimeApp.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import AppKit
import SwiftUI
import SwiftData

@main
struct Xisto_In_TimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let sharedModelContainer: ModelContainer
    private let overlayController = OverlayController()
    private let idleMonitor: IdleMonitor
    private let menuBarController: MenuBarController
    private let checkpointTimer: Timer
    private var terminationObserver: NSObjectProtocol?

    @State private var timerEngine: TimerEngine
    @State private var pomodoro: PomodoroController

    init() {
        Theme.syncAppAppearance()
        let schema = Schema([Session.self, TaskItem.self, Project.self])
        StoreMaintenance.migrateLegacyStoreIfNeeded()
        let storeURL = StoreMaintenance.appDirectory().appending(path: "default.store")
        StoreMaintenance.backupBeforeOpening(storeURL: storeURL)
        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: storeURL)])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        // Safety net beyond the explicit save-on-every-edit calls elsewhere:
        // guarantees no more than a minute of work is ever at risk even if
        // some future code path forgets to save explicitly.
        let container = sharedModelContainer
        checkpointTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                container.mainContext.saveAndCheckpoint()
            }
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // `queue: .main` guarantees this already runs on the main thread;
            // deferring into a new Task risks it firing after the process
            // has already exited, defeating the point of this hook.
            MainActor.assumeIsolated {
                container.mainContext.saveAndCheckpoint()
            }
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

        let bar = MenuBarController(timerEngine: engine, pomodoro: controller, modelContext: modelContext)
        menuBarController = bar

        let delegate = appDelegate
        delegate.onReopen = { [weak bar] in
            bar?.showMainWindow()
        }
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
