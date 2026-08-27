//
//  SessionEditorView.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 18/08/2026.
//

import SwiftUI
import SwiftData

struct SessionEditorView: View {
    private let existingSession: Session?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Project> { !$0.archived }, sort: \Project.name)
    private var projects: [Project]
    @Query(filter: #Predicate<TaskItem> { !$0.archived }, sort: \TaskItem.title)
    private var tasks: [TaskItem]
    @Query(sort: \Session.startedAt) private var allSessions: [Session]

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var kind: SessionKind
    @State private var note: String
    @State private var interrupted: Bool
    @State private var selectedProject: Project?
    @State private var selectedTask: TaskItem?

    @State private var errorMessage: String?
    @State private var showingOverlapAlert = false
    @State private var overlapDescription = ""
    @State private var showingLongDurationAlert = false
    @State private var showingDeleteConfirmation = false

    init(session: Session? = nil) {
        self.existingSession = session
        let now = Date()
        _startedAt = State(initialValue: session?.startedAt ?? now.addingTimeInterval(-3600))
        _endedAt = State(initialValue: session?.endedAt ?? now)
        _kind = State(initialValue: session?.kind ?? .work)
        _note = State(initialValue: session?.note ?? "")
        _interrupted = State(initialValue: session?.interrupted ?? false)
        _selectedTask = State(initialValue: session?.task)
        _selectedProject = State(initialValue: session?.task?.project)
    }

    private var tasksForSelectedProject: [TaskItem] {
        guard let selectedProject else { return [] }
        return tasks.filter { $0.project?.persistentModelID == selectedProject.persistentModelID }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Início", selection: $startedAt)
                DatePicker("Fim", selection: $endedAt)
                LabeledContent("Duração", value: TimerEngine.format(max(0, endedAt.timeIntervalSince(startedAt))))
                Picker("Tipo", selection: $kind) {
                    Text("Trabalho").tag(SessionKind.work)
                    Text("Pausa").tag(SessionKind.break)
                    Text("Plano").tag(SessionKind.plan)
                }
                .pickerStyle(.segmented)
            }

            Section("Atribuição") {
                Picker("Projecto", selection: $selectedProject) {
                    Text("Nenhum").tag(Project?.none)
                    ForEach(projects) { project in
                        projectLabel(project).tag(Project?.some(project))
                    }
                }
                .onChange(of: selectedProject) { selectedTask = nil }

                Picker("Tarefa", selection: $selectedTask) {
                    Text("Nenhuma").tag(TaskItem?.none)
                    ForEach(tasksForSelectedProject) { task in
                        Text(task.title).tag(TaskItem?.some(task))
                    }
                }
                .disabled(selectedProject == nil)
            }

            Section("Nota (opcional)") {
                TextEditor(text: $note)
                    .frame(minHeight: 90)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if existingSession != nil {
                Section {
                    Button("Apagar sessão", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(existingSession == nil ? "Nova sessão" : "Editar sessão")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { attemptSave() }
            }
        }
        .alert("Sobreposição de sessões", isPresented: $showingOverlapAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Continuar mesmo assim") { checkDurationThenSave() }
        } message: {
            Text("Esta sessão sobrepõe-se a: \(overlapDescription)")
        }
        .alert("Sessão muito longa", isPresented: $showingLongDurationAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Continuar mesmo assim") { commitSave() }
        } message: {
            Text("Esta sessão dura mais de 12 horas. Tens a certeza?")
        }
        .confirmationDialog("Apagar esta sessão?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) {
                if let existingSession {
                    modelContext.delete(existingSession)
                    modelContext.saveAndCheckpoint()
                }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func attemptSave() {
        errorMessage = nil

        guard endedAt > startedAt else {
            errorMessage = "O fim tem de ser depois do início."
            return
        }

        if kind != .plan {
            let now = Date()
            guard startedAt <= now, endedAt <= now else {
                errorMessage = "Não podes usar datas no futuro."
                return
            }
        }

        if let overlapping = SessionStore.overlappingSession(startedAt: startedAt, endedAt: endedAt, excluding: existingSession?.persistentModelID, kind: kind, in: allSessions) {
            overlapDescription = SessionStore.describe(overlapping)
            showingOverlapAlert = true
            return
        }

        checkDurationThenSave()
    }

    private func checkDurationThenSave() {
        let duration = endedAt.timeIntervalSince(startedAt)
        if duration > 12 * 3600 {
            showingLongDurationAlert = true
            return
        }
        commitSave()
    }

    private func commitSave() {
        if let existingSession {
            existingSession.startedAt = startedAt
            existingSession.endedAt = endedAt
            existingSession.kind = kind
            existingSession.note = note.isEmpty ? nil : note
            existingSession.interrupted = interrupted
            existingSession.task = selectedTask
            existingSession.editedAt = Date()
        } else {
            let newSession = Session(
                startedAt: startedAt,
                endedAt: endedAt,
                task: selectedTask,
                kind: kind,
                note: note.isEmpty ? nil : note,
                interrupted: interrupted,
                editedAt: Date()
            )
            modelContext.insert(newSession)
        }
        modelContext.saveAndCheckpoint()
        dismiss()
    }

    private func projectLabel(_ project: Project) -> some View {
        Label {
            Text(project.name)
        } icon: {
            Circle().fill(project.color).frame(width: 10, height: 10)
        }
    }
}
