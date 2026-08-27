//
//  ReportsView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

private enum ReportMode: String, CaseIterable, Identifiable {
    case daily = "Diária"
    case weekly = "Semanal"
    var id: String { rawValue }
}

struct ReportsView: View {
    @Query(sort: \Session.startedAt) private var allSessions: [Session]
    @Query(filter: #Predicate<Project> { !$0.archived }, sort: \Project.name)
    private var projects: [Project]
    @Query(filter: #Predicate<TaskItem> { !$0.archived }, sort: \TaskItem.title)
    private var tasks: [TaskItem]

    @AppStorage(PreferencesKey.reportsShowWeekend)
    private var showWeekend = PreferencesDefault.reportsShowWeekend

    @State private var mode: ReportMode = .daily
    @State private var referenceDate = Date()
    @State private var filterProject: Project?
    @State private var filterTask: TaskItem?

    private var tasksForFilterProject: [TaskItem] {
        guard let filterProject else { return tasks }
        return tasks.filter { $0.project?.persistentModelID == filterProject.persistentModelID }
    }

    private var filteredSessions: [Session] {
        allSessions.filter { session in
            if let filterTask {
                return session.task?.persistentModelID == filterTask.persistentModelID
            }
            if let filterProject {
                return session.task?.project?.persistentModelID == filterProject.persistentModelID
            }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Picker("Vista", selection: $mode) {
                    ForEach(ReportMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                filtersRow

                Divider()

                switch mode {
                case .daily:
                    dailySection
                case .weekly:
                    weeklySection
                }
            }
            .padding()
        }
        .navigationTitle("Estatísticas")
    }

    @ViewBuilder
    private var filtersRow: some View {
        HStack {
            Picker("Projecto", selection: $filterProject) {
                Text("Todos").tag(Project?.none)
                ForEach(projects) { project in
                    projectLabel(project).tag(Project?.some(project))
                }
            }
            .onChange(of: filterProject) { filterTask = nil }
            .frame(maxWidth: 220)

            Picker("Tarefa", selection: $filterTask) {
                Text("Todas").tag(TaskItem?.none)
                ForEach(tasksForFilterProject) { task in
                    Text(task.title).tag(TaskItem?.some(task))
                }
            }
            .frame(maxWidth: 220)
        }
    }

    private func projectLabel(_ project: Project) -> some View {
        Label {
            Text(project.name)
        } icon: {
            Circle().fill(project.color).frame(width: 10, height: 10)
        }
    }

    private func totalCard(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, Theme.Spacing.md)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func colorForBucket(id: String) -> Color? {
        projects.first { "p:\($0.persistentModelID)" == id }?.color
    }

    // MARK: - Daily

    @ViewBuilder
    private var dailySection: some View {
        let report = ReportBuilder.dailyReport(sessions: filteredSessions, day: referenceDate)

        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            dayNavigator

            totalCard("Total: \(ReportBuilder.formatHoursMinutes(report.total)) (\(ReportBuilder.formatDecimalHours(report.total)))")

            if !report.buckets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.buckets) { bucket in
                        HStack {
                            if let color = colorForBucket(id: bucket.id) {
                                Circle().fill(color).frame(width: 8, height: 8)
                            }
                            Text(bucket.title)
                            Spacer()
                            Text("\(ReportBuilder.formatHoursMinutes(bucket.total)) (\(ReportBuilder.formatDecimalHours(bucket.total)))")
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                }
            }

            Divider()

            if report.sessions.isEmpty {
                ContentUnavailableView("Sem sessões neste dia", systemImage: "calendar")
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.sessions) { session in
                        timelineRow(session)
                    }
                }
            }
        }
    }

    private func timelineRow(_ session: Session) -> some View {
        HStack {
            if let color = session.task?.project?.color {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
            Text(session.task?.title ?? "Sem atribuição")
                .foregroundStyle(.secondary)
            Spacer()
            if session.interrupted {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.secondary)
            }
            if session.editedAt != nil {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            Text(ReportBuilder.formatHoursMinutes(session.endedAt.timeIntervalSince(session.startedAt)))
                .monospacedDigit()
        }
        .font(.caption)
    }

    private var dayNavigator: some View {
        HStack {
            Button {
                referenceDate = Calendar.current.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
            } label: {
                Image(systemName: "chevron.left")
            }
            Text(referenceDate.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.bold())
                .frame(minWidth: 140)
            Button {
                referenceDate = Calendar.current.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
            } label: {
                Image(systemName: "chevron.right")
            }
            Button("Hoje") { referenceDate = Date() }
                .font(.caption)
        }
    }

    // MARK: - Weekly

    @ViewBuilder
    private var weeklySection: some View {
        let days = weekDays(containing: referenceDate)
        let report = ReportBuilder.weeklyReport(sessions: filteredSessions, days: days)

        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            weekNavigator(days: days)

            totalCard("Total da semana: \(ReportBuilder.formatHoursMinutes(report.grandTotal)) (\(ReportBuilder.formatDecimalHours(report.grandTotal)))")

            ScrollView(.horizontal) {
                weeklyTable(report: report)
            }
        }
    }

    private func weekDays(containing date: Date) -> [Date] {
        ReportBuilder.weekDays(containing: date, showWeekend: showWeekend)
    }

    private func weekNavigator(days: [Date]) -> some View {
        HStack {
            Button {
                referenceDate = Calendar.current.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
            } label: {
                Image(systemName: "chevron.left")
            }
            if let first = days.first, let last = days.last {
                Text("Semana de \(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.bold())
                    .frame(minWidth: 220)
            }
            Button {
                referenceDate = Calendar.current.date(byAdding: .day, value: 7, to: referenceDate) ?? referenceDate
            } label: {
                Image(systemName: "chevron.right")
            }
            Button("Esta semana") { referenceDate = Date() }
                .font(.caption)
        }
    }

    private func weeklyTable(report: WeeklyReport) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("")
                    .frame(width: 150, alignment: .leading)
                ForEach(report.days, id: \.self) { day in
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .frame(width: 60)
                }
                Text("Total")
                    .frame(width: 70)
            }
            .font(.caption.bold())

            Divider()

            ForEach(report.projectRows) { projectRow in
                GridRow {
                    HStack(spacing: 6) {
                        if let color = colorForBucket(id: projectRow.id) {
                            Circle().fill(color).frame(width: 8, height: 8)
                        }
                        Text(projectRow.title)
                            .bold()
                    }
                    .frame(width: 150, alignment: .leading)
                    ForEach(projectRow.dailyTotals.indices, id: \.self) { index in
                        Text(ReportBuilder.formatHoursMinutes(projectRow.dailyTotals[index]))
                            .frame(width: 60)
                            .monospacedDigit()
                    }
                    Text(ReportBuilder.formatHoursMinutes(projectRow.total))
                        .bold()
                        .frame(width: 70)
                        .monospacedDigit()
                }
                .font(.caption)

                ForEach(projectRow.taskRows) { taskRow in
                    GridRow {
                        Text(taskRow.title)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)
                            .frame(width: 150, alignment: .leading)
                        ForEach(taskRow.dailyTotals.indices, id: \.self) { index in
                            Text(ReportBuilder.formatHoursMinutes(taskRow.dailyTotals[index]))
                                .frame(width: 60)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Text(ReportBuilder.formatHoursMinutes(taskRow.total))
                            .frame(width: 70)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }

            if report.unassignedTotal > 0 {
                GridRow {
                    Text("Sem atribuição")
                        .italic()
                        .frame(width: 150, alignment: .leading)
                    ForEach(report.unassignedDailyTotals.indices, id: \.self) { index in
                        Text(ReportBuilder.formatHoursMinutes(report.unassignedDailyTotals[index]))
                            .frame(width: 60)
                            .monospacedDigit()
                    }
                    Text(ReportBuilder.formatHoursMinutes(report.unassignedTotal))
                        .frame(width: 70)
                        .monospacedDigit()
                }
                .font(.caption)
            }

            Divider()

            GridRow {
                Text("Total")
                    .bold()
                    .frame(width: 150, alignment: .leading)
                ForEach(report.days.indices, id: \.self) { index in
                    Text(ReportBuilder.formatHoursMinutes(report.dayTotal(at: index)))
                        .bold()
                        .frame(width: 60)
                        .monospacedDigit()
                }
                Text(ReportBuilder.formatHoursMinutes(report.grandTotal))
                    .bold()
                    .frame(width: 70)
                    .monospacedDigit()
            }
            .font(.caption)
        }
    }
}
