//
//  TaskListViewModel.swift
//  TaskTrackerApp
//

import Foundation
import Observation

@Observable
final class TaskListViewModel {
    static let titleCharacterLimit = 200

    private(set) var tasks: [TaskItem]
    var validationMessage: String?

    private let storage: TaskStoring

    init(storage: TaskStoring = TransientTaskStore()) {
        self.storage = storage
        self.tasks = storage.loadTasks()
    }

    @discardableResult
    func addTask(title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            validationMessage = "Task title can't be empty."
            return false
        }

        guard trimmedTitle.count <= Self.titleCharacterLimit else {
            validationMessage = "Task title can't be longer than \(Self.titleCharacterLimit) characters."
            return false
        }

        tasks.append(TaskItem(title: trimmedTitle))
        validationMessage = nil
        storage.save(tasks)
        return true
    }

    func toggleCompletion(for taskID: TaskItem.ID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].isCompleted.toggle()
        storage.save(tasks)
    }

    func deleteTask(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            tasks.remove(at: index)
        }
        storage.save(tasks)
    }
}
