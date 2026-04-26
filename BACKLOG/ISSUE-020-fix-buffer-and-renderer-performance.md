# ISSUE-020: Fix O(N) buffer operations and O(N²) renderer frame building

## Problem

Opening an 800-line file makes the editor noticeably sluggish. Profiling points to two independent bottlenecks:

### Bottleneck 1: `SimpleBuffer.insert` / `delete` flatten the entire file every keystroke

```ocaml
let insert ~offset s t =
  let full_str = to_string t in   (* String.concat "\n" over all lines *)
  ...
  of_string (before ^ s ^ after)  (* String.split_on_char '\n' again *)
```

For an 800-line × 80-char file (~64 KB), every keystroke allocates ~192 KB and rebuilds the entire `string array`. `next_word_boundary` and `prev_word_boundary` also call `to_string`.

**Expected complexity**: O(line_len) for intra-line edits, O(line_count) for cross-line edits.
**Actual complexity**: O(total_bytes) for every operation.

### Bottleneck 2: `Diff_renderer.set` copies the entire cell array on every cell write

```ocaml
let set ~row ~col cell frame =
  let cells = Array.copy frame.cells in   (* copies cols×rows cells every call *)
  cells.(index frame ~row ~col) <- cell;
  { frame with cells }
```

`jeditor.ml` calls `set` once per character per line (via `put_text`) and once per column (via `clear_line`).
For an 80×24 terminal: ~1920 calls × copying 1920 cells = ~3.7 M cell copies per rendered frame.

**Expected complexity**: O(cols × rows) to build a frame.
**Actual complexity**: O((cols × rows)²).

## Scope

- `lib/buffer/buffer.ml`: rewrite `insert`, `delete`, `next_word_boundary`, `prev_word_boundary` to operate at the line-array level without flattening.
- `lib/terminal/diff_renderer.ml`: change frame construction to use a mutable cell array internally; expose the finished frame as an immutable value (or keep mutable but document it).
- No changes to `buffer.mli` or `diff_renderer.mli` — the public interface contracts stay the same.
- All existing tests must remain green.

## Acceptance criteria

- [ ] `dune test` fully green
- [ ] Opening a file with 800+ lines: typing feels instant (no perceptible lag)
- [ ] `SimpleBuffer.insert` / `delete` no longer call `to_string` for intra-line edits
- [ ] `Diff_renderer` frame construction does not call `Array.copy` per cell

## Notes

- See `BACKLOG/REFERENCE-buffer-data-structures.md` for long-term data structure strategy.
- The `buffer.mli` module signature is the stable interface; this fix stays within `SimpleBuffer` (the current `include`d implementation). If we later upgrade to Piece Table, only `buffer.ml` changes.
