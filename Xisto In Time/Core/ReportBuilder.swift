//
//  ReportBuilder.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import Foundation
import SwiftData

struct DailyReport {
    struct Bucket: Identifiable {
        let id: String
        let title: String
        let total: TimeInterval
    }

    let sessions: [Session]
    let total: TimeInterval
    let buckets: [Bucket]
}

struct WeeklyReport {
    struct TaskRow: Identifiable {
        let id: String
        let title: String
        let dailyTotals: [TimeInterval]
        var total: TimeInterval { dailyTotals.reduce(0, +) }
    }

    struct ProjectRow: Identifiable {
        let id: String
        let title: String
        let taskRows: [TaskRow]
        let dailyTotals: [TimeInterval]
        var total: TimeInterval { dailyTotals.reduce(0, +) }
    }

    let days: [Date]
    let projectRows: [ProjectRow]
    let unassignedDailyTotals: [TimeInterval]

    var unassignedTotal: TimeInterval { unassignedDailyTotals.reduce(0, +) }
    var grandTotal: TimeInterval { projectRows.reduce(0) { $0 + $1.total } + unassignedTotal }

    func dayTotal(at index: Int) -> TimeInterval {
        projectRows.reduce(unassignedDailyTotals[index]) { $0 + $1.dailyTotals[index] }
    }
}

enum ReportBuilder {
    /// Monday of the ISO week containing `date`.
    static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        var isoCalendar = calendar
        isoCalendar.firstWeekday = 2
        let components = isoCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return isoCalendar.date(from: components) ?? date
    }

    /// The days of the ISO week containing `date`, Monday first. `showWeekend`
    /// trims it to Monday–Friday when the weekly-view preference is off.
    static func weekDays(containing date: Date, showWeekend: Bool, calendar: Calendar = .current) -> [Date] {
        let start = startOfWeek(containing: date, calendar: calendar)
        let count = showWeekend ? 7 : 5
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func dailyReport(sessions: [Session], day: Date, calendar: Calendar = .current) -> DailyReport {
        let daySessions = sessions
            .filter { $0.kind == .work && calendar.isDate($0.startedAt, inSameDayAs: day) }
            .sorted { $0.startedAt < $1.startedAt }

        let total = daySessions.reduce(TimeInterval(0)) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }

        var buckets: [String: (title: String, total: TimeInterval)] = [:]
        for session in daySessions {
            let (key, title) = bucketKey(for: session)
            let duration = session.endedAt.timeIntervalSince(session.startedAt)
            var entry = buckets[key] ?? (title, 0)
            entry.total += duration
            buckets[key] = entry
        }

        let bucketList = buckets.map { DailyReport.Bucket(id: $0.key, title: $0.value.title, total: $0.value.total) }
            .sorted { $0.total > $1.total }

        return DailyReport(sessions: daySessions, total: total, buckets: bucketList)
    }

    static func weeklyReport(sessions: [Session], days: [Date], calendar: Calendar = .current) -> WeeklyReport {
        let workSessions = sessions.filter { $0.kind == .work }

        func dayIndex(for date: Date) -> Int? {
            days.firstIndex { calendar.isDate($0, inSameDayAs: date) }
        }

        var unassignedTotals = Array(repeating: TimeInterval(0), count: days.count)
        var projectGroups: [String: (title: String, tasks: [String: (title: String, totals: [TimeInterval])])] = [:]

        for session in workSessions {
            guard let index = dayIndex(for: session.startedAt) else { continue }
            let duration = session.endedAt.timeIntervalSince(session.startedAt)

            guard let task = session.task else {
                unassignedTotals[index] += duration
                continue
            }

            let projectKey = task.project.map { "p:\($0.persistentModelID)" } ?? "no-project"
            let projectTitle = task.project?.name ?? "Sem projecto"
            let taskKey = "t:\(task.persistentModelID)"

            var group = projectGroups[projectKey] ?? (projectTitle, [:])
            var taskEntry = group.tasks[taskKey] ?? (task.title, Array(repeating: TimeInterval(0), count: days.count))
            taskEntry.totals[index] += duration
            group.tasks[taskKey] = taskEntry
            projectGroups[projectKey] = group
        }

        let projectRows = projectGroups.map { key, group -> WeeklyReport.ProjectRow in
            let taskRows = group.tasks.map { key, entry in
                WeeklyReport.TaskRow(id: key, title: entry.title, dailyTotals: entry.totals)
            }.sorted { $0.title < $1.title }

            let dailyTotals = (0..<days.count).map { index in
                taskRows.reduce(TimeInterval(0)) { $0 + $1.dailyTotals[index] }
            }

            return WeeklyReport.ProjectRow(id: key, title: group.title, taskRows: taskRows, dailyTotals: dailyTotals)
        }.sorted { $0.title < $1.title }

        return WeeklyReport(days: days, projectRows: projectRows, unassignedDailyTotals: unassignedTotals)
    }

    static func formatHoursMinutes(_ interval: TimeInterval) -> String {
        let totalMinutes = Int((interval / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }

    static func formatDecimalHours(_ interval: TimeInterval) -> String {
        String(format: "%.2fh", interval / 3600)
    }

    private static func bucketKey(for session: Session) -> (key: String, title: String) {
        guard let task = session.task else {
            return ("unassigned", "Sem atribuição")
        }
        if let project = task.project {
            return ("p:\(project.persistentModelID)", project.name)
        }
        return ("no-project", "Sem projecto")
    }
}
