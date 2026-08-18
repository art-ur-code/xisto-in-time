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
            Image(systemName: "circle.dashed")
                .symbolEffect(.pulse, isActive: timerEngine.isRunning)
            if timerEngine.isRunning {
                Text(TimerEngine.format(timerEngine.remaining ?? timerEngine.elapsed))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 6)
    }
}
