## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Add persistent screen chrome: a line-number gutter on the left and a status bar on the bottom row. These are rendered every frame as part of the main view, not as overlays. The renderer must account for the gutter width when computing the text area dimensions so line wrapping and cursor positioning remain correct.

## Acceptance criteria

- [x] Line numbers are displayed in a right-aligned gutter to the left of the text area
- [x] Gutter width adjusts automatically as the file grows past 9, 99, 999 lines etc.
- [x] The status bar on the bottom row shows: filename (or `[No Name]`), cursor position as `line:col`, total line count, and a `**` modified indicator
- [x] Cursor column in the status bar counts display columns, not bytes (CJK characters count as 2 columns)
- [x] The text area correctly excludes gutter and status bar rows -- the cursor never renders on top of chrome
- [x] Resizing the terminal window (SIGWINCH on Linux, console resize event on Windows) redraws correctly without corruption

## Completed

2026-04-25 — all acceptance criteria met. Implemented via TDD. Added `View` module for pure layout and `Wcwidth` for Unicode display width. Real terminal size and SIGWINCH support added to Unix backend.

## Blocked by

- [ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## User stories addressed

- User story 27 (line numbers)
- User story 29 (status bar)
