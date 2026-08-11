# CLAUDE.md

## Overview

Task Tracker is a SwiftUI iOS app for managing a personal task list. Features: create, view, edit, mark complete, filter, and delete tasks, with deletion protected by a 5-second undo window. Data is persisted across launches to the app's Application Support directory as JSON via `FileTaskStore`.

- **Language:** Swift 5.0
- **UI framework:** SwiftUI (iOS 26.5+ deployment target)
- **Architecture:** MVVM with protocol-based dependency injection
- **Bundle ID:** `taskTracker.TaskTrackerApp`
- **Jira board:** KAN

## Architecture

### Flat file structure — no subdirectory grouping

All source files live directly under `TaskTrackerApp/` (no `Models/`, `ViewModels/`, or `Views/` subdirectories).

| File | Layer | Responsibility |
|------|-------|----------------|
| `Task.swift` | Model | `TaskItem` — `struct`, `Identifiable`, `Equatable`, `Codable` |
| `TaskFilter.swift` | Model | `TaskFilter` enum — `.all`, `.notCompleted`, `.completed` |
| `TaskListViewModel.swift` | ViewModel | `@Observable` class; owns tasks array, filter state, validation, undo logic |
| `ContentView.swift` | View | SwiftUI list, add/edit inline rows, filter picker, undo banner |
| `TaskStoring.swift` | Infrastructure | `TaskStoring` protocol; `FileTaskStore` (JSON on disk); `TransientTaskStore` (in-memory, used as default in init) |
| `UndoScheduler.swift` | Infrastructure | `UndoScheduler` protocol; `DispatchUndoScheduler` (production) |
| `TaskTrackerAppApp.swift` | Entry point | `@main` struct; injects `FileTaskStore()` into `ContentView` |

### Key design decisions

- All business logic stays in `TaskListViewModel`; `ContentView` delegates every mutation to it.
- `TaskStoring` and `UndoScheduler` are injected via protocols so `TaskListViewModel` is unit-testable without real I/O or real timers.
- `TaskListViewModel()` with no arguments uses `TransientTaskStore` — constructing it in tests is side-effect-free.
- `FileTaskStore` and `TransientTaskStore` are `nonisolated` to avoid inheriting the MainActor default and blocking off-main-actor callers (test code via the `TaskStoring` existential).

## Build & Test

All commands run from the project root — the directory that contains `TaskTrackerApp.xcodeproj`.

**Scheme:** `TaskTrackerApp`  
**Destination:** `platform=iOS Simulator,name=iPhone 17`

### Build

```sh
xcodebuild -scheme TaskTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### Run unit tests only

```sh
xcodebuild test \
  -scheme TaskTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TaskTrackerAppTests
```

### Run all tests (unit + UI)

```sh
xcodebuild test \
  -scheme TaskTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Tests with code coverage

```sh
xcodebuild test \
  -scheme TaskTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES
```

Coverage results land in `~/Library/Developer/Xcode/DerivedData/` and can be inspected in Xcode's Report Navigator or via `xcrun xccov`.

## Agent Pipeline

Full per-agent rules (input contract, output format, Jira status transitions, tooling) are defined in `.claude/agents/`. This section describes the overall flow and artifact handoffs only — do not duplicate those rules here.

### 0. BA-agent (`ba-agent.md`)
Upstream of the main pipeline. Drafts Jira stories from free-text feature or sprint-goal descriptions, searches the existing backlog for duplicates, and files the ticket (Status: To Do) with AC (Given/When/Then), Out of scope, and Notes for Dev-agent. Does not estimate, does not touch status beyond creating To Do.

