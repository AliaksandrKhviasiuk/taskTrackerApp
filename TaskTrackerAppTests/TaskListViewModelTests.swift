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

    func test_deleteTask_onListWithSingleTask_removesTaskAndResultsInEmptyList() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - AC: delete action removes only the targeted task; list order is otherwise preserved

    func test_deleteTask_firstOfMultipleTasks_removesOnlyThatTaskAndPreservesOrder() {
        // Arrange
        addThreeSampleTasks()

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Walk the dog", "Write report"])
    }

    func test_deleteTask_middleOfMultipleTasks_removesOnlyThatTaskAndPreservesOrder() {
        // Arrange
        addThreeSampleTasks()

        // Act
        sut.deleteTask(at: IndexSet(integer: 1))

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Write report"])
    }

    func test_deleteTask_lastOfMultipleTasks_removesOnlyThatTaskAndPreservesOrder() {
        // Arrange
        addThreeSampleTasks()

        // Act
        sut.deleteTask(at: IndexSet(integer: 2))

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog"])
    }

    // MARK: - AC: deletion is confirmed permanently -> no undo; repeated deletions stay consistent

    func test_deleteTask_calledSequentially_eventuallyEmptiesTheList() {
        // Arrange
        addThreeSampleTasks()

        // Act
        sut.deleteTask(at: IndexSet(integer: 0)) // removes "Buy milk"
        sut.deleteTask(at: IndexSet(integer: 0)) // removes "Walk the dog" (shifted to index 0)
        sut.deleteTask(at: IndexSet(integer: 0)) // removes "Write report" (shifted to index 0)

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
}
