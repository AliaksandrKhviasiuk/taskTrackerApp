//
//  TaskListViewModelUndoTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Test double that captures the scheduled commit instead of waiting on a
/// real delay, so the undo window can be "fired" or left pending
/// deterministically from a test.
final class ManualUndoScheduler: UndoScheduler {
    private(set) var scheduledDelay: TimeInterval?
    private(set) var cancelCallCount = 0
    private var scheduledAction: (() -> Void)?

    func schedule(after seconds: TimeInterval, action: @escaping () -> Void) {
        scheduledDelay = seconds
        scheduledAction = action
    }

    func cancel() {
        cancelCallCount += 1
        scheduledAction = nil
    }

    /// Simulates the undo window expiring by running the scheduled commit now.
    func fireScheduledAction() {
        scheduledAction?()
    }
}

final class TaskListViewModelUndoTests: XCTestCase {

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

    // MARK: - Deleting hides the task immediately without committing it

    func test_deleteTask_hidesTaskFromDisplayedTasksButKeepsItInTasks() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertTrue(sut.displayedTasks.isEmpty)
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk"])
    }

    func test_deleteTask_setsHasPendingDeletion() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertTrue(sut.hasPendingDeletion)
    }

    func test_deleteTask_schedulesCommitAfterUndoWindow() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertEqual(scheduler.scheduledDelay, TaskListViewModel.undoWindow)
    }

    func test_deleteTask_withEmptyOffsets_doesNotCreatePendingDeletion() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.deleteTask(at: IndexSet())

        // Assert
        XCTAssertFalse(sut.hasPendingDeletion)
        XCTAssertNil(scheduler.scheduledDelay)
    }

    // MARK: - KAN-10-TC-01: undo restores the task to its original position

    func test_KAN10TC01_undoDelete_restoresTaskToOriginalPosition() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.addTask(title: "Write report")
        sut.deleteTask(at: IndexSet(integer: 1)) // "Walk the dog"

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog", "Write report"])
    }

    func test_KAN10TC01_undoDelete_restoresTaskToDisplayedTasks() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertEqual(sut.displayedTasks.map(\.title), ["Buy milk"])
    }

    func test_KAN10TC01_undoDelete_clearsHasPendingDeletion() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertFalse(sut.hasPendingDeletion)
    }

    func test_KAN10TC01_undoDelete_cancelsTheScheduledCommit() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertEqual(scheduler.cancelCallCount, 1)
    }

    func test_KAN10TC01_undoDelete_doesNotCallSave() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.deleteTask(at: IndexSet(integer: 0))
        let saveCallCountAfterDelete = fakeStorage.saveCallCount

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountAfterDelete)
    }

    func test_undoDelete_withNoPendingDeletion_doesNothing() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk"])
        XCTAssertFalse(sut.hasPendingDeletion)
    }

    // MARK: - KAN-10-TC-02: undo window expiring makes the deletion permanent

    func test_KAN10TC02_firingScheduledCommit_removesTaskFromTasks() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        scheduler.fireScheduledAction()

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    func test_KAN10TC02_firingScheduledCommit_persistsTheDeletion() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        scheduler.fireScheduledAction()

        // Assert
        XCTAssertEqual(fakeStorage.lastSavedTasks?.count, 0)
    }

    func test_KAN10TC02_firingScheduledCommit_clearsHasPendingDeletion() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        scheduler.fireScheduledAction()

        // Assert
        XCTAssertFalse(sut.hasPendingDeletion)
    }

    // MARK: - KAN-10-TC-03: nothing is persisted while the undo window is still open
    // (traces to the ticket's explicit KAN-7 coordination note)

    func test_KAN10TC03_deleteTask_beforeUndoWindowExpires_doesNotCallSave() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let saveCallCountAfterAdd = fakeStorage.saveCallCount

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountAfterAdd)
    }

    func test_KAN10TC03_deleteTask_beforeUndoWindowExpires_storageStillHasTheTask() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertEqual(fakeStorage.lastSavedTasks?.map(\.title), ["Buy milk"])
    }

    func test_commitPendingDeletion_withNothingPending_doesNotCallSave() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let saveCallCountAfterAdd = fakeStorage.saveCallCount

        // Act
        sut.commitPendingDeletion()

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountAfterAdd)
    }

    // MARK: - KAN-10-TC-04: starting a new deletion commits whatever was already
    // pending — only the most recent deletion is ever undoable, no stacking

    func test_KAN10TC04_deleteTask_whileAnotherIsPending_commitsThePreviousDeletionPermanently() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.deleteTask(at: IndexSet(integer: 0)) // "Buy milk" pending

        // Act
        sut.deleteTask(at: IndexSet(integer: 0)) // "Walk the dog" (now first displayed) pending; commits "Buy milk"

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Walk the dog"])
    }

    func test_KAN10TC04_deleteTask_whileAnotherIsPending_persistsThePreviousDeletion() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertEqual(fakeStorage.lastSavedTasks?.map(\.title), ["Walk the dog"])
    }

    func test_KAN10TC04_deleteTask_whileAnotherIsPending_onlyMostRecentDeletionIsUndoable() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.deleteTask(at: IndexSet(integer: 0)) // "Buy milk" pending
        sut.deleteTask(at: IndexSet(integer: 0)) // "Walk the dog" pending; "Buy milk" committed

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Walk the dog"]) // "Buy milk" cannot be recovered
    }

    // MARK: - KAN-10-TC-05: undo fully restores normal editability

    func test_KAN10TC05_updateTitle_afterUndo_succeedsNormally() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.deleteTask(at: IndexSet(integer: 0))
        sut.undoDelete()

        // Act
        let result = sut.updateTitle(for: taskID, to: "Buy oat milk")

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.title, "Buy oat milk")
    }

    // MARK: - KAN-10-TC-06: undo preserves completion status

    func test_KAN10TC06_undoDelete_preservesCompletionStatus() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.toggleCompletion(for: taskID)
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertTrue(sut.tasks[0].isCompleted)
    }

    // MARK: - KAN-10-TC-07: delete/undo under an active filter

    func test_KAN10TC07_deleteTask_withFilterActive_hidesFromDisplayedTasksImmediately() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.toggleCompletion(for: sut.tasks[1].id) // "Walk the dog" completed
        sut.filter = .completed

        // Act
        sut.deleteTask(at: IndexSet(integer: 0)) // "Walk the dog" via the displayed (filtered) offset

        // Assert
        XCTAssertTrue(sut.displayedTasks.isEmpty)
    }

    func test_KAN10TC07_undoDelete_withFilterActive_restoresTaskToFilteredView() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.toggleCompletion(for: sut.tasks[1].id)
        sut.filter = .completed
        sut.deleteTask(at: IndexSet(integer: 0))

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertEqual(sut.displayedTasks.map(\.title), ["Walk the dog"])
    }

    // MARK: - KAN-10-TC-08: deleting the last remaining task under a filter

    func test_KAN10TC08_deleteTask_lastRemainingUnderFilter_displayedTasksIsEmptyButUndoAvailable() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.toggleCompletion(for: sut.tasks[0].id)
        sut.filter = .completed // only "Buy milk" matches

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertTrue(sut.displayedTasks.isEmpty)
        XCTAssertTrue(sut.hasPendingDeletion)
    }

    // MARK: - KAN-10-TC-09: other mutations during the pending window don't
    // interfere with (or finalize) the pending deletion

    func test_KAN10TC09_toggleCompletion_onDifferentTask_whilePending_doesNotClearPendingDeletion() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.deleteTask(at: IndexSet(integer: 0)) // "Buy milk" pending

        // Act
        sut.toggleCompletion(for: sut.tasks[1].id) // "Walk the dog" — unrelated task

        // Assert
        XCTAssertTrue(sut.hasPendingDeletion)
    }

    func test_KAN10TC09_toggleCompletion_onDifferentTask_whilePending_stillPersistsThePendingTaskUncommitted() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.deleteTask(at: IndexSet(integer: 0)) // "Buy milk" pending, not yet persisted as deleted

        // Act
        sut.toggleCompletion(for: sut.tasks[1].id)

        // Assert
        XCTAssertEqual(fakeStorage.lastSavedTasks?.map(\.title), ["Buy milk", "Walk the dog"])
    }

    func test_KAN10TC09_toggleCompletion_onDifferentTask_whilePending_pendingDeletionStillUndoableAfterward() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.deleteTask(at: IndexSet(integer: 0))
        sut.toggleCompletion(for: sut.tasks[1].id)

        // Act
        sut.undoDelete()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog"])
    }
}