### 0.5. Requirements-analysis-agent (`requirements-analysis-agent.md`)
**Starts from:** The story BA-agent just created, plus any tickets it references in "Notes for Dev-agent."  
**Produces:** A Jira comment classifying each finding by **Resolution path**: *Auto-apply* (the fix just relocates an already-decided fact — e.g. something stated only in Notes for Dev-agent — into the AC; BA-agent folds it in on a follow-up pass and the pipeline continues automatically) or *Needs human* (resolving it means picking an answer, like a concrete threshold, that doesn't exist anywhere in the ticket yet).  
A finding that is both **Critical** and **Needs human** gets the ticket labeled `needs-clarification` — Manual-QA-agent and Dev-agent must not start on a labeled ticket. This holds only that one ticket; the rest of the sprint proceeds normally. The label is removed once a human resolves the AC.  
Runs **after** BA-agent, **before** Manual-QA-agent/Dev-agent.

### 1. Manual-QA-agent (`manual-qa-agent.md`)
**Starts from:** Jira AC and Out of scope only — deliberately blind to any implementation. Do not start on a ticket carrying the `needs-clarification` label.  
**Produces:** A Jira comment with a Markdown test-case table using `{ISSUE_KEY}-TC-{NN}` IDs.  
Runs **in parallel** with Dev-agent; both start from the same ticket.

### 2. Dev-agent (`dev-agent.md`)
**Starts from:** Jira story (Summary, AC, Out of scope, Notes for Dev-agent). Do not start on a ticket carrying the `needs-clarification` label.  
**Produces:** Swift/SwiftUI code changes + a written summary (files changed, assumptions, explicit out-of-scope callouts). Transitions ticket to **In Progress** at the start of every pass.  
Runs **in parallel** with Manual-QA-agent.

### 2.5. PR-review-agent (`pr-review-agent.md`)
**Starts from:** Jira story (AC, Out of scope, Notes for Dev-agent) + Dev-agent's diff/summary. No tests exist yet at this stage — that's deliberate.  
**Produces:** A fast Jira comment verdict — `Pass` or `Blocker` — on scope creep, logic duplication, MVVM violations, and obvious correctness red flags only. Deliberately narrower than Reviewer-agent (no test quality, no coverage, no traceability — those need tests to exist). Defaults to Pass when uncertain; a false block costs a full Dev-agent round-trip for nothing.  
**Gate:** `Blocker` sends the ticket back to Dev-agent for a fix pass; PR-review-agent then re-reviews the updated diff before Unit-Tests-agent starts. `Pass` (even with non-blocking `note`s) proceeds straight through. Does not transition status.  
Runs **after** Dev-agent, **before** Unit-Tests-agent.

### 3. Unit-Tests-agent (`unit-tests-agent.md`)
**Starts from:** Jira story + Dev-agent diff (after a PR-review-agent `Pass`) + Manual-QA-agent's latest Jira comment (fetched via Atlassian Rovo MCP).  
**Produces:** XCTest unit tests in `TaskTrackerAppTests/` targeting the ViewModel/Model layer, plus a report: AC → test mapping, Manual-QA ID → test mapping, coverage estimate (≥70% target), and notes for Reviewer-agent.  
Test name format: `test_<scenario>_<condition>_<expectedResult>()`; when a test traces to a Manual-QA-agent case, its ID is prepended: `test_{ISSUE_KEY}{TC_NUMBER}_<scenario>_<condition>_<expectedResult>()`. Coverage-only tests with no Manual-QA mapping keep the unprefixed form — never invent a fake ID.  
Runs **after** Dev-agent.

### 4. Reviewer-agent (`reviewer-agent.md`)
**Starts from:** Jira story + Dev-agent diff + Unit-Tests-agent output and report + Manual-QA-agent's latest Jira comment (fetched via Atlassian Rovo MCP).  
**Produces:** A Jira comment with Verdict (`Approve` / `Request Changes`), severity-tagged comments (`blocker` | `suggestion` | `nit`), and a traceability table for every Manual-QA-agent ID (Automated or Manual-only).  
Transitions ticket to **In Review** on start; to **Done** on Approve; back to **In Progress** on Request Changes.

### 5. UIAQA-agent (planned — v2)
No agent file defined yet. Intended to author real XCUITest scenarios against the `TaskTrackerAppUITests` target, which currently holds only Xcode-generated stubs. Agent file will be added to `.claude/agents/` when the scope is defined.

## Known Tech Debt

| Ticket | Title | Status | Note |
|--------|-------|--------|------|
| KAN-5 | Consolidate title validation between View and ViewModel | Resolved | Introduced `TaskListViewModel.isValidTitle(_:)` (canonical pass/fail rule) and `cappedTitle(_:)` (live cap). **Do not add a second validation path.** Both the Reviewer-agent and ba-agent flag re-introducing duplicate validation as a `blocker`; it was a recurring issue across KAN-1, 8, 9, and 10. |

## Working Conventions

- **Scope discipline:** implement only what the AC and "Notes for Dev-agent" require. Callout scope gaps in the output summary; never silently expand a story.
- **Test file ownership:** files under `TaskTrackerAppTests/` and `TaskTrackerAppUITests/` are owned by the Unit-Tests-agent. Dev-agent must not modify them.
- **No persistence without a story:** do not introduce `CoreData`, `SwiftData`, or `UserDefaults` unless a story explicitly asks for it.
- **Single validation path:** all title validation goes through `TaskListViewModel.isValidTitle(_:)` and `cappedTitle(_:)`. See KAN-5.
- **Coverage floor:** Unit-Tests-agent targets ≥70% coverage on the ViewModel/Model layer per story. Uncovered lines must be explained in the report — do not pad with meaningless tests.
- **Jira status ownership:** Dev-agent → In Progress; Reviewer-agent → In Review or Done. No other agent sets status.
- **Git commit format:** `<description> (<TICKET_KEY>)`, e.g. `Undo a task deletion (KAN-10)`.
- **Minimum deployment target:** iOS 26.5. Flag any API that requires a higher OS version before using it.
