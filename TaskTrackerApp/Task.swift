//
//  Task.swift
//  TaskTrackerApp
//

import Foundation

/// Fixed set of task priorities (KAN-30) — Low, Medium, or High only; no
/// custom/user-defined levels (explicitly out of scope). `String` raw values
/// keep the persisted JSON representation stable and human-readable, and
/// `CaseIterable`/`Identifiable` let the add-task row iterate over the three
/// cases to build its picker control without a second source of truth.
enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

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

    /// Optional priority (KAN-30), fixed to one of `Priority`'s three cases.
    /// Set only at creation time — this story deliberately doesn't add an
    /// edit-priority affordance (that's KAN-31).
    ///
    /// Declared `Optional`, mirroring `dueDate`, so the synthesized
    /// `Codable` conformance decodes it via `decodeIfPresent`: JSON persisted
    /// before this property existed (no `priority` key) still decodes
    /// successfully, as `nil`.
    var priority: Priority?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, dueDate: Date? = nil, priority: Priority? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
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
