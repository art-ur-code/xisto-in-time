//
//  IdleResolutionView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI

struct IdleResolutionView: View {
    let idleStartedAt: Date
    let onDiscard: () -> Void
    let onKeep: () -> Void
    let onEndSession: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: Theme.Font.title2))
                .foregroundStyle(.blue)

            Text("Sem actividade desde as \(idleStartedAt.formatted(date: .omitted, time: .shortened))")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("O que fazer com esse tempo?")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Button("Manter tempo inactivo", action: onKeep)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                Button("Descartar tempo inactivo", action: onDiscard)
                    .buttonStyle(.bordered)
                Button("Terminar sessão nesse momento", action: onEndSession)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(width: 380, height: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.xl).strokeBorder(.separator))
        .onExitCommand(perform: onKeep)
    }
}
