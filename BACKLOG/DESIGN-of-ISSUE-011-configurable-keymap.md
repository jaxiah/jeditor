## Parent Issue

[ISSUE-011-configurable-keymap.md](ISSUE-011-configurable-keymap.md)

## Interfaces

### New: `lib/core/keymap.ml` / `keymap.mli`

```ocaml
type binding =
  | Command of string   (* leaf: a named command *)
  | Prefix  of t        (* internal node: sub-keymap for multi-key sequences *)

and t = (Key.t * binding) list
(** Prefix trie stored as an association list. Lookup is O(n) per level;
    keymaps are small so this is acceptable. *)

type lookup_result =
  | Matched of string   (* command name to dispatch *)
  | Pending             (* valid prefix so far -- wait for next key *)
  | Unbound             (* no binding in any layer *)

val empty : t
(** The empty keymap. *)

val bind : Key.t list -> string -> t -> t
(** [bind keys cmd km] returns [km] with [keys] (length ≥ 1) mapped to
    [Command cmd]. Intermediate nodes are created as needed; existing
    Prefix nodes at those keys are extended rather than replaced. *)

val lookup : t list -> Key.t list -> lookup_result
(** [lookup layers keys] walks each layer in priority order (head = highest).
    The first layer that has ANY binding for the first key in [keys] "owns"
    the sequence.  Within that layer the full sequence is traversed:
    - All keys consumed and land on a Command  → Matched cmd
    - All keys consumed and land on a Prefix   → Pending
    - Key not found at some level              → Unbound
    If no layer matches the first key → Unbound. *)

val emacs_default : t
(** Built-in Emacs-style keymap covering all commands from ISSUE-006
    through ISSUE-010.  Not special -- just the initial global layer. *)
```

**Standard command name strings** (used in `emacs_default` and by
`action_of_command` in `App`):

| Command name             | Bound keys              |
| ------------------------ | ----------------------- |
| `"move-forward-char"`    | C-f, Arrow Right        |
| `"move-backward-char"`   | C-b, Arrow Left         |
| `"move-next-line"`       | C-n, Arrow Down         |
| `"move-prev-line"`       | C-p, Arrow Up           |
| `"move-forward-word"`    | M-f                     |
| `"move-backward-word"`   | M-b                     |
| `"move-line-start"`      | C-a                     |
| `"move-line-end"`        | C-e                     |
| `"move-buf-start"`       | M-<                     |
| `"move-buf-end"`         | M->                     |
| `"delete-forward-char"`  | C-d, Delete             |
| `"backward-delete-char"` | Backspace               |
| `"delete-word-back"`     | C-M-h (ESC + Backspace) |
| `"kill-word-forward"`    | M-d                     |
| `"kill-line"`            | C-k                     |
| `"new-line"`             | Enter                   |
| `"save"`                 | C-x C-s                 |
| `"save-as"`              | C-x C-w                 |
| `"quit"`                 | C-x C-c, C-c            |
| `"undo"`                 | C-/, C-\_               |
| `"redo"`                 | M-\_                    |
| `"goto-line"`            | M-g g                   |
| `"cancel"`               | C-g, Escape             |

---

### Modified: `lib/core/app.mli`

**`mode` type** — remove `PendingCx` and `PendingMg` (now handled by the
keymap prefix trie; no dedicated mode is needed):

```ocaml
type mode =
  | Normal
  | PromptSaveAs
  | ConfirmQuit
  | PromptGotoLine
```

**`action` type** — remove `PendingCx`, `JumpToLinePrompt`,
`StartGotoLinePrompt` (prefix states handled by keymap); keep all others:

```ocaml
type action =
  | Insert of Uchar.t | Backspace | Enter
  | Save | StartSaveAs | TryQuit
  | MinibufAppend of Uchar.t | MinibufBackspace | MinibufConfirm | MinibufCancel
  | WriteDone of string | WriteError of string | Quit | Ignore
  | Move of move_target
  | DeleteForward | DeleteWordBack | KillLine
  | JumpToLine of int       (* kept for direct use and testability *)
  | Resize of { cols : int; rows : int }
  | Undo | Redo
```

**`app_state`** — add two fields:

```ocaml
type app_state = {
  (* ... existing fields ... *)
  pending_keys : Key.t list;    (* accumulated prefix keys in Normal mode *)
  keymap       : Keymap.t list; (* active layers, head = highest priority *)
}
```

