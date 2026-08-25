//
//  SessionDayHeader.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 25/08/2026.
//

import SwiftUI

/// Day-section header shared by every sessions list ("Segunda, 24 Ago 2026"
/// + "N sessões · total"). Weekday/month names are a fixed PT table rather
/// than `Locale`-driven formatting — the app has no localization and this
/// avoids forms like "segunda-feira" that `EEEE` gives in pt.
struct SessionDayHeader: View {
    let group: DaySessionGroup

    private static let weekdayNames = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
    private static let monthAbbreviations = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]

    var body: some View {
        HStack {
            Text(Self.dayTitle(for: group.day))
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Spacer()
            Text("\(group.sessions.count) sessões · \(TimerEngine.format(group.total))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private static func dayTitle(for day: Date) -> String {
        let calendar = Calendar.current
        let weekday = weekdayNames[calendar.component(.weekday, from: day) - 1]
        let dayNumber = calendar.component(.day, from: day)
        let month = monthAbbreviations[calendar.component(.month, from: day) - 1]
        let year = calendar.component(.year, from: day)
        return "\(weekday), \(dayNumber) \(month) \(year)"
    }
}
