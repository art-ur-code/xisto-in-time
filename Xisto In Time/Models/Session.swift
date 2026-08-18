//
//  Session.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import Foundation
import SwiftData

enum SessionKind: String, Codable {
    case work
    case `break`
}

@Model
final class Session {
    var startedAt: Date
    var endedAt: Date
    var task: TaskItem?
    var kind: SessionKind
    var note: String?
    var interrupted: Bool
    var editedAt: Date?

    init(startedAt: Date, endedAt: Date, task: TaskItem? = nil, kind: SessionKind, note: String? = nil, interrupted: Bool = false, editedAt: Date? = nil) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.task = task
        self.kind = kind
        self.note = note
        self.interrupted = interrupted
        self.editedAt = editedAt
    }
}
