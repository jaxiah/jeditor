## Parent Issue

[ISSUE-017-multi-cursor.md](ISSUE-017-multi-cursor.md)

## Interfaces

```
App.update(app_state, AddNextOccurrence) -> app_state * cmd
App.update(app_state, AddCursorBelow) -> app_state * cmd
```

Add a cursor for the next selected-text occurrence, or add a cursor one line
below the bottom-most cursor at the same display column.

```
Cursor.to_list(Cursor.t) -> Cursor.range list
Cursor.add(Cursor.range, Cursor.t) -> Cursor.t
Cursor.of_list(Cursor.range list) -> Cursor.t
```

Existing cursor primitives remain the public surface for sorted,
deduplicated, collision-merged cursor sets.

## Module Boundaries

- `App` owns command semantics: finding selected text, expanding columns, and
  applying edit/navigation commands across every cursor.
- `Cursor` remains the normalization boundary for sort/dedup/merge after edits.
- `Keymap` and `Registry` expose `add-next-occurrence` and `add-cursor-below`.
- The renderer highlights every cursor cell for visual distinction while the
  terminal cursor stays on the primary cursor.

## Deep Module Opportunities

The app-level edit helpers hide shifted multi-edit application behind small
functions. Existing commands can keep using the same actions while gaining
multi-cursor behavior.

## Testing Priorities

1. Next occurrence adds a selected range at the next match and leaves the
   original selection active, covering the first criterion.
2. Repeated next-occurrence invocations add further matches without disturbing
   existing cursors, covering the repeated invocation criterion.
3. Column expansion adds one cursor below at the same column and stops at the
   last line, covering both column criteria.
4. Insert, delete, and navigation operate on all cursors, covering simultaneous
   edit/navigation behavior.
5. Colliding cursors merge after edits, covering the inherited merge criterion.
6. `C-g` removes secondary cursors, covering dismissal.
7. Renderer cursor highlighting is verified manually because it depends on
   terminal cell attributes.

## Open Questions

The issue does not specify key chords. This design exposes commands through
`M-x` and binds `M-n` to next occurrence and `M-N` to cursor-below.
