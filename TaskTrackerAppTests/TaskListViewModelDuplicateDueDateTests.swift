//
//  TaskListViewModelDuplicateDueDateTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for KAN-20: `TaskListViewModel.duplicateTask(id:)` forwards
/// `source.dueDate` into `addTask(title:dueDate:)`, so a duplicate now keeps
/// the source task's due date (previously always `nil`, per KAN-14/KAN-19 —
/// see the superseded test in `TaskListViewModelDueDateTests.swift`).
/// `isCompleted` copying is explicitly unchanged/out of scope (KAN-14) and is
/// exercised here only as a fixed expectation alongside the dueDate change,
/// per Manual-QA-agent's TC-03/TC-04.
final class TaskListViewModelDuplicateDueDateTests: XCTestCase {

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

    // MARK: - KAN-20-TC-01 / AC1: task with a due date -> duplicate has the same title and due date

    func test_KAN20TC01_duplicateTask_ofTaskWithDueDate_copiesTitleAndDueDateToDuplicate() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)
        let sourceID = sut.tasks[0].id

        // Act
        let result = sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.count, 2)
        XCTAssertEqual(sut.tasks[1].title, "Buy milk")
        XCTAssertEqual(sut.tasks[1].dueDate, dueDate)
    }

    // MARK: - KAN-20-TC-02 / AC2: task with no due date -> duplicate has no due date (unchanged)

    func test_KAN20TC02_duplicateTask_ofTaskWithNoDueDate_duplicateHasNoDueDate() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertNil(sut.tasks[1].dueDate)
    }

    // MARK: - KAN-20-TC-03 / AC3: task with a due date and isCompleted = true ->
    // duplicate copies the due date but resets isCompleted to false

    func test_KAN20TC03_duplicateTask_ofCompletedTaskWithDueDate_copiesDueDateButDuplicateIsNotCompleted() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)
        let sourceID = sut.tasks[0].id
        sut.toggleCompletion(for: sourceID)
        XCTAssertTrue(sut.tasks[0].isCompleted)

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[1].dueDate, dueDate)
        XCTAssertFalse(sut.tasks[1].isCompleted, "duplicate must never copy the source's completion state, regardless of dueDate")
    }

    // MARK: - KAN-20-TC-04: same as TC-03 but source is not completed, confirming
    // dueDate copying is independent of isCompleted either way

    func test_KAN20TC04_duplicateTask_ofNotCompletedTaskWithDueDate_copiesDueDateAndDuplicateIsNotCompleted() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)
        let sourceID = sut.tasks[0].id
        XCTAssertFalse(sut.tasks[0].isCompleted)

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[1].dueDate, dueDate)
        XCTAssertFalse(sut.tasks[1].isCompleted)
    }

    // MARK: - KAN-20-TC-05: duplicating a task does not mutate the source task
    // itself (title, dueDate, isCompleted all unchanged afterward)

    func test_KAN20TC05_duplicateTask_ofTaskWithDueDate_leavesSourceTaskUnchanged() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)
        let sourceID = sut.tasks[0].id
        sut.toggleCompletion(for: sourceID)
        let sourceBeforeDuplication = sut.tasks[0]

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        let sourceAfterDuplication = sut.tasks.first(where: { $0.id == sourceID })
        XCTAssertEqual(sourceAfterDuplication, sourceBeforeDuplication)
        XCTAssertEqual(sourceAfterDuplication?.title, "Buy milk")
        XCTAssertEqual(sourceAfterDuplication?.dueDate, dueDate)
        XCTAssertTrue(sourceAfterDuplication?.isCompleted ?? false)
    }

    // MARK: - KAN-20-TC-06: due date set to today -> duplicate's due date
    // exactly matches the source's, no off-by-one/shift

    func test_KAN20TC06_duplicateTask_ofTaskDueToday_duplicateDueDateExactlyMatchesSource() {
        // Arrange
        let now = Date() // captured once so source/expectation can't drift across a midnight boundary
        sut.addTask(title: "Buy milk", dueDate: now)
        let sourceID = sut.tasks[0].id
        let sourceDueDate = sut.tasks[0].dueDate

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[1].dueDate, sourceDueDate)
        XCTAssertEqual(sut.tasks[1].dueDate, Calendar.current.startOfDay(for: now))
    }

    // MARK: - KAN-20-TC-07: chained duplication — duplicating a duplicate still
    // carries the original due date through the second hop

    func test_KAN20TC07_duplicateTask_appliedTwiceInChain_secondDuplicateStillHasOriginalDueDate() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID) // Duplicate A
        let duplicateAID = sut.tasks[1].id
        sut.duplicateTask(id: duplicateAID) // Duplicate B, duplicated from A

        // Assert
        XCTAssertEqual(sut.tasks.count, 3)
        XCTAssertEqual(sut.tasks[2].dueDate, dueDate, "due date must propagate through a chained duplication, not just a single hop")
    }

    // MARK: - KAN-20-TC-08: duplicating two independent tasks (one with a due
    // date, one without) does not cross-contaminate either duplication

    func test_KAN20TC08_duplicateTask_onTwoIndependentTasks_eachDuplicateOnlyReflectsItsOwnSource() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Task X", dueDate: dueDate)
        let taskXID = sut.tasks[0].id
        sut.addTask(title: "Task Y")
        let taskYID = sut.tasks[1].id

        // Act
        sut.duplicateTask(id: taskXID)
        sut.duplicateTask(id: taskYID)

        // Assert
        XCTAssertEqual(sut.tasks.count, 4)
        let taskXDuplicate = sut.tasks.first { $0.title == "Task X" && $0.id != taskXID }
        let taskYDuplicate = sut.tasks.first { $0.title == "Task Y" && $0.id != taskYID }
        XCTAssertEqual(taskXDuplicate?.dueDate, dueDate)
        XCTAssertNil(taskYDuplicate?.dueDate)
        // Neither original task was mutated by the other's duplication
        XCTAssertEqual(sut.tasks.first(where: { $0.id == taskXID })?.dueDate, dueDate)
        XCTAssertNil(sut.tasks.first(where: { $0.id == taskYID })?.dueDate)
    }

    // MARK: - Coverage: persistence — the copied due date participates in what
    // gets saved, like every other field `duplicateTask` -> `addTask` persists

    func test_duplicateTask_ofTaskWithDueDate_savesDuplicateWithCopiedDueDateToStorage() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate) // 1st save
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID) // 2nd save

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 2)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.last?.dueDate, dueDate)
    }
}
