## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Extend the `App` state to maintain a map of open buffers (buffer-id -> `Editor.t`), independent of the window layout. Any window can display any buffer. Implement the buffer-switching and lifecycle commands.

## Acceptance criteria

- [x] C-x b prompts (via minibuffer) for a buffer name and switches the current window to display that buffer; Tab-completion works over open buffer names
- [x] C-x C-b opens a buffer list window showing all open buffers, their filenames, and modification state
- [x] C-x k prompts for a buffer to kill; if the buffer has unsaved changes, asks for confirmation
- [x] Opening a file that is already loaded switches to the existing buffer rather than loading a duplicate
- [x] Each buffer has its own independent undo history
- [x] Killing a buffer that is displayed in multiple windows replaces it with the next available buffer in all those windows
- [x] A buffer created with `jeditor` and no filename is named `*scratch*` by default

## Blocked by

- [ISSUE-015-window-splitting.md](ISSUE-015-window-splitting.md)
- [ISSUE-012-command-registry-mx-minibuffer.md](ISSUE-012-command-registry-mx-minibuffer.md)

## User stories addressed

- User story 37 (C-x b switch buffer)
- User story 38 (C-x C-b list buffers)
- User story 39 (C-x k kill buffer)

## Completed

2026-04-26 — all acceptance criteria met. Implemented via TDD.
