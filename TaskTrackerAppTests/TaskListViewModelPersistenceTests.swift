//
//  TaskListViewModelPersistenceTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Test double that records `save` calls and lets tests stub what
/// `loadTasks()` returns, without touching the filesystem. Used to verify
/// `TaskListViewModel`'s persistence *behavior* (when it loads, when it
/// saves, with what data) independently of any concrete storage
/// implementation.
final class FakeTaskStoring: TaskStoring {
    var stubbedTasks: [TaskItem] = []
    private(set) var saveCallCount = 0
    private(set) var lastSavedTasks: [TaskItem]?

    func loadTasks() -> [TaskItem] {
        stubbedTasks
    }

    func save(_ tasks: [TaskItem]) {
        saveCallCount += 1
        lastSavedTasks = tasks
    }
}

final class TaskListViewModelPersistenceTests: XCTestCase {

    private var fakeStorage: FakeTaskStoring!

    override func setUp() {
        super.setUp()
        fakeStorage = FakeTaskStoring()
    }

    override func tearDown() {
        fakeStorage = nil
        super.tearDown()
    }

    // MARK: - AC: given tasks were created, when the app is closed and reopened, all tasks and completion status are restored exactly

    func test_init_withPreviouslySavedTasks_loadsThemIntoTasks() {
        // Arrange
        let savedTasks = [
            TaskItem(title: "Buy milk", isCompleted: false),
            TaskItem(title: "Walk the dog", isCompleted: true)
        ]
        fakeStorage.stubbedTasks = savedTasks

        // Act
        let sut = TaskListViewModel(storage: fakeStorage)

        // Assert
        XCTAssertEqual(sut.tasks, savedTasks)
    }

    func test_init_withPreviouslySavedTasks_preservesCompletionStatusOfEachTask() {
        // Arrange
        fakeStorage.stubbedTasks = [
            TaskItem(title: "Buy milk", isCompleted: true),
            TaskItem(title: "Walk the dog", isCompleted: false)
        ]

        // Act
        let sut = TaskListViewModel(storage: fakeStorage)

        // Assert
        XCTAssertEqual(sut.tasks.map(\.isCompleted), [true, false])
    }

