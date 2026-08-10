//
//  TaskListViewModelTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskListViewModelTests: XCTestCase {

    private var sut: TaskListViewModel!

    override func setUp() {
        super.setUp()
        sut = TaskListViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Test helpers

    private func addThreeSampleTasks() {
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.addTask(title: "Write report")
    }

    // MARK: - Initial state

    func test_tasks_initially_isEmpty() {
        // Arrange
        // sut created in setUp()

        // Act
        let tasks = sut.tasks

        // Assert
        XCTAssertTrue(tasks.isEmpty)
    }

    // MARK: - AC: non-empty title and confirm -> task added as "not completed"

    func test_addTask_withValidTitle_addsTaskToList() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertEqual(sut.tasks.first?.title, "Buy milk")
    }

    func test_addTask_withValidTitle_newTaskIsNotCompleted() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(sut.tasks.first?.isCompleted, false)
    }

    func test_addTask_withValidTitle_returnsTrue() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertTrue(result)
    }

    func test_addTask_withValidTitle_clearsValidationMessage() {
        // Arrange
        sut.addTask(title: "") // populate a validation message first

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertNil(sut.validationMessage)
    }

    func test_addTask_withSurroundingWhitespace_trimsTitleBeforeStoring() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "  Buy milk  ")

        // Assert
        XCTAssertEqual(sut.tasks.first?.title, "Buy milk")
    }

    func test_addTask_calledMultipleTimes_appendsTasksInOrder() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "First task")
        sut.addTask(title: "Second task")

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["First task", "Second task"])
    }

    func test_addTask_calledMultipleTimes_assignsUniqueIdToEachTask() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "First task")
        sut.addTask(title: "Second task")

        // Assert
        XCTAssertNotEqual(sut.tasks[0].id, sut.tasks[1].id)
    }

    // MARK: - AC: confirming an empty title -> no task created, validation message shown

    func test_addTask_withEmptyTitle_doesNotAddTask() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "")

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    func test_addTask_withEmptyTitle_returnsFalse() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "")

        // Assert
        XCTAssertFalse(result)
    }

    func test_addTask_withEmptyTitle_setsValidationMessage() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "")

        // Assert
        XCTAssertNotNil(sut.validationMessage)
    }

    func test_addTask_withWhitespaceOnlyTitle_doesNotAddTask() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "   \n  ")

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
        XCTAssertNotNil(sut.validationMessage)
    }

    // MARK: - AC: title longer than 200 characters -> validation error shown, no task added

    func test_addTask_withTitleExceeding200Characters_doesNotAddTask() {
        // Arrange
        let tooLongTitle = String(repeating: "a", count: 201)

        // Act
        sut.addTask(title: tooLongTitle)

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    func test_addTask_withTitleExceeding200Characters_setsValidationMessage() {
        // Arrange
        let tooLongTitle = String(repeating: "a", count: 201)

        // Act
        sut.addTask(title: tooLongTitle)

        // Assert
        XCTAssertNotNil(sut.validationMessage)
    }

    func test_addTask_withTitleExactly200Characters_addsTask() {
        // Arrange
        let boundaryTitle = String(repeating: "a", count: 200)

        // Act
        let result = sut.addTask(title: boundaryTitle)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.title.count, 200)
    }

    func test_addTask_withTitleOf201Characters_returnsFalse() {
        // Arrange
        let overBoundaryTitle = String(repeating: "a", count: 201)

        // Act
        let result = sut.addTask(title: overBoundaryTitle)

        // Assert
        XCTAssertFalse(result)
    }

    // MARK: - State toggling

    func test_addTask_afterValidationFailure_thenValidTitle_addsTaskAndClearsMessage() {
        // Arrange
        sut.addTask(title: "")
        XCTAssertNotNil(sut.validationMessage) // sanity check on arranged state

        // Act
        let result = sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertNil(sut.validationMessage)
    }

    func test_addTask_withValidTitle_afterPriorSuccess_thenEmptyTitle_keepsPreviousTaskAndSetsMessage() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.addTask(title: "")

        // Assert
        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertNotNil(sut.validationMessage)
    }

    // MARK: - AC: user opens main screen with tasks -> sees all tasks with titles and status

    func test_tasks_withMultipleTasksAdded_exposesEachTasksTitleAndCompletionStatus() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.addTask(title: "Write report")

        // Act
        let tasks = sut.tasks

        // Assert
        XCTAssertEqual(tasks.map(\.title), ["Buy milk", "Walk the dog", "Write report"])
        XCTAssertEqual(tasks.map(\.isCompleted), [false, false, false])
    }

    // MARK: - AC: task list is long -> scrolling loses no items (data-integrity precondition)

    func test_tasks_withLargeNumberOfTasksAdded_retainsAllItemsInCreationOrder() {
        // Arrange
        let expectedTitles = (0..<50).map { "Task \($0)" }
        expectedTitles.forEach { sut.addTask(title: $0) }

        // Act
        let tasks = sut.tasks

        // Assert
        XCTAssertEqual(tasks.count, 50)
        XCTAssertEqual(tasks.map(\.title), expectedTitles)
    }

    // MARK: - AC: task is "not completed" -> tapping it marks it "completed"

    func test_toggleCompletion_onNotCompletedTask_setsIsCompletedTrue() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.toggleCompletion(for: taskID)

        // Assert
        XCTAssertTrue(sut.tasks[0].isCompleted)
    }

    // MARK: - AC: task is "completed" -> tapping it again reverts to "not completed" (toggle behavior)

    func test_toggleCompletion_calledTwiceOnSameTask_revertsIsCompletedToFalse() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.toggleCompletion(for: taskID) // first tap: not completed -> completed
        XCTAssertTrue(sut.tasks[0].isCompleted) // sanity check on arranged state

        // Act
        sut.toggleCompletion(for: taskID) // second tap: completed -> not completed

        // Assert
        XCTAssertFalse(sut.tasks[0].isCompleted)
    }

    // MARK: - toggleCompletion data integrity

    func test_toggleCompletion_doesNotChangeTaskCount() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        let taskID = sut.tasks[0].id

        // Act
        sut.toggleCompletion(for: taskID)

        // Assert
        XCTAssertEqual(sut.tasks.count, 2)
    }

    func test_toggleCompletion_doesNotModifyTaskTitleOrId() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let originalTask = sut.tasks[0]

        // Act
        sut.toggleCompletion(for: originalTask.id)

        // Assert
        XCTAssertEqual(sut.tasks[0].id, originalTask.id)
        XCTAssertEqual(sut.tasks[0].title, originalTask.title)
    }

    // MARK: - AC: list has both completed and not-completed tasks -> each task's status is independent

    func test_toggleCompletion_withMultipleTasks_onlyAffectsTargetedTask() {
        // Arrange
        addThreeSampleTasks()
        let targetID = sut.tasks[1].id

        // Act
        sut.toggleCompletion(for: targetID)

        // Assert
        XCTAssertEqual(sut.tasks.map(\.isCompleted), [false, true, false])
    }

    // MARK: - Notes for Dev-agent: toggling status must not reorder the task in the list

    func test_toggleCompletion_onFirstOfMultipleTasks_preservesListOrder() {
        // Arrange
        addThreeSampleTasks()
        let firstTaskID = sut.tasks[0].id

        // Act
        sut.toggleCompletion(for: firstTaskID)

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog", "Write report"])
    }

    func test_toggleCompletion_onLastOfMultipleTasks_preservesListOrder() {
        // Arrange
        addThreeSampleTasks()
        let lastTaskID = sut.tasks[2].id

        // Act
        sut.toggleCompletion(for: lastTaskID)

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog", "Write report"])
    }

    // MARK: - Edge cases

    func test_toggleCompletion_withUnknownTaskID_doesNotModifyTasks() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let unknownID = UUID()

        // Act
        sut.toggleCompletion(for: unknownID)

        // Assert
        XCTAssertFalse(sut.tasks[0].isCompleted)
        XCTAssertEqual(sut.tasks.count, 1)
    }

    func test_toggleCompletion_onEmptyTaskList_doesNothing() {
        // Arrange
        let unknownID = UUID()

        // Act
        sut.toggleCompletion(for: unknownID)

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - AC: task exists in the list -> delete action removes it; AC: list had only one task -> deleting it empties the list

    // Since KAN-10, deleteTask only soft-deletes (see the KAN-10-tagged tests
    // below); these AC-level tests commit the pending deletion immediately
    // via commitPendingDeletion() to observe the same end state as before.

    func test_deleteTask_onListWithSingleTask_removesTaskAndResultsInEmptyList() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))
        sut.commitPendingDeletion()

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - AC: delete action removes only the targeted task; list order is otherwise preserved

    func test_deleteTask_firstOfMultipleTasks_removesOnlyThatTaskAndPreservesOrder() {
        // Arrange
        addThreeSampleTasks()

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))
        sut.commitPendingDeletion()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Walk the dog", "Write report"])
    }

    func test_deleteTask_middleOfMultipleTasks_removesOnlyThatTaskAndPreservesOrder() {
        // Arrange
        addThreeSampleTasks()

        // Act
        sut.deleteTask(at: IndexSet(integer: 1))
        sut.commitPendingDeletion()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Write report"])
    }

    func test_deleteTask_lastOfMultipleTasks_removesOnlyThatTaskAndPreservesOrder() {
        // Arrange
        addThreeSampleTasks()

        // Act
        sut.deleteTask(at: IndexSet(integer: 2))
        sut.commitPendingDeletion()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog"])
    }

    // MARK: - AC: once committed, deletion is permanent; repeated deletions stay consistent
    // (each subsequent deleteTask call also commits the previous one — see the
    // KAN-10-TC-04 tests below for that behavior in isolation)

    func test_deleteTask_calledSequentially_eventuallyEmptiesTheList() {
        // Arrange
        addThreeSampleTasks()

        // Act
        sut.deleteTask(at: IndexSet(integer: 0)) // removes "Buy milk"
        sut.deleteTask(at: IndexSet(integer: 0)) // removes "Walk the dog" (shifted to index 0), commits "Buy milk"
        sut.deleteTask(at: IndexSet(integer: 0)) // removes "Write report" (shifted to index 0), commits "Walk the dog"
        sut.commitPendingDeletion() // commit "Write report", the last pending one

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - Edge cases

    func test_deleteTask_onEmptyTaskList_withEmptyOffsets_doesNothing() {
        // Arrange
        // sut created in setUp(), no tasks added

        // Act
        sut.deleteTask(at: IndexSet())

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - KAN-8-TC-01: valid non-empty title -> updated title is saved and displayed in the list

    func test_KAN8TC01_updateTitle_withValidTitle_returnsTrue() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        let result = sut.updateTitle(for: taskID, to: "Buy oat milk")

        // Assert
        XCTAssertTrue(result)
    }

    func test_KAN8TC01_updateTitle_withValidTitle_updatesTaskTitleInList() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateTitle(for: taskID, to: "Buy oat milk")

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy oat milk")
    }

    func test_KAN8TC01_updateTitle_withSurroundingWhitespace_trimsTitleBeforeStoring() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateTitle(for: taskID, to: "  Buy oat milk  ")

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy oat milk")
    }

    // MARK: - KAN-8-TC-02: clearing the title entirely -> save is blocked, validation message shown

    func test_KAN8TC02_updateTitle_withEmptyTitle_returnsFalse() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        let result = sut.updateTitle(for: taskID, to: "")

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN8TC02_updateTitle_withEmptyTitle_doesNotChangeTaskTitle() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateTitle(for: taskID, to: "")

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy milk")
    }

    func test_KAN8TC02_updateTitle_withEmptyTitle_setsValidationMessage() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateTitle(for: taskID, to: "")

        // Assert
        XCTAssertNotNil(sut.validationMessage)
    }

    // MARK: - KAN-8-TC-03: exactly 200 characters -> accepted (boundary case)

    func test_KAN8TC03_updateTitle_withTitleExactly200Characters_returnsTrue() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        let boundaryTitle = String(repeating: "a", count: 200)

        // Act
        let result = sut.updateTitle(for: taskID, to: boundaryTitle)

        // Assert
        XCTAssertTrue(result)
    }

    func test_KAN8TC03_updateTitle_withTitleExactly200Characters_updatesTitle() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        let boundaryTitle = String(repeating: "a", count: 200)

        // Act
        sut.updateTitle(for: taskID, to: boundaryTitle)

        // Assert
        XCTAssertEqual(sut.tasks[0].title.count, 200)
    }

    // MARK: - KAN-8-TC-04: 201+ characters -> same length rule as task creation applies (rejected with message)

    func test_KAN8TC04_updateTitle_withTitleOf201Characters_returnsFalse() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        let overBoundaryTitle = String(repeating: "a", count: 201)

        // Act
        let result = sut.updateTitle(for: taskID, to: overBoundaryTitle)

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN8TC04_updateTitle_withTitleOf201Characters_doesNotChangeTaskTitle() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        let overBoundaryTitle = String(repeating: "a", count: 201)

        // Act
        sut.updateTitle(for: taskID, to: overBoundaryTitle)

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy milk")
    }

    func test_KAN8TC04_updateTitle_withTitleOf201Characters_setsValidationMessage() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        let overBoundaryTitle = String(repeating: "a", count: 201)

        // Act
        sut.updateTitle(for: taskID, to: overBoundaryTitle)

        // Assert
        XCTAssertNotNil(sut.validationMessage)
    }

    // MARK: - KAN-8-TC-05: whitespace-only title -> treated as empty, save blocked, validation message shown

    func test_KAN8TC05_updateTitle_withWhitespaceOnlyTitle_returnsFalse() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        let result = sut.updateTitle(for: taskID, to: "   \n  ")

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN8TC05_updateTitle_withWhitespaceOnlyTitle_doesNotChangeTaskTitle() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateTitle(for: taskID, to: "   \n  ")

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy milk")
    }

    func test_KAN8TC05_updateTitle_withWhitespaceOnlyTitle_setsValidationMessage() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateTitle(for: taskID, to: "   \n  ")

        // Assert
        XCTAssertNotNil(sut.validationMessage)
    }

    // MARK: - KAN-8-TC-09: editing a completed task -> title updates correctly, completed status unaffected

    func test_KAN8TC09_updateTitle_onCompletedTask_updatesTitle() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.toggleCompletion(for: taskID)
        XCTAssertTrue(sut.tasks[0].isCompleted) // sanity check on arranged state

        // Act
        sut.updateTitle(for: taskID, to: "Buy oat milk")

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy oat milk")
    }

    func test_KAN8TC09_updateTitle_onCompletedTask_doesNotChangeCompletionStatus() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.toggleCompletion(for: taskID)

        // Act
        sut.updateTitle(for: taskID, to: "Buy oat milk")

        // Assert
        XCTAssertTrue(sut.tasks[0].isCompleted)
    }

    // MARK: - updateTitle: state toggling (mirrors addTask's validation-recovery behavior)

    func test_updateTitle_afterValidationFailure_thenValidTitle_updatesTitleAndClearsMessage() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.updateTitle(for: taskID, to: "")
        XCTAssertNotNil(sut.validationMessage) // sanity check on arranged state

        // Act
        let result = sut.updateTitle(for: taskID, to: "Buy oat milk")

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks[0].title, "Buy oat milk")
        XCTAssertNil(sut.validationMessage)
    }

    // MARK: - updateTitle: multi-task list integrity (implementation detail, not a specific manual case)

    func test_updateTitle_withMultipleTasks_onlyUpdatesTargetedTask() {
        // Arrange
        addThreeSampleTasks()
        let targetID = sut.tasks[1].id

        // Act
        sut.updateTitle(for: targetID, to: "Walk the cat")

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the cat", "Write report"])
    }

    func test_updateTitle_withMultipleTasks_preservesListOrder() {
        // Arrange
        addThreeSampleTasks()
        let lastID = sut.tasks[2].id

        // Act
        sut.updateTitle(for: lastID, to: "Submit report")

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog", "Submit report"])
    }

    // MARK: - updateTitle: edge cases

    func test_updateTitle_withUnknownTaskID_returnsFalse() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let unknownID = UUID()

        // Act
        let result = sut.updateTitle(for: unknownID, to: "New title")

        // Assert
        XCTAssertFalse(result)
    }

    func test_updateTitle_withUnknownTaskID_doesNotModifyTasks() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let unknownID = UUID()

        // Act
        sut.updateTitle(for: unknownID, to: "New title")

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy milk")
    }

    func test_updateTitle_onEmptyTaskList_returnsFalse() {
        // Arrange
        let unknownID = UUID()

        // Act
        let result = sut.updateTitle(for: unknownID, to: "New title")

        // Assert
        XCTAssertFalse(result)
    }
}
