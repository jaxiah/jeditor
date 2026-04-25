# PRD-001: JEditor -- Core TUI Text Editor

## Problem Statement

The user wants to build a TUI-based text editor in OCaml as a vehicle for learning both the OCaml language (module system, functors, algebraic data types, pure functional style) and the fundamentals of editor design (text buffer data structures, modal interaction, multi-cursor editing, plugin systems). The editor should be practically usable on files ranging from a few lines to several million lines, run cross-platform (Windows and Linux), and be extensible enough that any behavior can be overridden or augmented via OCaml plugins -- similar in spirit to Emacs and its Elisp environment.

## Solution

Build JEditor as a layered OCaml application following the "Functional Core, Imperative Shell" principle. The text buffer is hidden behind a stable module interface so the initial naive implementation can be replaced with a high-performance data structure (Rope or Piece Tree) without touching any other code. The editor state is modeled as an immutable value transformed by pure `update` functions (MVU pattern). The terminal I/O is the only place with side effects. A plugin system based on OCaml's `Dynlink` allows plugins to register commands, keybindings, hooks, and directly manipulate editor state through a well-defined API.

The editing paradigm follows Emacs conventions: chord-based keybindings, a minibuffer for command input and search, and a command registry that maps string names to functions callable from M-x. The editor ships with an Emacs-compatible default keymap, but every binding is configurable -- users and plugins can rebind, shadow, or remove any key at any layer. Multi-cursor support is provided without mouse dependency.

## User Stories