    func test_init_doesNotWriteLoadedTasksBackToStorage() {
        // Arrange
        fakeStorage.stubbedTasks = [TaskItem(title: "Buy milk")]

        // Act
        _ = TaskListViewModel(storage: fakeStorage)

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 0)
    }

    // MARK: - AC: app launches for the first time with no saved data -> normal empty state

    func test_init_withNoSavedTasks_resultsInEmptyTaskList() {
        // Arrange
        // fakeStorage.stubbedTasks defaults to []

        // Act
        let sut = TaskListViewModel(storage: fakeStorage)

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - Mutations persist the updated list (supports the "restored exactly" AC on the next launch)

    func test_addTask_withValidTitle_savesFullUpdatedTaskListToStorage() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 1)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.map(\.title), ["Buy milk"])
    }

    func test_addTask_withInvalidEmptyTitle_doesNotSaveToStorage() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)

        // Act
        sut.addTask(title: "")

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 0)
    }

    // MARK: - KAN-8-TC-01 / KAN-8-TC-02: updateTitle persists like addTask does

    func test_KAN8TC01_updateTitle_withValidTitle_savesFullUpdatedTaskListToStorage() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        let saveCallCountBeforeUpdate = fakeStorage.saveCallCount

        // Act
        sut.updateTitle(for: taskID, to: "Buy oat milk")

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountBeforeUpdate + 1)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.map(\.title), ["Buy oat milk"])
    }

    func test_KAN8TC02_updateTitle_withEmptyTitle_doesNotSaveToStorage() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        let saveCallCountBeforeUpdate = fakeStorage.saveCallCount

        // Act
        sut.updateTitle(for: taskID, to: "")

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountBeforeUpdate)
    }

    func test_updateTitle_withUnknownTaskID_doesNotCallSave() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)
        sut.addTask(title: "Buy milk")
        let saveCallCountBeforeUpdate = fakeStorage.saveCallCount

        // Act
        sut.updateTitle(for: UUID(), to: "New title")

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountBeforeUpdate)
    }

    func test_toggleCompletion_savesUpdatedCompletionStatusToStorage() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.toggleCompletion(for: taskID)

        // Assert
        XCTAssertEqual(fakeStorage.lastSavedTasks?.first?.isCompleted, true)
    }

    func test_toggleCompletion_withUnknownTaskID_doesNotCallSave() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)
        sut.addTask(title: "Buy milk")
        let saveCallCountBeforeToggle = fakeStorage.saveCallCount

        // Act
        sut.toggleCompletion(for: UUID())

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountBeforeToggle)
    }

    func test_deleteTask_savesResultingTaskListToStorage() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))
        sut.commitPendingDeletion() // KAN-10: deletion is soft until committed

        // Assert
        XCTAssertEqual(fakeStorage.lastSavedTasks?.map(\.title), ["Walk the dog"])
    }

    func test_deleteTask_downToEmptyList_savesEmptyListToStorage() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)
        sut.addTask(title: "Buy milk")

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))
        sut.commitPendingDeletion() // KAN-10: deletion is soft until committed

        // Assert
        XCTAssertEqual(fakeStorage.lastSavedTasks?.count, 0)
    }

    // KAN-10: deleteTask is now a true no-op for empty offsets — no pending
    // deletion is created, so there's nothing to commit and no reason to save.
    func test_deleteTask_withEmptyOffsets_doesNotCallSave() {
        // Arrange
        let sut = TaskListViewModel(storage: fakeStorage)
        sut.addTask(title: "Buy milk")
        let saveCallCountBeforeDelete = fakeStorage.saveCallCount

        // Act
        sut.deleteTask(at: IndexSet())

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountBeforeDelete)
        XCTAssertFalse(sut.hasPendingDeletion)
    }

    // MARK: - AC: previously saved data is missing, corrupted, or unreadable -> falls back to empty list instead of crashing
    // (exercised through the real FileTaskStore + DirectoryOverridingFileManager seam defined in TaskStoringTests.swift,
    // to prove the fallback holds all the way up through the ViewModel's public API, not just inside FileTaskStore.)

    func test_init_withCorruptedPersistedFile_resultsInEmptyTaskListInsteadOfCrashing() throws {
        // Arrange
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try Data("not valid json".utf8).write(to: tempDirectory.appendingPathComponent("tasks.json"))
        let fileStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))

        // Act
        let sut = TaskListViewModel(storage: fileStore)

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - Full round trip: closing and reopening the app restores tasks and completion status exactly

    func test_newViewModelInstanceBackedBySameFileStore_restoresTasksAndCompletionStatusExactly() {
        // Arrange
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let firstLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let firstLaunchViewModel = TaskListViewModel(storage: firstLaunchStore)
        firstLaunchViewModel.addTask(title: "Buy milk")
        firstLaunchViewModel.addTask(title: "Walk the dog")
        firstLaunchViewModel.toggleCompletion(for: firstLaunchViewModel.tasks[0].id)

        // Act (simulate closing and reopening the app: fresh store + fresh view model over the same file)
        let secondLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let secondLaunchViewModel = TaskListViewModel(storage: secondLaunchStore)

        // Assert
        XCTAssertEqual(secondLaunchViewModel.tasks.map(\.title), ["Buy milk", "Walk the dog"])
        XCTAssertEqual(secondLaunchViewModel.tasks.map(\.isCompleted), [true, false])
    }

    // MARK: - KAN-19-TC-02: a task's due date survives closing and relaunching
    // the app (proxied the same way as the round trip above: a fresh
    // ViewModel/FileTaskStore pair over the same underlying file)

    func test_KAN19TC02_newViewModelInstanceBackedBySameFileStore_restoresDueDateAcrossRelaunch() {
        // Arrange
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let firstLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let firstLaunchViewModel = TaskListViewModel(storage: firstLaunchStore)
        firstLaunchViewModel.addTask(title: "Buy milk", dueDate: dueDate)

        // Act (simulate closing and reopening the app: fresh store + fresh view model over the same file)
        let secondLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let secondLaunchViewModel = TaskListViewModel(storage: secondLaunchStore)

        // Assert
        XCTAssertEqual(secondLaunchViewModel.tasks.first?.dueDate, dueDate)
    }
}
