//
//  TaskListViewModelFilteringTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskListViewModelFilteringTests: XCTestCase {

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

    /// "Buy milk" (not completed), "Walk the dog" (completed), "Write report" (not completed)
    private func addMixedSampleTasks() {
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.addTask(title: "Write report")
        sut.toggleCompletion(for: sut.tasks[1].id)
    }

    // MARK: - KAN-9-TC-05: default filter on launch is "All"

    func test_KAN9TC05_filter_initialValue_isAll() {
        // Arrange
        // sut created in setUp()

        // Act
        let filter = sut.filter

        // Assert
        XCTAssertEqual(filter, .all)
    }

    func test_KAN9TC05_filteredTasks_withDefaultFilter_returnsAllTasks() {
        // Arrange
        addMixedSampleTasks()

        // Act
        let filteredTasks = sut.filteredTasks

        // Assert
        XCTAssertEqual(filteredTasks.map(\.title), sut.tasks.map(\.title))
    }

    // MARK: - KAN-9-TC-01: "Not Completed" filter shows only not-completed tasks

    func test_KAN9TC01_filteredTasks_withNotCompletedFilter_excludesCompletedTasks() {
        // Arrange
        addMixedSampleTasks()

        // Act
        sut.filter = .notCompleted
        let filteredTasks = sut.filteredTasks

        // Assert
        XCTAssertEqual(filteredTasks.map(\.title), ["Buy milk", "Write report"])
    }

    func test_KAN9TC01_filteredTasks_withNotCompletedFilter_containsOnlyNotCompletedTasks() {
        // Arrange
        addMixedSampleTasks()

        // Act
        sut.filter = .notCompleted

        // Assert
        XCTAssertTrue(sut.filteredTasks.allSatisfy { !$0.isCompleted })
    }

    // MARK: - KAN-9-TC-02: "Completed" filter shows only completed tasks

    func test_KAN9TC02_filteredTasks_withCompletedFilter_excludesNotCompletedTasks() {
        // Arrange
        addMixedSampleTasks()

        // Act
        sut.filter = .completed
        let filteredTasks = sut.filteredTasks

        // Assert
        XCTAssertEqual(filteredTasks.map(\.title), ["Walk the dog"])
    }

    func test_KAN9TC02_filteredTasks_withCompletedFilter_containsOnlyCompletedTasks() {
        // Arrange
        addMixedSampleTasks()

        // Act
        sut.filter = .completed

        // Assert
        XCTAssertTrue(sut.filteredTasks.allSatisfy(\.isCompleted))
    }

    // MARK: - KAN-9-TC-03 (partial — data condition only, not the empty-state UI text):
    // "Completed" filter with no completed tasks -> filtered result is empty, but the
    // underlying list is not, which is what the View uses to pick the distinct empty state.

    func test_KAN9TC03_filteredTasks_withCompletedFilterAndNoCompletedTasks_isEmpty() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        // (neither task completed)

        // Act
        sut.filter = .completed

        // Assert
        XCTAssertTrue(sut.filteredTasks.isEmpty)
        XCTAssertFalse(sut.tasks.isEmpty) // distinguishes "no matches" from "no tasks yet"
    }

    // MARK: - KAN-9-TC-04 (partial — data condition only, not the empty-state UI text):
    // "Not Completed" filter with everything completed -> filtered result is empty, but the
    // underlying list is not.

    func test_KAN9TC04_filteredTasks_withNotCompletedFilterAndEverythingCompleted_isEmpty() {
        // Arrange
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Walk the dog")
        sut.toggleCompletion(for: sut.tasks[0].id)
        sut.toggleCompletion(for: sut.tasks[1].id)

        // Act
        sut.filter = .notCompleted

        // Assert
        XCTAssertTrue(sut.filteredTasks.isEmpty)
        XCTAssertFalse(sut.tasks.isEmpty)
    }

    // MARK: - KAN-9-TC-06: switching back to "All" shows every task again

    func test_KAN9TC06_filteredTasks_afterSwitchingBackToAll_returnsAllTasks() {
        // Arrange
        addMixedSampleTasks()
        sut.filter = .completed
        XCTAssertEqual(sut.filteredTasks.count, 1) // sanity check on arranged state

        // Act
        sut.filter = .all

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), sut.tasks.map(\.title))
    }

    // MARK: - KAN-9-TC-07: toggling completion while a filter is active updates the
    // filtered view without disturbing the underlying list

    func test_KAN9TC07_toggleCompletion_whileNotCompletedFilterActive_removesTaskFromFilteredView() {
        // Arrange
        addMixedSampleTasks()
        sut.filter = .notCompleted
        let taskID = sut.tasks[0].id // "Buy milk", currently not completed
        XCTAssertTrue(sut.filteredTasks.contains { $0.id == taskID }) // sanity check on arranged state

        // Act
        sut.toggleCompletion(for: taskID)

        // Assert
        XCTAssertFalse(sut.filteredTasks.contains { $0.id == taskID })
    }

    func test_KAN9TC07_toggleCompletion_whileFilterActive_doesNotReorderUnderlyingTasks() {
        // Arrange
        addMixedSampleTasks()
        sut.filter = .notCompleted
        let taskID = sut.tasks[0].id
        let expectedOrder = sut.tasks.map(\.title)

        // Act
        sut.toggleCompletion(for: taskID)

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), expectedOrder)
    }

    // MARK: - KAN-9-TC-08: repeatedly switching filters never reorders or mutates the underlying task list

    func test_KAN9TC08_switchingFiltersRepeatedly_doesNotReorderUnderlyingTasks() {
        // Arrange
        addMixedSampleTasks()
        let expectedOrder = sut.tasks.map(\.title)

        // Act
        sut.filter = .completed
        _ = sut.filteredTasks
        sut.filter = .notCompleted
        _ = sut.filteredTasks
        sut.filter = .all
        _ = sut.filteredTasks

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), expectedOrder)
    }

    func test_KAN9TC08_switchingFiltersRepeatedly_doesNotChangeTaskCount() {
        // Arrange
        addMixedSampleTasks()
        let expectedCount = sut.tasks.count

        // Act
        sut.filter = .completed
        sut.filter = .notCompleted
        sut.filter = .all

        // Assert
        XCTAssertEqual(sut.tasks.count, expectedCount)
    }

    // MARK: - deleteTask with a filter active (implementation detail, not a specific manual
    // case — regression coverage for the offset-translation fix introduced by this story)

    func test_deleteTask_withNotCompletedFilterActive_deletesCorrectUnderlyingTask() {
        // Arrange
        addMixedSampleTasks() // filteredTasks (Not Completed) == ["Buy milk", "Write report"]
        sut.filter = .notCompleted

        // Act
        sut.deleteTask(at: IndexSet(integer: 1)) // offset 1 in the filtered list == "Write report"

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog"])
    }

    func test_deleteTask_withCompletedFilterActive_deletesCorrectUnderlyingTask() {
        // Arrange
        addMixedSampleTasks() // filteredTasks (Completed) == ["Walk the dog"]
        sut.filter = .completed

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Write report"])
    }

    func test_deleteTask_withFilterActive_preservesOrderOfRemainingUnderlyingTasks() {
        // Arrange
        addMixedSampleTasks()
        sut.filter = .notCompleted

        // Act
        sut.deleteTask(at: IndexSet(integer: 0)) // removes "Buy milk" via the filtered view

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Walk the dog", "Write report"])
    }
}
