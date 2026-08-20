//
//  TaskListViewModelDuplicatePriorityTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for `TaskListViewModel.duplicateTask(id:)` forwarding
/// `source.priority` (KAN-30, extending KAN-20's due-date-forwarding
/// precedent — see `TaskListViewModelDuplicateDueDateTests.swift`). Not
/// requested by KAN-30's AC or "Notes for Dev-agent"; Dev-agent extended it
/// on its own initiative (explicitly flagged in its summary), and
/// PR-review-agent's Pass verdict judged it a reasonable consistency fix
/// rather than scope creep. No Manual-QA-agent test case covers this
/// directly (KAN-30's manual cases only exercise creation and list display),
/// so every test below is coverage-only — none carry a KAN-30-TC- prefix,
/// per Rule 6 (never invent a fake traceability ID).
final class TaskListViewModelDuplicatePriorityTests: XCTestCase {

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

    // MARK: - Source has a priority set -> duplicate inherits it (each of the three fixed values)

    func test_duplicateTask_ofTaskWithEachPriorityValue_copiesThatPriorityToDuplicate() {
        for priority in Priority.allCases {
            // Arrange (fresh SUT per case — a genuinely different initial state, per Rule 4)
            let viewModel = TaskListViewModel(storage: FakeTaskStoring())
            viewModel.addTask(title: "Buy milk", priority: priority)
            let sourceID = viewModel.tasks[0].id

            // Act
            let result = viewModel.duplicateTask(id: sourceID)

            // Assert
            XCTAssertTrue(result, "priority \(priority) case")
            XCTAssertEqual(viewModel.tasks[1].priority, priority, "priority \(priority) case")
        }
    }

    // MARK: - Source has no priority set -> duplicate has no priority either (unchanged)

    func test_duplicateTask_ofTaskWithNoPriority_duplicateHasNoPriority() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertNil(sut.tasks[1].priority)
    }

    // MARK: - Duplicating a task does not mutate the source task's own priority

    func test_duplicateTask_ofTaskWithPriority_leavesSourceTaskPriorityUnchanged() {
        // Arrange
        sut.addTask(title: "Buy milk", priority: .high)
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[0].priority, .high, "original task's priority must be unaffected")
    }

    // MARK: - Composition: priority forwarding doesn't interfere with isCompleted
    // always resetting to false on a duplicate (mirrors KAN-20-TC-03's due-date
    // analog in TaskListViewModelDuplicateDueDateTests.swift)

    func test_duplicateTask_ofCompletedTaskWithPriority_copiesPriorityButDuplicateIsNotCompleted() {
        // Arrange
        sut.addTask(title: "Buy milk", priority: .medium)
        let sourceID = sut.tasks[0].id
        sut.toggleCompletion(for: sourceID)
        XCTAssertTrue(sut.tasks[0].isCompleted)

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[1].priority, .medium)
        XCTAssertFalse(sut.tasks[1].isCompleted, "duplicate must never copy the source's completion state, regardless of priority")
    }

    // MARK: - Composition: priority and dueDate are forwarded together without
    // either interfering with the other now that duplicateTask forwards both

    func test_duplicateTask_ofTaskWithPriorityAndDueDate_copiesBothToDuplicate() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate, priority: .low)
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[1].dueDate, dueDate)
        XCTAssertEqual(sut.tasks[1].priority, .low)
    }

    // MARK: - Chained duplication: duplicating a duplicate still carries the
    // original priority through the second hop (mirrors KAN-20-TC-07's
    // due-date analog)

    func test_duplicateTask_appliedTwiceInChain_secondDuplicateStillHasOriginalPriority() {
        // Arrange
        sut.addTask(title: "Buy milk", priority: .high)
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID) // Duplicate A
        let duplicateAID = sut.tasks[1].id
        sut.duplicateTask(id: duplicateAID) // Duplicate B, duplicated from A

        // Assert
        XCTAssertEqual(sut.tasks.count, 3)
        XCTAssertEqual(sut.tasks[2].priority, .high, "priority must propagate through a chained duplication, not just a single hop")
    }

    // MARK: - No cross-contamination between two independent duplications
    // (mirrors KAN-20-TC-08's due-date analog)

    func test_duplicateTask_onTwoIndependentTasksWithDifferentPriorities_eachDuplicateOnlyReflectsItsOwnSource() {
        // Arrange
        sut.addTask(title: "Task X", priority: .low)
        let taskXID = sut.tasks[0].id
        sut.addTask(title: "Task Y") // no priority
        let taskYID = sut.tasks[1].id

        // Act
        sut.duplicateTask(id: taskXID)
        sut.duplicateTask(id: taskYID)

        // Assert
        XCTAssertEqual(sut.tasks.count, 4)
        let taskXDuplicate = sut.tasks.first { $0.title == "Task X" && $0.id != taskXID }
        let taskYDuplicate = sut.tasks.first { $0.title == "Task Y" && $0.id != taskYID }
        XCTAssertEqual(taskXDuplicate?.priority, .low)
        XCTAssertNil(taskYDuplicate?.priority)
        // Neither original task was mutated by the other's duplication
        XCTAssertEqual(sut.tasks.first(where: { $0.id == taskXID })?.priority, .low)
        XCTAssertNil(sut.tasks.first(where: { $0.id == taskYID })?.priority)
    }

    // MARK: - Persistence: the copied priority participates in what gets
    // saved, like every other field duplicateTask -> addTask persists

    func test_duplicateTask_ofTaskWithPriority_savesDuplicateWithCopiedPriorityToStorage() {
        // Arrange
        sut.addTask(title: "Buy milk", priority: .high) // 1st save
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID) // 2nd save

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 2)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.last?.priority, .high)
    }
}
