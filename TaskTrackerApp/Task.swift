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

    /// Whether this task is overdue (KAN-23) — derived from `dueDate` and
    /// `isCompleted` at access time rather than stored, per the ticket's
    /// explicit instruction not to add a persisted field. A task only
    /// qualifies when it's not completed AND `dueDate` is strictly before
    /// today's calendar day: completed tasks are exempt regardless of due
    /// date, tasks with no due date are never flagged, and a due date of
    /// today is not yet overdue. `dueDate` is already normalized to
    /// `Calendar.current.startOfDay(for:)` when stored (KAN-19), so
    /// comparing it against today's start-of-day compares calendar days
    /// rather than exact timestamps, matching the date-only semantics of
    /// due dates.
    var isOverdue: Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }
}
