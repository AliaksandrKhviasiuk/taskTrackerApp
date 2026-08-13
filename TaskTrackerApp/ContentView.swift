//
//  ContentView.swift
//  TaskTrackerApp
//
//  Created by Aliaksandr Khviasiuk on 09/08/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = TaskListViewModel(storage: FileTaskStore(), filterStorage: UserDefaultsFilterStore())
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var hasNewTaskDueDate = false
    @State private var newTaskDueDate = Date()
    @State private var editingTask: TaskItem?

    /// Drives the due-date edit sheet (KAN-22). Triggered via a long-press
    /// context menu on the row — distinct from tap-to-complete (KAN-3), the
    /// leading edit-title/duplicate swipe (KAN-8/KAN-14), and the trailing
    /// delete swipe (KAN-4/KAN-46), per the AC's non-collision requirement.
    @State private var editingDueDateTask: TaskItem?
    @FocusState private var isTitleFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isAddingTask {
                    addTaskRow
                }

                if !viewModel.tasks.isEmpty {
                    Picker("Filter", selection: $viewModel.filter) {
                        ForEach(TaskFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Yet",
                        systemImage: "checklist",
                        description: Text("Tap \"Add Task\" to create your first task.")
                    )
                } else if viewModel.displayedTasks.isEmpty {
                    ContentUnavailableView(
                        "No Matching Tasks",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(noMatchingTasksDescription)
                    )
                } else {
                    List {
                        ForEach(viewModel.displayedTasks) { task in
                            Button {
                                viewModel.toggleCompletion(for: task.id)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title)
                                            .strikethrough(task.isCompleted)
                                            .foregroundStyle(task.isCompleted ? .secondary : .primary)

                                        // (KAN-19) Only shown when the task has a due date —
                                        // no placeholder for tasks without one.
                                        if let dueDate = task.dueDate {
                                            HStack(spacing: 4) {
                                                // (KAN-23) Icon + color cue for overdue tasks —
                                                // display only, doesn't affect list order.
                                                if task.isOverdue {
                                                    Image(systemName: "exclamationmark.circle.fill")
                                                        .font(.caption)
                                                        .foregroundStyle(.red)
                                                }
                                                Text(dueDate, style: .date)
                                                    .font(.caption)
                                                    .foregroundStyle(task.isOverdue ? .red : .secondary)
                                            }
                                        }
                                    }
                                } icon: {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    editingDueDateTask = task
                                } label: {
                                    Label(
                                        task.dueDate == nil ? "Set Due Date" : "Edit Due Date",
                                        systemImage: "calendar"
                                    )
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingTask = task
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button {
                                    viewModel.duplicateTask(id: task.id)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                .tint(.indigo)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    if let index = viewModel.displayedTasks.firstIndex(where: { $0.id == task.id }) {
                                        viewModel.deleteTask(at: IndexSet(integer: index))
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $viewModel.searchText, prompt: "Search tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Task") {
                        isAddingTask = true
                        isTitleFieldFocused = true
                    }
                }
                if viewModel.hasCompletedTasks {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Clear Completed", role: .destructive) {
                            viewModel.clearCompletedTasks()
                        }
                    }
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(task: task, viewModel: viewModel) {
                    editingTask = nil
                }
            }
            .sheet(item: $editingDueDateTask) { task in
                EditDueDateSheet(task: task, viewModel: viewModel) {
                    editingDueDateTask = nil
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.hasPendingDeletion || viewModel.hasPendingEdit {
                    undoBanner
                }
            }
        }
    }

    /// Reuses the single "No Matching Tasks" empty state for every
    /// zero-result cause (filter, search, or both combined) — text-only
    /// change, no new empty-state variant (KAN-13, composes with KAN-9).
    private var noMatchingTasksDescription: String {
        let trimmedSearch = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasFilter = viewModel.filter != .all

        switch (hasFilter, viewModel.isSearching) {
        case (true, true):
            return "No tasks match \"\(trimmedSearch)\" in the \"\(viewModel.filter.rawValue)\" filter."
        case (true, false):
            return "No tasks match the \"\(viewModel.filter.rawValue)\" filter."
        case (false, true):
            return "No tasks match \"\(trimmedSearch)\"."
        case (false, false):
            return ""
        }
    }

    /// Covers both pending-action kinds (KAN-17) — deletion and edit share a
    /// single pending-action slot on the ViewModel, so at most one of
    /// `hasPendingDeletion`/`hasPendingEdit` is ever true, and this banner
    /// never needs to represent both at once.
    private var undoBanner: some View {
        HStack {
            Text(undoBannerText)
            Spacer()
            Button("Undo") {
                if viewModel.hasPendingDeletion {
                    viewModel.undoDelete()
                } else {
                    viewModel.undoEdit()
                }
            }
            .fontWeight(.semibold)
        }
        .padding()
        .background(.thinMaterial)
    }

    private var undoBannerText: String {
        if viewModel.hasPendingDeletion {
            let count = viewModel.pendingDeletionTaskIDs.count
            return count == 1 ? "Task deleted" : "\(count) tasks deleted"
        } else {
            return "Task edited"
        }
    }

    private var addTaskRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("Task title", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTitleFieldFocused)
                    .onSubmit(confirmNewTask)
                    .onChange(of: newTaskTitle) {
                        newTaskTitle = TaskListViewModel.cappedTitle(newTaskTitle)
                    }

                Button("Confirm", action: confirmNewTask)
                    .disabled(!TaskListViewModel.isValidTitle(newTaskTitle))

                Button("Cancel", role: .cancel) {
                    cancelNewTask()
                }
            }

            // (KAN-19) Optional due date, date-only — no time picker.
            Toggle("Due Date", isOn: $hasNewTaskDueDate.animation())

            if hasNewTaskDueDate {
                DatePicker("Due Date", selection: $newTaskDueDate, displayedComponents: .date)
                    .labelsHidden()
            }

            if let validationMessage = viewModel.validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private func confirmNewTask() {
        let dueDate = hasNewTaskDueDate ? newTaskDueDate : nil
        guard viewModel.addTask(title: newTaskTitle, dueDate: dueDate) else { return }
        resetNewTaskInput()
    }

    private func cancelNewTask() {
        viewModel.validationMessage = nil
        resetNewTaskInput()
    }

    private func resetNewTaskInput() {
        newTaskTitle = ""
        hasNewTaskDueDate = false
        newTaskDueDate = Date()
        isAddingTask = false
        isTitleFieldFocused = false
    }
}

