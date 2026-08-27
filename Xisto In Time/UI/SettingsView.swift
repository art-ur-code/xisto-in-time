//
//  SettingsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralSettingsPane()
                    .tabItem {
                        Label("Geral", systemImage: "gearshape")
                    }

                PomodoroSettingsPane()
                    .tabItem {
                        Label("Pomodoro", systemImage: "timer")
                    }

                IdleSettingsPane()
                    .tabItem {
                        Label("Idle", systemImage: "moon.zzz")
                    }

                ReportsSettingsPane()
                    .tabItem {
                        Label("Relatórios", systemImage: "chart.bar")
                    }

                CalendarSettingsPane()
                    .tabItem {
                        Label("Calendário", systemImage: "calendar")
                    }
            }

            Divider()

            Text("Xisto In Time v\(AppVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
        .frame(width: 420, height: 344)
    }
}

private struct GeneralSettingsPane: View {
    @AppStorage(PreferencesKey.openWindowOnLaunch)
    private var openWindowOnLaunch = PreferencesDefault.openWindowOnLaunch
    @AppStorage(PreferencesKey.notePreviewSize)
    private var notePreviewSize = PreferencesDefault.notePreviewSize
    @AppStorage(PreferencesKey.appTheme)
    private var appTheme = PreferencesDefault.appTheme

    var body: some View {
        Form {
            Section("Aparência") {
                Picker("Tema", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appTheme) { _, _ in
                    Theme.syncAppAppearance()
                }
            }

            Section {
                Toggle("Abrir a janela principal ao iniciar", isOn: $openWindowOnLaunch)
            }
            Section("Listas de sessões") {
                Picker("Preview da nota", selection: $notePreviewSize) {
                    ForEach(NotePreviewSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// A slider bound to an `Int` preference, with its current value shown above.
private struct IntSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(value) min")
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
        }
    }
}

private struct PomodoroSettingsPane: View {
    @AppStorage(PreferencesKey.pomodoroWorkMinutes)
    private var workMinutes = PreferencesDefault.pomodoroWorkMinutes
    @AppStorage(PreferencesKey.pomodoroShortBreakMinutes)
    private var shortBreakMinutes = PreferencesDefault.pomodoroShortBreakMinutes
    @AppStorage(PreferencesKey.pomodoroLongBreakMinutes)
    private var longBreakMinutes = PreferencesDefault.pomodoroLongBreakMinutes
    @AppStorage(PreferencesKey.pomodoroCyclesBeforeLongBreak)
    private var cyclesBeforeLongBreak = PreferencesDefault.pomodoroCyclesBeforeLongBreak

    var body: some View {
        Form {
            Section("Durações") {
                IntSlider(title: "Trabalho", value: $workMinutes, range: 1...90, step: 1)
                IntSlider(title: "Pausa curta", value: $shortBreakMinutes, range: 1...30, step: 1)
                IntSlider(title: "Pausa longa", value: $longBreakMinutes, range: 1...60, step: 1)
            }
            Section("Ciclo") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ciclos até pausa longa: \(cyclesBeforeLongBreak)")
                    Slider(
                        value: Binding(
                            get: { Double(cyclesBeforeLongBreak) },
                            set: { cyclesBeforeLongBreak = Int($0) }
                        ),
                        in: 1...8,
                        step: 1
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct IdleSettingsPane: View {
    @AppStorage(PreferencesKey.idleDetectionEnabled)
    private var idleDetectionEnabled = PreferencesDefault.idleDetectionEnabled
    @AppStorage(PreferencesKey.idleThresholdMinutes)
    private var idleThresholdMinutes = PreferencesDefault.idleThresholdMinutes
    @AppStorage(PreferencesKey.idleResolutionMode)
    private var idleResolutionMode = PreferencesDefault.idleResolutionMode

    var body: some View {
        Form {
            Section {
                Toggle("Detectar inactividade", isOn: $idleDetectionEnabled)
            }
            Section("Comportamento") {
                IntSlider(title: "Limiar", value: $idleThresholdMinutes, range: 1...60, step: 1)
                    .disabled(!idleDetectionEnabled)
                Picker("Ao detectar idle", selection: $idleResolutionMode) {
                    ForEach(IdleResolutionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .disabled(!idleDetectionEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ReportsSettingsPane: View {
    @AppStorage(PreferencesKey.reportsShowWeekend)
    private var reportsShowWeekend = PreferencesDefault.reportsShowWeekend

    var body: some View {
        Form {
            Section {
                Toggle("Mostrar fim-de-semana na vista semanal", isOn: $reportsShowWeekend)
            }
        }
        .formStyle(.grouped)
    }
}

private struct CalendarSettingsPane: View {
    @AppStorage(PreferencesKey.calendarSnapMinutes)
    private var calendarSnapMinutes = PreferencesDefault.calendarSnapMinutes
    @AppStorage(PreferencesKey.calendarUse24Hour)
    private var use24Hour = PreferencesDefault.calendarUse24Hour
    @AppStorage(PreferencesKey.calendarStartHour)
    private var startHour = PreferencesDefault.calendarStartHour

    private let snapOptions = [5, 15, 30]

    var body: some View {
        Form {
            Section {
                Picker("Encaixar (snap) ao arrastar", selection: $calendarSnapMinutes) {
                    ForEach(snapOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
            }

            Section("Intervalo de horas") {
                Picker("Mostrar", selection: $use24Hour) {
                    Text("12 horas").tag(false)
                    Text("24 horas").tag(true)
                }
                .pickerStyle(.segmented)

                if !use24Hour {
                    Picker("Início", selection: $startHour) {
                        ForEach(0...12, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    Text("Mostra das \(String(format: "%02d:00", startHour)) às \(String(format: "%02d:00", startHour + 12))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
