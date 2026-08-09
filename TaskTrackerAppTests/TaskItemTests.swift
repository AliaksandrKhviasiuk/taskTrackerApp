//
//  TaskItemTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

final class TaskItemTests: XCTestCase {

    // MARK: - AC: a task's status is represented as completed/not completed

    func test_init_withoutIsCompletedArgument_defaultsToNotCompleted() {
        // Arrange
        // no setup needed

        // Act
        let task = TaskItem(title: "Buy milk")

        // Assert
        XCTAssertFalse(task.isCompleted)
    }

    func test_init_withIsCompletedTrue_isMarkedCompleted() {
        // Arrange
        // no setup needed

        // Act
        let task = TaskItem(title: "Buy milk", isCompleted: true)

        // Assert
        XCTAssertTrue(task.isCompleted)
    }

    func test_init_storesTitleUnmodified() {
        // Arrange
        // no setup needed

        // Act
        let task = TaskItem(title: "Buy milk")

        // Assert
        XCTAssertEqual(task.title, "Buy milk")
    }

    // MARK: - AC: each task in the list is distinguishable (stable identity for list rendering)

    func test_init_withoutIdArgument_assignsUniqueIdToEachInstance() {
        // Arrange
        // no setup needed

        // Act
        let first = TaskItem(title: "Buy milk")
        let second = TaskItem(title: "Buy milk")

        // Assert
        XCTAssertNotEqual(first.id, second.id)
    }

    // MARK: - Equatable conformance

    func test_equality_withSameIdTitleAndCompletion_areEqual() {
        // Arrange
        let id = UUID()
        let first = TaskItem(id: id, title: "Buy milk", isCompleted: false)

        // Act
        let second = TaskItem(id: id, title: "Buy milk", isCompleted: false)

        // Assert
        XCTAssertEqual(first, second)
    }

    func test_equality_withDifferentCompletionStatus_areNotEqual() {
        // Arrange
        let id = UUID()
        let notCompleted = TaskItem(id: id, title: "Buy milk", isCompleted: false)

        // Act
        let completed = TaskItem(id: id, title: "Buy milk", isCompleted: true)

        // Assert
        XCTAssertNotEqual(notCompleted, completed)
    }
}
