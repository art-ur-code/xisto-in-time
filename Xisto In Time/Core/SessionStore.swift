//
//  SessionStore.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftData

enum SessionStore {
    @discardableResult
    static func recordFinishedSession(_ finished: FinishedSession, in context: ModelContext) -> Session {
        let session = Session(
            startedAt: finished.startedAt,
            endedAt: finished.endedAt,
            task: finished.task,
            kind: finished.kind,
            interrupted: finished.interrupted
        )
        context.insert(session)
        return session
    }
}
