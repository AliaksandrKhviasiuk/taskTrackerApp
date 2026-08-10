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

    private(set) var tasks: [TaskItem]
    var validationMessage: String?
    var filter: TaskFilter = .all

    private let storage: TaskStoring

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

    init(storage: TaskStoring = TransientTaskStore()) {
        self.storage = storage
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

    /// `offsets` are positions within the currently displayed (possibly
    /// filtered) list, not `tasks` itself — translated via `filteredTasks` so
    /// deletion still targets the correct task when a filter is active.
    func deleteTask(at offsets: IndexSet) {
        let idsToDelete = Set(offsets.map { filteredTasks[$0].id })
        tasks.removeAll { idsToDelete.contains($0.id) }
        storage.save(tasks)
    }

    /// Single validation path shared by `addTask` and `updateTitle`, so title
    /// rules only need to change in one place. Sets `validationMessage` and
    /// returns the trimmed, valid title, or returns `nil` on failure.
    private func validatedTitle(from title: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            validationMessage = "Task title can't be empty."
            return nil
        }

        guard trimmedTitle.count <= Self.titleCharacterLimit else {
            validationMessage = "Task title can't be longer than \(Self.titleCharacterLimit) characters."
            return nil
        }

        validationMessage = nil
        return trimmedTitle
    }
}
