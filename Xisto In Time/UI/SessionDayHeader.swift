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
    var isToday: Bool = false

    private static let weekdayNames = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
    private static let monthAbbreviations = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Self.dayTitle(for: group.day))
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.primary)
            if isToday {
                Text("HOJE")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color(hex: "B05800"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(hex: "FFD6D6"), in: RoundedRectangle(cornerRadius: 5))
            }
            Rectangle()
                .fill(Color(hex: "ECECF0"))
                .frame(height: 1)
            Text("\(group.sessions.count) \(group.sessions.count == 1 ? "sessão" : "sessões") · \(TimerEngine.format(group.total))")
                .font(.system(size: 11.5))
                .foregroundStyle(Color(hex: "9A9AA0"))
                .monospacedDigit()
        }
        .textCase(nil)
        .padding(.top, 9)
        .padding(.bottom, 7)
        .padding(.horizontal, 2)
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