private struct EditTaskSheet: View {
    let task: TaskItem
    let viewModel: TaskListViewModel
    let onDismiss: () -> Void

    @State private var title: String
    @FocusState private var isTitleFieldFocused: Bool

    init(task: TaskItem, viewModel: TaskListViewModel, onDismiss: @escaping () -> Void) {
        self.task = task
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _title = State(initialValue: task.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .focused($isTitleFieldFocused)
                        .onChange(of: title) {
                            title = TaskListViewModel.cappedTitle(title)
                        }

                    if let validationMessage = viewModel.validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.validationMessage = nil
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard viewModel.updateTitle(for: task.id, to: title) else { return }
                        onDismiss()
                    }
                    .disabled(!TaskListViewModel.isValidTitle(title))
                }
            }
            .onAppear { isTitleFieldFocused = true }
        }
    }
}

/// Due-date-only edit sheet (KAN-22), opened via the row's context menu.
/// Reuses the same Toggle + date-only `DatePicker` shape the add-task row
/// uses for a due date at creation time (KAN-19) — an off toggle on Save
/// clears the due date, satisfying the AC's "clear" case.
private struct EditDueDateSheet: View {
    let task: TaskItem
    let viewModel: TaskListViewModel
    let onDismiss: () -> Void

    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: TaskItem, viewModel: TaskListViewModel, onDismiss: @escaping () -> Void) {
        self.task = task
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Due Date", isOn: $hasDueDate.animation())

                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateDueDate(for: task.id, to: hasDueDate ? dueDate : nil)
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
