## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement the plugin system: a `Plugin_api` module type that defines what plugins can do, and a `Plugin_loader` that uses OCaml's `Dynlink` to load `.cmxs` files at startup.

Plugins interact with the editor exclusively through `Plugin_api` typed accessors — they never receive a raw `app_state`. This means the internal state representation can evolve without breaking existing plugins as long as the API accessors are maintained.

A plugin is an OCaml module that satisfies the `PLUGIN` signature. Its top-level code runs when the `.cmxs` is loaded, at which point it calls `Plugin_api.register` to install its commands, keybindings, and hooks into the running editor.

Ship one non-trivial example plugin alongside the core (`plugins/line-highlight/`) that highlights the current cursor line in a distinct color, demonstrating buffer read access and renderer integration.

## Acceptance criteria

- [ ] A `.cmxs` plugin file listed in the user config is loaded at startup via `Dynlink.loadfile`
- [ ] A plugin can register a named command that appears in M-x
- [ ] A plugin can bind its command to a keychord
- [ ] A plugin can register hooks for: before-save, after-open, on-cursor-move
- [ ] A plugin can read any buffer's content via `Plugin_api` accessors
- [ ] A plugin can write (insert/delete) into any buffer via `Plugin_api` accessors, and the change is undoable
- [ ] A plugin can read and set cursor positions
- [ ] A plugin can display a message in the minibuffer
- [ ] A plugin crash (raised exception) is caught and reported as a minibuffer error without taking down the editor
- [ ] The example `line-highlight` plugin loads, activates, and visually highlights the cursor line
- [ ] Plugin loading errors (file not found, signature mismatch) display a clear error message and skip the plugin without crashing

## Blocked by

- [ISSUE-012-command-registry-mx-minibuffer.md](ISSUE-012-command-registry-mx-minibuffer.md)

## User stories addressed

- User story 48 (plugin registers M-x command)
- User story 49 (plugin binds keychord)
- User story 50 (plugin registers hooks)
- User story 51 (plugin reads/writes buffer)
- User story 52 (plugin reads/moves cursor)
- User story 53 (plugin opens buffers/windows)
- User story 54 (plugin displays minibuffer message)
- User story 55 (plugin as compiled .cmxs)
