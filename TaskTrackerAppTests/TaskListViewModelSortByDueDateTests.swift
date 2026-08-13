//
//  TaskListViewModelSortByDueDateTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for `TaskListViewModel.isSortedByDueDate` / `sortedTasks` (KAN-24) —
/// the third independent axis alongside `filter` (KAN-9) and `searchText`
/// (KAN-13). Mirrors the composition-testing pattern established by
/// `TaskListViewModelFilteringTests` (filter alone, filter + delete) and
/// `TaskListViewModelSearchTests` (search alone, search + filter): here we
/// cover sort alone, then sort composing with filter, with search, and with
/// both together, plus the tie-break/no-due-date-last comparator behavior
/// flagged by Manual-QA-agent's Note for Unit-Tests-agent.
///
/// `displayedTasks` now reads from `sortedTasks` (previously `filteredTasks`)
/// before hiding pending deletions, so a couple of tests exercise that
/// pipeline directly rather than only `sortedTasks` in isolation.
final class TaskListViewModelSortByDueDateTests: XCTestCase {

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

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - KAN-24-TC-01: enabling sort reorders soonest-first, no-due-date last

    func test_KAN24TC01_sortedTasks_afterEnablingSort_ordersBySoonestDueDateFirstWithNoDueDateLast() {
        // Arrange
        sut.addTask(title: "No due date task")
        sut.addTask(title: "Due later", dueDate: date(2026, 9, 20))
        sut.addTask(title: "Due soonest", dueDate: date(2026, 9, 1))
        sut.addTask(title: "Due middle", dueDate: date(2026, 9, 10))
        XCTAssertFalse(sut.isSortedByDueDate) // sanity check: sort starts disabled

        // Act
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(
            sut.sortedTasks.map(\.title),
            ["Due soonest", "Due middle", "Due later", "No due date task"]
        )
    }

    // MARK: - KAN-24-TC-02: every task has a due date -> full list ordered soonest-to-latest

