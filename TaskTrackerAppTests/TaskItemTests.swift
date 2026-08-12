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

    // MARK: - AC: a task can optionally have a due date attached (KAN-19)

    func test_init_withoutDueDateArgument_defaultsToNilDueDate() {
        // Arrange
        // no setup needed

        // Act
        let task = TaskItem(title: "Buy milk")

        // Assert
        XCTAssertNil(task.dueDate)
    }

    func test_init_withDueDateArgument_storesDueDate() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        let task = TaskItem(title: "Buy milk", dueDate: dueDate)

        // Assert
        XCTAssertEqual(task.dueDate, dueDate)
    }

    // MARK: - Codable: dueDate round-trips through encode/decode (KAN-19)

    func test_encodeThenDecode_withDueDateSet_preservesDueDate() throws {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let task = TaskItem(title: "Buy milk", dueDate: dueDate)
        let data = try JSONEncoder().encode(task)

        // Act
        let decoded = try JSONDecoder().decode(TaskItem.self, from: data)

        // Assert
        XCTAssertEqual(decoded.dueDate, dueDate)
    }

    func test_encodeThenDecode_withNilDueDate_preservesNilDueDate() throws {
        // Arrange
        let task = TaskItem(title: "Buy milk")
        let data = try JSONEncoder().encode(task)

        // Act
        let decoded = try JSONDecoder().decode(TaskItem.self, from: data)

        // Assert
        XCTAssertNil(decoded.dueDate)
    }

    // MARK: - Codable: JSON persisted before KAN-19 (no "dueDate" key at all) still
    // decodes successfully, as nil (Requirements-analysis-agent Auto-apply
    // finding #3 / Manual-QA-agent's note for Unit-Tests-agent).

    func test_decode_legacyJSONWithoutDueDateKey_decodesWithNilDueDate() throws {
        // Arrange
        let id = UUID()
        let legacyJSON = """
        {"id":"\(id.uuidString)","title":"Buy milk","isCompleted":false}
        """
        let data = Data(legacyJSON.utf8)

        // Act
        let decoded = try JSONDecoder().decode(TaskItem.self, from: data)

        // Assert
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.title, "Buy milk")
        XCTAssertNil(decoded.dueDate)
    }

    // MARK: - Equatable: dueDate participates in equality (KAN-19)

    func test_equality_withSameDueDate_areEqual() {
        // Arrange
        let id = UUID()
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let first = TaskItem(id: id, title: "Buy milk", dueDate: dueDate)

        // Act
        let second = TaskItem(id: id, title: "Buy milk", dueDate: dueDate)

        // Assert
        XCTAssertEqual(first, second)
    }

    func test_equality_withDifferentDueDate_areNotEqual() {
        // Arrange
        let id = UUID()
        let first = TaskItem(id: id, title: "Buy milk", dueDate: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!)

        // Act
        let second = TaskItem(id: id, title: "Buy milk", dueDate: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 4))!)

        // Assert
        XCTAssertNotEqual(first, second)
    }

    func test_equality_withOneNilAndOneSetDueDate_areNotEqual() {
        // Arrange
        let id = UUID()
        let withoutDueDate = TaskItem(id: id, title: "Buy milk")

        // Act
        let withDueDate = TaskItem(id: id, title: "Buy milk", dueDate: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!)

        // Assert
        XCTAssertNotEqual(withoutDueDate, withDueDate)
    }
}
