## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Upgrade the renderer from full-screen redraws to cell-level differential rendering. The renderer maintains a `prev_frame` grid of cells (character + SGR color attributes). Each new frame is computed in full, diffed against `prev_frame`, and only the changed cells are written to the terminal as ANSI sequences. This eliminates visible flicker on slow terminals and is the standard technique used by ncurses, Notty, and every production TUI framework.

This is a pure optimization -- no user-visible behavior changes other than the elimination of flicker. All acceptance criteria from previous issues remain valid after this change.

## Acceptance criteria

- [x] On a static screen (no edits, no cursor movement), zero bytes are written to stdout after the first frame
- [x] Typing a single character causes only the affected cells (the new character and any reflowed text) to be updated -- not the entire screen
- [x] Cursor movement updates only the previous and new cursor cell
- [x] The diff renderer produces visually identical output to the full-redraw renderer for all scenarios in previous issues
- [x] A forced full redraw (e.g. after C-l or terminal resize) works correctly and re-syncs `prev_frame`
- [x] The `prev_frame` grid is correctly invalidated and rebuilt after terminal resize

## Blocked by

- [ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## User stories addressed

- User story 46 (sub-100ms feel -- this issue is the primary enabler for the visual performance target)

## Completed

2026-04-26 — all acceptance criteria met. Implemented via TDD.
