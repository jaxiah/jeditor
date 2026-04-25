## Parent Issue

[ISSUE-015-window-splitting.md](ISSUE-015-window-splitting.md)

## Goal

Add a frame tree that supports Emacs-style split windows. Phase 1 keeps the
existing single-buffer editor model: every window points at buffer id `0`, but
each window has its own scroll position and focus identity. This gives the
renderer enough structure to paint multiple views of the same buffer and gives
future multi-buffer work a place to attach buffer ids.

## Frame Model

New module: `lib/core/frame.ml`.

```ocaml
type orientation = Horizontal | Vertical

type window = {
  id : int;
  buffer_id : int;
  scroll_top_line : int;
}

type node =
  | Leaf of window
  | Split of orientation * float * node * node

type t = {
  root : node;
  focused : int;
  next_id : int;
}
```

Conventions:

- `Horizontal` means top/bottom (`C-x 2`).
- `Vertical` means left/right (`C-x 3`).
- `ratio` is the first child share. Phase 1 always creates `0.5` splits.
- Focus order is the left-to-right/top-to-bottom leaf order.

## Frame Operations

```ocaml
val single : buffer_id:int -> t
val focused_window : t -> window
val update_focused : (window -> window) -> t -> t
val split_focused : orientation -> t -> t
val focus_next : t -> t
val close_focused : t -> t
val close_others : t -> t
val leaves : t -> window list
val layouts : cols:int -> rows:int -> t -> (window * rect) list
```

`close_focused` on the last remaining window is a no-op. Closing a focused leaf
promotes its sibling and focuses the first leaf in the promoted subtree.

`layouts` returns rectangles for text plus each window's local status bar. The
renderer is responsible for drawing split dividers between child rectangles.

## App Integration

Add fields/actions:

```ocaml
frame : Frame.t

| SplitWindowHorizontal
| SplitWindowVertical
| FocusNextWindow
| CloseWindow
| CloseOtherWindows
```

`scroll_top_line` remains as a compatibility mirror for tests and status logic,
but the focused window's `scroll_top_line` is authoritative. `ensure_cursor_visible`
updates the focused window only, so two windows viewing the same buffer can scroll
independently.

## Keymap / Registry

| Key | Command |
| --- | --- |
| `C-x 2` | `split-window-below` |
| `C-x 3` | `split-window-right` |
| `C-x o` | `other-window` |
| `C-x 0` | `delete-window` |
| `C-x 1` | `delete-other-windows` |

All names are registered for `M-x`.

## Rendering

`bin/jeditor.ml` asks `Frame.layouts` for window rectangles. Each window:

- renders its own gutter;
- uses its own `scroll_top_line`;
- gets a local status bar on the last row of its rectangle;
- uses a brighter/reverse status bar when focused.

Split dividers are ASCII `-` for horizontal splits and `|` for vertical splits.
They occupy rows/columns between child rectangles and do not overlap text.

## Tests

Frame unit tests:

1. `single` creates one focused window.
2. Horizontal split creates two leaves with same buffer id.
3. Vertical split creates two leaves with same buffer id.
4. Nested split creates three leaves.
5. `focus_next` cycles through leaves.
6. `close_focused` removes a window and is a no-op for the last window.
7. `close_others` leaves only the focused window.
8. Updating focused scroll affects only focused window.
9. Layouts divide terminal space without overlap.

App tests:

1. `C-x 2`, `C-x 3`, `C-x o`, `C-x 0`, `C-x 1` dispatch correctly.
2. Focused-window scrolling is independent.
3. Window commands are present in the registry.

## Manual Test

1. Open a file and press `C-x 2`: two stacked windows show the same buffer.
2. Press `C-x 3` in one window: a nested third pane appears.
3. Press `C-x o` to cycle focus; focused status bar changes.
4. Move down enough to scroll one pane, cycle to another pane, and verify its
   scroll position is unchanged.
5. Press `C-x 0` to close the current pane; `C-x 1` to keep only the current pane.
