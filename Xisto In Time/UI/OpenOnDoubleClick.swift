//
//  OpenOnDoubleClick.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import AppKit
import SwiftUI

extension View {
    /// A single click on a row does nothing — only a double click opens it.
    /// Prevents accidentally pushing a detail/editor while just scanning a list.
    /// The first click still flashes a brief highlight so the click registers
    /// as feedback while waiting to see if a second one completes it.
    func openOnDoubleClick(action: @escaping () -> Void) -> some View {
        modifier(OpenOnDoubleClickModifier(action: action))
    }
}

private struct OpenOnDoubleClickModifier: ViewModifier {
    let action: () -> Void

    @State private var isArmed = false
    @State private var armToken = 0

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(isArmed ? 0.18 : 0))
            )
            .contentShape(Rectangle())
            .help("Duplo clique para abrir")
            .onTapGesture(count: 2) {
                isArmed = false
                action()
            }
            .simultaneousGesture(
                TapGesture(count: 1).onEnded {
                    isArmed = true
                    armToken += 1
                    let token = armToken
                    DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval) {
                        if armToken == token {
                            isArmed = false
                        }
                    }
                }
            )
            .animation(.easeOut(duration: 0.15), value: isArmed)
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
