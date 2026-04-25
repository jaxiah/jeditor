## Parent Issue

[ISSUE-007-file-open-save.md](ISSUE-007-file-open-save.md)

## Interfaces

### `lib/core/app.mli`

```ocaml
open Jeditor_buffer
open Jeditor_terminal

type mode =
  | Normal
  | PendingCx      (** C-x pressed; awaiting second key *)
  | PromptSaveAs   (** C-x C-w: minibuf accumulates the save path *)
  | ConfirmQuit    (** C-x C-c with unsaved changes: waiting for y/n *)

type effect =
  | Noop
  | WriteFile of { path : string; content : string }

type action =
  | Insert of Uchar.t
  | Backspace
  | Enter
  | PendingCx          (** C-x pressed in Normal mode *)
  | Save               (** C-x C-s: save to current file_path *)
  | StartSaveAs        (** C-x C-w: enter PromptSaveAs mode *)
  | TryQuit            (** C-x C-c or Escape: quit if clean, else ConfirmQuit *)
  | MinibufAppend of Uchar.t
  | MinibufBackspace
  | MinibufConfirm     (** Enter in PromptSaveAs -> emits WriteFile effect *)
  | MinibufCancel      (** C-g; also 'n' in ConfirmQuit *)
  | WriteDone of string   (** IO layer: save succeeded, carries final path *)
  | WriteError of string  (** IO layer: save failed, carries error message *)
  | Quit
  | Ignore

type app_state = {
  buffer    : Buffer.t;
  cursor    : Cursor.t;
  quit      : bool;
  file_path : string option;
  modified  : bool;
  mode      : mode;
  minibuf   : string;
  (** Accumulates save-as path in PromptSaveAs; unused in other modes. *)
  message   : string;
  (** Ephemeral bottom-of-screen message ("Saved." / error text).
      Cleared on the next non-Ignore action. *)
}

val initial_state : app_state
(** Empty unnamed buffer, cursor at 0, unmodified. *)

val state_with_file : path:string -> content:string -> app_state
(** Pure constructor: load file content into a new app_state.
    modified = false; file_path = Some path. *)

val action_of_key : mode -> Key.t -> action
(** Mode-aware key -> action dispatch (replaces ISSUE-006's Key.t -> action).
    The full keymap system arrives in ISSUE-011; this is the interim impl. *)

val update : app_state -> action -> app_state * effect
(** Pure state transition. Returns the new state and an optional IO effect.
    The caller (bin/jeditor.ml) executes the effect and feeds results back
    as WriteDone / WriteError actions. *)
```

#### `action_of_key` dispatch table

| mode | key | action |
|------|-----|--------|
| Normal | `Ctrl 'x'` | `PendingCx` |
| Normal | `Ctrl 'c'` / `Escape` | `TryQuit` |
| Normal | printable char | `Insert c` |
| Normal | `Backspace` / `Delete` | `Backspace` |
| Normal | `Enter` | `Enter` |
| Normal | other | `Ignore` |
| PendingCx | `Ctrl 's'` | `Save` |
| PendingCx | `Ctrl 'w'` | `StartSaveAs` |
| PendingCx | `Ctrl 'c'` | `TryQuit` |
| PendingCx | other | `Ignore` (update resets mode to Normal) |
| PromptSaveAs | `Enter` | `MinibufConfirm` |
| PromptSaveAs | `Backspace` | `MinibufBackspace` |
| PromptSaveAs | `Ctrl 'g'` | `MinibufCancel` |
| PromptSaveAs | printable char | `MinibufAppend c` |
| PromptSaveAs | other | `Ignore` |
| ConfirmQuit | `Char 'y'` / `Char 'Y'` | `Quit` |
| ConfirmQuit | other | `MinibufCancel` |

#### `update` state-machine rules (summary)

- Any `Insert` / `Backspace` / `Enter` in Normal mode: sets `modified = true`, clears `message`.
- `PendingCx`: mode -> PendingCx, message cleared.
- `Save` with `file_path = Some p`: returns `WriteFile {path=p; content}`. If `file_path = None`, falls back to `StartSaveAs`.
- `Save` / `StartSaveAs` with `file_path = None`: mode -> PromptSaveAs, minibuf = "".
- `StartSaveAs`: mode -> PromptSaveAs, minibuf = "".
- `MinibufConfirm` in PromptSaveAs: returns `WriteFile {path=minibuf; content}`, mode -> Normal.
- `MinibufCancel`: mode -> Normal, minibuf = "", message = "".
- `WriteDone path`: file_path = Some path, modified = false, message = "Saved.".
- `WriteError msg`: message = msg, modified unchanged.
- `TryQuit` when `modified = false`: quit = true.
- `TryQuit` when `modified = true`: mode -> ConfirmQuit.
- `Quit` (from ConfirmQuit 'y'): quit = true.
- `Ignore` in PendingCx: mode -> Normal (consumes the pending prefix).

