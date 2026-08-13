//
//  TaskListViewModelUpdateDueDateTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Tests for `TaskListViewModel.updateDueDate(for:to:)` (KAN-22), extending
/// KAN-19's creation-only due date to existing tasks: change an existing due
/// date, set one where none existed, and clear one back to `nil`. Unlike
/// `updateTitle(for:to:)`, this method has no validation path and no KAN-17
/// undo integration (deliberate, not requested by AC), so those two concerns
/// (covered by `TaskListViewModelEditUndoTests.swift`/
/// `TaskListViewModelValidationTests.swift` for titles) have no analog here.
/// Date-only normalization itself is already covered against
/// `normalizedDueDate(_:)`'s only other call site in
/// `TaskListViewModelDueDateTests.swift` (KAN-19); this file only asserts
/// that `updateDueDate` actually routes through that same helper, not that
/// the helper's normalization logic is correct in general (no duplicate
/// coverage of the underlying rule).
final class TaskListViewModelUpdateDueDateTests: XCTestCase {

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

    // MARK: - KAN-22-TC-01 / AC1: task with a due date -> changed to a different value, saved and reflected

    func test_KAN22TC01_updateDueDate_onTaskWithExistingDueDate_changesToNewValue() {
        // Arrange
        let originalDueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let newDueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        sut.addTask(title: "Buy milk", dueDate: originalDueDate)
        let taskID = sut.tasks[0].id

        // Act
        let result = sut.updateDueDate(for: taskID, to: newDueDate)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks[0].dueDate, newDueDate)
    }

    func test_KAN22TC01_updateDueDate_onTaskWithExistingDueDate_savesChangedDueDateToStorage() {
        // Arrange
        let originalDueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let newDueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        sut.addTask(title: "Buy milk", dueDate: originalDueDate)
        let taskID = sut.tasks[0].id
        let saveCallCountBeforeUpdate = fakeStorage.saveCallCount

        // Act
        sut.updateDueDate(for: taskID, to: newDueDate)

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountBeforeUpdate + 1)
        XCTAssertEqual(fakeStorage.lastSavedTasks?.first?.dueDate, newDueDate)
    }

    // MARK: - KAN-22-TC-02 / AC2: task with no due date -> a date is picked, saved and reflected

    func test_KAN22TC02_updateDueDate_onTaskWithNoDueDate_setsDueDate() {
        // Arrange
        let pickedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        XCTAssertNil(sut.tasks[0].dueDate, "sanity: task starts with no due date")

        // Act
        let result = sut.updateDueDate(for: taskID, to: pickedDate)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks[0].dueDate, pickedDate)
    }

    func test_KAN22TC02_updateDueDate_onTaskWithNoDueDate_savesNewDueDateToStorage() {
        // Arrange
        let pickedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateDueDate(for: taskID, to: pickedDate)

        // Assert
        XCTAssertEqual(fakeStorage.lastSavedTasks?.first?.dueDate, pickedDate)
    }

    // MARK: - KAN-22-TC-03 / AC3: task with a due date -> cleared, saved as nil, no longer shown

    func test_KAN22TC03_updateDueDate_withNilOnTaskWithExistingDueDate_clearsDueDate() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)
        let taskID = sut.tasks[0].id

        // Act
        let result = sut.updateDueDate(for: taskID, to: nil)

        // Assert
        XCTAssertTrue(result)
        XCTAssertNil(sut.tasks[0].dueDate)
    }

    func test_KAN22TC03_updateDueDate_withNilOnTaskWithExistingDueDate_savesClearedDueDateToStorage() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)
        let taskID = sut.tasks[0].id

        // Act
        sut.updateDueDate(for: taskID, to: nil)

        // Assert
        XCTAssertNil(fakeStorage.lastSavedTasks?.first?.dueDate)
    }

    // MARK: - KAN-22-TC-10: re-selecting the same date and saving succeeds without error, value unchanged

    func test_KAN22TC10_updateDueDate_withSameDateAsCurrent_succeedsAndLeavesDueDateUnchanged() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)
        let taskID = sut.tasks[0].id

        // Act
        let result = sut.updateDueDate(for: taskID, to: dueDate)

        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(sut.tasks[0].dueDate, dueDate)
    }

    // MARK: - KAN-22-TC-11: the updated due date is persisted immediately (proxied the same
    // way as KAN-19-TC-02/KAN-8-TC-06's relaunch checks: a fresh ViewModel/FileTaskStore pair
    // over the same underlying file, simulating closing and reopening the app)

    func test_KAN22TC11_newViewModelInstanceBackedBySameFileStore_restoresUpdatedDueDateAcrossRelaunch() {
        // Arrange
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let originalDueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let newDueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let firstLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let firstLaunchViewModel = TaskListViewModel(storage: firstLaunchStore)
        firstLaunchViewModel.addTask(title: "Buy milk", dueDate: originalDueDate)
        let taskID = firstLaunchViewModel.tasks[0].id

        // Act
        firstLaunchViewModel.updateDueDate(for: taskID, to: newDueDate)
        let secondLaunchStore = FileTaskStore(fileManager: DirectoryOverridingFileManager(overrideDirectory: tempDirectory))
        let secondLaunchViewModel = TaskListViewModel(storage: secondLaunchStore)

        // Assert
        XCTAssertEqual(secondLaunchViewModel.tasks.first?.dueDate, newDueDate)
    }

    // MARK: - KAN-22-TC-12 / AC "distinct interaction not requested to touch other state": only the
    // targeted task's due date changes; other tasks (with and without due dates) are untouched

    func test_KAN22TC12_updateDueDate_withMultipleTasks_onlyUpdatesTargetedTasksDueDate() {
        // Arrange
        let untouchedDueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 20))!
        sut.addTask(title: "Task A", dueDate: untouchedDueDate)
        sut.addTask(title: "Task B") // no due date
        sut.addTask(title: "Task C", dueDate: untouchedDueDate)
        let targetID = sut.tasks[1].id // Task B, currently nil
        let newDueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        // Act
        sut.updateDueDate(for: targetID, to: newDueDate)

        // Assert
        XCTAssertEqual(sut.tasks[0].dueDate, untouchedDueDate, "Task A must be unaffected")
        XCTAssertEqual(sut.tasks[1].dueDate, newDueDate, "Task B is the only one that should change")
        XCTAssertEqual(sut.tasks[2].dueDate, untouchedDueDate, "Task C must be unaffected")
    }

    func test_updateDueDate_withMultipleTasks_preservesListOrder() {
        // Arrange
        sut.addTask(title: "Task A")
        sut.addTask(title: "Task B")
        sut.addTask(title: "Task C")
        let lastID = sut.tasks[2].id

        // Act
        sut.updateDueDate(for: lastID, to: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3)))

        // Assert
        XCTAssertEqual(sut.tasks.map(\.title), ["Task A", "Task B", "Task C"])
    }

    // MARK: - Unknown task ID: no-op, returns false, doesn't mutate any existing task

    func test_updateDueDate_withUnknownTaskID_returnsFalse() {
        // Arrange
        sut.addTask(title: "Buy milk")

        // Act
        let result = sut.updateDueDate(for: UUID(), to: Date())

        // Assert
        XCTAssertFalse(result)
    }

    func test_updateDueDate_withUnknownTaskID_doesNotModifyExistingTasksDueDates() {
        // Arrange
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        sut.addTask(title: "Buy milk", dueDate: dueDate)

        // Act
        sut.updateDueDate(for: UUID(), to: nil)

        // Assert
        XCTAssertEqual(sut.tasks[0].dueDate, dueDate, "an unknown id must not clear an unrelated task's due date")
    }

    func test_updateDueDate_withUnknownTaskID_doesNotCallSave() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let saveCallCountBeforeUpdate = fakeStorage.saveCallCount

        // Act
        sut.updateDueDate(for: UUID(), to: Date())

        // Assert
        XCTAssertEqual(fakeStorage.saveCallCount, saveCallCountBeforeUpdate)
    }

    func test_updateDueDate_onEmptyTaskList_returnsFalse() {
        // Act
        let result = sut.updateDueDate(for: UUID(), to: Date())

        // Assert
        XCTAssertFalse(result)
    }

    // MARK: - Normalization: updateDueDate reuses the same `normalizedDueDate(_:)`
    // helper as addTask (KAN-5-style single-path reuse, per Notes for Dev-agent) —
    // this asserts the routing, not the normalization rule itself (already covered
    // for addTask in TaskListViewModelDueDateTests.swift, KAN-19).

    func test_updateDueDate_withDateContainingTimeComponent_normalizesToStartOfDay() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        let dateWithTime = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 23, minute: 59, second: 59))!
        let expectedNormalizedDate = Calendar.current.startOfDay(for: dateWithTime)

        // Act
        sut.updateDueDate(for: taskID, to: dateWithTime)

        // Assert
        XCTAssertEqual(sut.tasks[0].dueDate, expectedNormalizedDate)
        XCTAssertNotEqual(sut.tasks[0].dueDate, dateWithTime, "the raw time-of-day component must not survive storage")
    }

    // MARK: - Coverage: updateDueDate never mutates isCompleted or title (i.e. it is
    // due-date-only) — supports Manual-QA's TC-04 "must not also toggle isCompleted"
    // note, at the ViewModel/state-transition level called out in the Jira comment.

    func test_updateDueDate_onIncompleteTask_doesNotChangeCompletionStatus() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        XCTAssertFalse(sut.tasks[0].isCompleted, "sanity")

        // Act
        sut.updateDueDate(for: taskID, to: Date())

        // Assert
        XCTAssertFalse(sut.tasks[0].isCompleted)
    }

    func test_updateDueDate_onCompletedTask_doesNotChangeCompletionStatus() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id
        sut.toggleCompletion(for: taskID)
        XCTAssertTrue(sut.tasks[0].isCompleted, "sanity")

        // Act
        sut.updateDueDate(for: taskID, to: Date())

        // Assert
        XCTAssertTrue(sut.tasks[0].isCompleted)
    }

    func test_updateDueDate_doesNotChangeTaskTitle() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateDueDate(for: taskID, to: Date())

        // Assert
        XCTAssertEqual(sut.tasks[0].title, "Buy milk")
    }

    // MARK: - Coverage: updateDueDate does not participate in the KAN-17 pending-edit/undo
    // mechanism (deliberate — see Dev-agent's summary and PR-review-agent's Pass verdict)

    func test_updateDueDate_doesNotCreateAPendingEdit() {
        // Arrange
        sut.addTask(title: "Buy milk")
        let taskID = sut.tasks[0].id

        // Act
        sut.updateDueDate(for: taskID, to: Date())

        // Assert
        XCTAssertFalse(sut.hasPendingEdit)
    }
}
