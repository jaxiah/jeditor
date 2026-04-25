## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Replace the hardcoded key dispatch in ISSUE-006 with a proper layered keymap system. Keybindings are data, not code -- no binding is hardcoded in the `update` function or anywhere in the core modules.

A `Keymap.t` is a prefix tree where leaf nodes are command name strings and internal nodes are prefix keys (e.g. C-x branches to a sub-keymap). The lookup function takes a `Keymap.t list` (the active stack, highest priority first) and a `Key.t`, and returns `Matched of string`, `Pending` (waiting for the next key in a prefix chain), or `Unbound`.

The editor ships a built-in `Keymap.emacs_default` value that covers all bindings introduced in ISSUE-006 through ISSUE-010. This value is constructed at startup and installed as the global layer. It has no special status -- it can be replaced, derived from, or shadowed by users and plugins.

Layering priority: buffer-local -> mode -> global. Plugins and user config add layers at startup by prepending to the stack.

## Acceptance criteria

- [x] All commands from ISSUE-006 through ISSUE-010 continue to work after the hardcoded dispatch is removed
- [x] C-x prefix chains (C-x C-s, C-x C-c, etc.) resolve correctly across two key events
- [x] A binding in a higher-priority layer shadows the same binding in a lower-priority layer
- [x] A user can rebind any command to any key by providing a custom `Keymap.t` that overrides the global layer
- [x] Unbound keys display a brief "Key not bound" message in the status bar and do not crash
- [x] C-g in any pending-prefix state cancels the prefix and returns to normal dispatch
- [x] Alcotest suite covers: exact match, prefix resolution over two keys, shadowing, C-g cancels pending

## Completed

2026-04-25 — all acceptance criteria met. Implemented via TDD. New `Keymap` module (prefix trie + `emacs_default`). `App.handle_key` replaces hardcoded `action_of_key`. `PendingCx`/`PendingMg` modes removed; prefix state tracked in `pending_keys : Key.t list` in `app_state`. Pending prefix hint shown in status bar. 6 Keymap tests + 6 handle_key tests added (54 total).

## Blocked by

- [ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## User stories addressed

- User story 56 (rebind any command to any key)
- User story 57 (Emacs default keymap is default but not mandatory)
- User story 24 (C-g cancel)
