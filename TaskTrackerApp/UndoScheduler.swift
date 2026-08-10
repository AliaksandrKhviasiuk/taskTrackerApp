//
//  UndoScheduler.swift
//  TaskTrackerApp
//

import Foundation

/// Schedules the delayed commit of a pending undo-able action.
protocol UndoScheduler {
    /// Schedules `action` to run after `seconds`, replacing any previously
    /// scheduled action on this instance.
    func schedule(after seconds: TimeInterval, action: @escaping () -> Void)

    /// Cancels a previously scheduled action, if any. No-op if nothing is scheduled.
    func cancel()
}

/// Schedules on the main queue via `DispatchQueue.asyncAfter`.
final class DispatchUndoScheduler: UndoScheduler {
    private var workItem: DispatchWorkItem?

    func schedule(after seconds: TimeInterval, action: @escaping () -> Void) {
        cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
