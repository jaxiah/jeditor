## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement the platform abstraction layer for terminal I/O so the rest of the editor is completely insulated from OS differences. The editor is developed natively on Windows (not WSL2), so this is a required foundation, not an optional optimization.

Two modules get platform-specific implementations:

**Input backend**: reads raw bytes from stdin. On Windows, calls `SetConsoleMode` to enable `ENABLE_VIRTUAL_TERMINAL_INPUT` and `ENABLE_PROCESSED_INPUT` off. Parses multi-byte escape sequences (arrow keys, function keys, Meta via ESC prefix, C-x prefix chains) into a typed `Key.t` value. On Linux, uses standard POSIX `termios` raw mode.

**Terminal backend**: writes output. On Windows, calls `SetConsoleMode` on stdout to enable `ENABLE_VIRTUAL_TERMINAL_PROCESSING`. Exposes `hide_cursor`, `show_cursor`, `move_to`, `clear_screen`, `write_cell` (character + SGR color attributes). On Linux, emits the same ANSI sequences directly.

Both backends expose the same module signature -- the rest of the codebase never calls any platform-specific function directly.

## Acceptance criteria

- [x] `Key.t` type covers: printable characters, C-letter chords, M-letter chords, M-x prefix, arrow keys, Backspace, Delete, Enter, Escape, C-x followed by a second key
- [x] Input backend correctly parses all `Key.t` variants from raw Windows Console VT input
- [x] Terminal backend renders colored text and moves the cursor on a real Windows terminal (Windows Terminal or cmd.exe with VT enabled)
- [x] A manual smoke test program (`bin/term_test.exe`) draws a colored grid and responds to keypresses, demonstrating both backends work end-to-end on Windows
- [x] The same code compiles and runs correctly on Linux without modification (conditional compilation via Dune `(select ...)` or `(enabled_if ...)` stanzas)
- [x] No module outside `Input` and `Terminal` contains any platform-specific code or ANSI escape literals

## Blocked by

None -- can start immediately (run in parallel with ISSUE-003 and ISSUE-004).

## User stories addressed

- Cross-platform prerequisite for all user stories (see PRD-001 Further Notes).

## Completed

2026-04-25 -- All acceptance criteria met. Implemented via TDD. Platform abstraction with conditional compilation added for Win32 and Unix.
