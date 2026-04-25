## Parent Issue

[ISSUE-008-status-bar-line-numbers.md](ISSUE-008-status-bar-line-numbers.md)

## Interfaces

### `lib/core/view.ml` (new)

Pure layout computations -- no terminal I/O, no app_state dependency.

```ocaml
val gutter_width : line_count:int -> int
(** Column width of the line-number gutter for a buffer with [line_count] lines.
    Format: right-aligned number + one space.
    Examples: 1-9 -> 2, 10-99 -> 3, 100-999 -> 4. *)

val status_text :
  file_path:string option ->
  modified:bool ->
  cursor_line:int ->       (** 0-indexed *)
  cursor_display_col:int ->
  line_count:int ->
  cols:int ->
  string
(** Returns a string of exactly [cols] display-columns for the status bar.
    Layout: left side = "{filename|[No Name]}{' *' if modified}"
            right side = "{line+1}:{col+1}  L {line_count}"
    The two sides are separated by spaces; the whole string is padded or
    truncated to exactly [cols] columns. *)
```

`View` has no dependencies beyond the OCaml stdlib.

---

### `lib/terminal/wcwidth.ml` (new)

```ocaml
val char_width : Uchar.t -> int
(** Display width of a single Unicode character: 2 for wide chars (CJK,
    full-width forms, etc.), 0 for control/combining, 1 for everything else.
    Delegates to [Uucp.Break.tty_width_hint]. *)

val string_display_width : string -> int
(** Total display column width of a UTF-8 string. *)

val display_col_of_byte_col : string -> byte_col:int -> int
(** Given a UTF-8 line string and a byte offset within it, return the
    corresponding display column (sum of [char_width] for all codepoints
    before [byte_col]). Used to map cursor byte offset -> terminal column. *)
```

Depends on `uucp` (same author as `uutf`/`uuseg`).

---

### `lib/terminal/terminal_stubs.c` -- Unix `get_term_size`

Add real `ioctl TIOCGWINSZ` implementation under `#else`:

```c
#else  /* Unix */
#include <sys/ioctl.h>
#include <unistd.h>
CAMLprim value jeditor_get_term_size(value unit) {
    struct winsize ws;
    int cols = 80, rows = 24;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) {
        cols = ws.ws_col; rows = ws.ws_row;
    }
    /* return (cols, rows) tuple */
}
```

---

### `lib/terminal/platform_unix.ml` -- two changes

**`size`**: replace hardcoded `(80, 24)` with `get_term_size ()` (external).

**`next_key`**: do NOT retry on EINTR -- return `None` instead:
```ocaml
with Unix.Unix_error (Unix.EINTR, _, _) -> None
```
This allows SIGWINCH to interrupt the blocking read and propagate up to the main loop.

---

### `bin/jeditor.ml` -- render + resize

```ocaml
let needs_redraw = ref false

(* SIGWINCH: set flag; safe to call on Windows (signal never fires there) *)
let () =
  Sys.set_signal Sys.sigwinch
    (Sys.Signal_handle (fun _ -> needs_redraw := true))

let render term state =
  let (cols, rows) = Terminal.size term in
  let gutter = View.gutter_width ~line_count:(Buffer.line_count state.App.buffer) in
  let _text_cols = cols - gutter in
  (* 1. hide cursor, clear screen *)
  (* 2. for each visible line: write gutter (right-aligned number, dim attr)
        then write line content (truncated to text_cols) *)
  (* 3. write status bar on row (rows-1) *)
  let (byte_line, byte_col) =
    Buffer.offset_to_line_col
      ~offset:(Cursor.primary state.App.cursor).head
      state.App.buffer
  in
  let line_str = Buffer.slice
    ~start:(Buffer.line_to_offset ~line:byte_line state.App.buffer)
    ~length:byte_col state.App.buffer
  in
  let dcol = Jeditor_terminal.Wcwidth.display_col_of_byte_col line_str ~byte_col in
  (* status bar text depends on mode *)
  let stext = match state.App.mode with
    | App.PromptSaveAs -> "Save as: " ^ state.App.minibuf ^ "_"
    | App.ConfirmQuit  -> "Unsaved changes \xe2\x80\x94 quit anyway? (y/n)"
    | _ ->
        if state.App.message <> "" then state.App.message
        else View.status_text
          ~file_path:state.App.file_path ~modified:state.App.modified
          ~cursor_line:byte_line ~cursor_display_col:dcol
          ~line_count:(Buffer.line_count state.App.buffer) ~cols
  in
  Terminal.move_to term ~row:(rows-1) ~col:0;
  Terminal.write_string term stext Attr.default;
  (* position cursor in text area *)
  Terminal.move_to term ~row:byte_line ~col:(gutter + dcol);
  Terminal.show_cursor term;
  Terminal.flush term

(* main loop: re-render on needs_redraw *)
while !running do
  if !needs_redraw then begin
    needs_redraw := false;
    render term !state
  end;
  match Input.next_key input with
  | None -> ()        (* EINTR from SIGWINCH on Linux; loop again *)
  | Some key -> ...
done
```