---

### `bin/jeditor.ml` -- main loop change

```ocaml
(* Key dispatch is now mode-aware *)
let action = App.action_of_key !state.App.mode key in
let (new_state, effect) = App.update !state action in
state := new_state;
(match effect with
 | App.WriteFile { path; content } ->
     (try
       Out_channel.(with_open_text path (fun oc -> output_string oc content));
       state := fst (App.update !state (App.WriteDone path))
     with exn ->
       state := fst (App.update !state (App.WriteError (Printexc.to_string exn))))
 | App.Noop -> ())
```

File loading on startup (before the main loop):
```ocaml
let state = ref (match Sys.argv with
  | [| _; path |] ->
      (try
        let content = In_channel.(with_open_text path input_all) in
        App.state_with_file ~path ~content
      with exn ->
        { App.initial_state with
          App.message = "Error opening file: " ^ Printexc.to_string exn })
  | _ -> App.initial_state)
```

### Renderer changes (bin/jeditor.ml)

The last terminal row is reserved. Content is rendered to rows `0 .. (term_rows - 2)`.
Bottom row shows one of:
- `PromptSaveAs`: `Save as: {minibuf}▌`
- `ConfirmQuit`: `Unsaved changes -- quit anyway? (y/n)`
- message != "": the message string
- otherwise: {filename or "[No Name]"}{" *" if modified}

## Module Boundaries

| Module | Change |
|--------|--------|
| `lib/core/app.ml` | Add `mode`, `effect` types; extend `action` and `app_state`; change `update` signature to return `(app_state * effect)`; add `state_with_file`; make `action_of_key` mode-aware |
| `bin/jeditor.ml` | Handle `effect` after each `update`; parse `Sys.argv`; add status bar / minibuf rendering |

No new library modules. File I/O stays entirely in `bin/jeditor.ml` (the imperative shell).

## Deep Module Opportunities

`update` encapsulates the entire mode state-machine. The `bin/jeditor.ml` never inspects `mode` or `minibuf` directly -- it only reads `quit`, `message`, `file_path`, `modified` for rendering, and feeds back `WriteDone`/`WriteError`. This means the state machine can be redesigned (e.g. when ISSUE-011 replaces the keymap) without touching the shell.

## Testing Priorities

1. `state_with_file` sets buffer content, file_path, modified=false -- covers: "`jeditor path` reads the file and displays it" (the pure half; file reading is in the shell).
2. `update state Save` when `file_path = Some p` -> returns `WriteFile` effect with correct content -- covers: "C-x C-s saves to its file path".
3. `update state Save` when `file_path = None` -> mode becomes `PromptSaveAs` -- covers: "C-x C-s falls back to prompting like C-x C-w".
4. `MinibufAppend` / `MinibufBackspace` accumulate and edit `minibuf` correctly -- covers: "C-x C-w prompts for a file path".
5. `MinibufConfirm` -> returns `WriteFile` effect with `path = minibuf` -- covers: "C-x C-w saves to that path".
6. `WriteDone path` -> `modified = false`, `file_path = Some path`, `message = "Saved."` -- covers: "saving a file that does not yet exist creates it" (observable state after success).
7. `WriteError msg` -> `message = msg`, modified unchanged -- covers: "read errors display a message without crashing".
8. `Insert` / `Backspace` / `Enter` -> sets `modified = true` -- covers: status bar `*` indicator (the flag that drives rendering).
9. `TryQuit` when `modified = true` -> mode = `ConfirmQuit` -- covers: "C-x C-c prompts 'Unsaved changes'".
10. `TryQuit` when `modified = false` -> `quit = true` -- covers: "C-x C-c quits cleanly when no unsaved changes".
11. In `ConfirmQuit` mode, `Quit` action -> `quit = true` -- covers: confirming the quit prompt.
12. In `ConfirmQuit` mode, `MinibufCancel` -> mode = Normal, `quit = false` -- covers: cancelling the quit prompt.

## Open Questions

None -- all decisions resolved during design.
