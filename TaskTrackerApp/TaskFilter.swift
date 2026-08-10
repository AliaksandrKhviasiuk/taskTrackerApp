//
//  TaskFilter.swift
//  TaskTrackerApp
//

import Foundation

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case notCompleted = "Not Completed"
    case completed = "Completed"

    var id: String { rawValue }
}