---

## Module Boundaries

| Module | Change |
|--------|--------|
| `lib/core/view.ml` | **New** -- pure layout functions, no deps |
| `lib/terminal/wcwidth.ml` | **New** -- `uucp`-backed display width |
| `lib/terminal/terminal_stubs.c` | Add Unix `ioctl TIOCGWINSZ` |
| `lib/terminal/platform_unix.ml` | Real `size`; EINTR -> `None` in `next_key` |
| `lib/terminal/dune` | Add `wcwidth` to modules; add `uucp` to libraries |
| `lib/core/dune` | Add `view` to modules |
| `jeditor.opam` | Add `uucp` |
| `bin/jeditor.ml` | New render with gutter + real status bar; SIGWINCH; resize loop |

File I/O remains entirely in `bin/jeditor.ml`. The renderer remains in `bin/jeditor.ml` for now; it will be extracted to a `Renderer` library module in a later issue when diffing is introduced.

## Deep Module Opportunities

**`View.status_text`** hides all the padding, truncation, and column-counting logic behind a single call. When ISSUE-018 (plugin system) is implemented, this function becomes the insertion point for a `status_bar_providers` hook -- plugins register functions, the renderer collects their contributions, and `View.status_text` formats the result. No other module needs to change.

**`Wcwidth.display_col_of_byte_col`** hides the UTF-8 decode + width-sum loop. The caller (renderer) just passes a line string and a byte offset; it never needs to know about Uucp internals.

## Testing Priorities

1. `View.gutter_width` returns correct column count for boundary values (1, 9, 10, 99, 100, 1000) -- covers: "gutter width adjusts automatically as the file grows past 9, 99, 999 lines".
2. `View.status_text` contains filename when file_path is set; `[No Name]` otherwise -- covers: "status bar shows filename (or `[No Name]`)".
3. `View.status_text` contains `*` when modified=true; no `*` when false -- covers: "status bar `**` modified indicator" (using single `*` here; the issue says `**` -- to confirm).
4. `View.status_text` contains `{line+1}:{col+1}` correctly -- covers: "cursor position as line:col".
5. `View.status_text` output length equals [cols] argument -- covers: "text area correctly excludes gutter and status bar rows" (status bar stays in its row).
6. `Wcwidth.char_width` returns 2 for a CJK codepoint, 1 for ASCII -- covers: "cursor column counts display columns, CJK = 2 columns".
7. `Wcwidth.display_col_of_byte_col` on a mixed ASCII+CJK string returns correct display column -- covers: "cursor column in status bar counts display columns, not bytes".
8. [manual] Line numbers visible in gutter, right-aligned -- covers: "line numbers displayed in a right-aligned gutter".
9. [manual] Resize terminal -> next keypress redraws correctly -- covers: "resizing the terminal window redraws correctly without corruption".

## Open Questions

- ISSUE says status bar shows `**` (two asterisks) for modified. ISSUE-007 used single `*`. Which convention to follow? Design uses single `*`; confirm before TDD.
- Windows resize without a keypress will not immediately redraw (SIGWINCH doesn't fire on Windows). This is an accepted limitation for now; future fix is isolated to `platform_win32.ml`.
