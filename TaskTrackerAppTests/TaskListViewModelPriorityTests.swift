//
//  TaskListViewModelPriorityTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for `TaskListViewModel.addTask(title:dueDate:priority:)`'s new
/// optional `priority` parameter (KAN-30). Covers the AC-level behavior
/// (attach a priority, leave it unset, each of the three fixed values, title
/// validation is unaffected/unbypassed) plus persistence, mirroring the
/// KAN-19 due-date precedent in `TaskListViewModelDueDateTests.swift`.
/// `duplicateTask(id:)`'s priority-forwarding is covered separately in
/// `TaskListViewModelDuplicatePriorityTests.swift`, mirroring how KAN-20's
/// due-date forwarding got its own file
/// (`TaskListViewModelDuplicateDueDateTests.swift`).
final class TaskListViewModelPriorityTests: XCTestCase {

    private var sut: TaskListViewModel!
    private var fakeStorage: FakeTaskStoring!

    override func setUp() {
        super.setUp()
        fakeStorage = FakeTaskStoring()
        sut = TaskListViewModel(storage: fakeStorage)
    }

    override func tearDown() {
        sut = nil
        fakeStorage = nil
        super.tearDown()
    }

    // MARK: - KAN-30-TC-01/02/03: priority picked before confirming -> task created and saved with that priority

    func test_KAN30TC01_addTask_withLowPriority_addsTaskWithThatPriority() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", priority: .low)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.priority, .low)
    }

    func test_KAN30TC02_addTask_withMediumPriority_addsTaskWithThatPriority() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", priority: .medium)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.priority, .medium)
    }

    func test_KAN30TC03_addTask_withHighPriority_addsTaskWithThatPriority() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", priority: .high)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.priority, .high)
    }

    // MARK: - KAN-30-TC-04: priority left unset -> task created successfully with no priority

    func test_KAN30TC04_addTask_withoutPriorityArgument_createsTaskWithNilPriority() {
        // Arrange
        // sut created in setUp(); addTask's priority parameter defaults to nil

        // Act
        let result = sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertTrue(result)
        XCTAssertNil(sut.tasks.first?.priority)
    }

    func test_KAN30TC04_addTask_withExplicitNilPriority_createsTaskWithNilPrioritySameAsOmitted() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", priority: nil)

        // Assert
        XCTAssertTrue(result)
        XCTAssertNil(sut.tasks.first?.priority)
    }

    // MARK: - AC: title validation is not bypassed or altered by a priority
    // being attached (mirrors KAN-19-TC-11's due-date precedent, and directly
    // answers Manual-QA-agent's note-for-Unit-Tests-agent about whether
    // priority reuses/interferes with the KAN-5 title validation path — it
    // does not: `addTask` still routes every title through
    // `validatedTitle(from:)` regardless of `priority`)

    func test_addTask_withEmptyTitleAndPrioritySet_doesNotAddTaskRegardlessOfPriority() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "", priority: .high)

        // Assert
        XCTAssertFalse(result)
        XCTAssertTrue(sut.tasks.isEmpty)
        XCTAssertNotNil(sut.validationMessage)
    }

    func test_addTask_withWhitespaceOnlyTitleAndPrioritySet_doesNotAddTask() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "   \n  ", priority: .medium)

        // Assert
        XCTAssertFalse(result)
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - Coverage: priority composes independently with the existing
    // dueDate parameter — setting one doesn't affect or require the other

    func test_addTask_withPriorityAndDueDate_addsTaskWithBothAttached() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        sut.addTask(title: "Buy milk", dueDate: dueDate, priority: .high)

        // Assert
        XCTAssertEqual(sut.tasks.first?.priority, .high)
        XCTAssertEqual(sut.tasks.first?.dueDate, dueDate)
    }

    func test_addTask_withPriorityOnly_leavesDueDateNil() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk", priority: .low)

        // Assert
        XCTAssertNil(sut.tasks.first?.dueDate)
    }

    // MARK: - Coverage: Priority.allCases offers exactly the three fixed
    // values (KAN-30-TC-08, at the Model level Manual-QA-agent's picker-level
    // case traces to — ContentView's priority picker iterates
    // `Priority.allCases` as its single source of truth per Dev-agent's
    // summary, so this pins that the source itself never grows a 4th case or
    // a custom value)

    func test_KAN30TC08_priorityAllCases_containsExactlyLowMediumHighInOrder() {
        // Arrange
        // no setup needed

        // Act
        let allCases = Priority.allCases

        // Assert
        XCTAssertEqual(allCases, [.low, .medium, .high])
    }

    // MARK: - Persistence: addTask's priority participates in what gets
    // saved, like every other task field

    func test_addTask_withPriority_savesFullUpdatedTaskListIncludingPriorityToStorage() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk", priority: .medium)

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 1)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.first?.priority, .medium)
    }

    func test_addTask_withoutPriority_savesTaskWithNilPriorityToStorage() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertNil(fakeStorage.lastSavedTasks?.first?.priority)
    }

    // MARK: - Persistence: priority survives a save/reload cycle, proxied the
    // same way as KAN-19-TC-02/KAN-22-TC-11's relaunch checks: a fresh
    // ViewModel/FileTaskStore pair over the same underlying file, simulating
    // closing and reopening the app

    func test_newViewModelInstanceBackedBySameFileStore_restoresPriorityAcrossRelaunch() {
        // Arrange
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let firstLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let firstLaunchViewModel = TaskListViewModel(storage: firstLaunchStore)
        firstLaunchViewModel.addTask(title: "Buy milk", priority: .high)

        // Act (simulate closing and reopening the app: fresh store + fresh view model over the same file)
        let secondLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let secondLaunchViewModel = TaskListViewModel(storage: secondLaunchStore)

        // Assert
        XCTAssertEqual(secondLaunchViewModel.tasks.first?.priority, .high)
    }

    func test_newViewModelInstanceBackedBySameFileStore_restoresNilPriorityAcrossRelaunch() {
        // Arrange
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let firstLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let firstLaunchViewModel = TaskListViewModel(storage: firstLaunchStore)
        firstLaunchViewModel.addTask(title: "Buy milk")

        // Act (simulate closing and reopening the app: fresh store + fresh view model over the same file)
        let secondLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let secondLaunchViewModel = TaskListViewModel(storage: secondLaunchStore)

        // Assert
        XCTAssertNil(secondLaunchViewModel.tasks.first?.priority)
    }
}