1. As a user, I want to open a file from the command line (`jeditor myfile.txt`), so that I can start editing immediately.
2. As a user, I want to open a new empty buffer when no file is given, so that I can start writing from scratch.
3. As a user, I want to save the current buffer to its file with C-x C-s, so that my changes are persisted.
4. As a user, I want to save a buffer to a new path with C-x C-w, so that I can save a copy under a different name.
5. As a user, I want to move the cursor with arrow keys and Emacs chords (C-f, C-b, C-n, C-p), so that I can navigate without leaving home row.
6. As a user, I want to move word-by-word with M-f and M-b, so that I can navigate faster through text.
7. As a user, I want to jump to the beginning and end of a line with C-a and C-e, so that line-level navigation is fast.
8. As a user, I want to jump to the beginning and end of the buffer with M-< and M->, so that I can navigate large files quickly.
9. As a user, I want to insert text at the cursor position by typing, so that I can write content.
10. As a user, I want to delete the character before the cursor with Backspace, so that I can correct typos.
11. As a user, I want to delete the character at the cursor with C-d, so that I can delete forward.
12. As a user, I want to delete the word before the cursor with M-Backspace, so that I can erase words quickly.
13. As a user, I want to delete from the cursor to end of line with C-k, so that I can clear lines efficiently.
14. As a user, I want to undo the last change with C-/, so that I can recover from mistakes.
15. As a user, I want to redo an undone change with C-? or M-\_, so that I can move forward again after undoing too far.
16. As a user, I want undo history that survives arbitrary sequences of edits and undos, so that no edit is permanently lost.
17. As a user, I want to set a mark with C-Space and select a region between mark and cursor, so that I can operate on a range of text.
18. As a user, I want to copy the selected region with M-w, so that I can duplicate text.
19. As a user, I want to cut the selected region with C-w, so that I can move text.
20. As a user, I want to paste the clipboard content with C-y, so that I can insert copied or cut text.
21. As a user, I want incremental forward search with C-s, so that I can find text as I type.
22. As a user, I want incremental backward search with C-r, so that I can search in reverse.
23. As a user, I want to search and replace with M-%, so that I can rename identifiers or fix repeated errors.
24. As a user, I want to cancel any in-progress operation with C-g, so that I can recover from a wrong command sequence.
25. As a user, I want to invoke any named command by name using M-x, so that I can run commands I haven't memorized keybindings for.
26. As a user, I want a minibuffer at the bottom of the screen that accepts input for M-x and search, so that command input is contextual and non-disruptive.
27. As a user, I want line numbers displayed in the gutter, so that I can orient myself in the file.
28. As a user, I want to jump to a specific line number with M-g g, so that I can navigate by line reference.
29. As a user, I want a status bar showing filename, cursor position (line:col), and modification state, so that I always know the current context.
30. As a user, I want to split the window horizontally with C-x 2, so that I can view two parts of a file simultaneously.
31. As a user, I want to split the window vertically with C-x 3, so that I can view files side by side.
32. As a user, I want to close the current window with C-x 0, so that I can reclaim screen space.
33. As a user, I want to close all other windows with C-x 1, so that I can focus on one buffer.
34. As a user, I want to move focus between windows with C-x o, so that I can work across splits.
35. As a user, I want to resize windows by dragging the split boundary or via commands, so that I can allocate screen space as needed.
36. As a user, I want each window to independently scroll its view into a buffer, so that two windows on the same file show different positions.
37. As a user, I want to open a new buffer in the current window with C-x b, so that I can switch between open files.
38. As a user, I want to list open buffers with C-x C-b, so that I can see what files are open.
39. As a user, I want to kill a buffer with C-x k, so that I can close files I no longer need.
40. As a user, I want to add a secondary cursor at the next occurrence of the selected text with a dedicated keybinding, so that I can edit multiple instances simultaneously.
41. As a user, I want to expand cursors by column downward (rectangular/block selection) with a dedicated keybinding, so that I can perform columnar edits.
42. As a user, I want all cursors to perform the same edits simultaneously, so that multi-cursor editing is consistent.
43. As a user, I want cursors to be automatically merged if they collide, so that I never have duplicate cursors at the same position.
44. As a user, I want to dismiss all secondary cursors and return to a single cursor with C-g, so that I can exit multi-cursor mode.
45. As a user, I want to open large files (millions of lines) without waiting more than a few seconds, so that the editor is usable on real-world data files.
46. As a user, I want cursor movement and text insertion on large files to feel immediate (sub-100ms), so that the editor is faster than bare Vim in everyday use.
47. As a user, I want to quit the editor with C-x C-c, prompting if there are unsaved changes, so that I never accidentally lose work.
48. As a plugin author, I want to register a named command that appears in M-x, so that my plugin's functionality is discoverable.
49. As a plugin author, I want to bind my command to a keychord, so that users can invoke it without M-x.
50. As a plugin author, I want to register hooks for events (before-save, after-open, on-cursor-move), so that my plugin can react to editor events.
51. As a plugin author, I want to read and write the contents of any buffer, so that I can implement text transformations.
52. As a plugin author, I want to read and move any cursor, so that I can implement navigation extensions.
53. As a plugin author, I want to open new buffers and windows, so that I can implement file management features.
54. As a plugin author, I want to display messages in the minibuffer, so that my plugin can communicate status to the user.
55. As a plugin author, I want my plugin to be a compiled OCaml `.cmxs` file loaded at startup via a config file, so that the loading mechanism is simple and explicit.
56. As a user, I want to rebind any command to any key sequence, so that I can use a keymap other than the Emacs defaults.
57. As a user, I want the built-in Emacs-compatible keymap to be the default but not mandatory, so that I can start productive immediately and customize later.

## Implementation Decisions

### Module Architecture

**Buffer (deep module -- highest priority)**
The central abstraction of the entire editor. Exposes a purely functional interface operating on byte offsets. The initial implementation uses a simple `string array` (one entry per line). This implementation is intentionally naive and will be replaced in a later phase with an augmented B-tree (Rope or Piece Tree) without any changes to callers.

The interface is built around byte offsets as the canonical coordinate system. Line/column coordinates are derived from byte offsets, never stored as primary state. This prevents the common pitfall of mixing coordinate systems across modules.

**Cursor (deep module)**
Manages a sorted, non-overlapping list of cursors. Each cursor is an absolute byte offset plus an optional anchor offset for selections. Provides a function to apply an edit (offset + delta) to all cursors atomically, handling the cases: cursor before edit point (unchanged), cursor inside deleted range (clamp to edit start), cursor after edit point (shift by delta). Enforces the invariant that the cursor list is always sorted and deduplicated after any mutation.

