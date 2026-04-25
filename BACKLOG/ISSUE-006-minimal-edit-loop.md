## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Wire all the foundational modules together into the first end-to-end working editor loop. This is the thinnest possible slice that lets a user open the editor, see a cursor, type characters, delete with Backspace, and quit. Every layer is exercised: Input → Keymap (hardcoded) → App/Update → Renderer → Terminal.

The keymap at this stage is hardcoded — a simple pattern match on `Key.t`, not the full configurable system from ISSUE-011. The renderer does full screen redraws (no diffing). Both are intentional shortcuts that will be replaced in later issues.

The `App` module introduces the top-level `app_state` type and the pure `update : app_state -> action -> app_state` function. The main loop in `bin/jeditor.ml` holds a single `app_state ref`, reads keys, calls `update`, and renders.

## Acceptance criteria

- [x] `jeditor` launches with an empty buffer and a visible cursor
- [x] Typing printable characters inserts them at the cursor and they appear on screen
- [x] Backspace deletes the character before the cursor (including multi-byte UTF-8 / CJK)
- [x] Enter inserts a newline
- [x] Cursor is visible and positioned correctly after every edit — **ASCII only; CJK display-column offset deferred to ISSUE-008** (byte column ≠ display column for wide chars)
- [x] C-x C-c quits the editor cleanly, restoring the terminal to normal mode (`C-x` / `Escape` / `C-c` all quit in this minimal implementation; chord system comes in ISSUE-011)
- [x] The terminal is always restored on exit, including when the process receives SIGINT (Ctrl+C)
- [x] `update` is a pure function with no side effects — all I/O stays in `bin/jeditor.ml` and the Terminal backend

## Blocked by

- [ISSUE-003-buffer-implementation.md](ISSUE-003-buffer-implementation.md)
- [ISSUE-004-cursor-module.md](ISSUE-004-cursor-module.md)
- [ISSUE-005-windows-terminal-backend.md](ISSUE-005-windows-terminal-backend.md)

## User stories addressed

- User story 9 (insert text)
- User story 10 (Backspace)
- User story 47 (quit)

## Completed

2026-04-25 — all acceptance criteria met. Implemented via TDD. Two bugs fixed during implementation: `ENABLE_LINE_INPUT`/`ENABLE_ECHO_INPUT` not disabled in Win32 raw mode stubs; `escape_parser` not decoding multi-byte UTF-8 sequences. CJK cursor display-column offset is a known limitation deferred to ISSUE-008.
