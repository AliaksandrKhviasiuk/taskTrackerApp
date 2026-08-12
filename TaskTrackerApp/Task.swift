//
//  Task.swift
//  TaskTrackerApp
//

import Foundation

struct TaskItem: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    /// Optional due date (KAN-19). Date-only — callers are expected to strip
    /// any time-of-day component before assigning (see
    /// `TaskListViewModel.addTask(title:dueDate:)`), so this always
    /// represents a calendar day rather than a specific moment.
    ///
    /// Declared `Optional` so the synthesized `Codable` conformance decodes
    /// it via `decodeIfPresent`, meaning JSON persisted before this property
    /// existed (no `dueDate` key) still decodes successfully, as `nil`.
    var dueDate: Date?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
    }
}
