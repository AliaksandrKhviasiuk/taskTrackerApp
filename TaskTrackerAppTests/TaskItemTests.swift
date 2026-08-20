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

    // MARK: - AC: a task can optionally have a priority attached (KAN-30)

    func test_init_withoutPriorityArgument_defaultsToNilPriority() {
        // Arrange
        // no setup needed

        // Act
        let task = TaskItem(title: "Buy milk")

        // Assert
        XCTAssertNil(task.priority)
    }

    func test_init_withPriorityArgument_storesPriority() {
        // Arrange
        // no setup needed

        // Act
        let task = TaskItem(title: "Buy milk", priority: .high)

        // Assert
        XCTAssertEqual(task.priority, .high)
    }

    // MARK: - Priority: the fixed set of cases (KAN-30-TC-08's Model-level
    // source of truth — ContentView's picker iterates `Priority.allCases`,
    // so pinning its raw values/identity here also pins what the picker can
    // ever offer and how it's persisted)

    func test_KAN30TC08_priority_rawValues_matchExpectedDisplayStrings() {
        // Arrange
        // no setup needed

        // Act / Assert
        XCTAssertEqual(Priority.low.rawValue, "Low")
        XCTAssertEqual(Priority.medium.rawValue, "Medium")
        XCTAssertEqual(Priority.high.rawValue, "High")
    }

    func test_priority_id_equalsRawValue() {
        // Arrange
        // no setup needed

        // Act / Assert
        for priority in Priority.allCases {
            XCTAssertEqual(priority.id, priority.rawValue, "priority \(priority) case")
        }
    }

    // MARK: - Codable: priority round-trips through encode/decode (KAN-30),
    // for each of the three fixed values

    func test_encodeThenDecode_withEachPriorityValue_preservesPriority() throws {
        for priority in Priority.allCases {
            // Arrange
            let task = TaskItem(title: "Buy milk", priority: priority)
            let data = try JSONEncoder().encode(task)

            // Act
            let decoded = try JSONDecoder().decode(TaskItem.self, from: data)

            // Assert
            XCTAssertEqual(decoded.priority, priority, "priority \(priority) case")
        }
    }

    func test_encodeThenDecode_withNilPriority_preservesNilPriority() throws {
        // Arrange
        let task = TaskItem(title: "Buy milk")
        let data = try JSONEncoder().encode(task)

        // Act
        let decoded = try JSONDecoder().decode(TaskItem.self, from: data)

        // Assert
        XCTAssertNil(decoded.priority)
    }

    // MARK: - Codable: a nil priority is omitted from the encoded JSON
    // entirely (encodeIfPresent, mirroring dueDate's KAN-19 precedent) rather
    // than encoded as an explicit null — this is exactly what makes
    // pre-KAN-30 persisted JSON (which never had a "priority" key at all)
    // already shaped like a task with no priority, so no migration is needed.

    func test_encode_withNilPriority_omitsPriorityKeyFromJSON() throws {
        // Arrange
        let task = TaskItem(title: "Buy milk", dueDate: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3)))

        // Act
        let data = try JSONEncoder().encode(task)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        // Assert
        XCTAssertFalse(jsonString.contains("priority"), "a nil priority must be omitted from the encoded JSON, not written as an explicit null")
    }

    // MARK: - Codable: JSON persisted before KAN-30 (no "priority" key at
    // all) still decodes successfully, as nil — same backward-compatibility
    // guarantee KAN-19 established for "dueDate" (see
    // test_decode_legacyJSONWithoutDueDateKey_decodesWithNilDueDate above),
    // now re-verified for the newly-added "priority" key (Manual-QA-agent's
    // note-for-Unit-Tests-agent flagged this as worth checking directly).

    func test_decode_legacyJSONWithoutPriorityKey_decodesWithNilPriority() throws {
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
        XCTAssertNil(decoded.priority)
    }

    // MARK: - Equatable: priority participates in equality (KAN-30)

    func test_equality_withSamePriority_areEqual() {
        // Arrange
        let id = UUID()
        let first = TaskItem(id: id, title: "Buy milk", priority: .medium)

        // Act
        let second = TaskItem(id: id, title: "Buy milk", priority: .medium)

        // Assert
        XCTAssertEqual(first, second)
    }

    func test_equality_withDifferentPriority_areNotEqual() {
        // Arrange
        let id = UUID()
        let first = TaskItem(id: id, title: "Buy milk", priority: .low)

        // Act
        let second = TaskItem(id: id, title: "Buy milk", priority: .high)

        // Assert
        XCTAssertNotEqual(first, second)
    }

    func test_equality_withOneNilAndOneSetPriority_areNotEqual() {
        // Arrange
        let id = UUID()
        let withoutPriority = TaskItem(id: id, title: "Buy milk")

        // Act
        let withPriority = TaskItem(id: id, title: "Buy milk", priority: .low)

        // Assert
        XCTAssertNotEqual(withoutPriority, withPriority)
    }

    // MARK: - AC: overdue determination (KAN-23)
    //
    // TaskItem.isOverdue is a pure derived value of (isCompleted, dueDate) evaluated
    // against "now" — tests use dates relative to today (via `daysFromToday`) rather
    // than fixed calendar dates so they remain valid on any run date.

    /// Returns a `Date` `days` calendar days from today's start-of-day, matching the
    /// start-of-day storage convention `TaskListViewModel` normalizes `dueDate` to
    /// (KAN-19/22). Passing `0` yields today; negative values are in the past.
    private func daysFromToday(_ days: Int) -> Date {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: days, to: startOfToday)!
    }

    func test_KAN23TC01_isOverdue_notCompletedWithDueDateYesterday_isOverdue() {
        // Arrange
        let task = TaskItem(title: "Buy milk", isCompleted: false, dueDate: daysFromToday(-1))

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertTrue(result)
    }

    func test_KAN23TC02_isOverdue_notCompletedWithDueDateMonthsAgo_isOverdue() {
        // Arrange
        let task = TaskItem(title: "Buy milk", isCompleted: false, dueDate: daysFromToday(-90))

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertTrue(result)
    }

    func test_KAN23TC03_isOverdue_completedWithDueDateBeforeToday_notOverdue() {
        // Arrange
        let task = TaskItem(title: "Buy milk", isCompleted: true, dueDate: daysFromToday(-1))

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN23TC04_isOverdue_notCompletedWithNoDueDate_notOverdue() {
        // Arrange
        let task = TaskItem(title: "Buy milk", isCompleted: false, dueDate: nil)

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN23TC05_isOverdue_completedWithNoDueDate_notOverdue() {
        // Arrange
        let task = TaskItem(title: "Buy milk", isCompleted: true, dueDate: nil)

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN23TC06_isOverdue_notCompletedWithDueDateToday_notOverdue() {
        // Arrange
        let task = TaskItem(title: "Buy milk", isCompleted: false, dueDate: daysFromToday(0))

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN23TC07_isOverdue_completedWithDueDateToday_notOverdue() {
        // Arrange
        let task = TaskItem(title: "Buy milk", isCompleted: true, dueDate: daysFromToday(0))

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN23TC08_isOverdue_notCompletedWithDueDateTomorrow_notOverdue() {
        // Arrange
        let task = TaskItem(title: "Buy milk", isCompleted: false, dueDate: daysFromToday(1))

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertFalse(result)
    }

    func test_KAN23TC09_isOverdue_mixedSetOfTasks_flagsOnlyNotCompletedTasksWithPastDueDate() {
        // Arrange
        let overdueTask = TaskItem(title: "Overdue", isCompleted: false, dueDate: daysFromToday(-1))
        let dueTodayTask = TaskItem(title: "Due today", isCompleted: false, dueDate: daysFromToday(0))
        let dueFutureTask = TaskItem(title: "Due future", isCompleted: false, dueDate: daysFromToday(1))
        let completedPastDueTask = TaskItem(title: "Completed past due", isCompleted: true, dueDate: daysFromToday(-1))
        let noDueDateNotCompletedTask = TaskItem(title: "No due date", isCompleted: false, dueDate: nil)
        let noDueDateCompletedTask = TaskItem(title: "No due date, completed", isCompleted: true, dueDate: nil)
        let tasks = [overdueTask, dueTodayTask, dueFutureTask, completedPastDueTask, noDueDateNotCompletedTask, noDueDateCompletedTask]

        // Act
        let overdueIDs = tasks.filter(\.isOverdue).map(\.id)

        // Assert
        XCTAssertEqual(overdueIDs, [overdueTask.id])
    }

    func test_KAN23TC10_isOverdue_completingAPreviouslyOverdueTask_stopsBeingFlagged() {
        // Arrange
        var task = TaskItem(title: "Buy milk", isCompleted: false, dueDate: daysFromToday(-1))
        XCTAssertTrue(task.isOverdue, "precondition: task should start out overdue")

        // Act
        task.isCompleted = true

        // Assert
        XCTAssertFalse(task.isOverdue)
    }

    // MARK: - isOverdue and the normalizedDueDate storage convention (KAN-19/22)
    //
    // `dueDate` is normalized to `Calendar.current.startOfDay(for:)` before it's ever
    // stored on a TaskItem (see `TaskListViewModel`'s add/update paths), so isOverdue
    // itself never needs to normalize its `dueDate` input. These two tests construct
    // TaskItem directly with an un-normalized (time-of-day-bearing) dueDate — bypassing
    // that ViewModel-layer normalization — to confirm isOverdue still produces the
    // correct calendar-day result. It does, because the comparison is always against
    // `Calendar.current.startOfDay(for: Date())` (today's start-of-day), not against
    // `dueDate`'s own start-of-day, so any time-of-day component on `dueDate` is
    // irrelevant to the outcome.

    func test_isOverdue_notCompletedWithUnnormalizedDueDateLateYesterday_isOverdue() {
        // Arrange
        let lateYesterday = Calendar.current.date(byAdding: .hour, value: 23, to: daysFromToday(-1))!
        let task = TaskItem(title: "Buy milk", isCompleted: false, dueDate: lateYesterday)

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertTrue(result)
    }

    func test_isOverdue_notCompletedWithUnnormalizedDueDateMiddayToday_notOverdue() {
        // Arrange
        let middayToday = Calendar.current.date(byAdding: .hour, value: 12, to: daysFromToday(0))!
        let task = TaskItem(title: "Buy milk", isCompleted: false, dueDate: middayToday)

        // Act
        let result = task.isOverdue

        // Assert
        XCTAssertFalse(result)
    }
}
