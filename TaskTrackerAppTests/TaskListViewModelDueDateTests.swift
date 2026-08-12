//
//  TaskListViewModelDueDateTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for `TaskListViewModel.addTask(title:dueDate:)`'s new optional
/// `dueDate` parameter (KAN-19). Covers the AC-level behavior (attach a due
/// date, leave it unset, past/today/far-future dates all accepted, title
/// validation is unaffected/unbypassed) plus the start-of-day normalization
/// `addTask` applies before storing.
final class TaskListViewModelDueDateTests: XCTestCase {

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

    // MARK: - KAN-19-TC-01: due date picked before confirming -> task created and saved with that due date

    func test_KAN19TC01_addTask_withDueDate_addsTaskWithThatDueDate() {
        // Arrange
        let pickedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        sut.addTask(title: "Buy milk", dueDate: pickedDate)

        // Assert
        XCTAssertEqual(sut.tasks.first?.dueDate, pickedDate)
    }

    func test_KAN19TC01_addTask_withDueDate_returnsTrue() {
        // Arrange
        let pickedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        let result = sut.addTask(title: "Buy milk", dueDate: pickedDate)

        // Assert
        XCTAssertTrue(result)
    }

    // MARK: - KAN-19-TC-03: due date left unset -> task created successfully with no due date

    func test_KAN19TC03_addTask_withoutDueDateArgument_createsTaskWithNilDueDate() {
        // Arrange
        // sut created in setUp(); addTask's dueDate parameter defaults to nil

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertNil(sut.tasks.first?.dueDate)
    }

    func test_KAN19TC03_addTask_withoutDueDateArgument_returnsTrue() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertTrue(result)
    }

    // MARK: - KAN-19-TC-04: due date picked then cleared before confirming -> same
    // result as never having set one. `hasNewTaskDueDate`/clearing is a
    // ContentView-only concern (see `confirmNewTask()`): by the time the View
    // calls into the ViewModel, "cleared" and "never set" are indistinguishable
    // — both resolve to an explicit `nil` argument. This test documents that
    // the ViewModel's contract for that resolved `nil` is identical to
    // KAN-19-TC-03's "never touched" case.

    func test_KAN19TC04_addTask_withExplicitNilDueDate_createsTaskWithNilDueDateSameAsNeverSet() {
        // Arrange
        // sut created in setUp()

        // Act
        let result = sut.addTask(title: "Buy milk", dueDate: nil)

        // Assert
        XCTAssertTrue(result)
        XCTAssertNil(sut.tasks.first?.dueDate)
    }

    // MARK: - KAN-19-TC-08: due date before today -> task still created successfully, no validation error

    func test_KAN19TC08_addTask_withPastDueDate_addsTaskWithThatDueDateAndNoValidationError() {
        // Arrange
        let pastDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 10))!

        // Act
        let result = sut.addTask(title: "Buy milk", dueDate: pastDate)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.dueDate, pastDate)
        XCTAssertNil(sut.validationMessage)
    }

    // MARK: - KAN-19-TC-09: today's date picked as due date -> created with today's date attached

    func test_KAN19TC09_addTask_withTodayAsDueDate_addsTaskWithTodaysNormalizedDate() {
        // Arrange
        let now = Date() // captured once so input and expectation can't drift across a midnight boundary
        let expectedDueDate = Calendar.current.startOfDay(for: now)

        // Act
        sut.addTask(title: "Buy milk", dueDate: now)

        // Assert
        XCTAssertEqual(sut.tasks.first?.dueDate, expectedDueDate)
    }

    // MARK: - KAN-19-TC-10: due date far in the future -> created successfully with that date

    func test_KAN19TC10_addTask_withFarFutureDueDate_addsTaskWithThatDueDate() {
        // Arrange
        let farFutureDate = Calendar.current.date(from: DateComponents(year: 2099, month: 12, day: 25))!

        // Act
        let result = sut.addTask(title: "Buy milk", dueDate: farFutureDate)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks.first?.dueDate, farFutureDate)
    }

    // MARK: - KAN-19-TC-11: empty/whitespace title with a due date set -> creation
    // still blocked by existing title validation; due date does not bypass it

    func test_KAN19TC11_addTask_withEmptyTitleAndDueDateSet_doesNotAddTaskRegardlessOfDueDate() {
        // Arrange
        let pickedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        let result = sut.addTask(title: "", dueDate: pickedDate)

        // Assert
        XCTAssertFalse(result)
        XCTAssertTrue(sut.tasks.isEmpty)
        XCTAssertNotNil(sut.validationMessage)
    }

    func test_KAN19TC11_addTask_withWhitespaceOnlyTitleAndDueDateSet_doesNotAddTask() {
        // Arrange
        let pickedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        let result = sut.addTask(title: "   \n  ", dueDate: pickedDate)

        // Assert
        XCTAssertFalse(result)
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - Normalization (Notes for Dev-agent / Requirements-analysis-agent
    // Auto-apply #2): whatever time-of-day component the caller's Date carries
    // is stripped before storing, so `dueDate` always represents a calendar day.

    func test_addTask_withDueDateContainingTimeComponent_normalizesToStartOfDay() {
        // Arrange
        let dateWithTime = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 23, minute: 59, second: 59))!
        let expectedNormalizedDate = Calendar.current.startOfDay(for: dateWithTime)

        // Act
        sut.addTask(title: "Buy milk", dueDate: dateWithTime)

        // Assert
        XCTAssertEqual(sut.tasks.first?.dueDate, expectedNormalizedDate)
        XCTAssertNotEqual(sut.tasks.first?.dueDate, dateWithTime, "the raw time-of-day component must not survive storage")
    }

    // MARK: - Persistence: addTask's dueDate participates in what gets saved,
    // like every other task field

    func test_addTask_withDueDate_savesFullUpdatedTaskListIncludingDueDateToStorage() {
        // Arrange
        let pickedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        sut.addTask(title: "Buy milk", dueDate: pickedDate)

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, 1)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.first?.dueDate, pickedDate)
    }

    func test_addTask_withoutDueDate_savesTaskWithNilDueDateToStorage() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertNil(fakeStorage.lastSavedTasks?.first?.dueDate)
    }

    // MARK: - duplicateTask interaction (PR-review-agent non-blocking note):
    // `duplicateTask` routes through `addTask(title:)` only, so a task's due
    // date is not carried over to its duplicate — mirrors the pre-existing
    // behavior of not copying `isCompleted` either. Documented here as
    // current, intentional-looking behavior; flagged for Reviewer-agent since
    // no KAN-19 AC states this either way.

    func test_duplicateTask_ofTaskWithDueDate_doesNotCopyDueDateToDuplicate() {
        // Arrange
        let pickedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: pickedDate)
        let sourceID = sut.tasks[0].id

        // Act
        sut.duplicateTask(id: sourceID)

        // Assert
        XCTAssertEqual(sut.tasks[0].dueDate, pickedDate, "original task's due date must be unaffected")
        XCTAssertNil(sut.tasks[1].dueDate, "duplicate must not inherit the source's due date")
    }
}
