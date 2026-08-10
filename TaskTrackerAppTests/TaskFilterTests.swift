//
//  TaskFilterTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskFilterTests: XCTestCase {

    func test_id_forEachCase_equalsRawValue() {
        // Arrange
        let allCases = TaskFilter.allCases

        // Act & Assert
        for filter in allCases {
            XCTAssertEqual(filter.id, filter.rawValue)
        }
    }

    func test_allCases_containsAllThreeFilters() {
        // Arrange
        // (no fixture needed)

        // Act
        let allCases = Set(TaskFilter.allCases)

        // Assert
        XCTAssertEqual(allCases, [.all, .notCompleted, .completed])
    }
}
