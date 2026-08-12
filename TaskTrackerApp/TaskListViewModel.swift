//
//  TaskListViewModel.swift
//  TaskTrackerApp
//

import Foundation
import Observation

@Observable
final class TaskListViewModel {
    static let titleCharacterLimit = 200

    /// Truncates `title` to `titleCharacterLimit` if needed. Shared by every
    /// live-capping text field (add + edit) so the limit is enforced in one
    /// place rather than copy-pasted per call site.
    static func cappedTitle(_ title: String) -> String {
        guard title.count > titleCharacterLimit else { return title }
        return String(title.prefix(titleCharacterLimit))
    }

    /// The single canonical "is this title valid" check — non-empty after
    /// trimming, and within `titleCharacterLimit`. Both the View's
    /// button-enabled state and `validatedTitle(from:)` derive from this, so
    /// the rule itself only needs to change in one place.
    static func isValidTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= titleCharacterLimit
    }

    static let undoWindow: TimeInterval = 5

    private(set) var tasks: [TaskItem]
    var validationMessage: String?

    /// Persisted via `filterStorage` on every change (KAN-16) — restored in
    /// `init`, independent of `searchText` which is deliberately never persisted.
    var filter: TaskFilter = .all {
        didSet {
            filterStorage.save(filter)
        }
    }

    var searchText: String = ""

    /// IDs of tasks that have been deleted from the display but not yet
    /// committed to `tasks`/storage — still recoverable via `undoDelete()`.
    private(set) var pendingDeletionTaskIDs: Set<TaskItem.ID> = []

    /// The most recent title edit, still within its undo window (KAN-17).
    /// Unlike a pending deletion, the new title is already saved to
    /// `storage` — this only tracks what to revert to, for `undoEdit()`.
    struct PendingEdit: Equatable {
        let taskID: TaskItem.ID
        let previousTitle: String
    }

    /// Shares a single pending-action slot with `pendingDeletionTaskIDs`
    /// (KAN-17, generalizing KAN-10's single-pending-deletion rule across
    /// both action types): starting a new pending deletion or a new pending
    /// edit always commits whatever else was pending first, via
    /// `beginPendingDeletion(for:)`/`beginPendingEdit(taskID:previousTitle:)`
    /// — so at most one of `pendingDeletionTaskIDs`/`pendingEdit` is ever
    /// non-empty/non-nil at a time, and only one undo banner is ever shown.
    private(set) var pendingEdit: PendingEdit?

    private let storage: TaskStoring
    private let undoScheduler: UndoScheduler
    private let filterStorage: FilterStoring

    /// Derived view of `tasks` for the active status filter and search text —
    /// two independent, combinable predicates (KAN-13). Never mutates or
    /// reorders `tasks` itself — filtering only changes what's displayed.
    var filteredTasks: [TaskItem] {
        let statusFiltered: [TaskItem]
        switch filter {
        case .all:
            statusFiltered = tasks
        case .notCompleted:
            statusFiltered = tasks.filter { !$0.isCompleted }
        case .completed:
            statusFiltered = tasks.filter { $0.isCompleted }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return statusFiltered }

        return statusFiltered.filter {
            $0.title.range(of: trimmedSearch, options: .caseInsensitive) != nil
        }
    }

    /// Whether the empty `displayedTasks` state (when `tasks` is non-empty)
    /// was caused by the search text, the status filter, or both — drives
    /// which empty-state message the View shows.
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `filteredTasks` with any pending (not-yet-committed) deletions hidden.
    /// This is what the list should actually render.
    var displayedTasks: [TaskItem] {
        filteredTasks.filter { !pendingDeletionTaskIDs.contains($0.id) }
    }

    var hasPendingDeletion: Bool { !pendingDeletionTaskIDs.isEmpty }

    var hasPendingEdit: Bool { pendingEdit != nil }

    /// Whether "Clear Completed" (KAN-18) has anything to act on.
    var hasCompletedTasks: Bool { tasks.contains { $0.isCompleted } }

    init(
        storage: TaskStoring = TransientTaskStore(),
        undoScheduler: UndoScheduler = DispatchUndoScheduler(),
        filterStorage: FilterStoring = TransientFilterStore()
    ) {
        self.storage = storage
        self.undoScheduler = undoScheduler
        self.filterStorage = filterStorage
        self.tasks = storage.loadTasks()
        self.filter = filterStorage.loadFilter()
    }

    /// - Parameter dueDate: Optional due date (KAN-19). Not required —
    ///   passing `nil` (the default) creates the task with no due date.
    ///   Normalized to a date-only value via `normalizedDueDate(_:)` before
    ///   being stored, regardless of what time-of-day component the caller
    ///   passed in.
    @discardableResult
    func addTask(title: String, dueDate: Date? = nil) -> Bool {
        guard let validTitle = validatedTitle(from: title) else { return false }

        let newTask = TaskItem(title: validTitle, dueDate: normalizedDueDate(dueDate))
        tasks.append(newTask)
        storage.save(tasks)
        revealIfHidden(newTask.id)
        return true
    }

    /// Strips any time-of-day component so a stored due date always
    /// represents a calendar day (KAN-19: date only, no time-of-day) —
    /// regardless of what time component a `DatePicker`-bound `Date` happens
    /// to carry. `dueDate` stays a plain `Date` (rather than a dedicated
    /// date-only type) to keep `TaskItem`'s `Codable` conformance simple.
    private func normalizedDueDate(_ dueDate: Date?) -> Date? {
        guard let dueDate else { return nil }
        return Calendar.current.startOfDay(for: dueDate)
    }

    @discardableResult
    func updateTitle(for taskID: TaskItem.ID, to newTitle: String) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        guard let validTitle = validatedTitle(from: newTitle) else { return false }

        let previousTitle = tasks[index].title
        tasks[index].title = validTitle
        storage.save(tasks)
        revealIfHidden(taskID)
        beginPendingEdit(taskID: taskID, previousTitle: previousTitle)
        return true
    }

    /// After an add or edit, resets only whichever of `filter`/`searchText`
    /// is actually hiding the affected task from `displayedTasks` — never
    /// both when only one is the cause, and never either when neither is
    /// (KAN-15). Editing a title never changes `isCompleted`, so the status
    /// filter can only ever need resetting for a freshly-added (always
    /// not-completed) task, not for an edit.
    private func revealIfHidden(_ taskID: TaskItem.ID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        guard !displayedTasks.contains(where: { $0.id == taskID }) else { return }

        if filter == .completed, !task.isCompleted {
            filter = .all
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty, task.title.range(of: trimmedSearch, options: .caseInsensitive) == nil {
            searchText = ""
        }
    }

    /// Creates a copy of the task with the given ID (same title and due
    /// date, not completed — KAN-20 forwards `source.dueDate`, isCompleted
    /// duplication itself is unchanged from KAN-14) and appends it via the
    /// same `addTask` path every other creation goes through (KAN-5's
    /// single-validation-path rule) — the source title is already
    /// valid/trimmed, so this always succeeds. No-op if `taskID` doesn't
    /// match a task in `tasks` (e.g. it's mid a pending deletion and already
    /// hidden from the View).
    @discardableResult
    func duplicateTask(id taskID: TaskItem.ID) -> Bool {
        guard let source = tasks.first(where: { $0.id == taskID }) else { return false }
        return addTask(title: source.title, dueDate: source.dueDate)
    }

    func toggleCompletion(for taskID: TaskItem.ID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].isCompleted.toggle()
        storage.save(tasks)
    }

    /// `offsets` are positions within the currently displayed list
    /// (`displayedTasks`), not `tasks` itself. The targeted tasks are hidden
    /// immediately but stay in `tasks` — and therefore still get persisted by
    /// any other mutation's `storage.save(tasks)` in the meantime — until
    /// `commitPendingDeletion()` runs `undoWindow` seconds later, or
    /// `undoDelete()` restores them. Only one pending deletion is ever live
    /// at a time: starting a new one immediately commits whatever was
    /// already pending, since its undo option is no longer visible.
    func deleteTask(at offsets: IndexSet) {
        let idsToDelete = Set(offsets.map { displayedTasks[$0].id })
        beginPendingDeletion(for: idsToDelete)
    }

    /// Clears every completed task in one batch action (KAN-18). IDs are
    /// computed from the full `tasks` array, not `displayedTasks` — an
    /// active filter or search must never hide part of the batch from
    /// being cleared. Shares the same single-pending-action undo mechanism
    /// as `deleteTask(at:)` via `beginPendingDeletion(for:)`.
    func clearCompletedTasks() {
        let idsToDelete = Set(tasks.filter(\.isCompleted).map(\.id))
        beginPendingDeletion(for: idsToDelete)
    }

    /// Shared entry point for starting a new pending deletion — used by both
    /// single-task swipe-delete (KAN-4/KAN-10) and the batch "Clear
    /// Completed" action (KAN-18), so "commit whatever was already pending,
    /// then start the new one" has one implementation. Also commits a
    /// pending edit, if any — deletion and edit share one pending-action
    /// slot (KAN-17).
    private func beginPendingDeletion(for idsToDelete: Set<TaskItem.ID>) {
        guard !idsToDelete.isEmpty else { return }

        commitPendingDeletion()
        commitPendingEdit()

        pendingDeletionTaskIDs = idsToDelete
        undoScheduler.schedule(after: Self.undoWindow) { [weak self] in
            self?.commitPendingDeletion()
        }
    }

    /// Restores whatever deletion is currently pending. No-op if nothing is pending.
    func undoDelete() {
        guard hasPendingDeletion else { return }
        undoScheduler.cancel()
        pendingDeletionTaskIDs.removeAll()
    }

    /// Permanently removes the pending deletion from `tasks` and persists
    /// it. Called when the undo window expires, or immediately when a new
    /// deletion starts and an older one is still pending.
    func commitPendingDeletion() {
        guard hasPendingDeletion else { return }
        undoScheduler.cancel()
        let idsToDelete = pendingDeletionTaskIDs
        pendingDeletionTaskIDs.removeAll()
        tasks.removeAll { idsToDelete.contains($0.id) }
        storage.save(tasks)
    }

    /// Shared entry point for starting a new pending edit (KAN-17), mirroring
    /// `beginPendingDeletion(for:)`: commits any earlier pending edit (same
    /// type, e.g. a second edit before the first's window closes) AND any
    /// pending deletion (different type, single shared slot) before starting
    /// the new one. Uses the same `undoScheduler` instance as deletion —
    /// `schedule(after:action:)` already replaces whatever was previously
    /// scheduled on it, so only one timer is ever live regardless of type.
    private func beginPendingEdit(taskID: TaskItem.ID, previousTitle: String) {
        commitPendingDeletion()
        commitPendingEdit()

        pendingEdit = PendingEdit(taskID: taskID, previousTitle: previousTitle)
        undoScheduler.schedule(after: Self.undoWindow) { [weak self] in
            self?.commitPendingEdit()
        }
    }

    /// Restores whatever edit is currently pending, reverting the task's
    /// title back to its value before the edit. No-op if nothing is pending.
    func undoEdit() {
        guard let pendingEdit else { return }
        undoScheduler.cancel()
        if let index = tasks.firstIndex(where: { $0.id == pendingEdit.taskID }) {
            tasks[index].title = pendingEdit.previousTitle
            storage.save(tasks)
        }
        self.pendingEdit = nil
    }

    /// Makes the pending edit permanent (it's already the current title —
    /// this just clears the tracking that made it recoverable). Called when
    /// the undo window expires, or immediately when a new pending action
    /// (deletion or edit) starts and an older edit is still pending.
    private func commitPendingEdit() {
        guard pendingEdit != nil else { return }
        undoScheduler.cancel()
        pendingEdit = nil
    }

    /// Single validation path shared by `addTask` and `updateTitle`. Defers
    /// the actual pass/fail rule to `isValidTitle(_:)`; only picks which
    /// message to show when it fails. Sets `validationMessage` and returns
    /// the trimmed, valid title, or returns `nil` on failure.
    ///
    /// The length check below is unreachable through the real UI today — the
    /// View caps input live via `cappedTitle`, per KAN-5's decision to keep
    /// prevention-at-input-time rather than switch to reject-with-message.
    /// It's kept deliberately, not as dead code: it's the ViewModel's own
    /// invariant, so any future caller that bypasses the View (tests, a
    /// future extension, etc.) still gets a correctly rejected over-length
    /// title instead of silently accepting one.
    private func validatedTitle(from title: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isValidTitle(title) else {
            validationMessage = trimmedTitle.isEmpty
                ? "Task title can't be empty."
                : "Task title can't be longer than \(Self.titleCharacterLimit) characters."
            return nil
        }

        validationMessage = nil
        return trimmedTitle
    }
}
