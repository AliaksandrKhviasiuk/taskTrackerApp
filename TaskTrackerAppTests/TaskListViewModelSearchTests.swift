//
//  TaskListViewModelSearchTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskListViewModelSearchTests: XCTestCase {

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

    /// "Buy milk" (not completed), "Buy bread" (not completed), "Walk the dog" (completed)
    private func addSearchSampleTasks() {
        sut.addTask(title: "Buy milk")
        sut.addTask(title: "Buy bread")
        sut.addTask(title: "Walk the dog")
        sut.toggleCompletion(for: sut.tasks[2].id)
    }

    // MARK: - KAN-13-TC-01: case-insensitive substring match

    func test_KAN13TC01_filteredTasks_withSearchTextDifferentCase_returnsCaseInsensitiveMatch() {
        // Arrange
        addSearchSampleTasks()

        // Act
        sut.searchText = "MILK"

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), ["Buy milk"])
    }

    // MARK: - KAN-13-TC-02: search term matching multiple titles returns all matches

    func test_KAN13TC02_filteredTasks_withSearchTextMatchingMultipleTitles_returnsAllMatches() {
        // Arrange
        addSearchSampleTasks()

        // Act
        sut.searchText = "buy"

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), ["Buy milk", "Buy bread"])
    }

    // MARK: - KAN-13-TC-03: search term matching nothing returns an empty result,
    // distinguishable from "no tasks yet" (View's job; here we assert the data condition)

    func test_KAN13TC03_filteredTasks_withSearchTextMatchingNothing_isEmpty() {
        // Arrange
        addSearchSampleTasks()

        // Act
        sut.searchText = "xyz"

        // Assert
        XCTAssertTrue(sut.filteredTasks.isEmpty)
        XCTAssertFalse(sut.tasks.isEmpty)
    }

    // MARK: - KAN-13-TC-04: search composes with an active status filter (both must match)

    func test_KAN13TC04_filteredTasks_withSearchTextAndCompletedFilter_returnsOnlyMatchingCompletedTasks() {
        // Arrange
        addSearchSampleTasks()
        sut.filter = .completed

        // Act
        sut.searchText = "walk"

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), ["Walk the dog"])
    }

    // MARK: - KAN-13-TC-05: a title match that fails the active status filter is excluded

    func test_KAN13TC05_filteredTasks_withSearchTextMatchingOnlyCompletedTaskWhileNotCompletedFilterActive_isEmpty() {
        // Arrange
        addSearchSampleTasks()
        sut.filter = .notCompleted

        // Act
        sut.searchText = "walk" // only matches the completed "Walk the dog"

        // Assert
        XCTAssertTrue(sut.filteredTasks.isEmpty)
    }

    // MARK: - KAN-13-TC-06: clearing the search field restores the full (filter-respecting) list

    func test_KAN13TC06_filteredTasks_afterClearingSearchText_returnsFullFilteredList() {
        // Arrange
        addSearchSampleTasks()
        sut.searchText = "milk"
        XCTAssertEqual(sut.filteredTasks.count, 1) // sanity check on arranged state

        // Act
        sut.searchText = ""

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), sut.tasks.map(\.title))
    }

    func test_KAN13TC06_filteredTasks_afterClearingSearchTextWithFilterActive_respectsCurrentFilter() {
        // Arrange
        addSearchSampleTasks()
        sut.filter = .completed
        sut.searchText = "buy" // matches nothing under this filter

        // Act
        sut.searchText = ""

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), ["Walk the dog"])
    }

    // MARK: - KAN-13-TC-07: the status filter still works normally with search text empty
    // (regression coverage for the existing KAN-9 behavior now that filtering composes
    // with search — full filter-picker interaction is View-level, covered manually)

    func test_KAN13TC07_filteredTasks_withSearchTextEmptyAndFilterChanged_behavesLikeKAN9() {
        // Arrange
        addSearchSampleTasks()

        // Act
        sut.filter = .notCompleted

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), ["Buy milk", "Buy bread"])
    }

    // MARK: - KAN-13-TC-08: whitespace-only search text is treated as no search (trimmed),
    // not a literal match against spaces inside titles — see Dev-agent's assumption note

    func test_KAN13TC08_filteredTasks_withWhitespaceOnlySearchText_returnsFullFilteredList() {
        // Arrange
        addSearchSampleTasks()

        // Act
        sut.searchText = "   "

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), sut.tasks.map(\.title))
    }

    func test_KAN13TC08_isSearching_withWhitespaceOnlySearchText_isFalse() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.searchText = "   "

        // Assert
        XCTAssertFalse(sut.isSearching)
    }

    // MARK: - KAN-13-TC-09: a search term exactly equal to a title still matches ("contains" boundary)

    func test_KAN13TC09_filteredTasks_withSearchTextExactlyMatchingATitle_returnsThatTask() {
        // Arrange
        addSearchSampleTasks()

        // Act
        sut.searchText = "Buy milk"

        // Assert
        XCTAssertEqual(sut.filteredTasks.map(\.title), ["Buy milk"])
    }

    // MARK: - isSearching (coverage-only, no direct Manual-QA case)

    func test_isSearching_withNonEmptySearchText_isTrue() {
        // Arrange
        // sut created in setUp()

        // Act
        sut.searchText = "milk"

        // Assert
        XCTAssertTrue(sut.isSearching)
    }

    func test_isSearching_withEmptySearchText_isFalse() {
        // Arrange
        // sut created in setUp(), searchText defaults to ""

        // Act & Assert
        XCTAssertFalse(sut.isSearching)
    }

    // MARK: - deleteTask with search active (implementation detail, not a specific manual
    // case — regression coverage mirroring the filter+delete tests in
    // TaskListViewModelFilteringTests, now that displayedTasks composes with search too)

    func test_deleteTask_withSearchTextActive_deletesCorrectUnderlyingTask() {
        // Arrange
        addSearchSampleTasks() // displayedTasks (search "bread") == ["Buy bread"]
        sut.searchText = "bread"

        // Act
        sut.deleteTask(at: IndexSet(integer: 0))
        sut.commitPendingDeletion()

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Buy milk", "Walk the dog"])
    }
}
