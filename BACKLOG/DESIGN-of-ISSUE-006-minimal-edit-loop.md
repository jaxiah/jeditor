## Parent Issue

[ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## Interfaces

### `lib/core/app.mli`

```ocaml
open Jeditor_buffer
open Jeditor_terminal

type action =
  | Insert of Uchar.t
  | Backspace
  | Enter
  | Quit
  | Ignore

type app_state = {
  buffer : Buffer.t;
  cursor : Cursor.t;
  quit : bool;
}

val initial_state : app_state
(** Creates a fresh state with an empty buffer and cursor at offset 0. *)

val action_of_key : Key.t -> action
(** Translates a terminal keypress into an editor action. *)

val update : app_state -> action -> app_state
(** A pure function that applies an action to the current state, returning the new state. *)
```

`Buffer.t` is the abstract buffer type exposed by `jeditor_buffer`. No module outside `lib/buffer/` may reference `Buffer.SimpleBuffer` directly; the type is opaque and swappable.

### `bin/jeditor.ml`

The main loop implementation:

```ocaml
val main : unit -> unit
```

## Module Boundaries

- **`lib/core/app.ml`**: Pure state management. Defines the high-level `action` type and `app_state`. Contains the `update` function which encapsulates all logic for mutating the document state based on actions. Depends on `Buffer` and `Cursor`. No side effects.
- **`bin/jeditor.ml`**: Impure application shell. Handles terminal setup, the `Input.next_key` loop, drawing the current `app_state` to the `Terminal`, and cleanup on exit (including signals).

Rendering for this issue is intentionally minimal: clear screen, write buffer content line by line from the top-left, then move the cursor to its computed row/col position. No diffing, no gutter, no status bar -- these come in later issues.

## Deep Module Opportunities

The `update` function hides the complexity of keeping `Buffer` and `Cursor` in sync. When text is inserted, `update` advances the cursor. When text is deleted, it moves the cursor back.

## Testing Priorities

1. `update initial_state (Insert c)` -> buffer has character, cursor offset increases -- covers: "Typing printable characters inserts them at the cursor"; `update` is a pure function.
2. `update initial_state Backspace` -> buffer remains empty, cursor offset remains 0 -- covers: "Backspace deletes the character before the cursor" (bounds check at offset 0).
3. `update state (Insert c)` then `Backspace` -> buffer is back to empty, cursor back to 0 -- covers: "Backspace deletes the character before the cursor".
4. `update state Enter` -> buffer has newline inserted, cursor offset increases by 1 -- covers: "Enter inserts a newline".
5. `update state Quit` -> `quit` flag is set to true -- covers: "C-x C-c quits the editor cleanly".
