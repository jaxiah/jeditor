## Parent Issue

[ISSUE-010-undo-redo.md](ISSUE-010-undo-redo.md)

## Interfaces

### `lib/core/app.mli` & `app.ml`

Extend the `app_state` and `action` to handle history.

```ocaml
type snapshot = {
  buffer : Buffer.t;
  cursor : Cursor.t;
}

type action =
  ...
  | Undo
  | Redo
  ...

type app_state = {
  ...
  undo_stack : snapshot list;
  redo_stack : snapshot list;
}
```

## Module Boundaries

- **`App`**: Solely responsible for capturing snapshots before mutations and managing the history stacks in the `update` function.
- **`Buffer` & `Cursor`**: Remain pure and unaware of history. Their immutability is the foundation for the snapshot strategy.

## Deep Module Opportunities

The snapshot mechanism is already a high-level abstraction ("Deep Module" principle): the history management is just a list of pointers to immutable data structures, hiding the complexity of delta calculation (which OCaml's GC handles via structure sharing).

## Testing Priorities

1. **Simple Undo**: Perform one edit, trigger `Undo`, verify buffer and cursor return to initial state. (Acceptance: "C-/ undoes the most recent buffer-modifying command")
2. **Undo Chain**: Perform multiple edits, trigger `Undo` multiple times, verify step-by-step restoration. (Acceptance: "Repeated C-/ undoes further back through history")
3. **Redo**: Perform an edit, `Undo`, then `Redo`, verify the edit is reapplied. (Acceptance: "C-? (or M-\_) redoes the last undone command")
4. **History Forking**: Perform `Undo`, then make a _new_ edit. Verify `redo_stack` is cleared. (Acceptance: "Any new edit after an undo clears the redo stack")
5. **Initial State**: Verify `Undo` on an empty stack does nothing. (Acceptance: "Undo on a freshly opened buffer does nothing")
6. **Cursor Restoration**: Verify that `Undo` restores the cursor position exactly as it was before the edit. (Acceptance: "Undo/redo correctly restores cursor position")

## Open Questions

- Terminal keybinding for `C-/`: In many terminals, `C-/` is sent as `\x1f` (Unit Separator). Our `Escape_parser` needs to handle this.
- Keybinding for `C-?`: This is often `\x7f` (Backspace/Delete) in some terminals. We will use `M-_` as the primary Redo binding to avoid conflicts.
