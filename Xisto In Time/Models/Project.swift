//
//  Project.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftData
import SwiftUI

@Model
final class Project {
    var name: String
    var colorHex: String
    var archived: Bool

    init(name: String, colorHex: String, archived: Bool = false) {
        self.name = name
        self.colorHex = colorHex
        self.archived = archived
    }

    var color: Color { Color(hex: colorHex) }
}
