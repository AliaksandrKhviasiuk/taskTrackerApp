//
//  ContentView.swift
//  TaskTrackerApp
//
//  Created by Aliaksandr Khviasiuk on 09/08/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = TaskListViewModel(storage: FileTaskStore(), filterStorage: UserDefaultsFilterStore())
    @State private var newTaskTitle = ""
    @State private var editingTask: TaskItem?

    /// Due date staged for the in-progress new task (KAN-45) — `nil` until
    /// the "Due Date" pill is used, matching `addTask(title:dueDate:)`'s
    /// optional parameter. Lives only in this row's local state; nothing is
    /// persisted until `commitOrDiscardNewTask()` actually creates the task.
    @State private var newTaskDueDate: Date?

    /// Whether `dueDatePickerSheet` is currently presented (KAN-45). Doubles
    /// as the guard that prevents `commitOrDiscardNewTask()` from firing
    /// prematurely when the sheet's presentation steals focus from the title
    /// field — see `addTaskRow`'s `onChange(of: isTitleFieldFocused)`.
    @State private var isDueDatePickerPresented = false

    /// Drives the due-date edit sheet (KAN-22). Triggered via a long-press
    /// context menu on the row — distinct from tap-to-complete (KAN-3), the
    /// leading edit-title/duplicate swipe (KAN-8/KAN-14), and the trailing
    /// delete swipe (KAN-4/KAN-46), per the AC's non-collision requirement.
    @State private var editingDueDateTask: TaskItem?
    @FocusState private var isTitleFieldFocused: Bool

    /// Stable id for the trailing add-task row (KAN-43), so `ScrollViewReader`
    /// can scroll it into view regardless of how many task rows precede it.
    private static let addTaskRowID = "addTaskRow"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                // (KAN-43) `addTaskRow` below is always a real trailing row
                // inside this same `List` — the empty states, the status
                // filter (KAN-9), search (KAN-13), and due-date sort (KAN-24)
                // only affect the branch above it, never whether it renders.
                ScrollViewReader { proxy in
                    List {
                        if viewModel.tasks.isEmpty {
                            ContentUnavailableView(
                                "No Tasks Yet",
                                systemImage: "checklist",
                                description: Text("Type a title below to create your first task.")
                            )
                            .listRowSeparator(.hidden)
                        } else if viewModel.displayedTasks.isEmpty {
                            ContentUnavailableView(
                                "No Matching Tasks",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text(noMatchingTasksDescription)
                            )
                            .listRowSeparator(.hidden)
                        } else {
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

                        addTaskRow
                    }
                    .onAppear {
                        // (KAN-43) KAN-44's reveal trigger doesn't exist yet, so
                        // the row is always visible today — this is the closest
                        // available "revealed" moment to auto-scroll to it and
                        // focus its title field. Once KAN-44 adds a real reveal
                        // action, this should move to fire from that action
                        // instead of on every appearance of the screen.
                        isTitleFieldFocused = true
                        proxy.scrollTo(Self.addTaskRowID, anchor: .bottom)
                    }
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $viewModel.searchText, prompt: "Search tasks")
            .toolbar {
                if viewModel.hasCompletedTasks {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Clear Completed", role: .destructive) {
                            viewModel.clearCompletedTasks()
                        }
                    }
                }
                if !viewModel.tasks.isEmpty {
                    // (KAN-24) Sort toggle — a continuous dimension, so a
                    // toggle rather than a new TaskFilter case. Composes with
                    // the existing status filter and search independently.
                    ToolbarItem(placement: .secondaryAction) {
                        Toggle(isOn: $viewModel.isSortedByDueDate) {
                            Label("Sort by Due Date", systemImage: "arrow.up.arrow.down")
                        }
                        .toggleStyle(.button)
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
            .sheet(isPresented: $isDueDatePickerPresented, onDismiss: {
                // (KAN-45) Refocus the title field once the picker closes,
                // regardless of how it closed (Clear, Done, or swipe-to-
                // dismiss). The sheet's own presentation is what resigned
                // the title field's focus in the first place (see the risk
                // this solves in `addTaskRow`'s onChange), so this restores
                // the row to the same "still being edited" state the user
                // was in before tapping the pill, letting a later real
                // blur/tap-away commit or discard the row normally.
                isTitleFieldFocused = true
            }) {
                dueDatePickerSheet
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

    /// (KAN-43) Auto-committing trailing row inside the task `List`: losing
    /// focus with a non-empty title creates the task through the same
    /// `isValidTitle`/`addTask` path every other creation entry point uses
    /// (KAN-5's single-validation-path rule), while an empty title is
    /// silently discarded with no error shown. No Confirm/Cancel controls —
    /// the story explicitly removes them. Due-date input (KAN-45) lives in
    /// `dueDatePill`, shown beneath the title.
    ///
    /// **Premature-commit risk (KAN-45):** presenting `dueDatePickerSheet`
    /// resigns the title `TextField`'s focus (sheet presentation dismisses
    /// the keyboard), which would otherwise fire `commitOrDiscardNewTask()`
    /// via the `onChange` below before a due date is ever picked — creating
    /// the task early, with no due date, out from under the still-open
    /// picker. The `onChange` guards on `isDueDatePickerPresented` (set true
    /// the instant the pill is tapped, in the same state update that later
    /// presents the sheet) so that focus loss caused by opening/using the
    /// picker is ignored; `onDismiss` on the sheet then refocuses the title
    /// field, restoring the row to its pre-tap editing state so a later
    /// genuine blur commits or discards normally.
    private var addTaskRow: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                TextField("New Task", text: $newTaskTitle)
                    .focused($isTitleFieldFocused)
                    .onChange(of: newTaskTitle) {
                        newTaskTitle = TaskListViewModel.cappedTitle(newTaskTitle)
                    }
                    .onSubmit(commitOrDiscardNewTask)

                dueDatePill
            }
        } icon: {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
        }
        .id(Self.addTaskRowID)
        .onChange(of: isTitleFieldFocused) { _, isFocused in
            guard !isFocused, !isDueDatePickerPresented else { return }
            commitOrDiscardNewTask()
        }
    }

    /// Tap-to-set due-date pill (KAN-45), replacing the pre-KAN-43
    /// `Toggle("Due Date", ...)` pattern. Shows the lightweight "Due Date"
    /// placeholder while `newTaskDueDate` is `nil`, or the chosen date once
    /// one is picked. Tapping opens `dueDatePickerSheet`.
    private var dueDatePill: some View {
        Button {
            isDueDatePickerPresented = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(newTaskDueDate?.formatted(date: .abbreviated, time: .omitted) ?? "Due Date")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    /// Date-only picker sheet (KAN-45) for `dueDatePill`. Writes directly
    /// into `newTaskDueDate` — nothing is persisted here, since the task
    /// doesn't exist yet; `commitOrDiscardNewTask()` is what actually
    /// creates it, passing `newTaskDueDate` through as `addTask`'s `dueDate`
    /// argument. "Clear" is the AC's required discoverable way to remove an
    /// already-set date back to "no due date."
    private var dueDatePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Due Date",
                selection: Binding(
                    get: { newTaskDueDate ?? Date() },
                    set: { newTaskDueDate = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        newTaskDueDate = nil
                        isDueDatePickerPresented = false
                    }
                    .disabled(newTaskDueDate == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isDueDatePickerPresented = false
                    }
                }
            }
        }
    }

    /// Commits the row's current title (and any staged `newTaskDueDate`,
    /// KAN-45) as a new task when the title passes the same `isValidTitle`
    /// check every other creation path uses (KAN-5), or silently discards
    /// both otherwise. Checks validity itself rather than calling `addTask`
    /// unconditionally and inspecting its result, so the empty-title/lose-
    /// focus case never sets `viewModel.validationMessage` and therefore
    /// never surfaces an error, per the AC.
    private func commitOrDiscardNewTask() {
        if TaskListViewModel.isValidTitle(newTaskTitle) {
            viewModel.addTask(title: newTaskTitle, dueDate: newTaskDueDate)
        }
        newTaskTitle = ""
        newTaskDueDate = nil
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
/// Uses a Toggle + date-only `DatePicker` shape — an off toggle on Save
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
