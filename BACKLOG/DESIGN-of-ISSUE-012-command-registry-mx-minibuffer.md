## Parent Issue

[ISSUE-012-command-registry-mx-minibuffer.md](ISSUE-012-command-registry-mx-minibuffer.md)

## Interfaces

### `lib/core/registry.ml` (new module)

```ocaml
type 'a t
(** Parametric over handler type — no dependency on App, no circular import. *)

val empty    : 'a t
val register : string -> 'a -> 'a t -> 'a t
(** [register name handler t] returns a new registry with [name] bound to
    [handler]. Duplicate names are silently overwritten. *)

val lookup   : string -> 'a t -> 'a option
(** Exact-match lookup. Returns [None] if name is not registered. *)

val names    : 'a t -> string list
(** All registered names in alphabetical order. *)

val complete : prefix:string -> 'a t -> string list
(** All names whose prefix matches [prefix], in alphabetical order.
    [complete ~prefix:"" t] is equivalent to [names t]. *)
```

### `lib/core/app.ml` — modified types

New mutually-recursive types using `and`:

```ocaml
type handler = app_state -> app_state * cmd
and app_state = {
  (* ... all existing fields ... *)
  registry : handler Registry.t;
}
```

New `mode` variant:

```ocaml
type mode = Normal | PromptSaveAs | ConfirmQuit | PromptGotoLine | PromptMx
```

New `action` variant:

```ocaml
type action = ... | StartMx | MinibufTab
```

New public function (no signature change to `handle_key` or `update`):

```ocaml
val initial_state : app_state
(** registry field is pre-populated with all built-in commands. *)
```

### `lib/core/keymap.ml` — one addition to `emacs_default`

```
bind [Key.Meta 'x']  "execute-extended-command"
```

### `bin/jeditor.ml` — render changes

When `state.App.mode = App.PromptMx`:

- Row `rows-1` (status bar): `"M-x " ^ state.App.minibuf ^ "_"`
- Row `rows-2` (completion line): space-separated matches from
  `Registry.complete ~prefix:state.App.minibuf state.App.registry`,
  truncated to `cols` width; empty line if no matches
- Text area uses rows `0` to `rows-3`

## Module Boundaries

| Module                 | Status   | Responsibility                                                                                                                                                                            |
| ---------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/core/registry.ml` | **New**  | Parametric name→handler map; prefix completion; alphabetical ordering. Pure functional — no side effects, no global state.                                                                |
| `lib/core/app.ml`      | Modified | Adds `registry` field to `app_state`; adds `PromptMx` mode; `StartMx`/`MinibufTab` actions; dispatches commands from registry in `MinibufConfirm`; populates registry in `initial_state`. |
| `lib/core/keymap.ml`   | Modified | Adds `m 'x' → "execute-extended-command"` to `emacs_default`.                                                                                                                             |
| `lib/core/dune`        | Modified | Adds `registry` to the modules list.                                                                                                                                                      |
| `bin/jeditor.ml`       | Modified | Renders completion row; handles `PromptMx` in status-bar display.                                                                                                                         |

## Deep Module Opportunities

**`Registry`**: the caller only ever sees `'a t` as an opaque type. Internally it uses `Map.Make(String)` for O(log n) lookup and sorted iteration. This means the entire data-structure choice is hidden — switching to a hash table later requires no interface change.

**`MinibufConfirm` in `PromptMx`**: the full dispatch path (lookup → execute handler → return state) is a single match arm inside `update`. The caller (`handle_key`) cannot tell whether a command was executed via keybinding or M-x; both paths go through `update` and both push to `undo_stack` identically.

**Built-in command registration**: `initial_state.registry` is built from the same `command_of_name` table, expressed as:

```ocaml
let h action st = update st action
Registry.register "move-forward-char" (h (Move CharF)) ...
```

The `command_of_name` private function can be kept as-is for keymap dispatch; the registry wraps it. No duplication of logic.

## Testing Priorities

1. **`Registry.complete` prefix narrowing** — empty prefix returns all names; typed prefix narrows correctly; non-matching prefix returns `[]`.
   Covers: _"M-x shows a completion list that narrows as the user types"_

2. **`Registry.lookup` exact match and miss** — known name returns `Some handler`; unknown name returns `None`.
   Covers: _"Invoking an unknown command name displays an error message"_

3. **`StartMx` opens `PromptMx` mode** — pressing M-x via `handle_key` sets `mode = PromptMx` and `minibuf = ""`.
   Covers: basic M-x invocation prerequisite for all other criteria.

4. **M-x executes command: same result as keybinding** — type `"move-forward-char"` + Enter produces identical state to pressing C-f.
   Covers: _"Selecting and executing a command produces the same result as its keybinding"_

5. **M-x unknown command shows error** — type `"no-such-cmd"` + Enter leaves mode Normal and sets a non-empty `message`.
   Covers: _"Invoking an unknown command name displays an error message"_

6. **C-g in `PromptMx` returns to Normal** — buffer, cursor, undo stack all unchanged.
   Covers: _"Minibuffer C-g cancels without side effects"_

7. **Undo after M-x** — command via M-x followed by C-/ undoes the change; undo stack depth matches.
   Covers: _"The minibuffer does not interfere with undo history"_

8. **`register` makes command available in M-x** — register a new name, then `Registry.complete` and `Registry.lookup` see it.
   Covers: _"A plugin or user config can register a new command"_

9. **`MinibufTab` inserts longest-common-prefix** — when completions share a prefix longer than current input, Tab extends input to LCP.
   Covers: Tab completion (part of _"M-x shows a completion list"_)

10. **All built-in commands reachable** — `Registry.names initial_state.registry` contains every command name in `emacs_default`.
    Covers: _"Every command from previous issues is accessible by name via M-x"_

## Open Questions

1. **`PromptMx` character filter**: save-as and goto-line restrict input (any char vs digits only). M-x allows any printable character. The existing `prompt_action_of_key` already has this distinction; `PromptMx` follows the same any-char pattern as `PromptSaveAs`.

2. **Partial-match Enter**: if the user types a prefix (e.g. `"move-f"`) and presses Enter, should jeditor auto-complete to the unique match? For MVP: no — Enter only accepts an exact name. Error message otherwise.

3. **`command_of_name` vs registry duplication**: both will map the same name strings to actions for now. A future cleanup could eliminate `command_of_name` entirely and route all keymap dispatch through the registry. Out of scope for this issue.
