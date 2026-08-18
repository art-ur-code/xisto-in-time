//
//  TimerEngine.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import AppKit
import Observation

struct FinishedSession {
    let startedAt: Date
    let endedAt: Date
    let interrupted: Bool
    let kind: SessionKind
    let task: TaskItem?
}

@Observable
final class TimerEngine {
    private(set) var isRunning = false
    private(set) var interrupted = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var targetReached = false
    private(set) var currentKind: SessionKind = .work
    private(set) var currentTask: TaskItem?
    var onTargetReached: (() -> Void)?

    private var startedAt: Date?
    private var targetDuration: TimeInterval?
    private var pausedDuration: TimeInterval = 0
    private var sleepStartedAt: Date?
    private var ticker: Timer?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    init() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWillSleep()
        }
        wakeObserver = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleDidWake()
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        if let sleepObserver { center.removeObserver(sleepObserver) }
        if let wakeObserver { center.removeObserver(wakeObserver) }
        ticker?.invalidate()
    }

    func start(targetDuration: TimeInterval? = nil, kind: SessionKind = .work, task: TaskItem? = nil) {
        guard !isRunning else { return }
        startedAt = Date()
        self.targetDuration = targetDuration
        currentKind = kind
        currentTask = task
        targetReached = false
        pausedDuration = 0
        sleepStartedAt = nil
        interrupted = false
        elapsed = 0
        isRunning = true
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateElapsed()
        }
    }

    func snoozeTarget() {
        targetReached = false
        targetDuration = nil
    }

    /// Discards a stretch of elapsed time (e.g. idle time) without stopping the session.
    func discardInterval(_ duration: TimeInterval) {
        guard duration > 0 else { return }
        pausedDuration += duration
        updateElapsed()
    }

    /// Manually overrides the elapsed time of the running session (e.g. "I actually
    /// started 5 minutes ago"), by backdating `startedAt` so the count continues on naturally.
    func setElapsed(_ newElapsed: TimeInterval) {
        guard isRunning, newElapsed >= 0 else { return }
        pausedDuration = 0
        startedAt = Date().addingTimeInterval(-newElapsed)
        updateElapsed()
    }

    /// Time left until `targetDuration` is reached, for callers that want a countdown
    /// display (e.g. Pomodoro). `nil` when there's no target (e.g. free mode, or snoozed).
    var remaining: TimeInterval? {
        guard let targetDuration else { return nil }
        return max(0, targetDuration - elapsed)
    }

    /// Overrides how much time is left until `targetDuration`, by adjusting elapsed
    /// accordingly. Counterpart to `setElapsed` for countdown-style displays. No-op
    /// without a target.
    func setRemaining(_ newRemaining: TimeInterval) {
        guard isRunning, let targetDuration, newRemaining >= 0 else { return }
        setElapsed(max(0, targetDuration - newRemaining))
    }

    @discardableResult
    func stop(endedAt overrideEndedAt: Date? = nil) -> FinishedSession? {
        guard isRunning, let startedAt else { return nil }
        updateElapsed()
        let endedAt = overrideEndedAt ?? Date()
        let finished = FinishedSession(startedAt: startedAt, endedAt: endedAt, interrupted: interrupted, kind: currentKind, task: currentTask)
        ticker?.invalidate()
        ticker = nil
        isRunning = false
        self.startedAt = nil
        sleepStartedAt = nil
        targetReached = false
        targetDuration = nil
        currentTask = nil
        elapsed = 0
        return finished
    }

    private func updateElapsed() {
        guard let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt) - pausedDuration
        if let targetDuration, elapsed >= targetDuration, !targetReached {
            targetReached = true
            onTargetReached?()
        }
    }

    private func handleWillSleep() {
        guard isRunning else { return }
        sleepStartedAt = Date()
    }

    private func handleDidWake() {
        guard isRunning, let sleepStartedAt else { return }
        pausedDuration += Date().timeIntervalSince(sleepStartedAt)
        interrupted = true
        self.sleepStartedAt = nil
        updateElapsed()
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    /// Parses "H:MM:SS", "MM:SS", or a bare number of minutes typed by hand.
    static func parseDuration(_ text: String) -> TimeInterval? {
        let numbers = text
            .trimmingCharacters(in: .whitespaces)
            .split(separator: ":", omittingEmptySubsequences: false)
            .map { Int($0) }

        guard !numbers.isEmpty, !numbers.contains(where: { $0 == nil }) else { return nil }
        let values = numbers.compactMap { $0 }

        switch values.count {
        case 1:
            return TimeInterval(values[0] * 60)
        case 2:
            return TimeInterval(values[0] * 60 + values[1])
        case 3:
            return TimeInterval(values[0] * 3600 + values[1] * 60 + values[2])
        default:
            return nil
        }
    }
}
