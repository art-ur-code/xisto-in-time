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

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: phase == .work ? "cup.and.saucer.fill" : "figure.mind.and.body")
                .font(.system(size: 34))
                .foregroundStyle(phase == .work ? .orange : .green)

            Text(phase == .work ? "Sessão de trabalho concluída" : "Pausa concluída")
                .font(.title2.bold())

            HStack(spacing: 12) {
                Button(phase == .work ? "Continuar a trabalhar" : "Continuar pausa", action: onSnooze)
                    .buttonStyle(.bordered)
                Button(phase == .work ? "Começar pausa" : "Voltar ao trabalho", action: onAdvance)
                    .buttonStyle(.borderedProminent)
                    .tint(phase == .work ? .orange : .green)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 380, height: 220)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.separator))
        .onExitCommand(perform: onSnooze)
    }
}
