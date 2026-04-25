## Parent Issue

[ISSUE-013-selection-clipboard.md](ISSUE-013-selection-clipboard.md)

## Goal

Add Emacs-style mark/region selection and a phase-1 kill ring. The editor
stores one optional mark offset and one kill-ring entry. When mark and cursor
span a non-empty range, the renderer highlights that region. Region commands
copy, cut, and yank text through the kill ring, while normal edit history stays
undoable through the existing snapshot mechanism.

## App State

Add fields to `App.app_state`:

```ocaml
mark : int option
kill_ring : string option
last_action_was_kill : bool
```

- `mark = Some offset` activates the region with the primary cursor.
- `kill_ring = Some text` stores the single clipboard entry.
- `last_action_was_kill` supports Emacs-style consecutive `C-k` append. It is
  set only after a successful `KillLine`; unrelated actions reset it.

Region boundaries are always normalized:

```ocaml
let region_bounds st =
  match st.mark with
  | None -> None
  | Some mark ->
      let head = (Cursor.primary st.cursor).head in
      if head = mark then None else Some (min mark head, max mark head)
```

## Actions

Add actions:

```ocaml
| ToggleMark
| KillRegion
| CopyRegion
| Yank
| Cancel
```

Semantics:

- `ToggleMark`: if no mark, set it to the primary cursor head; if mark exists,
  clear it.
- `Cancel`: clears mark and pending user-visible message in Normal mode. Prompt
  modes continue to use `MinibufCancel`.
- `CopyRegion`: copy normalized non-empty region to `kill_ring`; buffer and undo
  history are unchanged.
- `KillRegion`: copy normalized non-empty region, delete it, move cursor to
  region start, clear mark, and push exactly one undo snapshot.
- `Yank`: insert `kill_ring` text at every active cursor position. For phase 1,
  apply cursors from left to right while accounting for offset shifts. The whole
  yank records one undo snapshot. If the kill ring is empty, do nothing.
- `KillLine`: store killed text in `kill_ring`; if the immediately previous
  successful action was also `KillLine`, append to the existing kill entry.

Any buffer-modifying action other than successful `KillLine` resets
`last_action_was_kill` to false. Copying a region also resets it because it is
not part of a consecutive line kill sequence.

## Keymap And Registry

Add built-in command names:

| Key               | Command            |
| ----------------- | ------------------ |
| `C-Space` / `C-@` | `set-mark-command` |
| `C-w`             | `kill-region`      |
| `M-w`             | `copy-region`      |
| `C-y`             | `yank`             |

Register all names in `initial_state.registry` so they are available via `M-x`.

## Rendering

`bin/jeditor.ml` computes a highlighted byte range from `state.mark` and the
primary cursor. For each visible line, it writes text in chunks:

- normal attribute outside the selected byte range;
- reverse-video attribute inside the selected byte range.

This first implementation keeps the existing byte-based truncation model. It is
consistent with current rendering, which already truncates by bytes rather than
display cells.

## Tests

Add focused App tests:

1. `C-@` toggles mark at the cursor and toggles it off on second press.
2. Region bounds work whether mark is before or after cursor.
3. `C-w` kills selected text, stores kill ring, clears mark, and undo restores.
4. `M-w` copies selected text without modifying the buffer or undo stack.
5. `C-y` inserts kill ring text at the cursor.
6. `C-y` inserts kill ring text at multiple active cursors.
7. `C-g` clears active mark.
8. Consecutive `C-k` appends killed text into the kill ring.
9. New commands are present in the built-in registry.

Rendering is covered by a small pure helper for range intersection if extracted;
otherwise manual testing verifies the highlighted region.

## Manual Test

1. Open a file.
2. Move to a position, press `C-Space`, move the cursor, and confirm the region
   is highlighted.
3. Press `M-w`, move elsewhere, press `C-y`; copied text appears.
4. Select again, press `C-w`; text disappears. Press `C-/`; text returns.
5. Press `C-k` on two consecutive lines, then `C-y`; both killed chunks are
   yanked together.
