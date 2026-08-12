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

## Calibration checks (independent re-review, every 4-6 tickets)

Per CLAUDE.md's "Pipeline calibration": every 4-6 merged tickets, an independent `reviewer-agent.md` pass runs against the same diff without seeing the first review's verdict. Log the outcome here.

| Ticket reviewed | Date | Independent pass found extra blocker? | Note |
|---|---|---|---|
