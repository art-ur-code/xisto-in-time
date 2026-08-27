//
//  PomodoroDecisionView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI

struct PomodoroDecisionView: View {
    let phase: PomodoroPhase
    let onAdvance: () -> Void
    let onSnooze: () -> Void
    let onTerminate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: phase == .work ? "cup.and.saucer.fill" : "figure.mind.and.body")
                .font(.system(size: Theme.Font.largeTitle))
                .foregroundStyle(phase == .work ? .orange : .green)

            Text(phase == .work ? "Sessão de trabalho concluída" : "Pausa concluída")
                .font(.title2.bold())

            HStack(spacing: 12) {
                Button(phase == .work ? "Continuar a trabalhar" : "Continuar pausa", action: onSnooze)
                    .buttonStyle(DecisionButtonStyle(tint: .primary))
                Button(phase == .work ? "Começar pausa" : "Voltar ao trabalho", action: onAdvance)
                    .buttonStyle(DecisionButtonStyle(tint: phase == .work ? .orange : .green, prominent: true))
                    .keyboardShortcut(.defaultAction)
            }

            Divider()
                .frame(width: 200)

            Button("Terminar Sessão", action: onTerminate)
                .buttonStyle(DecisionButtonStyle(tint: .red))
        }
        .padding(32)
        .frame(width: 380, height: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.separator))
        .onExitCommand(perform: onSnooze)
    }
}

/// Native macOS buttons don't highlight on hover inside a custom NSPanel/NSHostingView,
/// so hover feedback has to be tracked and drawn by hand for the decision to feel clickable.
private struct DecisionButtonStyle: ButtonStyle {
    var tint: Color
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        DecisionButtonBody(configuration: configuration, tint: tint, prominent: prominent)
    }
}

private struct DecisionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    let prominent: Bool
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.body.weight(prominent ? .semibold : .medium))
            .foregroundStyle(prominent ? Color.white : tint)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .frame(minWidth: 120)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(prominent ? .clear : tint.opacity(isHovered ? 0.55 : 0.3))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var fillColor: Color {
        if prominent {
            tint.opacity(isHovered ? 0.85 : 1)
        } else {
            tint.opacity(isHovered ? 0.16 : 0.08)
        }
    }
}
