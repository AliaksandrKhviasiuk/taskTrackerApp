//
//  TaskStoringTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// A `FileManager` subclass that redirects `.applicationSupportDirectory`
/// lookups to a caller-supplied directory. This is the injection seam
/// `FileTaskStore` already exposes via its `fileManager` initializer
/// parameter, so `FileTaskStore` tests below can round-trip real files
/// without ever touching the real Application Support folder on disk.
final class DirectoryOverridingFileManager: FileManager {
    private let overrideDirectory: URL

    init(overrideDirectory: URL) {
        self.overrideDirectory = overrideDirectory
        super.init()
    }

    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        guard directory == .applicationSupportDirectory else {
            return super.urls(for: directory, in: domainMask)
        }
        return [overrideDirectory]
    }
}

final class FileTaskStoreTests: XCTestCase {

    private var tempDirectory: URL!
    private var sut: FileTaskStore!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        sut = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
    }

    override func tearDown() {
        sut = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - AC: tasks and completion status restored exactly across launches (round trip)

    func test_loadTasks_afterSavingTasks_returnsSameTasks() {
        // Arrange
        let tasks = [
            TaskItem(title: "Buy milk", isCompleted: false),
            TaskItem(title: "Walk the dog", isCompleted: true)
        ]
        sut.save(tasks)

        // Act
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertEqual(loaded, tasks)
    }

    func test_loadTasks_afterSavingTasks_preservesCompletionStatusOfEachTask() {
        // Arrange
        let tasks = [
            TaskItem(title: "Buy milk", isCompleted: true),
            TaskItem(title: "Walk the dog", isCompleted: false)
        ]
        sut.save(tasks)

        // Act
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertEqual(loaded.map(\.isCompleted), [true, false])
    }

    func test_loadTasks_afterSavingTasks_preservesTaskIdentity() {
        // Arrange
        let task = TaskItem(title: "Buy milk")
        sut.save([task])

        // Act
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertEqual(loaded.first?.id, task.id)
    }

    func test_save_calledAgainWithNewData_overwritesPreviouslySavedTasks() {
        // Arrange
        sut.save([TaskItem(title: "Buy milk")])

        // Act
        let newTasks = [TaskItem(title: "Walk the dog")]
        sut.save(newTasks)
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertEqual(loaded, newTasks)
    }

    func test_save_withEmptyTaskList_persistsEmptyList() {
        // Arrange
        sut.save([TaskItem(title: "Buy milk")])

        // Act
        sut.save([])
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - AC: app launches for the first time with no saved data -> empty state, no crash

    func test_loadTasks_whenNoFileHasEverBeenSaved_returnsEmptyArray() {
        // Arrange
        // sut created in setUp(); nothing saved yet, directory doesn't even exist

        // Act
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - AC: previously saved data is missing, corrupted, or unreadable -> falls back to empty list, no crash

    func test_loadTasks_whenFileContainsCorruptedJSON_returnsEmptyArrayWithoutCrashing() throws {
        // Arrange
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("tasks.json")
        try Data("{ this is not valid json ]".utf8).write(to: fileURL)

        // Act
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_loadTasks_whenFileContainsValidJSONOfWrongShape_returnsEmptyArrayWithoutCrashing() throws {
        // Arrange
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("tasks.json")
        try Data(#"{"foo": "bar"}"#.utf8).write(to: fileURL)

        // Act
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_loadTasks_afterCorruptedFile_subsequentSaveAndLoadStillWorksCorrectly() throws {
        // Arrange
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("tasks.json")
        try Data("not json".utf8).write(to: fileURL)
        XCTAssertTrue(sut.loadTasks().isEmpty) // sanity check on arranged (corrupted) state

        // Act
        let tasks = [TaskItem(title: "Buy milk")]
        sut.save(tasks)
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertEqual(loaded, tasks)
    }
}

final class TransientTaskStoreTests: XCTestCase {

    private var sut: TransientTaskStore!

    override func setUp() {
        super.setUp()
        sut = TransientTaskStore()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_loadTasks_alwaysReturnsEmptyArray() {
        // Arrange
        // sut created in setUp()

        // Act
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_loadTasks_afterSaveIsCalled_stillReturnsEmptyArray() {
        // Arrange
        sut.save([TaskItem(title: "Buy milk")])

        // Act
        let loaded = sut.loadTasks()

        // Assert
        XCTAssertTrue(loaded.isEmpty)
    }
}
