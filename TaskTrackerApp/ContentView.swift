//
//  ContentView.swift
//  TaskTrackerApp
//
//  Created by Aliaksandr Khviasiuk on 09/08/2026.
//

import SwiftUI

/// Carries `undoBanner`'s measured height (KAN-44 fix pass) up to `body` so
/// the floating add-task button can offset itself by exactly that amount
/// while the banner is showing. `.overlay(alignment: .bottomTrailing)`
/// chained after `.safeAreaInset(edge: .bottom)` does *not* reposition a
/// sibling overlay above the inset's reserved band on its own — verified
/// live in the simulator by Reviewer-agent (KAN-44 Request Changes) — so
/// this reads the banner's actual on-screen height instead of assuming
/// modifier order handles it.
private struct UndoBannerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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

    /// Priority staged for the in-progress new task (KAN-30) — `nil` until
    /// one of `priorityPills` is tapped, matching `addTask(title:dueDate:priority:)`'s
    /// optional parameter. Lives only in this row's local state; nothing is
    /// persisted until `commitOrDiscardNewTask()` actually creates the task.
    /// Unlike `newTaskDueDate`, no `isDueDatePickerPresented`-style guard is
    /// needed here — see `priorityPills`'s doc comment for why.
    @State private var newTaskPriority: Priority?

    /// Drives the due-date edit sheet (KAN-22). Triggered via a long-press
    /// context menu on the row — distinct from tap-to-complete (KAN-3), the
    /// leading edit-title/duplicate swipe (KAN-8/KAN-14), and the trailing
    /// delete swipe (KAN-4/KAN-46), per the AC's non-collision requirement.
    @State private var editingDueDateTask: TaskItem?
    @FocusState private var isTitleFieldFocused: Bool

    /// Captured from `ScrollViewReader` so `revealAddTaskRow()` (KAN-44) can
    /// scroll to `addTaskRow` from the floating button, which lives outside
    /// the reader's closure (it's an overlay on the outer `NavigationStack`,
    /// positioned after `.safeAreaInset` so it can react to the undo
    /// banner — see that modifier's placement below).
    @State private var scrollProxy: ScrollViewProxy?

    /// Stable id for the trailing add-task row (KAN-43), so `ScrollViewReader`
    /// can scroll it into view regardless of how many task rows precede it.
    private static let addTaskRowID = "addTaskRow"

    /// `undoBanner`'s measured height (KAN-44 fix pass), read via
    /// `UndoBannerHeightPreferenceKey` and applied as bottom padding to
    /// `addTaskFloatingButton` while the banner is visible, so the two never
    /// visually collide regardless of the banner's dynamic content height
    /// (single line vs. multi-task deletion text).
    @State private var undoBannerHeight: CGFloat = 0

    /// Single source of truth for "the undo banner is currently on screen" —
    /// shared by `.safeAreaInset`'s condition and the floating button's
    /// offset so the two can never disagree about whether the banner is
    /// showing.
    private var isUndoBannerVisible: Bool {
        viewModel.hasPendingDeletion || viewModel.hasPendingEdit
    }

    /// Maps a `Priority` to its display color (KAN-30). Kept in the View
    /// rather than on the `Priority` enum itself — `Task.swift` is a plain
    /// model file that only imports `Foundation`, and adding a SwiftUI
    /// `Color` dependency there would blur the model/view boundary this
    /// codebase otherwise keeps clean.
    private func color(for priority: Priority) -> Color {
        switch priority {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }

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
                                            HStack(spacing: 6) {
                                                Text(task.title)
                                                    .strikethrough(task.isCompleted)
                                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                                                // (KAN-30) Priority badge shown alongside the
                                                // title, on the same line — omitted entirely
                                                // (no placeholder/error) when the task has no
                                                // priority, mirroring the due date's
                                                // shown-only-when-set convention below.
                                                if let priority = task.priority {
                                                    Text(priority.rawValue)
                                                        .font(.caption2.weight(.semibold))
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Capsule().fill(color(for: priority)))
                                                }
                                            }

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
                        // (KAN-44) Capture the proxy so `revealAddTaskRow()`
                        // can drive it from the floating button's tap
                        // handler, which lives outside this closure.
                        scrollProxy = proxy
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
                if isUndoBannerVisible {
                    undoBanner
                }
            }
            .onPreferenceChange(UndoBannerHeightPreferenceKey.self) { height in
                undoBannerHeight = height
            }
            // (KAN-44 fix pass) `.overlay(alignment: .bottomTrailing)` after
            // `.safeAreaInset` does NOT push the overlay above the inset's
            // reserved band on its own — confirmed live by Reviewer-agent,
            // the button rendered on top of the undo banner instead of
            // above it. Explicitly offsetting the button by the banner's
            // *measured* height (via `UndoBannerHeightPreferenceKey`) while
            // it's visible guarantees no overlap regardless of the banner's
            // content height, and collapses back to 0 — the ordinary device
            // safe area position — the instant the banner is hidden. Always
            // present, independent of `viewModel.tasks.isEmpty`, so it's
            // available for the very first task too.
            .overlay(alignment: .bottomTrailing) {
                addTaskFloatingButton
                    .padding(.bottom, isUndoBannerVisible ? undoBannerHeight : 0)
                    .animation(.easeInOut(duration: 0.2), value: isUndoBannerVisible)
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
        .background(
            // (KAN-44 fix pass) Measures the banner's actual rendered
            // height — including its own padding and the safe-area
            // insetting SwiftUI adds for `.safeAreaInset(edge: .bottom)`
            // content — and publishes it up via `UndoBannerHeightPreferenceKey`
            // so `addTaskFloatingButton` can offset by exactly that amount.
            GeometryReader { proxy in
                Color.clear.preference(
                    key: UndoBannerHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
    }

    private var undoBannerText: String {
        if viewModel.hasPendingDeletion {
            let count = viewModel.pendingDeletionTaskIDs.count
            return count == 1 ? "Task deleted" : "\(count) tasks deleted"
        } else {
            return "Task edited"
        }
    }

    /// Icon-only floating "Add Task" trigger (KAN-44), overlaid in the
    /// bottom-right corner. Tapping it calls `revealAddTaskRow()` — the same
    /// scroll-to-row + focus-title-field behavior KAN-43 previously fired
    /// automatically on every screen appearance, now fired deliberately on
    /// tap instead. See `ContentView.body`'s `.overlay` placement (after
    /// `.safeAreaInset`) for how this avoids colliding with the undo banner.
    private var addTaskFloatingButton: some View {
        Button(action: revealAddTaskRow) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 4, y: 2)
        }
        .padding(20)
        .accessibilityLabel("Add Task")
    }

    /// Scrolls the trailing `addTaskRow` into view and focuses its title
    /// field (KAN-44). This is the same mechanism KAN-43 stubbed onto the
    /// list's `.onAppear` — since the row is a permanent trailing row with
    /// no show/hide state (KAN-43 removed the old reveal/dismiss toggle),
    /// "trigger the add-task action" now means "bring the always-present
    /// row to the user's attention and put the keyboard in it," which is
    /// exactly this.
    private func revealAddTaskRow() {
        isTitleFieldFocused = true
        withAnimation {
            scrollProxy?.scrollTo(Self.addTaskRowID, anchor: .bottom)
        }
    }

    /// (KAN-43) Auto-committing trailing row inside the task `List`: losing
    /// focus with a non-empty title creates the task through the same
    /// `isValidTitle`/`addTask` path every other creation entry point uses
    /// (KAN-5's single-validation-path rule), while an empty title is
    /// silently discarded with no error shown. No Confirm/Cancel controls —
    /// the story explicitly removes them. Due-date input (KAN-45) lives in
    /// `dueDatePill`, and priority input (KAN-30) in `priorityPills`, both
    /// shown beneath the title.
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
    ///
    /// **Priority control (KAN-30) deliberately doesn't share this risk.**
    /// `priorityPills` is a row of plain in-line `Button`s that write
    /// directly to `newTaskPriority` — it never presents a sheet, full
    /// screen cover, or any other modal. The KAN-45 bug's root cause was
    /// specifically *modal presentation* resigning the title field's focus
    /// as a side effect (see `dueDatePickerSheet`'s doc comment); a plain
    /// button tap within the same row does not do that. So no
    /// `isDueDatePickerPresented`-style guard was added for priority — the
    /// `onChange` below only ever needs to special-case the due-date sheet.
    private var addTaskRow: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                TextField("New Task", text: $newTaskTitle)
                    .focused($isTitleFieldFocused)
                    .onChange(of: newTaskTitle) {
                        newTaskTitle = TaskListViewModel.cappedTitle(newTaskTitle)
                    }
                    .onSubmit(commitOrDiscardNewTask)

                HStack(spacing: 8) {
                    dueDatePill
                    priorityPills
                }
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

    /// Tap-to-select priority control (KAN-30) — a row of tappable pills,
    /// one per `Priority` case, rather than a `Picker`/sheet-based control.
    /// Tapping the already-selected pill deselects it (back to "no
    /// priority"), so the row stays fully usable without a separate
    /// clear affordance. See `addTaskRow`'s doc comment for why this shape
    /// avoids KAN-45's premature-commit risk: nothing here presents a sheet,
    /// so the title field's focus is never disturbed by using this control.
    private var priorityPills: some View {
        HStack(spacing: 4) {
            ForEach(Priority.allCases) { priority in
                let isSelected = newTaskPriority == priority
                Button {
                    newTaskPriority = isSelected ? nil : priority
                } label: {
                    Text(priority.rawValue)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(isSelected ? color(for: priority) : Color.secondary.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Commits the row's current title (and any staged `newTaskDueDate`
    /// (KAN-45) / `newTaskPriority` (KAN-30)) as a new task when the title
    /// passes the same `isValidTitle` check every other creation path uses
    /// (KAN-5), or silently discards all three otherwise. Checks validity
    /// itself rather than calling `addTask` unconditionally and inspecting
    /// its result, so the empty-title/lose-focus case never sets
    /// `viewModel.validationMessage` and therefore never surfaces an error,
    /// per the AC.
    private func commitOrDiscardNewTask() {
        if TaskListViewModel.isValidTitle(newTaskTitle) {
            viewModel.addTask(title: newTaskTitle, dueDate: newTaskDueDate, priority: newTaskPriority)
        }
        newTaskTitle = ""
        newTaskDueDate = nil
        newTaskPriority = nil
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
