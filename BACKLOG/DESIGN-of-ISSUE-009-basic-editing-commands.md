## Parent Issue

[ISSUE-009-basic-editing-commands.md](ISSUE-009-basic-editing-commands.md)

## Interfaces

### `lib/core/app.mli` & `app.ml`

Extend the `action` and `app_state` types to handle navigation and scrolling.

```ocaml
type move_target =
  | CharF | CharB | LineN | LineP
  | WordF | WordB
  | LineStart | LineEnd
  | BufStart | BufEnd

type mode =
  ...
  | PendingMg        (** Waiting for second key of M-g sequence *)
  | PromptGotoLine   (** Entering line number in minibuffer *)

type action =
  ...
  | Move of move_target
  | DeleteForward
  | DeleteWordBack          (** M-Backspace: kill word before cursor (uses prev_word_boundary) *)
  | DeleteWordForward       (** M-d: kill word after cursor (uses next_word_boundary) *)
  | KillLine
  | JumpToLinePrompt        (** M-g: enter PendingMg mode *)
  | StartGotoLinePrompt     (** second key g in PendingMg: open PromptGotoLine *)
  | JumpToLine of int       (** jump cursor to 1-indexed line, clamped to buffer bounds *)
  ...

type app_state = {
  ...
  scroll_top_line : int; (** Index of the first visible line in the viewport *)
}
```

### `lib/buffer/buffer.mli` & `buffer.ml`

Add specialized inspection functions for advanced navigation.

```ocaml
val is_word_char : Uchar.t -> bool
(** Implementation of Emacs word boundary logic: alphanumeric only. *)

val first_non_whitespace : line:int -> t -> int
(** Returns the byte column of the first non-space/tab character on [line]. *)

val next_word_boundary : offset:int -> t -> int
(** Finds the start of the next word. *)

val prev_word_boundary : offset:int -> t -> int
(** Finds the start of the previous word. *)
```

---

## Module Boundaries

- **`App`**: Owns the high-level logic for binding keys to actions and updating the `scroll_top_line` invariant.
- **`Buffer`**: Remains the authority on text content and coordinate mapping. Added logic for word/indentation scanning.
- **`bin/jeditor.ml`**: The renderer now uses `scroll_top_line` to slice the buffer for display.

---

## Deep Module Opportunities

**`App.ensure_cursor_visible`**: A private helper that computes the necessary `scroll_top_line` based on the cursor position and window height. This keeps the "scroll-follows-cursor" policy centralized and easy to test.

---

## Testing Priorities

1. **`Buffer` word boundaries**: Verify that `next_word_boundary` and `prev_word_boundary` skip punctuation and whitespace correctly. (Acceptance: "M-f/M-b skip punctuation and whitespace consistently")
2. **`Buffer` indentation**: Verify `first_non_whitespace` handles empty lines and lines with various leading whitespaces. (Acceptance: "C-a moves to the first non-whitespace character")
3. **`App` Navigation Actions**: Verify `update` correctly modifies the cursor offset for each `move_target`. (Acceptance: "All navigation commands move the cursor to the correct byte offset")
4. **`App` Scrolling**: Verify that `update` adjusts `scroll_top_line` when the cursor moves out of the current viewport. (Acceptance: "Viewport scrolls to keep cursor visible")
5. **`App` Deletion Actions**: Verify `KillLine`, `DeleteForward`, `DeleteWordBack`, and `DeleteWordForward` behavior, especially edge cases like end-of-buffer and position 0. (Acceptance: "C-k on an empty line deletes the newline", "C-d at end of buffer does nothing", "M-Backspace delete word backward", "M-d delete word forward")
6. **`App` Goto Line**: Verify `JumpToLinePrompt`→`PendingMg`, `StartGotoLinePrompt`→`PromptGotoLine`, `JumpToLine n` cursor placement, and out-of-range clamping. (Acceptance: "M-g g prompts for a line number and jumps correctly")

---

## Open Questions

- Should `C-a` toggle between indentation and column 0 immediately, or only on consecutive presses? Design: Toggle on consecutive presses.
- How many lines of "context" (padding) should we keep when scrolling? Design: 0 lines for now (strict scroll-to-edge).
