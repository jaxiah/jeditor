## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement mark-based region selection and a kill ring for cut/copy/paste. The mark is stored as an optional byte offset in `Editor.t`. When both mark and cursor are set, the region between them is highlighted during rendering.

The kill ring is a single-entry clipboard in Phase 1 (no ring history). C-w cuts the region (deletes it and saves to kill ring), M-w copies it (saves without deleting), C-y yanks (inserts kill ring content at cursor). C-g clears the mark.

## Acceptance criteria

- [x] C-Space sets the mark at the current cursor position; a second C-Space clears it
- [x] The selected region is visually highlighted (inverse video or a distinct background color)
- [x] C-w removes the selected text and stores it in the kill ring; this is undoable as a single operation
- [x] M-w copies the selected text to the kill ring without modifying the buffer
- [x] C-y inserts the kill ring content at each active cursor position
- [x] C-g clears the mark and deactivates the region
- [x] C-k appends to the kill ring when called on consecutive lines (standard Emacs kill-append behavior)
- [x] All operations work correctly when the mark is before or after the cursor

## Blocked by

- [ISSUE-009-basic-editing-commands.md](ISSUE-009-basic-editing-commands.md)

## User stories addressed

- User story 17 (C-Space set mark, select region)
- User story 18 (M-w copy)
- User story 19 (C-w cut)
- User story 20 (C-y paste)
- User story 24 (C-g cancel / deactivate mark)

## Status

2026-04-25 -- all acceptance criteria met. Added mark state, single-entry kill
ring, region copy/cut/yank commands, consecutive `C-k` kill append, Normal-mode
`C-g` mark clearing, inverse-video region rendering, keymap/registry entries,
and focused App tests for forward/backward selections, multi-cursor yank, undo,
and registry reachability.
