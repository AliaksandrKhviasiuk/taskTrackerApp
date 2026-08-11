//
//  TaskListViewModelDuplicateTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskListViewModelDuplicateTests: XCTestCase {

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

    // MARK: - KAN-14-TC-01: same title, not completed, added to the list

    func test_KAN14TC01_duplicateTask_withExistingTask_addsNewTaskWithSameTitleNotCompleted() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let sourceID = sut.tasks[0].id

        // Act
        let result = sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.count, 2)
        XCTAssertEqual(sut.tasks[1].title, "Buy milk")
        XCTAssertFalse(sut.tasks[1].isCompleted)
        XCTAssertNotEqual(sut.tasks[1].id, sourceID)
    }

    // MARK: - KAN-14-TC-02: title at the 200-char boundary is copied unchanged

    func test_KAN14TC02_duplicateTask_withTitleAt200CharacterLimit_copiesTitleUnchanged() {
        // Arrange
        let boundaryTitle = String(repeating: "a", count: 200)
        sut.addTask(title: boundaryTitle)
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[1].title, boundaryTitle)
        XCTAssertEqual(sut.tasks[1].title.count, 200)
    }

    // MARK: - KAN-14-TC-03: duplicating a completed task doesn't copy completion state

    func test_KAN14TC03_duplicateTask_ofCompletedTask_duplicateIsNotCompletedAndOriginalUnaffected() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let sourceID = sut.tasks[0].id
        sut.toggleCompletion(for: sourceID)
        XCTAssertTrue(sut.tasks[0].isCompleted)

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertTrue(sut.tasks[0].isCompleted, "original task's completion state must be unaffected")
        XCTAssertFalse(sut.tasks[1].isCompleted, "duplicate must never copy the source's completion state")
    }

    // MARK: - KAN-14-TC-04: duplicate lands in the underlying list even when the
    // active filter would hide it (new tasks always start not completed)

    // Superseded by KAN-15: `duplicateTask` routes through `addTask`, and
    // KAN-15 made `addTask` auto-reset a filter that would hide the new
    // (always not-completed) task, instead of letting it silently
    // disappear. So under the "Completed" filter, a duplicate is no longer
    // just added-but-hidden — it's added AND immediately revealed by an
    // auto-reset to "All". Updated in place rather than left describing
    // behavior the app no longer has (KAN-14-TC-04 in Jira still describes
    // the pre-KAN-15 contract; this test now documents the composed result).
    func test_KAN14TC04_duplicateTask_whileCompletedFilterActive_addsToUnderlyingTasksAndKAN15AutoRevealsIt() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let sourceID = sut.tasks[0].id
        sut.toggleCompletion(for: sourceID)
        sut.filter = .completed

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks.count, 2, "duplicate must be added to the underlying list")
        XCTAssertEqual(sut.filter, .all, "KAN-15: the Completed filter, which would have hidden the not-completed duplicate, auto-resets")
        XCTAssertTrue(sut.displayedTasks.contains { $0.id == sut.tasks[1].id },
                       "the duplicate is immediately visible after the auto-reset")
    }

    // MARK: - KAN-14-TC-05: happy-path contrast — duplicate appears immediately
    // when the active filter doesn't hide not-completed tasks

    func test_KAN14TC05_duplicateTask_whileNotCompletedFilterActive_appearsInDisplayedTasksImmediately() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let sourceID = sut.tasks[0].id
        sut.filter = .notCompleted

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.displayedTasks.count, 2)
    }

    // MARK: - KAN-14-TC-06 (unit-level proxy): a task that can't be found (e.g.
    // already committed out of `tasks`, standing in for "mid pending-deletion
    // and unreachable via the View") is a no-op, not a crash.

    func test_KAN14TC06_duplicateTask_withUnknownTaskID_doesNothingAndReturnsFalse() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        let result = sut.duplicateTask(id: UUID())

        // Assert
        XCTAssertFalse(result)
        XCTAssertEqual(sut.tasks.count, 1)
    }

    // MARK: - Coverage: persistence, not tied to a specific manual case

    func test_duplicateTask_onSuccess_savesFullUpdatedTaskListToStorage() {
        // Arrange
        sut.addTask(title: "Buy milk") // 1st save
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID) // 2nd save

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 2)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.count, 2)
    }

    func test_duplicateTask_withUnknownTaskID_doesNotCallSave() {
        // Arrange
        sut.addTask(title: "Buy milk") // 1st (and, if this passes, only) save
        let saveCallCountAfterAdd = fakeStorage.saveCallCount

        // Act
        sut.duplicateTask(id: UUID())

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountAfterAdd)
    }
}
