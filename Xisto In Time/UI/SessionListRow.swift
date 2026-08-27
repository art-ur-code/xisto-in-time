//
//  SessionListRow.swift
//  Xisto In Time
//

import SwiftData
import SwiftUI

/// Redesigned session row for `AllSessionsView` (design handoff, Aug 2026):
/// a 3px type-colored rail, hover-reveal actions, and a mini-timeline.
///
/// Deliberately a separate component from `SessionRow` (used by
/// Project/Task detail, left unchanged): this row's outer styling assumes
/// it sits inside a single shared bordered block per day (no per-row
/// card/material of its own), which `SessionRow`'s existing callers don't
/// expect.
struct SessionListRow: View {
    let session: Session
    let isFirstInGroup: Bool
    let isSelected: Bool
    let path: Binding<NavigationPath>
    let onSelect: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(TimerEngine.self) private var timerEngine
    @Environment(PomodoroController.self) private var pomodoro
    @State private var isHovered = false
    @State private var showingDeleteConfirmation = false

    private var isRunningThisTask: Bool {
        guard let task = session.task else { return false }
        return timerEngine.isRunning && timerEngine.currentTask?.persistentModelID == task.persistentModelID
    }

    private var isHighlighted: Bool { isHovered || isSelected }

    private var duration: TimeInterval {
        session.endedAt.timeIntervalSince(session.startedAt)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isHighlighted ? session.kind.color : session.kind.lightColor)
                .frame(width: 3)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.05) : (isHovered ? Color(hex: "FAFAFC") : Color.white))
        .overlay(alignment: .top) {
            if !isFirstInGroup {
                Rectangle().fill(Color(hex: "F0F0F3")).frame(height: 1)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onSelect()
        }
        .openOnDoubleClick {
            path.wrappedValue.append(SessionRoute(id: session.persistentModelID))
        }
        .contextMenu {
            Button("Apagar sessão", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
        .confirmationDialog("Apagar esta sessão?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) {
                modelContext.delete(session)
                modelContext.saveAndCheckpoint()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var content: some View {
        HStack(spacing: 14) {
            textColumn
            durationText
            actions
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(session.task?.externalRef ?? "—")
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "8A8A90"))
                Text(session.task?.title ?? "Sem atribuição")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if session.kind != .work {
                    Text(session.kind.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(session.kind.lightColor, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(session.kind.chipTextColor)
                        .fixedSize()
                }
            }

            HStack(spacing: 8) {
                if let project = session.task?.project {
                    Text(project.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color(hex: "6A6A70"))
                    Text("·").foregroundStyle(Color(hex: "8A8A90").opacity(0.5))
                }
                Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                    .monospacedDigit()
                if let note = session.note, !note.isEmpty {
                    Text("·").foregroundStyle(Color(hex: "8A8A90").opacity(0.5))
                    Text(note)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 380, alignment: .leading)
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Color(hex: "8A8A90"))

            timeline
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    /// Mini-timeline: an 08:00–20:00 day scale, matching the design handoff's
    /// formula exactly (`left`/`width` as fractions of a 12h track).
    private var timeline: some View {
        GeometryReader { geo in
            let trackWidth = min(geo.size.width, 460)
            let calendar = Calendar.current
            let startComponents = calendar.dateComponents([.hour, .minute], from: session.startedAt)
            let startMinutes = Double((startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0))
            let durationMinutes = duration / 60
            let leftFraction = max(0, (startMinutes - 480) / 720)
            let widthFraction = max(0.015, durationMinutes / 720)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "F0F0F3"))
                RoundedRectangle(cornerRadius: 2)
                    .fill(session.kind.color)
                    .frame(width: max(2, trackWidth * widthFraction))
                    .offset(x: trackWidth * leftFraction)
            }
        }
        .frame(height: 3)
        .frame(maxWidth: 460)
        .padding(.top, 7)
    }

    private var durationText: some View {
        Text(TimerEngine.format(duration))
            .font(.system(size: 13.5, design: .monospaced))
            .foregroundStyle(session.kind == .break ? Color(hex: "9A9AA0") : Color(hex: "2A2A2F"))
            .frame(width: 84, alignment: .trailing)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button {
                startFreeSession()
            } label: {
                HStack(spacing: 5) {
                    Text("▶").font(.system(size: 9))
                    Text(isRunningThisTask ? "A correr" : "Começar")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .background(Color(hex: "EAF3FF"), in: RoundedRectangle(cornerRadius: 7))
            .foregroundStyle(Color(hex: "007AFF"))
            .disabled(isRunningThisTask)

            Menu {
                Button("Apagar sessão", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color(hex: "8A8A90"))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 26, height: 26)

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "C4C4C9"))
                .onTapGesture {
                    path.wrappedValue.append(SessionRoute(id: session.persistentModelID))
                }
        }
        .frame(width: 150, alignment: .trailing)
        .opacity(isHighlighted ? 1 : 0)
        .allowsHitTesting(isHighlighted)
    }

    private func startFreeSession() {
        if timerEngine.isRunning {
            pomodoro.cancel()
        }
        timerEngine.start(kind: .work, task: session.task)
    }
}
