//
//  FilterStoring.swift
//  TaskTrackerApp
//

import Foundation

/// Persists the selected status filter so it can be restored across app launches.
protocol FilterStoring {
    /// Loads the previously saved filter, or `.all` if nothing has been
    /// saved yet (fresh install) or the saved value can't be decoded.
    func loadFilter() -> TaskFilter

    /// Persists the given filter, replacing whatever was previously saved.
    func save(_ filter: TaskFilter)
}

/// Persists the filter as its raw string value in `UserDefaults` — a single
/// scalar, unlike the task list's own JSON-file storage (`FileTaskStore`),
/// so a lighter-weight mechanism is appropriate here (KAN-16).
nonisolated final class UserDefaultsFilterStore: FilterStoring {
    private static let key = "selectedTaskFilter"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadFilter() -> TaskFilter {
        guard let rawValue = defaults.string(forKey: Self.key),
              let filter = TaskFilter(rawValue: rawValue) else {
            return .all
        }
        return filter
    }

    func save(_ filter: TaskFilter) {
        defaults.set(filter.rawValue, forKey: Self.key)
    }
}

/// A no-op store that never reads or writes `UserDefaults`, keeping the
/// filter in memory only. Used as the default so constructing a bare
/// `TaskListViewModel()` (as the existing unit tests do) stays
/// side-effect-free; real persistence is opted into by passing
/// `UserDefaultsFilterStore()` explicitly.
nonisolated final class TransientFilterStore: FilterStoring {
    func loadFilter() -> TaskFilter { .all }
    func save(_ filter: TaskFilter) {}
}