**Keymap (deep module)**
Implements a fully configurable layered keybinding system. A keymap is a tree: leaf nodes are command names (strings), internal nodes are prefix keys (e.g. C-x branches to another keymap). Multiple keymaps are active simultaneously and searched in priority order: buffer-local -> mode -> global. Returns either a command name to dispatch, a pending prefix (waiting for more keys), or unbound.

The editor ships a built-in `emacs-default` keymap that covers the standard Emacs chords (C-x C-s, M-x, C-f, etc.). This keymap is a regular value of type `Keymap.t` -- it has no special status. Users can replace it entirely, derive a new keymap from it, or shadow individual bindings at any layer. The specific keybindings mentioned in the user stories are all defaults from this built-in map, not hardcoded behavior.

**Command (deep module)**
A registry mapping string names to functions of type `app_state -> app_state`. Commands are registered by name and are callable from M-x or from keybindings. Plugins register commands through this module. The registry is a mutable table (the only globally mutable state in the core, justified because command registration is a startup-time side effect).

**Editor (deep module)**
The logical state of one open buffer: the buffer value, the cursor list, the mark, the undo/redo stacks, and the file path. The undo stack is a list of past `editor` snapshots; structure sharing in OCaml's immutable values keeps memory overhead low. All editing operations are pure functions `editor -> editor`.

**Window**
A view into an editor: which editor it displays, the scroll position (top line, left column), and the physical dimensions assigned to it by the Frame. Stateless beyond scroll position.

**Frame**
The split-window layout. A frame is a binary tree of splits (horizontal or vertical) with Window values at the leaves. Manages focus (which window is active). Operations: split, close, resize, cycle focus.

**Minibuffer**
A special single-line editor at the bottom of the screen used for M-x input, incremental search, and prompted input (e.g. save-as path). Has its own input loop that temporarily captures key events and returns a result string to the caller.

**App**
The top-level application state: a Frame, a map of open editors (buffer-id -> Editor.t), the Minibuffer state, and the active Keymap stack. The `update : app_state -> action -> app_state` function is the single entry point for all state transitions. This function is pure.

**Renderer**
Computes the terminal output for a given `app_state`. Maintains a previous-frame cell grid and performs diff-based rendering: only emits ANSI sequences for cells that changed between frames. Each cell stores a character plus color/style attributes. The renderer has no knowledge of the buffer internals; it receives pre-computed line strings from the Window/Editor layer.

**Input**
Reads raw bytes from stdin in terminal raw mode and translates them into key events. Handles multi-byte escape sequences (arrow keys, function keys, Meta key via ESC prefix). On Windows, wraps the Windows Console Virtual Terminal API. Emits values of a `key` type consumed by the Keymap module.

