## Parent Issue

[ISSUE-018-plugin-system.md](ISSUE-018-plugin-system.md)

## Interfaces

```
module type Plugin_api.PLUGIN
```

Documents the plugin shape. Plugins run top-level initialization and call
`Plugin_api.register_*` functions.

```
type Plugin_api.editor
type Plugin_api.event = Before_save | After_open | On_cursor_move
type Plugin_api.command = editor -> editor
type Plugin_api.hook = editor -> editor
```

`editor` is abstract to plugin authors. Access is only through typed API
functions.

```
Plugin_api.register_command(name: string, command: command) -> unit
Plugin_api.bind_key(keys: Key.t list, command_name: string) -> unit
Plugin_api.register_hook(event: event, hook: hook) -> unit
Plugin_api.buffer_content(buffer_id: int, editor) -> string option
Plugin_api.insert(buffer_id: int, offset: int, text: string, editor) -> editor
Plugin_api.delete(buffer_id: int, offset: int, length: int, editor) -> editor
Plugin_api.cursor_positions(buffer_id: int, editor) -> int list option
Plugin_api.set_cursor_positions(buffer_id: int, positions: int list, editor) -> editor
Plugin_api.message(text: string, editor) -> editor
Plugin_api.enable_line_highlight(editor) -> editor
```

```
Plugin_loader.load_paths(paths: string list, App.app_state) -> App.app_state
Plugin_loader.apply_registered(App.app_state) -> App.app_state
```

Load `.cmxs` files with `Dynlink.loadfile`, catch failures, and install the
registrations accumulated through `Plugin_api`.

## Module Boundaries

- `Jeditor_core.App` stores installed plugin commands, keybindings, hooks, and
  renderer flags as ordinary app state.
- `Jeditor_plugin.Plugin_api` hides raw `App.app_state` behind typed accessors.
- `Jeditor_plugin.Plugin_loader` is the imperative Dynlink boundary.
- `bin/jeditor.ml` reads plugin paths from `JEDITOR_PLUGINS` and highlights the
  current line when a plugin enables the renderer flag.
- `plugins/line-highlight` demonstrates a non-trivial plugin using API calls.

## Deep Module Opportunities

The loader is intentionally thin. Most plugin behavior is represented as data
registered through `Plugin_api`, so tests can validate registration and command
behavior without compiling a separate `.cmxs` for every case.

## Testing Priorities

1. Loading paths calls Dynlink and reports load errors without crashing,
   covering startup loading and load-error criteria.
2. Registered commands appear in M-x and exceptions are reported as minibuffer
   messages, covering command and crash criteria.
3. Registered keybindings dispatch plugin commands, covering keychord binding.
4. Hooks run for before-save, after-open, and cursor move, covering hook
   registration.
5. API accessors read/write buffers with undoable edits and read/set cursors,
   covering buffer and cursor criteria.
6. `message` writes the minibuffer message, covering plugin status messages.
7. The example line-highlight plugin enables the renderer line-highlight flag,
   covering the example plugin criterion.

## Open Questions

The project has no config file format yet. This design uses the
`JEDITOR_PLUGINS` environment variable as the startup source for plugin paths;
paths are separated with `;` on Windows and `:` elsewhere.
