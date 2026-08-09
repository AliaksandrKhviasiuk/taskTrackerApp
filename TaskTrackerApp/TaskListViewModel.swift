//
//  TaskListViewModel.swift
//  TaskTrackerApp
//

import Foundation
import Observation

@Observable
final class TaskListViewModel {
    static let titleCharacterLimit = 200

    private(set) var tasks: [TaskItem] = []
    var validationMessage: String?

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
        return true
    }
}
