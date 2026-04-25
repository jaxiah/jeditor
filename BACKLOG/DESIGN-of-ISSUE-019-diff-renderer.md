## Parent Issue

[ISSUE-019-diff-renderer.md](ISSUE-019-diff-renderer.md)

## Interfaces

```
Diff_renderer.cell = { text: string; attr: Attr.t }
Diff_renderer.frame
Diff_renderer.state
Diff_renderer.blank(cols: int, rows: int) -> frame
Diff_renderer.set(row: int, col: int, cell: cell, frame) -> frame
Diff_renderer.empty_state -> state
Diff_renderer.render(?force: bool, state, frame) -> string * state
```

Render compares the new frame against the previous frame stored in `state`.
It emits ANSI only for changed cells, or a full clear/redraw when forced or
when dimensions change.

## Module Boundaries

- `Diff_renderer` is pure and testable. It owns previous-frame storage,
  resize invalidation, and ANSI emission for changed cells.
- `bin/jeditor.ml` remains responsible for translating editor state into
  terminal cells and deciding when to force a redraw after resize.
- `Terminal` remains the imperative stdout boundary.

## Deep Module Opportunities

The renderer hides terminal diff complexity behind one small `render` function.
The rest of the editor can build a full logical frame without knowing whether
the physical terminal will receive a full or incremental update.

## Testing Priorities

1. Rendering the same static frame twice emits bytes the first time and zero
   bytes the second time, covering the static-screen criterion.
2. Changing one character emits one cell update, covering incremental typing.
3. Moving a cursor represented as reverse-video cells updates the previous and
   new cursor cells, covering cursor movement.
4. Forced redraw emits a clear-screen sequence and resynchronizes state,
   covering forced redraw.
5. Dimension changes force a full redraw and rebuild previous-frame state,
   covering resize invalidation.
6. Full-frame and diff-frame final states are cell-identical, covering visual
   equivalence.

## Open Questions

None.
