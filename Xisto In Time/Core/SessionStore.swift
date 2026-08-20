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
}
