//
//  ProjectFormSheet.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI

/// Shared create/edit form for a project's name and colour — used by
/// `ProjectsView` (create) and `ProjectDetailView` (edit).
struct ProjectFormSheet: View {
    let title: String
    @Binding var name: String
    @Binding var color: Color
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome", text: $name)
                ColorPicker("Cor", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: onSave)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 340, height: 220)
    }
}
