## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement the `Cursor` module, which manages a sorted, non-overlapping list of cursors. Each cursor is an absolute byte offset into the buffer plus an optional anchor offset for selections. This module is the authoritative home for all invariant enforcement and offset adjustment logic -- no other module should contain cursor arithmetic.

The key operation is `apply_edit`: given an edit (start offset + byte delta), atomically update every cursor in the list. The three cases are: cursor before the edit point (unchanged), cursor inside a deleted range (clamp to edit start), cursor after the edit point (shift by delta). After any mutation, the list must be re-sorted and deduplicated.

## Acceptance criteria

- [x] `Cursor.t` is an opaque type; internal representation is not accessible to callers
- [x] `apply_edit` correctly handles all three cursor-relative-to-edit cases
- [x] `apply_edit` on a list with multiple cursors updates all of them atomically in one pass
- [x] Cursors that collide after an edit are merged into one
- [x] The sorted, non-overlapping invariant is verified by tests that check the invariant holds after a sequence of arbitrary edits
- [x] Selection anchor is preserved correctly through edits that do not destroy the anchor's position
- [x] Alcotest suite covers: single cursor insert before/after/at; delete that spans cursor; multiple cursors with edit between them; multiple cursors with edit overlapping several; collision and merge

## Blocked by

- [ISSUE-003-buffer-implementation.md](ISSUE-003-buffer-implementation.md) (needs `Buffer.S` offset semantics to be defined first)

## User stories addressed

- User stories 40-44 (multi-cursor)
- Foundational prerequisite for user stories 5-13, 17-20.

## Completed

2024-05-24 -- all acceptance criteria met. Implemented via TDD.
