//
//  SessionStore.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import Foundation
import SwiftData

enum SessionStore {
    @discardableResult
    static func recordFinishedSession(_ finished: FinishedSession, in context: ModelContext) -> Session {
        let session = Session(
            startedAt: finished.startedAt,
            endedAt: finished.endedAt,
            task: finished.task,
            kind: finished.kind,
            note: finished.note,
            interrupted: finished.interrupted
        )
        context.insert(session)
        context.saveAndCheckpoint()
        return session
    }

    // MARK: - Cascading deletes
    //
    // Project and TaskItem have no `@Relationship(deleteRule:)` — the models
    // only hold an optional child-to-parent reference, so SwiftData's default
    // behaviour on deleting a project/task would just nullify the link and
    // leave orphaned tasks/sessions behind. Deleting is deliberate here, one
    // fetch-and-delete pass per level, so a project takes its tasks with it
    // and each task takes its own sessions with it.

    static func tasks(in project: Project, context: ModelContext) -> [TaskItem] {
        let projectID = project.persistentModelID
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.project?.persistentModelID == projectID })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func sessions(for task: TaskItem, context: ModelContext) -> [Session] {
        let taskID = task.persistentModelID
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.task?.persistentModelID == taskID })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func delete(_ task: TaskItem, in context: ModelContext) {
        deleteCascading(task, context: context)
        context.saveAndCheckpoint()
    }

    static func delete(_ project: Project, in context: ModelContext) {
        for task in tasks(in: project, context: context) {
            deleteCascading(task, context: context)
        }
        context.delete(project)
        context.saveAndCheckpoint()
    }

    private static func deleteCascading(_ task: TaskItem, context: ModelContext) {
        for session in sessions(for: task, context: context) {
            context.delete(session)
        }
        context.delete(task)
    }

    // MARK: - Overlap / reschedule
    //
    // Shared by SessionEditorView (manual edit) and the calendar week view
    // (drag to move/resize) — same overlap rule, one place.

    static func overlappingSession(
        startedAt: Date,
        endedAt: Date,
        excluding excludedID: PersistentIdentifier?,
        in sessions: [Session]
    ) -> Session? {
        sessions.first { candidate in
            if let excludedID, candidate.persistentModelID == excludedID {
                return false
            }
            return startedAt < candidate.endedAt && endedAt > candidate.startedAt
        }
    }

    static func rescheduleSession(_ session: Session, startedAt: Date, endedAt: Date, in context: ModelContext) {
        // Safety net: every known caller already clamps/validates before
        // calling this, but this is a shared Core API now — never let a
        // future caller's bad clamping corrupt a session's ordering.
        guard endedAt > startedAt else { return }
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.editedAt = Date()
        context.saveAndCheckpoint()
    }

    static func describe(_ session: Session) -> String {
        let range = "\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))"
        if let title = session.task?.title {
            return "\(range) (\(title))"
        }
        return "\(range) (sem atribuição)"
    }
}
