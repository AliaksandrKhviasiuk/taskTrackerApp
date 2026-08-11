//
//  TaskListViewModelEditUndoTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskListViewModelEditUndoTests: XCTestCase {

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

    // MARK: - KAN-17-TC-01: undo reverts the title to its pre-edit value

    func test_KAN17TC01_undoEdit_withinWindow_revertsTitleToPreviousValue() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.updateTitle(for: taskID, to: "Buy groceries")

        // Act
        sut.undoEdit()

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy milk")
        XCTAssertFalse(sut.hasPendingEdit)
    }

    // MARK: - KAN-17-TC-02: letting the window expire makes the new title permanent

    func test_KAN17TC02_editUndoWindowExpires_newTitleRemainsPermanently() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.updateTitle(for: taskID, to: "Buy groceries")

        // Act
        scheduler.fireScheduledAction()

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy groceries")
        XCTAssertFalse(sut.hasPendingEdit)

        // undoEdit is now a no-op — nothing left to revert
        sut.undoEdit()
        XCTAssertEqual(sut.tasks[0].title, "Buy groceries")
    }

    // MARK: - KAN-17-TC-03: a second edit commits the first (same-type replacement)

    func test_KAN17TC03_editingASecondTask_commitsTheFirstEditPermanently_onlySecondIsUndoable() {
        // Arrange
        sut.addTask(title: "Task A")
        sut.addTask(title: "Task B")
        let taskAID = sut.tasks[0].id
        let taskBID = sut.tasks[1].id
        sut.updateTitle(for: taskAID, to: "Task A edited")

        // Act
        sut.updateTitle(for: taskBID, to: "Task B edited")
        sut.undoEdit()

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Task A edited", "task A's edit was committed, not left revertible")
        XCTAssertEqual(sut.tasks[1].title, "Task B", "task B's edit was undone — it was the only one still pending")
    }

    // MARK: - KAN-17-TC-04: a pending deletion is committed when an edit starts

    func test_KAN17TC04_editingATask_whileDeletionIsPending_commitsTheDeletionImmediately() {
        // Arrange
        sut.addTask(title: "To delete")
        sut.addTask(title: "To edit")
        let toDeleteID = sut.tasks[0].id
        let toEditID = sut.tasks[1].id
        sut.deleteTask(at: IndexSet(integer: 0))
        XCTAssertTrue(sut.hasPendingDeletion, "sanity: deletion pending before the edit")

        // Act
        sut.updateTitle(for: toEditID, to: "To edit, edited")

        // Assert
        XCTAssertFalse(sut.hasPendingDeletion, "the pending deletion was committed, not left pending")
        XCTAssertFalse(sut.tasks.contains { $0.id == toDeleteID }, "the deleted task is permanently gone")
        XCTAssertTrue(sut.hasPendingEdit, "the edit's undo banner takes over the single shared slot")
    }

    // MARK: - KAN-17-TC-05: a pending edit is committed when a deletion starts

    func test_KAN17TC05_deletingATask_whileEditIsPending_commitsTheEditImmediately() {
        // Arrange
        sut.addTask(title: "To edit")
        sut.addTask(title: "To delete")
        let toEditID = sut.tasks[0].id
        sut.updateTitle(for: toEditID, to: "To edit, edited")
        XCTAssertTrue(sut.hasPendingEdit, "sanity: edit pending before the deletion")

        // Act
        sut.deleteTask(at: IndexSet(integer: 1))

        // Assert
        XCTAssertFalse(sut.hasPendingEdit, "the pending edit was committed, not left pending")
        XCTAssertEqual(sut.tasks.first { $0.id == toEditID }?.title, "To edit, edited", "the committed edit is permanent — undoEdit() can no longer touch it")
        XCTAssertTrue(sut.hasPendingDeletion, "the deletion's undo banner takes over the single shared slot")
    }

    // MARK: - KAN-17-TC-06: the new title is written to storage immediately,
    // independent of the pending-edit undo window (unlike a pending deletion)

    func test_KAN17TC06_updateTitle_savesNewTitleToStorageImmediately_beforeUndoWindowExpires() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateTitle(for: taskID, to: "Buy groceries")

        // Assert: storage already reflects the new title, even though undoEdit() could still revert it in-memory
        XCTAssertEqual(fakeStorage.lastSavedTasks?.first(where: { $0.id == taskID })?.title, "Buy groceries")
    }

    // MARK: - KAN-17-TC-07: a completion toggle never creates a pending edit

    func test_KAN17TC07_toggleCompletion_doesNotCreateAPendingEdit() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.toggleCompletion(for: taskID)

        // Assert
        XCTAssertFalse(sut.hasPendingEdit)
    }

    // MARK: - Coverage: undoEdit / commitPendingEdit are no-ops with nothing pending

    func test_undoEdit_withNothingPending_isNoOp() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.undoEdit()

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy milk")
        XCTAssertFalse(sut.hasPendingEdit)
    }

    func test_updateTitle_withUnknownTaskID_doesNotCreateAPendingEdit() {
        // Act
        let result = sut.updateTitle(for: UUID(), to: "Anything")

        // Assert
        XCTAssertFalse(result)
        XCTAssertFalse(sut.hasPendingEdit)
    }
}