**Plugin**
Two sub-components: the Plugin API (a module type `PLUGIN` that plugins must implement, plus a registration function) and the Plugin Loader (uses `Dynlink.loadfile` to load `.cmxs` files listed in the user's config). The Plugin API exposes read/write access to `app_state` through typed accessors, not raw state mutation, so the API surface can evolve without breaking plugins.

### Key Design Decisions

- **Byte offsets as canonical coordinates.** All cursor positions, selection ranges, and buffer operations use absolute byte offsets. Line/column conversions are computed on demand by the Buffer module. This avoids coordinate-system confusion across module boundaries.

- **Buffer interface is sealed.** No module outside `Buffer` may inspect the internal representation. The upgrade path from `string array` to a tree structure requires only reimplementing the `Buffer.S` signature.

- **Undo as editor snapshots.** The undo stack is `Editor.t list`. OCaml's structural sharing makes consecutive snapshots cheap. No separate "operation log" is needed in Phase 1.

- **Command names as the integration boundary.** Keybindings, plugins, and M-x all refer to commands by string name. This means keybindings and plugins are decoupled from each other and from the update function's internals.

- **Keybindings are data, not code.** No keybinding is hardcoded in the update function or anywhere in the core. The built-in Emacs-compatible keymap is constructed at startup as a `Keymap.t` value and installed as the global layer. Replacing or modifying it requires no recompilation of core modules.

- **Plugin state isolation.** Plugins interact with editor state only through the Plugin API accessors. Plugins cannot hold references to internal editor state between calls; they receive a fresh `app_state` on each invocation and return a modified one.

- **Single mutable variable at the top.** The entire application state lives in one `ref` in `main.ml`. All other modules are purely functional. The main loop reads input, calls `update`, writes the result back to the ref, then renders.

- **Cross-platform terminal abstraction.** The `Input` and `Renderer` modules are the only ones that touch the terminal. They expose a platform-agnostic interface. Platform-specific code (POSIX `termios` vs Windows Console API) is isolated inside these two modules.

## Testing Decisions

A good test for this project tests the observable behavior of a module through its public interface only. Tests must not inspect internal data representations (e.g. the shape of the buffer tree), only the results of API calls. Tests should be deterministic and require no terminal or file system.

**Modules to test:**

- **Buffer** -- the most critical. Tests cover: insert/delete at start, middle, end; operations that span line boundaries; UTF-8 multi-byte characters (especially CJK); empty buffer edge cases; round-trip `of_string` / `slice`; `line_to_offset` and `offset_to_line_col` accuracy.

- **Cursor** -- tests cover: offset adjustment after insert before/after/inside each cursor; merging of colliding cursors after edits; sorted invariant preserved after all operations; selection anchor behavior.

- **Keymap** -- tests cover: exact key match returns correct command; prefix key returns Pending then resolves on next key; lower-priority map is shadowed by higher-priority map; C-g always resolves to cancel regardless of pending state.

- **Command** -- tests cover: registered command is callable by name; unknown command name returns an error; plugin-registered command is callable after registration.

- **Editor** -- tests cover: undo returns to previous buffer state; redo after undo restores forward state; undo stack is empty after fresh open; multi-cursor insert produces correct buffer content.

- **Frame** -- tests cover: split produces two windows; close last window in a split restores single window; focus cycles through windows correctly; split tree is always valid (no empty nodes).

All tests use Alcotest. No test touches stdin, stdout, or the filesystem.

## Out of Scope

- **Syntax highlighting.** Deferred to a later phase. The renderer will support color attributes so syntax highlighting can be added later without architectural changes.
- **LSP (Language Server Protocol) integration.** This is a separate project-sized feature.
- **Mouse support.** All interactions are keyboard-driven.
- **Tree-sitter integration.** Deferred until the plugin system is mature.
- **Network/collaborative editing.** Explicitly not required.
- **Config file format.** Phase 1 uses a hardcoded OCaml config file (a compiled plugin); a human-readable config format is deferred.
- **Fuzzy file finder / project-wide search.** Out of scope for core; can be implemented as a plugin later.
- **Terminal multiplexer features** (detach, session persistence). Out of scope.

## Further Notes

- The project is explicitly a learning vehicle. When there is a choice between a clever shortcut and a design that makes the OCaml type system do more work, prefer the latter.
- The Buffer module interface should be written and reviewed before any implementation begins. Getting this interface wrong is the highest-risk event in the project.
- Windows support is developed natively (not WSL2). The terminal backend uses `SetConsoleMode` + VT processing on Windows and POSIX `termios` on Linux, dispatched at compile time via Dune `(enabled_if ...)` stanzas. This was addressed in ISSUE-005.
- Performance baseline: the editor should feel faster than bare Vim on files up to 1 million lines. This is a UX target, not a benchmark. The naive `string array` buffer will not meet this target; the target applies after the buffer is upgraded in Phase 2.
- The choice between Rope and Piece Tree for Phase 2 is intentionally deferred. Both require a custom augmented balanced tree. The decision should be made after the Buffer interface is proven stable through Phase 1 usage.
