## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Define the `Buffer.S` module signature and provide the first concrete implementation backed by a `string array` (one entry per line). This is the most important interface in the entire project -- the signature must be stable enough that swapping the implementation for a Rope or Piece Tree later requires zero changes to callers.

The interface is built around **byte offsets** as the sole coordinate system. Line/column coordinates are derived from byte offsets on demand; they are never stored as primary state. All operations are pure functions returning new `t` values.

Design the signature with reference to how Helix (ropey), Zed (SumTree), and VS Code (PieceTree) expose their buffer APIs: prefer offset-based primitives over line/column primitives, and ensure the interface supports efficient bulk reads for rendering.

## Acceptance criteria

- [x] `Buffer.S` signature is defined in a `.mli` file and covers: `empty`, `of_string`, `to_string`, `insert`, `delete`, `slice`, `length`, `line_count`, `line_to_offset`, `offset_to_line_col`
- [x] `SimpleBuffer` implements `Buffer.S` using `string array`
- [x] All operations preserve valid UTF-8 -- no operation may split a multi-byte codepoint
- [x] Alcotest suite passes for: insert/delete at start, middle, end of buffer; operations spanning line boundaries; empty buffer edge cases; round-trip `of_string` -> multiple edits -> `to_string`; `line_to_offset` and `offset_to_line_col` accuracy on multi-line content; CJK characters (3-byte UTF-8 sequences)
- [x] No other module references `SimpleBuffer` directly -- all callers go through `Buffer.S`

## Blocked by

None -- can start immediately (run in parallel with ISSUE-004 and ISSUE-005).

## User stories addressed

- Foundational prerequisite for user stories 1-46.

## Completed

2026-04-25 -- all acceptance criteria met. Implemented via TDD. The Buffer.S interface is implemented with SimpleBuffer and full testing covering CJK chars, multi-line edits, and offset boundary checks.
