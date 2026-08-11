//
//  TaskListViewModelRevealHiddenTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskListViewModelRevealHiddenTests: XCTestCase {

    private var sut: TaskListViewModel!
    private var fakeFilterStorage: FakeFilterStoring!

    override func setUp() {
        super.setUp()
        fakeFilterStorage = FakeFilterStoring()
        sut = TaskListViewModel(filterStorage: fakeFilterStorage)
    }

    override func tearDown() {
        sut = nil
        fakeFilterStorage = nil
        super.tearDown()
    }

    // MARK: - KAN-15-TC-01: filter alone hides a newly-added task

    func test_KAN15TC01_addTask_withCompletedFilterActive_resetsFilterToAllAndRevealsNewTask() {
        // Arrange
        sut.filter = .completed

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(sut.filter, .all)
        XCTAssertTrue(sut.displayedTasks.contains { $0.title == "Buy milk" })
    }

    // MARK: - KAN-15-TC-02: search text alone hides a newly-added task

    func test_KAN15TC02_addTask_withNonMatchingSearchTextActive_clearsSearchTextAndRevealsNewTask() {
        // Arrange
        sut.searchText = "groceries"

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(sut.searchText, "")
        XCTAssertTrue(sut.displayedTasks.contains { $0.title == "Buy milk" })
    }

    // MARK: - KAN-15-TC-03: filter AND search text both hide the new task at once

    func test_KAN15TC03_addTask_withBothCompletedFilterAndNonMatchingSearchActive_resetsBoth() {
        // Arrange
        sut.filter = .completed
        sut.searchText = "groceries"

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(sut.filter, .all)
        XCTAssertEqual(sut.searchText, "")
        XCTAssertTrue(sut.displayedTasks.contains { $0.title == "Buy milk" })
    }

    // MARK: - KAN-15-TC-04: editing a visible task so its new title no longer
    // matches active search text clears the search text

    func test_KAN15TC04_updateTitle_makingTitleNoLongerMatchSearchText_clearsSearchTextAndKeepsTaskVisible() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.searchText = "milk"
        XCTAssertTrue(sut.displayedTasks.contains { $0.id == taskID }, "sanity: visible before the edit")

        // Act
        sut.updateTitle(for: taskID, to: "Buy groceries")

        // Assert
        XCTAssertEqual(sut.searchText, "")
        XCTAssertTrue(sut.displayedTasks.contains { $0.id == taskID })
    }

    // MARK: - KAN-15-TC-05: filter that never hides a not-completed task is left alone

    func test_KAN15TC05_addTask_withNotCompletedFilterActive_doesNotResetFilter() {
        // Arrange
        sut.filter = .notCompleted

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(sut.filter, .notCompleted)
    }

    // MARK: - KAN-15-TC-06: trivial no-op — neither filter nor search need resetting

    func test_KAN15TC06_addTask_withAllFilterAndNoSearchText_leavesBothUnchanged() {
        // Arrange
        sut.filter = .all
        sut.searchText = ""

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(sut.filter, .all)
        XCTAssertEqual(sut.searchText, "")
    }

    // MARK: - KAN-15-TC-07: search text that still matches after the edit is left untouched

    func test_KAN15TC07_updateTitle_withSearchTextStillMatchingAfterEdit_doesNotClearSearchText() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.searchText = "buy"

        // Act
        sut.updateTitle(for: taskID, to: "Buy groceries")

        // Assert
        XCTAssertEqual(sut.searchText, "buy")
        XCTAssertTrue(sut.displayedTasks.contains { $0.id == taskID })
    }

    // MARK: - Coverage: the auto-reset filter change is itself persisted, like any other

    func test_addTask_whenResettingFilterToRevealNewTask_persistsTheResetViaFilterStorage() {
        // Arrange
        sut.filter = .completed

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(fakeFilterStorage.savedFilters.last, .all)
    }

    // MARK: - Coverage: a completed task hidden by the "Not Completed" filter is
    // untouched by an unrelated add elsewhere (no over-eager reset)

    func test_addTask_withNotCompletedFilterActive_doesNotAffectAnUnrelatedAlreadyHiddenCompletedTask() {
        // Arrange
        sut.addTask(title: "Old completed task")
        sut.toggleCompletion(for: sut.tasks[0].id)
        sut.filter = .notCompleted
        XCTAssertFalse(sut.displayedTasks.contains { $0.title == "Old completed task" }, "sanity: hidden by the filter before the new add")

        // Act
        sut.addTask(title: "Buy milk")

        // Assert
        XCTAssertEqual(sut.filter, .notCompleted, "an unrelated pre-existing hidden task must not force a filter reset")
        XCTAssertFalse(sut.displayedTasks.contains { $0.title == "Old completed task" })
    }
}
