//
//  MenuBarLabel.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI

struct MenuBarLabel: View {
    @Environment(TimerEngine.self) private var timerEngine

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: timerEngine.isPaused ? "pause.circle.fill" : "circle.dashed")
                .symbolEffect(.pulse, isActive: timerEngine.isRunning && !timerEngine.isPaused)
            if timerEngine.isRunning {
                let time = TimerEngine.format(timerEngine.remaining ?? timerEngine.elapsed)
                if let projectName = timerEngine.currentTask?.project?.name {
                    Text("\(projectName) - \(time)")
                        .monospacedDigit()
                } else {
                    Text(time)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 6)
        .fixedSize()
    }
}
