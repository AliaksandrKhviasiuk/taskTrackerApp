//
//  TaskStoring.swift
//  TaskTrackerApp
//

import Foundation

/// Persists the task list so it can be restored across app launches.
protocol TaskStoring {
    /// Loads the previously saved tasks.
    /// Returns an empty array if nothing has been saved yet, or if the
    /// saved data is missing, corrupted, or otherwise unreadable.
    func loadTasks() -> [TaskItem]

    /// Persists the given tasks, replacing whatever was previously saved.
    func save(_ tasks: [TaskItem])
}

/// Persists tasks as JSON in a file under the app's Application Support directory.
final class FileTaskStore: TaskStoring {
    private let fileURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let directory = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        fileURL = directory.appendingPathComponent("tasks.json")
    }

    func loadTasks() -> [TaskItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let tasks = try? JSONDecoder().decode([TaskItem].self, from: data) else {
            return []
        }
        return tasks
    }

    func save(_ tasks: [TaskItem]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// A no-op store that never reads or writes to disk, keeping tasks in memory
/// only. Used as the default so constructing a bare `TaskListViewModel()`
/// (as the existing unit tests do) stays side-effect-free and isolated;
/// real persistence is opted into by passing `FileTaskStore()` explicitly.
final class TransientTaskStore: TaskStoring {
    func loadTasks() -> [TaskItem] { [] }
    func save(_ tasks: [TaskItem]) {}
}
