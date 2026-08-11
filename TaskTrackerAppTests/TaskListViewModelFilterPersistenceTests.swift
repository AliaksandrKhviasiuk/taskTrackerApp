//
//  TaskListViewModelFilterPersistenceTests.swift
//  TaskTrackerAppTests
//

import XCTest
@testable import TaskTrackerApp

/// Test double that records `save` calls and lets tests stub what
/// `loadFilter()` returns, without touching real `UserDefaults`.
final class FakeFilterStoring: FilterStoring {
    var stubbedFilter: TaskFilter = .all
    private(set) var saveCallCount = 0
    private(set) var savedFilters: [TaskFilter] = []

    func loadFilter() -> TaskFilter {
        stubbedFilter
    }

    func save(_ filter: TaskFilter) {
        saveCallCount += 1
        savedFilters.append(filter)
    }
}

final class TaskListViewModelFilterPersistenceTests: XCTestCase {

    private var fakeFilterStorage: FakeFilterStoring!

    override func setUp() {
        super.setUp()
        fakeFilterStorage = FakeFilterStoring()
    }

    override func tearDown() {
        fakeFilterStorage = nil
        super.tearDown()
    }

    // MARK: - KAN-16-TC-01/02: a non-default filter is restored on init
    // ("relaunch" is simulated by constructing a fresh ViewModel instance
    // backed by the same filter storage, matching how KAN-7's persistence
    // tests simulate relaunch for tasks).

    func test_KAN16TC01_init_withPreviouslySavedCompletedFilter_restoresIt() {
        // Arrange
        fakeFilterStorage.stubbedFilter = .completed

        // Act
        let sut = TaskListViewModel(filterStorage: fakeFilterStorage)

        // Assert
        XCTAssertEqual(sut.filter, .completed)
    }

    func test_KAN16TC02_init_withPreviouslySavedNotCompletedFilter_restoresIt() {
        // Arrange
        fakeFilterStorage.stubbedFilter = .notCompleted

        // Act
        let sut = TaskListViewModel(filterStorage: fakeFilterStorage)

        // Assert
        XCTAssertEqual(sut.filter, .notCompleted)
    }

    // MARK: - KAN-16-TC-03: fresh install (nothing saved) defaults to .all

    func test_KAN16TC03_init_withNoSavedFilter_defaultsToAll() {
        // Arrange
        // FakeFilterStoring's stubbedFilter already defaults to .all, matching
        // UserDefaultsFilterStore.loadFilter()'s real fallback behavior.

        // Act
        let sut = TaskListViewModel(filterStorage: fakeFilterStorage)

        // Assert
        XCTAssertEqual(sut.filter, .all)
    }

    // MARK: - KAN-16-TC-04: the most recently selected filter is what's
    // persisted, not the original one

    func test_KAN16TC04_settingFilterMultipleTimes_persistsEachChangeWithLatestWinning() {
        // Arrange
        let sut = TaskListViewModel(filterStorage: fakeFilterStorage)

        // Act
        sut.filter = .completed
        sut.filter = .notCompleted

        // Assert
        XCTAssertEqual(fakeFilterStorage.savedFilters.last, .notCompleted)
    }

    // MARK: - KAN-16-TC-05: explicitly selecting the default value is itself persisted

    func test_KAN16TC05_settingFilterToAllExplicitly_stillCallsSave() {
        // Arrange
        let sut = TaskListViewModel(filterStorage: fakeFilterStorage)
        let saveCallCountAfterInit = fakeFilterStorage.saveCallCount

        // Act
        sut.filter = .all

        // Assert
        XCTAssertEqual(fakeFilterStorage.saveCallCount, saveCallCountAfterInit + 1)
        XCTAssertEqual(fakeFilterStorage.savedFilters.last, .all)
    }

    // MARK: - Coverage: search text is never routed through filter persistence

    func test_settingSearchText_doesNotCallFilterStorageSave() {
        // Arrange
        let sut = TaskListViewModel(filterStorage: fakeFilterStorage)
        let saveCallCountAfterInit = fakeFilterStorage.saveCallCount

        // Act
        sut.searchText = "milk"

        // Assert
        XCTAssertEqual(fakeFilterStorage.saveCallCount, saveCallCountAfterInit)
    }
}

/// Tests against the real `UserDefaultsFilterStore`, using a dedicated
/// `UserDefaults` suite so nothing touches (or leaks into) the real app's
/// stored defaults.
final class UserDefaultsFilterStoreTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var sut: UserDefaultsFilterStore!

    override func setUp() {
        super.setUp()
        suiteName = "UserDefaultsFilterStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        sut = UserDefaultsFilterStore(defaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        sut = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_loadFilter_withNothingSaved_returnsAll() {
        // Act
        let result = sut.loadFilter()

        // Assert
        XCTAssertEqual(result, .all)
    }

    func test_loadFilter_afterSavingCompleted_returnsCompleted() {
        // Arrange
        sut.save(.completed)

        // Act
        let result = sut.loadFilter()

        // Assert
        XCTAssertEqual(result, .completed)
    }

    func test_loadFilter_afterSavingNotCompletedThenAll_returnsMostRecentlySavedValue() {
        // Arrange
        sut.save(.notCompleted)
        sut.save(.all)

        // Act
        let result = sut.loadFilter()

        // Assert
        XCTAssertEqual(result, .all)
    }

    func test_loadFilter_withGarbageStoredValue_fallsBackToAllInsteadOfCrashing() {
        // Arrange
        userDefaults.set("not-a-real-filter", forKey: "selectedTaskFilter")

        // Act
        let result = sut.loadFilter()

        // Assert
        XCTAssertEqual(result, .all)
    }
}
