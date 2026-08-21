//
//  TaskListViewModelTagTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for `TaskListViewModel.addTask(title:dueDate:priority:tag:)`'s new
/// optional `tag` parameter and its `normalizedTag(_:)` normalization helper
/// (KAN-33). Covers the AC-level behavior (attach a tag, leave it unset,
/// title validation is unaffected/unbypassed) plus `normalizedTag`'s
/// whitespace-trimming/blank-collapsing behavior and persistence, mirroring
/// the KAN-19/KAN-30 precedents in `TaskListViewModelDueDateTests.swift` /
/// `TaskListViewModelPriorityTests.swift`. `duplicateTask(id:)`'s
/// tag-forwarding is covered separately in
/// `TaskListViewModelDuplicateTagTests.swift`, mirroring how KAN-20's
/// due-date forwarding and KAN-30's priority forwarding each got their own
/// file.
final class TaskListViewModelTagTests: XCTestCase {

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

    // MARK: - KAN-33-TC-01: a tag entered before confirming -> task created and saved with that tag

    func test_KAN33TC01_addTask_withTag_addsTaskWithThatTag() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", tag: "Work")

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.tag, "Work")
    }

    // MARK: - KAN-33-TC-02: tag left unset -> task created successfully with no tag

    func test_KAN33TC02_addTask_withoutTagArgument_createsTaskWithNilTag() {
        // Arrange
        // sut created in setUp(); addTask's tag parameter defaults to nil

        // Act
        let result = sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertTrue(result)
        XCTAssertNil(sut.tasks.first?.tag)
    }

    func test_KAN33TC02_addTask_withExplicitNilTag_createsTaskWithNilTagSameAsOmitted() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", tag: nil)

        // Assert
        XCTAssertTrue(result)
        XCTAssertNil(sut.tasks.first?.tag)
    }

    // MARK: - KAN-33-TC-05: whitespace-only tag -> normalized to "no category/tag",
    // consistent with TC-02/TC-04 (Dev-agent's implemented behavior, per its
    // doc comment on normalizedTag(_:))

    func test_KAN33TC05_addTask_withWhitespaceOnlyTag_createsTaskWithNilTag() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", tag: "   ")

        // Assert
        XCTAssertTrue(result)
        XCTAssertNil(sut.tasks.first?.tag)
    }

    func test_KAN33TC05_addTask_withTabsAndNewlinesOnlyTag_createsTaskWithNilTag() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", tag: " \t\n ")

        // Assert
        XCTAssertTrue(result)
        XCTAssertNil(sut.tasks.first?.tag)
    }

    // MARK: - KAN-33-TC-06: leading/trailing whitespace around a tag is trimmed
    // before storing/displaying

    func test_KAN33TC06_addTask_withLeadingAndTrailingWhitespaceTag_storesTrimmedTag() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", tag: "  Urgent  ")

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.tag, "Urgent")
    }

    // MARK: - normalizedTag: internal whitespace within otherwise-meaningful
    // text is preserved as-is — only outer whitespace is trimmed, not
    // collapsed/stripped throughout the string

    func test_addTask_withTagContainingInternalSpaces_preservesInternalSpacing() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", tag: "Home Improvement")

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.tag, "Home Improvement")
    }

    func test_addTask_withOuterWhitespaceAroundInternalSpacedTag_trimsOnlyOuterWhitespace() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", tag: "  Home Improvement  ")

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.tag, "Home Improvement", "only leading/trailing whitespace should be trimmed; internal spacing must be untouched")
    }

    // MARK: - KAN-33-TC-07: no length cap on tag — Dev-agent's explicit design
    // decision (PR-review-agent's non-blocking note: "normalizedTag applies no
    // length cap, unlike title"), unlike TaskListViewModel.titleCharacterLimit's
    // cap on title. A very long tag must be accepted and stored verbatim, not
    // truncated.

    func test_KAN33TC07_addTask_withVeryLongTag_storesTagWithoutTruncation() {
        // Arrange
        let longTag = String(repeating: "a", count: 500)

        // Act
        let result = sut.addTask(title: "Buy milk", tag: longTag)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.tag, longTag)
        XCTAssertEqual(sut.tasks.first?.tag?.count, 500, "tag must not be truncated/capped the way title is")
    }

    // MARK: - AC: title validation is not bypassed or altered by a tag being
    // attached (mirrors KAN-19-TC-11/KAN-30's due-date/priority precedents,
    // and directly answers Manual-QA-agent's note-for-Unit-Tests-agent about
    // whether tag reuses/interferes with the KAN-5 title validation path — it
    // does not: `addTask` still routes every title through
    // `validatedTitle(from:)` regardless of `tag`)

    func test_addTask_withEmptyTitleAndTagSet_doesNotAddTaskRegardlessOfTag() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "", tag: "Work")

        // Assert
        XCTAssertFalse(result)
        XCTAssertTrue(sut.tasks.isEmpty)
        XCTAssertNotNil(sut.validationMessage)
    }

    func test_addTask_withWhitespaceOnlyTitleAndTagSet_doesNotAddTask() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "   \n  ", tag: "Work")

        // Assert
        XCTAssertFalse(result)
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - KAN-33-TC-08: cancelling task creation persists nothing (a
    // ViewModel-level analog: addTask is never called from a discarded row,
    // so no task exists and storage is never touched — mirrors ContentView's
    // commitOrDiscardNewTask() only calling addTask when the title is valid)

    func test_whenAddTaskIsNeverCalled_noTaskOrTagIsPersisted() {
        // Arrange
        // sut created in setUp(); simulates the row being discarded before
        // commitOrDiscardNewTask() would call addTask

        // Act
        // (no action — nothing invoked, matching a cancelled/discarded row)

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
        XCTAssertEqual(fakeStorage.saveCallCount, 0)
    }

    // MARK: - Coverage: tag composes independently with the existing dueDate
    // and priority parameters — setting one doesn't affect or require the others

    func test_addTask_withTagDueDateAndPriority_addsTaskWithAllThreeAttached() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        sut.addTask(title: "Buy milk", dueDate: dueDate, priority: .high, tag: "Errands")

        // Assert
        XCTAssertEqual(sut.tasks.first?.tag, "Errands")
        XCTAssertEqual(sut.tasks.first?.dueDate, dueDate)
        XCTAssertEqual(sut.tasks.first?.priority, .high)
    }

    func test_addTask_withTagOnly_leavesDueDateAndPriorityNil() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk", tag: "Errands")

        // Assert
        XCTAssertNil(sut.tasks.first?.dueDate)
        XCTAssertNil(sut.tasks.first?.priority)
    }

    // MARK: - Persistence: addTask's tag participates in what gets saved,
    // like every other task field

    func test_addTask_withTag_savesFullUpdatedTaskListIncludingTagToStorage() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk", tag: "Work")

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 1)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.first?.tag, "Work")
    }

    func test_addTask_withoutTag_savesTaskWithNilTagToStorage() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertNil(fakeStorage.lastSavedTasks?.first?.tag)
    }

    func test_addTask_withWhitespaceOnlyTag_savesTaskWithNilTagToStorage() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk", tag: "   ")

        // Assert
        XCTAssertNil(fakeStorage.lastSavedTasks?.first?.tag)
    }

    // MARK: - KAN-33-TC-09: tag survives a save/reload cycle, proxied the same
    // way as KAN-19-TC-02/KAN-22-TC-11/KAN-30's relaunch checks: a fresh
    // ViewModel/FileTaskStore pair over the same underlying file, simulating
    // closing and reopening the app

    func test_KAN33TC09_newViewModelInstanceBackedBySameFileStore_restoresTagAcrossRelaunch() {
        // Arrange
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let firstLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let firstLaunchViewModel = TaskListViewModel(storage: firstLaunchStore)
        firstLaunchViewModel.addTask(title: "Buy milk", tag: "Groceries")

        // Act (simulate closing and reopening the app: fresh store + fresh view model over the same file)
        let secondLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let secondLaunchViewModel = TaskListViewModel(storage: secondLaunchStore)

        // Assert
        XCTAssertEqual(secondLaunchViewModel.tasks.first?.tag, "Groceries")
    }

    func test_KAN33TC09_newViewModelInstanceBackedBySameFileStore_restoresNilTagAcrossRelaunch() {
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
        XCTAssertNil(secondLaunchViewModel.tasks.first?.tag)
    }

    // MARK: - KAN-33-TC-10: multiple tasks with different tags (or none) each
    // independently retain their own tag — no bleed between rows

    func test_KAN33TC10_multipleTasksWithDifferentTags_eachTaskRetainsItsOwnTag() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Task A", tag: "Work")
        sut.addTask(title: "Task B", tag: "Home")
        sut.addTask(title: "Task C") // no tag

        // Assert
        XCTAssertEqual(sut.tasks[0].tag, "Work")
        XCTAssertEqual(sut.tasks[1].tag, "Home")
        XCTAssertNil(sut.tasks[2].tag)
    }
}
