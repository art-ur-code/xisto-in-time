//
//  TaskItem.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import Foundation
import SwiftData

@Model
final class TaskItem {
    var title: String
    var externalRef: String?
    var project: Project?
    var archived: Bool
    var createdAt: Date

    init(title: String, externalRef: String? = nil, project: Project? = nil, archived: Bool = false, createdAt: Date = Date()) {
        self.title = title
        self.externalRef = externalRef
        self.project = project
        self.archived = archived
        self.createdAt = createdAt
    }
}
