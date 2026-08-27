//
//  PopoverView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct PopoverView: View {
    let onOpenMainWindow: () -> Void

    @Environment(TimerEngine.self) private var timerEngine
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    private var todayTotal: TimeInterval {
        ReportBuilder.dailyReport(sessions: sessions, day: Date()).total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            SessionControlView()
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 360)
        // Hard height cap so the hosting panel never has to guess at an
        // unbounded size while the content resizes (mode legend, Pomodoro
        // config, task picker).
        .frame(maxHeight: 600, alignment: .top)
        // The panel itself is a plain borderless NSPanel (see
        // MenuBarController) — no more NSPopover chrome, so the rounded
        // material background lives here instead.
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onOpenMainWindow) {
                Text("Hoje \(ReportBuilder.formatHoursMinutes(todayTotal))")
                    .font(.headline)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Abrir janela")

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preferências")
        }
    }
}
