//
//  PopoverView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI

struct PopoverView: View {
    let onOpenMainWindow: () -> Void

    @Environment(TimerEngine.self) private var timerEngine

    private var headerAccentColor: Color {
        timerEngine.isRunning ? (timerEngine.currentTask?.project?.color ?? .accentColor) : .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            SessionControlView()
        }
        .padding(16)
        .frame(width: 290)
    }

    private var header: some View {
        Button(action: onOpenMainWindow) {
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(headerAccentColor)
                    .font(.title3)
                Text("Xisto")
                    .font(.headline)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Abrir janela")
    }
}
