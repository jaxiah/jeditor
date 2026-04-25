## Parent Issue

[ISSUE-005-windows-terminal-backend.md](ISSUE-005-windows-terminal-backend.md)

## Interfaces

### `Key.t`

```ocaml
(* lib/terminal/key.ml *)

type t =
  | Char      of Uchar.t
  (** Printable characters without modifiers, such as letters, numbers, and punctuation. *)

  | Ctrl      of char
  (** Control + any ASCII character.
      Covers C-a ~ C-z as well as C-[ C-] C-\ C-^ C-_ etc.
      The value of char is the ASCII character itself (not the control code),
      e.g. C-a = Ctrl 'a', C-[ = Ctrl '['. *)

  | Meta      of Uchar.t
  (** Meta/Alt + character, e.g. M-a, M-x, M-< *)

  | Ctrl_meta of char
  (** Control + Meta + ASCII character, e.g. C-M-x *)

  | Arrow     of [ `Up | `Down | `Left | `Right ]
  | Function  of int
  (** F1~F12, values from 1~12. *)

  | Backspace
  | Delete
  | Enter
  | Tab
  | Escape
  | Page_up
  | Page_down
  | Home
  | End

val pp : Format.formatter -> t -> unit
(** Outputs a human-readable representation, such as "C-x", "M-a", "F5", "<backspace>".
    Used for displaying unbound key information in the status bar. *)

val of_string : string -> t option
(** Parses a key name from a configuration string, such as "C-x", "M-x", "<f5>".
    Returns None if unrecognizable. *)
```

---

### `Attr.t`

```ocaml
(* lib/terminal/attr.ml *)

type color =
  | Default
  | Black | Red | Green | Yellow | Blue | Magenta | Cyan | White
  | Bright of [ `Black | `Red | `Green | `Yellow
              | `Blue  | `Magenta | `Cyan | `White ]
  | Rgb of int * int * int
  (** True color. Downgrades to the nearest 256 colors if the terminal does not support it. *)

type t = {
  fg        : color;
  bg        : color;
  bold      : bool;
  italic    : bool;
  reverse   : bool;  (** Foreground/background swap, used for cursor and selection highlighting. *)
  underline : bool;
}

val default : t
(** fg = Default, bg = Default, all modifiers are false. *)
```

---

### `Input.S` (module type)

```ocaml
(* lib/terminal/input_intf.ml *)

module type S = sig
  type t

  val create   : unit -> (t, string) result
  (** Enter raw mode (Windows: disable ENABLE_PROCESSED_INPUT,
      enable ENABLE_VIRTUAL_TERMINAL_INPUT;
      Unix: tcsetattr TCSANOW sets raw flags).
      Returns an Error with a reason string on failure, does not throw exceptions. *)

  val next_key : t -> Key.t option
  (** Blocks and reads the next full key event.
      Handles multi-byte ESC sequences (arrow keys, Fn keys, Meta via ESC prefix).
      Returns None for EOF or unrecoverable errors. *)

  val close    : t -> unit
  (** Restore terminal to original mode. Safe to call multiple times (idempotent). *)
end
```

---

### `Terminal.S` (module type)

