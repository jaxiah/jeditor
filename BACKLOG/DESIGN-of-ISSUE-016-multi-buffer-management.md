## Parent Issue

[ISSUE-016-multi-buffer-management.md](ISSUE-016-multi-buffer-management.md)

## Interfaces

```
type buffer_entry
```

An open buffer record containing identity, display name, optional file path,
content, cursor, modified flag, and per-buffer undo/redo stacks.

```
App.open_file(path: string, content: string, app_state) -> app_state
```

Open a file into the buffer table, or switch to the existing buffer with the
same path without creating a duplicate.

```
App.update(app_state, SwitchBuffer of string) -> app_state * cmd
App.update(app_state, KillBuffer of string) -> app_state * cmd
App.update(app_state, ShowBufferList) -> app_state * cmd
```

Switch the focused window to a named buffer, kill a named buffer after any
required confirmation, and create or refresh the `*Buffer List*` buffer.

```
Frame.set_focused_buffer(buffer_id: int, Frame.t) -> Frame.t
Frame.replace_buffer(old_id: int, new_id: int, Frame.t) -> Frame.t
```

Update window-to-buffer associations without exposing the frame tree traversal
to `App`.

## Module Boundaries

- `App` owns the buffer table and lifecycle rules. Existing editing commands
  keep operating on the focused working copy, and `App` synchronizes that copy
  into the buffer table before switching focus or buffers.
- `Frame` owns window layout and buffer-id replacement helpers.
- `Keymap` owns `C-x b`, `C-x C-b`, and `C-x k` bindings.
- `bin/jeditor.ml` renders the buffer associated with each window by asking the
  app state for the window's current buffer entry.

## Deep Module Opportunities

The buffer table hides multi-buffer persistence behind a small `App` surface:
editing commands remain simple, while window focus, buffer switching, and
killing buffers share one save/activate path.

## Testing Priorities

1. `*scratch*` is the default unnamed buffer, covering the scratch acceptance
   criterion.
2. `C-x b` prompts, completes open buffer names, and switches the focused
   window, covering the switch-buffer and completion criterion.
3. `C-x C-b` creates a buffer list with name, file path, and modified state,
   covering the buffer-list criterion.
4. `C-x k` prompts, confirms dirty kills, and replaces killed buffers in every
   window, covering the kill lifecycle criteria.
5. `open_file` reuses an already loaded file buffer, covering duplicate-open
   prevention.
6. Edits and undo stacks remain independent per buffer, covering independent
   undo history.

## Open Questions

None. This implementation treats `*Buffer List*` as a generated read-only-style
buffer for now, but it is still represented by the same buffer table.
