//
//  TaskListViewModelDuplicateTagTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for `TaskListViewModel.duplicateTask(id:)` forwarding `source.tag`
/// (KAN-33, extending KAN-20's due-date-forwarding and KAN-30's
/// priority-forwarding precedents — see
/// `TaskListViewModelDuplicateDueDateTests.swift` /
/// `TaskListViewModelDuplicatePriorityTests.swift`). Not requested by
/// KAN-33's AC or "Notes for Dev-agent"; Dev-agent extended it on its own
/// initiative (consistent with the established KAN-20/KAN-30 pattern), and
/// PR-review-agent's Pass verdict judged it a reasonable consistency fix
/// rather than scope creep. No Manual-QA-agent test case covers this
/// directly (KAN-33's manual cases only exercise creation, list display, and
/// input normalization), so every test below is coverage-only — none carry
/// a KAN-33-TC- prefix, per Rule 6 (never invent a fake traceability ID).
final class TaskListViewModelDuplicateTagTests: XCTestCase {

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

    // MARK: - Source has a tag set -> duplicate inherits it

    func test_duplicateTask_ofTaskWithTag_copiesTagToDuplicate() {
        // Arrange
        sut.addTask(title: "Buy milk", tag: "Groceries")
        let sourceID = sut.tasks[0].id

        // Act
        let result = sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks[1].tag, "Groceries")
    }

    // MARK: - Source has no tag set -> duplicate has no tag either (unchanged)

    func test_duplicateTask_ofTaskWithNoTag_duplicateHasNoTag() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertNil(sut.tasks[1].tag)
    }

    // MARK: - Duplicating a task does not mutate the source task's own tag

    func test_duplicateTask_ofTaskWithTag_leavesSourceTaskTagUnchanged() {
        // Arrange
        sut.addTask(title: "Buy milk", tag: "Groceries")
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[0].tag, "Groceries", "original task's tag must be unaffected")
    }

    // MARK: - Composition: tag forwarding doesn't interfere with isCompleted
    // always resetting to false on a duplicate (mirrors KAN-20-TC-03/KAN-30's
    // due-date/priority analogs)

    func test_duplicateTask_ofCompletedTaskWithTag_copiesTagButDuplicateIsNotCompleted() {
        // Arrange
        sut.addTask(title: "Buy milk", tag: "Groceries")
        let sourceID = sut.tasks[0].id
        sut.toggleCompletion(for: sourceID)
        XCTAssertTrue(sut.tasks[0].isCompleted)

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[1].tag, "Groceries")
        XCTAssertFalse(sut.tasks[1].isCompleted, "duplicate must never copy the source's completion state, regardless of tag")
    }

    // MARK: - Composition: tag, dueDate and priority are all forwarded
    // together without any interfering with the others now that
    // duplicateTask forwards all three

    func test_duplicateTask_ofTaskWithTagDueDateAndPriority_copiesAllThreeToDuplicate() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate, priority: .low, tag: "Errands")
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[1].dueDate, dueDate)
        XCTAssertEqual(sut.tasks[1].priority, .low)
        XCTAssertEqual(sut.tasks[1].tag, "Errands")
    }

    // MARK: - Chained duplication: duplicating a duplicate still carries the
    // original tag through the second hop (mirrors KAN-20-TC-07's due-date
    // analog)

    func test_duplicateTask_appliedTwiceInChain_secondDuplicateStillHasOriginalTag() {
        // Arrange
        sut.addTask(title: "Buy milk", tag: "Groceries")
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID) // Duplicate A
        let duplicateAID = sut.tasks[1].id
        sut.duplicateTask(id: duplicateAID) // Duplicate B, duplicated from A

        // Assert
        XCTAssertEqual(sut.tasks.count, 3)
        XCTAssertEqual(sut.tasks[2].tag, "Groceries", "tag must propagate through a chained duplication, not just a single hop")
    }

    // MARK: - No cross-contamination between two independent duplications
    // (mirrors KAN-20-TC-08's due-date analog)

    func test_duplicateTask_onTwoIndependentTasksWithDifferentTags_eachDuplicateOnlyReflectsItsOwnSource() {
        // Arrange
        sut.addTask(title: "Task X", tag: "Work")
        let taskXID = sut.tasks[0].id
        sut.addTask(title: "Task Y") // no tag
        let taskYID = sut.tasks[1].id

        // Act
        sut.duplicateTask(id: taskXID)
        sut.duplicateTask(id: taskYID)

        // Assert
        XCTAssertEqual(sut.tasks.count, 4)
        let taskXDuplicate = sut.tasks.first { $0.title == "Task X" && $0.id != taskXID }
        let taskYDuplicate = sut.tasks.first { $0.title == "Task Y" && $0.id != taskYID }
        XCTAssertEqual(taskXDuplicate?.tag, "Work")
        XCTAssertNil(taskYDuplicate?.tag)
        // Neither original task was mutated by the other's duplication
        XCTAssertEqual(sut.tasks.first(where: { $0.id == taskXID })?.tag, "Work")
        XCTAssertNil(sut.tasks.first(where: { $0.id == taskYID })?.tag)
    }

    // MARK: - Persistence: the copied tag participates in what gets saved,
    // like every other field duplicateTask -> addTask persists

    func test_duplicateTask_ofTaskWithTag_savesDuplicateWithCopiedTagToStorage() {
        // Arrange
        sut.addTask(title: "Buy milk", tag: "Groceries") // 1st save
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID) // 2nd save

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 2)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.last?.tag, "Groceries")
    }
}