`initial_state` sets `pending_keys = []` and `keymap = [Keymap.emacs_default]`.

**New public function** (replaces direct `action_of_key` call in `bin/`):

```ocaml
val handle_key : app_state -> Key.t -> app_state * cmd
(** Dispatch a single key event through the full pipeline:
    - In prompt modes (PromptSaveAs, ConfirmQuit, PromptGotoLine):
      uses the existing hardcoded per-mode dispatch (unchanged).
    - In Normal mode:
        1. C-g with pending keys → cancel prefix (clear pending_keys).
        2. Append key to pending_keys, call Keymap.lookup.
           Pending  → update pending_keys, return state unchanged.
           Matched  → clear pending_keys, call update with the mapped action.
           Unbound  → clear pending_keys; if Key.Char c → Insert c (self-insert);
                      else set message "Key not bound". *)
```

`action_of_key` is removed from the public interface.

---

## Module Boundaries

| Module           | Role                                                                                            |
| ---------------- | ----------------------------------------------------------------------------------------------- |
| `Keymap`         | New. Pure trie data structure + `emacs_default`. No IO, no state.                               |
| `App`            | Gains `handle_key`. Owns `command_of_name` (private string→action). `update` unchanged.         |
| `bin/jeditor.ml` | Calls `handle_key` instead of `action_of_key` + `update`. Status bar shows pending prefix hint. |

`Keymap` is added to `lib/core/dune` modules list.

---

## Deep Module Opportunities

**`Keymap.lookup` hides prefix-tree traversal and layer priority completely.**
The caller never touches the trie structure directly -- it just holds a
`Key.t list` in `app_state.pending_keys` and calls `lookup`. This means
the trie implementation (association list today, balanced tree or hash table
tomorrow) can change without touching `App` or the renderer.

**`App.handle_key` consolidates dispatch.** The main loop in `bin/jeditor.ml`
shrinks from: "determine mode → call action_of_key → call update" to a single
`handle_key` call. Prompt-mode dispatch and keymap dispatch are both hidden
inside this one function.

---

## Testing Priorities

1. **`Keymap.lookup` exact match** — single-key binding returns `Matched`.
   Covers: "All commands from ISSUE-006 through ISSUE-010 continue to work."

2. **`Keymap.lookup` prefix resolution** — two-key sequence (C-x C-s):
   first key returns `Pending`, second returns `Matched "save"`.
   Covers: "C-x prefix chains resolve correctly across two key events."

3. **`Keymap.lookup` layer shadowing** — higher-priority layer binding
   overrides lower-priority layer for the same key.
   Covers: "A binding in a higher-priority layer shadows the same binding."

4. **`App.handle_key` C-g cancels pending** — pressing C-g while
   `pending_keys = [C-x]` clears pending and returns to Normal dispatch.
   Covers: "C-g in any pending-prefix state cancels the prefix."

5. **`App.handle_key` unbound key** — pressing an unbound key (not a printable
   char) sets `state.message = "Key not bound"`.
   Covers: "Unbound keys display a brief 'Key not bound' message."

6. **`App.handle_key` self-insert** — pressing a printable `Key.Char c` with
   no keymap binding inserts the character.
   Covers: "All commands from ISSUE-006 continue to work" (typed text).

7. **User rebind** — constructing a custom `Keymap.t` that overrides one
   command and verifying that `handle_key` dispatches to the new command.
   Covers: "A user can rebind any command to any key."

---

## Open Questions

1. **Status bar prefix hint**: should the status bar show `"C-x ..."` while
   `pending_keys` is non-empty? (Emacs shows this in the minibuffer echo area.)
   Proposed default: yes -- display `Key.pp` of pending keys in the status bar
   while in a pending-prefix state.

2. **`emacs_default` for Tab**: Tab currently falls through to `Ignore`. Should
   it be bound to `"self-insert"` (inserts a tab character) or left unbound?
   Proposed: bind `Tab → "new-line"` is wrong; leave unbound for now (inserts
   literal tab via self-insert fallback since `Key.Tab` is not `Key.Char`).
   Actually Tab needs explicit binding to insert-tab or be left as Ignore.
   For now: leave Tab unbound (Ignore via self-insert fallback won't fire for
   Tab since it's not `Key.Char`). Can be addressed in ISSUE-012.