```ocaml
(* lib/terminal/terminal_intf.ml *)

module type S = sig
  type t

  val create      : unit -> (t, string) result
  (** Initializes the output:
      Windows: SetConsoleMode enables ENABLE_VIRTUAL_TERMINAL_PROCESSING;
      Unix: Writes ANSI sequences directly, no extra initialization needed.
      Maintains an internal output buffer; all write operations are buffered and output at once when flushed. *)

  val size        : t -> int * int
  (** Returns (cols, rows), the current physical dimensions of the terminal.
      Windows: GetConsoleScreenBufferInfo;
      Unix: ioctl TIOCGWINSZ. *)

  val move_to     : t -> row:int -> col:int -> unit
  (** Moves the cursor to (row, col), both 0-indexed. *)

  val hide_cursor : t -> unit
  val show_cursor : t -> unit

  val write_char  : t -> Uchar.t -> Attr.t -> unit
  (** Writes a Unicode character at the current cursor position with styles.
      CJK wide characters (display width = 2) take up two columns; the caller is responsible for column counting. *)

  val write_string : t -> string -> Attr.t -> unit
  (** Writes a UTF-8 string. The string must be valid UTF-8, otherwise behavior is undefined.
      Equivalent to calling write_char for each Uchar, but more efficient in implementation. *)

  val clear_line  : t -> unit
  (** Clears from the current cursor position to the end of the line (ESC[K). *)

  val clear_screen : t -> unit
  (** Clears the entire screen and moves the cursor to the top-left corner. Used for forced full redraws. *)

  val flush       : t -> unit
  (** Flushes the internal buffer to stdout. Called once per frame. *)

  val close       : t -> unit
  (** Restores terminal state (shows cursor, resets styles). Safe to call multiple times. *)
end
```

---

### Platform Dispatch (Compile-time)

```
lib/terminal/
├── key.ml
├── attr.ml
├── input_intf.ml
├── terminal_intf.ml
├── platform_unix.ml      (* Implement Input.S + Terminal.S, depends on Unix module *)
├── platform_win32.ml     (* Implement Input.S + Terminal.S, calls Win32 API via C stubs *)
└── dune
```

`dune` uses `select` to choose the platform implementation at compile-time:

```
(select platform.ml from
 ((= %{ocaml-config:system} "win32") -> platform_win32.ml)
 (-> platform_unix.ml))
```

`platform.ml` does not exist in the source code; it is generated by dune as a copy of the selected platform file at build time. Win32 C stub code is only compiled on Windows; Linux builds do not include any Win32 code.

---

### Smoke test program for verification

```
bin/term_test/
├── dune    (* (executable (name term_test) (libraries jeditor_terminal)) *)
└── main.ml (* Draws a colored grid + responds to keys, verifies that both backends work correctly *)
```

This program is not included in the final release and is only used for manual verification of ISSUE-005 acceptance criteria.

## Module Boundaries

| Module | Exposed | Hidden |
|------|---------|------|
| `Key` | `Key.t`, `pp`, `of_string` | ESC sequence parsing table, state machine |
| `Attr` | `Attr.t`, `Attr.default`, `color` | -- |
| `Input` | `Input.S` module type, `Input.create/next_key/close` | platform_unix/win32 internal implementation |
| `Terminal` | `Terminal.S` module type, `Terminal.create/...` | Output buffer, ANSI sequence concatenation, Win32 API calls |

The `jeditor_terminal` library only exposes these four modules. `platform_unix.ml` and `platform_win32.ml` do not appear in the library's public interface.

## Deep Module Opportunities

**`Input`'s ESC sequence state machine** is the deepest source of complexity in this issue. The raw byte sequences sent by the terminal (e.g., `\x1b[A` for up arrow, `\x1b[1;5C` for Ctrl+Right arrow) require a state machine with a timeout to distinguish between a "standalone Escape key" and the "start of an ESC sequence." This state machine is completely hidden behind `next_key`, and callers only ever see `Key.t`.

## Testing Priorities

1. **`Key.of_string` / `Key.pp` round-trip tests** -- Pure functions, no terminal required, written first.
2. **`Input` sequence parsing** -- Construct raw byte sequences, verify that `next_key` outputs the correct `Key.t` (can be simulated with a pipe for stdin, no real terminal needed).
3. **`Terminal` output buffering** -- Verify that no bytes are written to stdout before `flush`, and that the bytes after `flush` match the expected ANSI sequences.
4. **`term_test` manual verification** -- Run in a real Windows Terminal, visually inspect the colored grid and key response.

## Open Questions

- Win32's `ReadConsoleInput` returns mouse events and window size events; mouse events need to be silently discarded in `next_key`, and window size events converted to internal notifications (or temporarily discarded, to be handled in ISSUE-008). This behavior will be confirmed during implementation.
