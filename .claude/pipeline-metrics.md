# Pipeline metrics

Lightweight, per-ticket log of how the agent pipeline performed. Purpose: catch drift in either direction — gates going quiet (self-review bias, see CLAUDE.md's "Pipeline calibration") or gates blocking so often they're just adding round-trips without catching real issues.

**Who updates this:** the orchestrator (main session), not a subagent — this is bookkeeping, not a review deliverable. Append one row per ticket right after Reviewer-agent's verdict lands (Approve or Request Changes), using the outcome of the *final* pass on that ticket.

## How to read the columns

- **PR-review:** final verdict + `(N rounds)`, e.g. `Pass (1 round)` if it passed first try, `Blocker → Pass (2 rounds)` if Dev-agent needed a fix pass.
- **Reviewer:** same pattern for the final-gate verdict, e.g. `Approve (1 round)` or `Request Changes → Approve (2 rounds)`.
- **Manual-QA cases:** `automated/manual-only/total` from Reviewer-agent's traceability table.
- **Coverage:** Unit-Tests-agent's self-reported estimate for the code touched by the story (not a project-wide number).

## Computing trends

No separate rollup is maintained — compute on demand by scanning the table:
- **Blocker rate per gate** = rows where that gate's column contains "→" / total rows, over a window (e.g. last 6 tickets).
- **Re-pass rate** = rows needing 2+ rounds at either gate / total rows.
- **Coverage trend** = plot the Coverage column over time; watch for a downward drift.

A rate that stays at 0% for a stretch is itself a signal — see the "Pipeline calibration" section in CLAUDE.md for the independent-review check that exists specifically to catch that.

## Per-ticket log

| Ticket | Date | PR-review | Reviewer | Manual-QA cases | Coverage |
|---|---|---|---|---|---|
| KAN-20 | 2026-08-12 | Blocker → Pass (2 rounds) | Approve (1 round) | 8/0/8 | ~95-100% |
| KAN-46 | 2026-08-13 | Pass (1 round) | Approve (1 round) | 0/13/13 | N/A — zero new lines in ViewModel/Model layer, view-only styling change |
| KAN-22 | 2026-08-13 | Pass (1 round) | Approve (1 round) | 6/6/12 | ~100% of new `updateDueDate` method |
| KAN-23 | 2026-08-14 | Pass (1 round) | Approve (1 round) | 10/0/10 | ~100% of new `isOverdue` property |
| KAN-24 | 2026-08-14 | Pass (1 round) | Approve (1 round) | 15/0/15 | 99.55% (`TaskListViewModel.swift`, xccov-measured) |
| KAN-43 | 2026-08-19 | Pass (1 round) | Approve (1 round) | 0/15/15 | N/A — zero new lines in ViewModel/Model layer, pure View-layer add-task-row rewrite |
| KAN-45 | 2026-08-19 | Pass (1 round) | Approve (1 round) | 0/10/10 | N/A — zero new lines in ViewModel/Model layer, pure View-layer due-date pill/sheet |
| KAN-44 | 2026-08-20 | Pass (1 round) | Request Changes → Approve (2 rounds) | 0/11/11 | N/A — pure View-layer floating button; Reviewer-agent caught the blocker (button visually overlapping the undo banner) only via a live simulator screenshot, which PR-review-agent and Unit-Tests-agent had both explicitly flagged they couldn't verify statically — confirms the "live-check when static reading can't certify layout" pattern is pulling weight |
| KAN-30 | 2026-08-20 | Pass (1 round) | Approve (1 round) | 5/4/9 | `Task.swift` 100%, `TaskListViewModel.swift` 99.55% (xccov-measured) |

## Calibration checks (independent re-review, every 4-6 tickets)

Per CLAUDE.md's "Pipeline calibration": every 4-6 merged tickets, an independent `reviewer-agent.md` pass runs against the same diff without seeing the first review's verdict. Log the outcome here.

| Ticket reviewed | Date | Independent pass found extra blocker? | Note |
|---|---|---|---|
| KAN-46 | 2026-08-14 | No | Approve, matches original. Same 2 suggestions independently found (View-layer id→index glue on delete; TC-02/03/04 could cite existing KAN-10 tests for formal traceability instead of landing Manual-only). |
| KAN-22 | 2026-08-14 | No | Approve, matches original. 2 new nits not raised the first time (unconditional `storage.save` on no-op re-save; missing explanatory comment for correctly omitting `revealIfHidden`) — both non-blocking, no missed blocker. |
| KAN-23 | 2026-08-14 | No | Approve, matches original. 1 new suggestion not raised the first time (`isOverdue` reads `Date()` at access time — a task can go stale mid-session across a midnight boundary until next re-render; judged an accepted v1 gap, not a blocker, since no AC/manual case asks for live refresh). |
| KAN-24 | 2026-08-14 | No | Approve, matches original. 1 new suggestion not raised the first time (sort toggle placed in the `.secondaryAction` overflow menu may hurt discoverability vs. a more prominent placement) — a UX/design note, not a defect. |

**Trend after 4 calibration checks:** 0/4 found a missed blocker — independent passes still agree with the original verdicts on the merge decision itself, though each independent pass surfaced 1-2 *additional* non-blocking suggestions/nits the first pass didn't. That's a healthier signal than a flat zero-difference rerun would be (the gate isn't just rubber-stamping — a fresh reviewer still finds new things to say, they just don't cross the blocker line), but the blocker rate itself is now 0/9 tickets since KAN-20's chaos-test. Worth revisiting with another deliberately-planted chaos ticket if the streak continues past the next 4-6.
