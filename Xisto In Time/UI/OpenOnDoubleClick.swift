//
//  OpenOnDoubleClick.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI

extension View {
    /// A single click on a row does nothing — only a double click opens it.
    /// Prevents accidentally pushing a detail/editor while just scanning a list.
    func openOnDoubleClick(action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .help("Duplo clique para abrir")
            .onTapGesture(count: 2, perform: action)
    }
}

/// Discreet affordance replacing the chevron `NavigationLink` used to draw
/// automatically, now that rows open on double click instead.
struct RowDisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}
