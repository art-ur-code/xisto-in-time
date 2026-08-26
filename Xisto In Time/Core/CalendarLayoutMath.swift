//
//  CalendarLayoutMath.swift
//  Xisto In Time
//

import Foundation
import SwiftData

/// A session split into per-day visual pieces. A session that doesn't cross
/// midnight produces exactly one segment where `isSessionStart` and
/// `isSessionEnd` are both true. `Session` itself is never split — this is
/// rendering-only.
struct CalendarSessionSegment: Identifiable {
    let id: String
    let session: Session
    let day: Date
    let segmentStart: Date
    let segmentEnd: Date
    let isSessionStart: Bool
    let isSessionEnd: Bool
    let lane: Int
    let laneCount: Int
}

enum CalendarLayoutMath {
    /// Rounds `date` to the nearest multiple of `minutes` since the start of
    /// its own day. `minutes <= 0` returns `date` unchanged (no snap).
    static func snap(_ date: Date, toMinutes minutes: Int, calendar: Calendar = .current) -> Date {
        guard minutes > 0 else { return date }
        let interval = TimeInterval(minutes * 60)
        let dayStart = calendar.startOfDay(for: date)
        let elapsed = date.timeIntervalSince(dayStart)
        let snappedElapsed = (elapsed / interval).rounded() * interval
        return dayStart.addingTimeInterval(snappedElapsed)
    }

    /// Vertical position of `date` within its day's column, `hourHeight` points per hour.
    static func yOffset(for date: Date, day: Date, hourHeight: CGFloat, calendar: Calendar = .current) -> CGFloat {
        let dayStart = calendar.startOfDay(for: day)
        let hours = date.timeIntervalSince(dayStart) / 3600
        return CGFloat(hours) * hourHeight
    }

    /// Inverse of `yOffset` — the `Date` a vertical drag position maps to within `day`.
    static func date(forYOffset y: CGFloat, day: Date, hourHeight: CGFloat, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let hours = Double(y / hourHeight)
        return dayStart.addingTimeInterval(hours * 3600)
    }

    /// Splits every session touching any of `days` into one segment per day it
    /// touches, and assigns side-by-side lanes to segments that overlap in
    /// time within the same day (overlapping sessions are allowed, just warned
    /// about elsewhere — this only decides how to lay them out visually).
    static func segments(for sessions: [Session], days: [Date], calendar: Calendar = .current) -> [CalendarSessionSegment] {
        struct Raw {
            let day: Date
            let session: Session
            let start: Date
            let end: Date
            let isStart: Bool
            let isEnd: Bool
        }

        var raw: [Raw] = []
        for session in sessions {
            for day in days {
                let dayStart = calendar.startOfDay(for: day)
                guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
                let segStart = max(session.startedAt, dayStart)
                let segEnd = min(session.endedAt, dayEnd)
                guard segStart < segEnd else { continue }
                raw.append(Raw(
                    day: day,
                    session: session,
                    start: segStart,
                    end: segEnd,
                    isStart: segStart == session.startedAt,
                    isEnd: segEnd == session.endedAt
                ))
            }
        }

        var result: [CalendarSessionSegment] = []
        let byDay = Dictionary(grouping: raw, by: { $0.day.timeIntervalSinceReferenceDate })
        for (_, entries) in byDay {
            let lanes = assignLanes(entries.map { ($0.start, $0.end) })
            let laneCount = (lanes.values.max() ?? 0) + 1
            for (index, entry) in entries.enumerated() {
                result.append(CalendarSessionSegment(
                    id: "\(entry.session.persistentModelID)-\(entry.day.timeIntervalSinceReferenceDate)",
                    session: entry.session,
                    day: entry.day,
                    segmentStart: entry.start,
                    segmentEnd: entry.end,
                    isSessionStart: entry.isStart,
                    isSessionEnd: entry.isEnd,
                    lane: lanes[index] ?? 0,
                    laneCount: laneCount
                ))
            }
        }
        return result.sorted { $0.segmentStart < $1.segmentStart }
    }

    /// Greedy interval-graph-coloring: earliest-start-first, each interval
    /// takes the lowest-numbered lane whose last occupant already ended.
    private static func assignLanes(_ intervals: [(start: Date, end: Date)]) -> [Int: Int] {
        var lanes: [Int: Int] = [:]
        var laneEndTimes: [Date] = []
        let ordered = intervals.enumerated().sorted { $0.element.start < $1.element.start }
        for (index, interval) in ordered {
            if let freeLane = laneEndTimes.firstIndex(where: { $0 <= interval.start }) {
                laneEndTimes[freeLane] = interval.end
                lanes[index] = freeLane
            } else {
                laneEndTimes.append(interval.end)
                lanes[index] = laneEndTimes.count - 1
            }
        }
        return lanes
    }
}
