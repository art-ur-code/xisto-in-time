//
//  AllSessionsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct AllSessionsView: View {
    let path: Binding<NavigationPath>

    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var showingNewSessionEditor = false

    private var todayTotal: TimeInterval {
        ReportBuilder.dailyReport(sessions: sessions, day: Date()).total
    }

    private var weekTotal: TimeInterval {
        let days = ReportBuilder.weekDays(containing: Date(), showWeekend: true)
        return ReportBuilder.weeklyReport(sessions: sessions, days: days).grandTotal
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    statCard(title: "Hoje", total: todayTotal)
                    statCard(title: "Esta semana", total: weekTotal)
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }

            Section("Histórico") {
                if sessions.isEmpty {
                    Text("Ainda sem sessões")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        SessionRow(session: session, path: path)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .navigationTitle("Sessões")
        .toolbar {
            ToolbarItem {
                Button {
                    showingNewSessionEditor = true
                } label: {
                    Label("Sessão manual", systemImage: "plus")
                }
                .help("Criar uma sessão passada, com início e fim escolhidos à mão")
            }
        }
        .sheet(isPresented: $showingNewSessionEditor) {
            NavigationStack {
                SessionEditorView()
            }
            .frame(width: 420, height: 520)
        }
    }

    private func statCard(title: String, total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(ReportBuilder.formatHoursMinutes(total)) (\(ReportBuilder.formatDecimalHours(total)))")
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
