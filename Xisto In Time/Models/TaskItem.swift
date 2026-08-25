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
    var link: String?
    var project: Project?
    var archived: Bool
    var createdAt: Date

    init(title: String, externalRef: String? = nil, link: String? = nil, project: Project? = nil, archived: Bool = false, createdAt: Date = Date()) {
        self.title = title
        self.externalRef = externalRef
        self.link = link
        self.project = project
        self.archived = archived
        self.createdAt = createdAt
    }

    /// Nil unless `link` parses to a URL with a scheme — avoids offering to open
    /// text like "exemplo.com" that would silently fail without "https://".
    var linkURL: URL? {
        guard let link, let url = URL(string: link), url.scheme != nil else { return nil }
        return url
    }
}
