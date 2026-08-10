//
//  TaskListViewModelValidationTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for `TaskListViewModel`'s two static validation helpers,
/// `isValidTitle(_:)` and `cappedTitle(_:)` — the single canonical rules
/// KAN-5 consolidated the create/edit flows onto. Both were previously
/// untested directly (only exercised indirectly through the View), a gap
/// flagged repeatedly since KAN-8.
final class TaskListViewModelValidationTests: XCTestCase {

    // MARK: - KAN-5-TC-02 / TC-03: empty title is invalid, identically for
    // the create and edit flows, since both now call the same function

    func test_KAN5TC02_isValidTitle_withEmptyTitle_returnsFalse() {
        // Arrange
        // (no fixture needed — pure function)

        // Act
        let result = TaskListViewModel.isValidTitle("")

        // Assert
        XCTAssertFalse(result)
    }

    func test_isValidTitle_withWhitespaceOnlyTitle_returnsFalse() {
        // Arrange
        // (no fixture needed)

        // Act
        let result = TaskListViewModel.isValidTitle("   \n  ")

        // Assert
        XCTAssertFalse(result)
    }

    func test_isValidTitle_withValidTitle_returnsTrue() {
        // Arrange
        // (no fixture needed)

        // Act
        let result = TaskListViewModel.isValidTitle("Buy milk")

        // Assert
        XCTAssertTrue(result)
    }

    func test_isValidTitle_withSurroundingWhitespace_stillValidIfTrimmedIsNonEmpty() {
        // Arrange
        // (no fixture needed)

        // Act
        let result = TaskListViewModel.isValidTitle("  Buy milk  ")

        // Assert
        XCTAssertTrue(result)
    }

    // MARK: - KAN-5-TC-04: length rule is identical for both flows

    func test_KAN5TC04_isValidTitle_withTitleExactly200Characters_returnsTrue() {
        // Arrange
        let boundaryTitle = String(repeating: "a", count: 200)

        // Act
        let result = TaskListViewModel.isValidTitle(boundaryTitle)

        // Assert
        XCTAssertTrue(result)
    }

    func test_KAN5TC04_isValidTitle_withTitleOf201Characters_returnsFalse() {
        // Arrange
        let overBoundaryTitle = String(repeating: "a", count: 201)

        // Act
        let result = TaskListViewModel.isValidTitle(overBoundaryTitle)

        // Assert
        XCTAssertFalse(result)
    }

    func test_isValidTitle_lengthCheckAppliesAfterTrimming() {
        // Arrange: 200 real characters plus surrounding whitespace that should not count
        let title = "  " + String(repeating: "a", count: 200) + "  "

        // Act
        let result = TaskListViewModel.isValidTitle(title)

        // Assert
        XCTAssertTrue(result)
    }

    // MARK: - KAN-5-TC-04: cappedTitle is the other half of the length rule
    // (the live-capping mechanism the View uses instead of rejection)

    func test_KAN5TC04_cappedTitle_withTitleUnderLimit_returnsUnchanged() {
        // Arrange
        let title = "Buy milk"

        // Act
        let result = TaskListViewModel.cappedTitle(title)

        // Assert
        XCTAssertEqual(result, title)
    }

    func test_KAN5TC04_cappedTitle_withTitleOverLimit_truncatesToLimit() {
        // Arrange
        let overLimitTitle = String(repeating: "a", count: 250)

        // Act
        let result = TaskListViewModel.cappedTitle(overLimitTitle)

        // Assert
        XCTAssertEqual(result.count, 200)
    }

    func test_cappedTitle_withTitleExactlyAtLimit_returnsUnchanged() {
        // Arrange
        let boundaryTitle = String(repeating: "a", count: 200)

        // Act
        let result = TaskListViewModel.cappedTitle(boundaryTitle)

        // Assert
        XCTAssertEqual(result, boundaryTitle)
    }
}
