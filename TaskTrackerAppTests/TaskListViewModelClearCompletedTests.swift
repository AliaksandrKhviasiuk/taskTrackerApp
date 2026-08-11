//
//  TaskListViewModelClearCompletedTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskListViewModelClearCompletedTests: XCTestCase {

    private var sut: TaskListViewModel!
    private var fakeStorage: FakeTaskStoring!
    private var scheduler: ManualUndoScheduler!

    override func setUp() {
        super.setUp()
        fakeStorage = FakeTaskStoring()
        scheduler = ManualUndoScheduler()
        sut = TaskListViewModel(storage: fakeStorage, undoScheduler: scheduler)
    }

    override func tearDown() {
        sut = nil
        fakeStorage = nil
        scheduler = nil
        super.tearDown()
    }

    private func addMixedTasks() {
        sut.addTask(title: "Buy milk")       // not completed
        sut.addTask(title: "Walk the dog")   // will complete
        sut.addTask(title: "Pay bills")      // will complete
        sut.toggleCompletion(for: sut.tasks[1].id)
        sut.toggleCompletion(for: sut.tasks[2].id)
    }

    // MARK: - KAN-18-TC-01: all completed tasks removed in one action, single pending batch

    func test_KAN18TC01_clearCompletedTasks_withMixedList_removesAllCompletedInOneBatch() {
        // Arrange
        addMixedTasks()

        // Act
        sut.clearCompletedTasks()

        // Assert
        XCTAssertTrue(sut.hasPendingDeletion)
        XCTAssertEqual(sut.pendingDeletionTaskIDs.count, 2)
        XCTAssertEqual(sut.displayedTasks.map(\.title), ["Buy milk"])
    }

    // MARK: - KAN-18-TC-02: action availability tracks whether any task is completed

    func test_KAN18TC02_hasCompletedTasks_withNoCompletedTasks_isFalse() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act & Assert
        XCTAssertFalse(sut.hasCompletedTasks)
    }

    func test_KAN18TC02_hasCompletedTasks_withAtLeastOneCompletedTask_isTrue() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.toggleCompletion(for: sut.tasks[0].id)

        // Act & Assert
        XCTAssertTrue(sut.hasCompletedTasks)
    }

    func test_KAN18TC02_clearCompletedTasks_withNoCompletedTasks_isNoOp() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.clearCompletedTasks()

        // Assert
        XCTAssertFalse(sut.hasPendingDeletion)
        XCTAssertEqual(sut.tasks.count, 1)
    }

    // MARK: - KAN-18-TC-03: undo restores the whole batch with original completed status

    func test_KAN18TC03_undoDelete_afterClearCompletedTasks_restoresWholeBatchWithOriginalCompletionStatus() {
        // Arrange
        addMixedTasks()
        sut.clearCompletedTasks()

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertFalse(sut.hasPendingDeletion)
        XCTAssertEqual(sut.tasks.count, 3)
        XCTAssertTrue(sut.tasks.first { $0.title == "Walk the dog" }?.isCompleted ?? false)
        XCTAssertTrue(sut.tasks.first { $0.title == "Pay bills" }?.isCompleted ?? false)
    }

    // MARK: - KAN-18-TC-04: letting the undo window expire commits the batch permanently

    func test_KAN18TC04_clearCompletedTasks_afterUndoWindowExpires_permanentlyRemovesBatch() {
        // Arrange
        addMixedTasks()
        sut.clearCompletedTasks()

        // Act
        scheduler.fireScheduledAction()

        // Assert
        XCTAssertFalse(sut.hasPendingDeletion)
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk"])
        XCTAssertEqual(fakeStorage.lastSavedTasks?.map(\.title), ["Buy milk"])
    }

    // MARK: - KAN-18-TC-05: clears from the underlying list even when the active
    // filter hides every completed task from `displayedTasks`

    func test_KAN18TC05_clearCompletedTasks_withNotCompletedFilterActive_stillClearsAllCompletedFromUnderlyingTasks() {
        // Arrange
        addMixedTasks()
        sut.filter = .notCompleted
        XCTAssertTrue(sut.displayedTasks.allSatisfy { !$0.isCompleted }, "sanity: no completed task is visible under this filter")

        // Act
        sut.clearCompletedTasks()

        // Assert
        XCTAssertEqual(sut.pendingDeletionTaskIDs.count, 2, "both completed tasks were targeted despite being invisible under the active filter")
    }

    // MARK: - KAN-18-TC-06: a pre-existing single pending deletion is committed
    // before the batch clear starts its own pending action

    func test_KAN18TC06_clearCompletedTasks_withAnotherPendingDeletionAlreadyActive_commitsThatOneFirst() {
        // Arrange
        addMixedTasks()
        sut.deleteTask(at: IndexSet(integer: 0)) // pending deletion of "Buy milk"
        XCTAssertTrue(sut.hasPendingDeletion, "sanity: the single-item deletion is pending before the batch clear starts")

        // Act
        sut.clearCompletedTasks()

        // Assert: the earlier pending deletion ("Buy milk") was committed, not merged into the new batch
        XCTAssertEqual(sut.tasks.map(\.title), ["Walk the dog", "Pay bills"], "\"Buy milk\" was committed and removed by starting the new pending action")
        XCTAssertEqual(sut.pendingDeletionTaskIDs.count, 2, "the new pending batch covers only the two completed tasks, not the already-committed one")
    }

    // MARK: - KAN-18-TC-07: not-completed tasks are left untouched

    func test_KAN18TC07_clearCompletedTasks_leavesNotCompletedTasksUntouched() {
        // Arrange
        addMixedTasks()

        // Act
        sut.clearCompletedTasks()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog", "Pay bills"], "not-completed task stays in `tasks`, only hidden via pendingDeletionTaskIDs until the window closes")
        XCTAssertFalse(sut.tasks[0].isCompleted)
    }
}
