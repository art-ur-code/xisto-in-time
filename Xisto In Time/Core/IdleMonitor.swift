//
//  IdleMonitor.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import CoreGraphics
import Foundation
import Observation
import UserNotifications

@Observable
final class IdleMonitor {
    private(set) var isIdle = false
    private(set) var idleStartedAt: Date?

    /// Fired once per idle stretch, with the moment inactivity actually began
    /// (derived from `CGEventSource`, not from when the 30s poll happened to run).
    var onIdleDetected: ((Date) -> Void)?

    private weak var timerEngine: TimerEngine?
    private var pollTimer: Timer?

    init(timerEngine: TimerEngine) {
        self.timerEngine = timerEngine
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    private func poll() {
        guard Preferences.idleDetectionEnabled(),
              let timerEngine, timerEngine.isRunning, timerEngine.currentKind == .work else {
            reset()
            return
        }

        let secondsSinceLastEvent = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        let threshold = TimeInterval(Preferences.idleThresholdMinutes() * 60)

        guard secondsSinceLastEvent >= threshold else {
            reset()
            return
        }
        guard !isIdle else { return }

        let startedAt = Date().addingTimeInterval(-secondsSinceLastEvent)
        isIdle = true
        idleStartedAt = startedAt
        onIdleDetected?(startedAt)
    }

    private func reset() {
        isIdle = false
        idleStartedAt = nil
    }

    static func notifyIdleDetected(thresholdMinutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Sem actividade"
            content.body = "Estás inactivo há mais de \(thresholdMinutes) min. O tempo continua a ser contado."
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }
}
