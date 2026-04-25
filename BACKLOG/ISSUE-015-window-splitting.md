## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement the `Frame` module and split-window layout. A `Frame.t` is a binary tree where internal nodes are horizontal or vertical splits with a ratio, and leaves are `Window.t` values. Each `Window.t` holds a buffer ID and an independent scroll position.

The renderer must be updated to paint each window into its assigned screen rectangle. Each window gets its own gutter and status bar row. The focused window is distinguished visually (e.g. brighter status bar).

## Acceptance criteria

- [x] C-x 2 splits the current window horizontally (top/bottom), both halves showing the same buffer
- [x] C-x 3 splits the current window vertically (left/right), both halves showing the same buffer
- [x] Splits can be nested arbitrarily -- C-x 2 inside an already-split window creates a third pane
- [x] C-x o cycles focus through all windows in the frame
- [x] C-x 0 closes the current window; its space is given to an adjacent sibling
- [x] C-x 1 closes all windows except the current one
- [x] C-x 0 on the last remaining window does nothing (no crash)
- [x] Each window scrolls independently -- the same buffer can be viewed at two different positions simultaneously
- [x] The split divider line is rendered between windows and does not overlap text
- [x] Terminal resize redistributes window proportions correctly

## Blocked by

- [ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## User stories addressed

- User story 30 (C-x 2 horizontal split)
- User story 31 (C-x 3 vertical split)
- User story 32 (C-x 0 close window)
- User story 33 (C-x 1 close others)
- User story 34 (C-x o move focus)
- User story 35 (resize)
- User story 36 (independent scroll)

## Status

2026-04-25 -- all acceptance criteria met. Added a `Frame` tree module with
horizontal/vertical splits, focus cycling, close-current/close-others, per-window
scroll state, proportional layouts, App actions and registry/keymap entries for
`C-x 2`, `C-x 3`, `C-x o`, `C-x 0`, and `C-x 1`, plus renderer support for
per-window gutters/status bars, focused-window status styling, and split
dividers.