    func test_KAN24TC02_sortedTasks_withAllTasksHavingDueDates_ordersFullListAscending() {
        // Arrange
        sut.addTask(title: "C", dueDate: date(2026, 9, 15))
        sut.addTask(title: "A", dueDate: date(2026, 9, 1))
        sut.addTask(title: "B", dueDate: date(2026, 9, 10))

        // Act
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["A", "B", "C"])
    }

    // MARK: - KAN-24-TC-03: no task has a due date -> stable/deterministic order (creation order)

    func test_KAN24TC03_sortedTasks_withNoTasksHavingDueDate_preservesCreationOrder() {
        // Arrange
        sut.addTask(title: "First")
        sut.addTask(title: "Second")
        sut.addTask(title: "Third")

        // Act
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["First", "Second", "Third"])
    }

    // MARK: - KAN-24-TC-04: sort on an empty task list -> stays empty, no crash

    func test_KAN24TC04_sortedTasks_withEmptyTaskList_isEmpty() {
        // Arrange
        // sut created empty in setUp()

        // Act
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertTrue(sut.sortedTasks.isEmpty)
    }

    // MARK: - KAN-24-TC-05: sort on a single-task list -> displayed with no error

    func test_KAN24TC05_sortedTasks_withSingleTask_returnsThatTask() {
        // Arrange
        sut.addTask(title: "Only task", dueDate: date(2026, 9, 1))

        // Act
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["Only task"])
    }

    // MARK: - KAN-24-TC-06: sort + status filter -> sorts only the filtered subset

    func test_KAN24TC06_sortedTasks_withNotCompletedFilterActive_sortsOnlyFilteredSubset() {
        // Arrange
        sut.addTask(title: "Not completed, later", dueDate: date(2026, 9, 20))
        sut.addTask(title: "Completed, soonest", dueDate: date(2026, 9, 1))
        sut.addTask(title: "Not completed, soonest", dueDate: date(2026, 9, 5))
        sut.toggleCompletion(for: sut.tasks[1].id) // "Completed, soonest"

        // Act
        sut.filter = .notCompleted
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(
            sut.sortedTasks.map(\.title),
            ["Not completed, soonest", "Not completed, later"]
        )
    }

    // MARK: - KAN-24-TC-07: sort + search text -> sorts only the matching subset

    func test_KAN24TC07_sortedTasks_withSearchTextActive_sortsOnlyMatchingSubset() {
        // Arrange
        sut.addTask(title: "Buy milk", dueDate: date(2026, 9, 20))
        sut.addTask(title: "Walk the dog", dueDate: date(2026, 9, 1))
        sut.addTask(title: "Buy bread", dueDate: date(2026, 9, 5))

        // Act
        sut.searchText = "buy"
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["Buy bread", "Buy milk"])
    }

    // MARK: - KAN-24-TC-08: sort + filter + search together -> sorts the subset satisfying both

    func test_KAN24TC08_sortedTasks_withFilterAndSearchActive_sortsSubsetSatisfyingBoth() {
        // Arrange
        sut.addTask(title: "Buy milk", dueDate: date(2026, 9, 20))  // not completed, matches search
        sut.addTask(title: "Buy bread", dueDate: date(2026, 9, 1))  // will be completed, matches search
        sut.addTask(title: "Buy eggs", dueDate: date(2026, 9, 10))  // not completed, matches search
        sut.addTask(title: "Walk the dog", dueDate: date(2026, 9, 2)) // not completed, doesn't match search
        sut.toggleCompletion(for: sut.tasks[1].id) // "Buy bread" -> completed

        // Act
        sut.filter = .notCompleted
        sut.searchText = "buy"
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["Buy eggs", "Buy milk"])
    }

    // MARK: - KAN-24-TC-09: sort left off (default) -> today's existing creation order, unchanged

    func test_KAN24TC09_sortedTasks_withSortDisabled_matchesCreationOrder() {
        // Arrange
        sut.addTask(title: "Third", dueDate: date(2026, 9, 1))
        sut.addTask(title: "First", dueDate: date(2026, 9, 20))
        sut.addTask(title: "Second", dueDate: date(2026, 9, 10))

        // Act
        // isSortedByDueDate defaults to false

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["Third", "First", "Second"])
        XCTAssertEqual(sut.sortedTasks, sut.filteredTasks)
    }

    // MARK: - KAN-24-TC-10: fresh app launch, sort untouched -> defaults off, creation order

    func test_KAN24TC10_isSortedByDueDate_initialValue_isFalse() {
        // Arrange
        // sut created in setUp()

        // Act & Assert
        XCTAssertFalse(sut.isSortedByDueDate)
    }

    func test_KAN24TC10_sortedTasks_onFreshLaunch_returnsCreationOrder() {
        // Arrange
        sut.addTask(title: "Alpha")
        sut.addTask(title: "Beta")

        // Act & Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["Alpha", "Beta"])
    }

    // MARK: - KAN-24-TC-11: disabling sort after it was on reverts to the original creation order

    func test_KAN24TC11_sortedTasks_afterDisablingSortOnceEnabled_revertsToCreationOrder() {
        // Arrange
        sut.addTask(title: "Third", dueDate: date(2026, 9, 1))
        sut.addTask(title: "First", dueDate: date(2026, 9, 20))
        sut.addTask(title: "Second", dueDate: date(2026, 9, 10))
        let creationOrder = sut.tasks.map(\.title)

        sut.isSortedByDueDate = true
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["Third", "Second", "First"]) // sanity check on sorted state

        // Act
        sut.isSortedByDueDate = false

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), creationOrder)
    }

    // MARK: - KAN-24-TC-12: two tasks sharing a due date keep a deterministic relative order across a toggle

    func test_KAN24TC12_sortedTasks_withTwoTasksSharingDueDate_preservesCreationOrderAcrossToggle() {
        // Arrange
        sut.addTask(title: "Tied A", dueDate: date(2026, 9, 10))
        sut.addTask(title: "Tied B", dueDate: date(2026, 9, 10))

        // Act
        sut.isSortedByDueDate = true
        let firstSortResult = sut.sortedTasks.map(\.title)

        sut.isSortedByDueDate = false
        sut.isSortedByDueDate = true
        let secondSortResult = sut.sortedTasks.map(\.title)

        // Assert
        XCTAssertEqual(firstSortResult, ["Tied A", "Tied B"])
        XCTAssertEqual(secondSortResult, firstSortResult)
    }

    // MARK: - KAN-24-TC-13: three or more tied tasks -> deterministic, consistent with creation order

    func test_KAN24TC13_sortedTasks_withThreeTasksSharingDueDate_preservesCreationOrderAmongTies() {
        // Arrange
        sut.addTask(title: "Tied A", dueDate: date(2026, 9, 10))
        sut.addTask(title: "Tied B", dueDate: date(2026, 9, 10))
        sut.addTask(title: "Tied C", dueDate: date(2026, 9, 10))

        // Act
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["Tied A", "Tied B", "Tied C"])
    }

    // MARK: - KAN-24-TC-14: multiple no-due-date tasks -> grouped at the end, deterministic among themselves

    func test_KAN24TC14_sortedTasks_withMultipleNoDueDateTasks_groupsAtEndPreservingCreationOrder() {
        // Arrange
        sut.addTask(title: "No date A")
        sut.addTask(title: "Has date", dueDate: date(2026, 9, 5))
        sut.addTask(title: "No date B")

        // Act
        sut.isSortedByDueDate = true

        // Assert
        XCTAssertEqual(sut.sortedTasks.map(\.title), ["Has date", "No date A", "No date B"])
    }

    // MARK: - KAN-24-TC-15: toggling sort off/on repeatedly never changes the tie-break order

    func test_KAN24TC15_sortedTasks_afterTogglingSortRepeatedly_tieBreakOrderStaysConsistent() {
        // Arrange
        sut.addTask(title: "Tied A", dueDate: date(2026, 9, 10))
        sut.addTask(title: "Tied B", dueDate: date(2026, 9, 10))
        sut.addTask(title: "Tied C", dueDate: date(2026, 9, 10))
        let expectedOrder = ["Tied A", "Tied B", "Tied C"]

        // Act & Assert
        for _ in 0..<4 {
            sut.isSortedByDueDate = true
            XCTAssertEqual(sut.sortedTasks.map(\.title), expectedOrder)
            sut.isSortedByDueDate = false
        }
    }

    // MARK: - displayedTasks composition (coverage-only, no Manual-QA case): sortedTasks -> hide
    // pending deletions pipeline order is preserved now that displayedTasks reads from sortedTasks

    func test_displayedTasks_withSortEnabledAndPendingDeletion_excludesDeletedTaskFromSortedOrder() {
        // Arrange
        sut.addTask(title: "Due later", dueDate: date(2026, 9, 20))
        sut.addTask(title: "Due soonest", dueDate: date(2026, 9, 1))
        sut.isSortedByDueDate = true
        XCTAssertEqual(sut.displayedTasks.map(\.title), ["Due soonest", "Due later"]) // sanity check
        let soonestID = sut.tasks.first { $0.title == "Due soonest" }!.id

        // Act
        sut.deleteTask(at: IndexSet(integer: 0)) // offset 0 in the displayed (sorted) list == "Due soonest"

        // Assert
        XCTAssertEqual(sut.displayedTasks.map(\.title), ["Due later"])
        XCTAssertTrue(sut.pendingDeletionTaskIDs.contains(soonestID))
    }

    // MARK: - Non-reorder-on-mutation (coverage-only, no Manual-QA case): mirrors the KAN-9/KAN-13
    // precedent that display-order derivations never mutate the underlying `tasks` array

    func test_sortedTasks_withSortEnabled_doesNotMutateUnderlyingTasksOrder() {
        // Arrange
        sut.addTask(title: "Third", dueDate: date(2026, 9, 1))
        sut.addTask(title: "First", dueDate: date(2026, 9, 20))
        sut.addTask(title: "Second", dueDate: date(2026, 9, 10))
        let expectedUnderlyingOrder = sut.tasks.map(\.title)

        // Act
        sut.isSortedByDueDate = true
        _ = sut.sortedTasks

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), expectedUnderlyingOrder)
    }
}
