## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement undo and redo using immutable editor snapshots. Because `Editor.t` is a pure value and OCaml's runtime shares structure between adjacent snapshots, the memory cost of the history stack is proportional to the number of changed nodes, not the total buffer size.

Every command that modifies the buffer pushes the pre-edit `Editor.t` onto the undo stack and clears the redo stack. Undo pops from the undo stack and pushes the current state onto the redo stack. Any edit after an undo clears the redo stack.

## Acceptance criteria

- [x] C-/ undoes the most recent buffer-modifying command
- [x] Repeated C-/ undoes further back through history
- [x] C-? (or M-\_) redoes the last undone command
- [x] Any new edit after an undo clears the redo stack
- [x] Undo/redo correctly restores cursor position alongside buffer content
- [x] Undo on a freshly opened buffer does nothing (no error, no crash)
- [x] Undo history is not bounded in Phase 1 (no arbitrary limit)
- [x] Undo/redo does not affect the file's on-disk state -- only in-memory buffer is changed

## Completed

2026-04-25 — all acceptance criteria met. Implemented via TDD. Uses an immutable snapshot strategy for efficient history management with OCaml structure sharing. Added `Undo` and `Redo` actions to `App` and mapped them to `C-/` and `M-_`.

## Blocked by

- [ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## User stories addressed

- User story 14 (C-/ undo)
- User story 15 (C-? redo)
- User story 16 (undo history survives arbitrary sequences)
