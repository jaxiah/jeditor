## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement undo and redo using immutable editor snapshots. Because `Editor.t` is a pure value and OCaml's runtime shares structure between adjacent snapshots, the memory cost of the history stack is proportional to the number of changed nodes, not the total buffer size.

Every command that modifies the buffer pushes the pre-edit `Editor.t` onto the undo stack and clears the redo stack. Undo pops from the undo stack and pushes the current state onto the redo stack. Any edit after an undo clears the redo stack.

## Acceptance criteria

- [ ] C-/ undoes the most recent buffer-modifying command
- [ ] Repeated C-/ undoes further back through history
- [ ] C-? (or M-\_) redoes the last undone command
- [ ] Any new edit after an undo clears the redo stack
- [ ] Undo/redo correctly restores cursor position alongside buffer content
- [ ] Undo on a freshly opened buffer does nothing (no error, no crash)
- [ ] Undo history is not bounded in Phase 1 (no arbitrary limit)
- [ ] Undo/redo does not affect the file's on-disk state — only in-memory buffer is changed

## Blocked by

- [ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## User stories addressed

- User story 14 (C-/ undo)
- User story 15 (C-? redo)
- User story 16 (undo history survives arbitrary sequences)
