## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Add file persistence: open a named file from the CLI, display its contents, and save it back. This is the first issue that exercises the filesystem boundary. The save-as path is read from a temporary minibuffer input (a minimal single-line prompt at the bottom of the screen -- the full Minibuffer module comes in ISSUE-012).

## Acceptance criteria

- [x] `jeditor path/to/file.txt` reads the file, loads it into a buffer, and displays it
- [x] `jeditor` with no argument opens an empty unnamed buffer (as before)
- [x] C-x C-s saves the current buffer to its file path; if the buffer has no path, falls back to prompting like C-x C-w
- [x] C-x C-w prompts for a file path at the bottom of the screen and saves to that path
- [x] The status bar shows the filename and a `*` indicator when the buffer has unsaved changes
- [x] C-x C-c prompts "Unsaved changes -- quit anyway? (y/n)" when the buffer is modified
- [x] Saving a file that does not yet exist creates it
- [x] Read errors (file not found, permission denied) display a message at the bottom of the screen without crashing

## Blocked by

- [ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## User stories addressed

- User story 1 (open from CLI)
- User story 2 (empty buffer)
- User story 3 (C-x C-s save)
- User story 4 (C-x C-w save-as)
- User story 47 (quit with unsaved changes prompt)

## Completed

2026-04-25 -- all acceptance criteria met. Implemented via TDD. 13 new automated tests cover the full state machine (mode transitions, cmd effects, minibuf accumulation, WriteDone/WriteError, TryQuit/ConfirmQuit). [manual] criteria verified by running `dune exec jeditor`. Note: `effect` is a reserved keyword in OCaml 5; renamed to `cmd` in the implementation.
