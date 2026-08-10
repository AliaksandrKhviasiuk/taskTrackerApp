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
    var filter: TaskFilter = .all

    /// IDs of tasks that have been deleted from the display but not yet
    /// committed to `tasks`/storage — still recoverable via `undoDelete()`.
    private(set) var pendingDeletionTaskIDs: Set<TaskItem.ID> = []

    private let storage: TaskStoring
    private let undoScheduler: UndoScheduler

    /// Derived view of `tasks` for the active filter. Never mutates or
    /// reorders `tasks` itself — filtering only changes what's displayed.
    var filteredTasks: [TaskItem] {
        switch filter {
        case .all:
            return tasks
        case .notCompleted:
            return tasks.filter { !$0.isCompleted }
        case .completed:
            return tasks.filter { $0.isCompleted }
        }
    }

    /// `filteredTasks` with any pending (not-yet-committed) deletions hidden.
    /// This is what the list should actually render.
    var displayedTasks: [TaskItem] {
        filteredTasks.filter { !pendingDeletionTaskIDs.contains($0.id) }
    }

    var hasPendingDeletion: Bool { !pendingDeletionTaskIDs.isEmpty }

    init(storage: TaskStoring = TransientTaskStore(), undoScheduler: UndoScheduler = DispatchUndoScheduler()) {
        self.storage = storage
        self.undoScheduler = undoScheduler
        self.tasks = storage.loadTasks()
    }

    @discardableResult
    func addTask(title: String) -> Bool {
        guard let validTitle = validatedTitle(from: title) else { return false }

        tasks.append(TaskItem(title: validTitle))
        storage.save(tasks)
        return true
    }

    @discardableResult
    func updateTitle(for taskID: TaskItem.ID, to newTitle: String) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        guard let validTitle = validatedTitle(from: newTitle) else { return false }

        tasks[index].title = validTitle
        storage.save(tasks)
        return true
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
        guard !idsToDelete.isEmpty else { return }

        commitPendingDeletion()

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
