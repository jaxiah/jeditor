## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement the command registry, M-x invocation, and the full Minibuffer module. These three components form the editor's primary extensibility boundary: everything from plugins to user config interacts with the editor by registering and invoking named commands.

**Command registry**: a mutable table mapping `string -> (app_state -> app_state)`. All commands registered so far (from previous issues) are migrated into this registry at startup. The registry is the only globally mutable state in the core -- this is justified because registration is a startup-time side effect.

**Minibuffer**: a single-line input area at the bottom of the screen with its own input loop. When active it temporarily captures all key events. Supports: text input, Backspace, C-g to cancel, Enter to confirm. Returns `Some string` on confirm, `None` on cancel. Used by M-x, save-as, jump-to-line, and search.

**M-x**: pressing M-x activates the minibuffer with a command-name prompt. Tab-completion over registered command names is displayed as a completion list above the minibuffer. Enter invokes the matched command; C-g cancels.

## Acceptance criteria

- [ ] Every command from previous issues is accessible by name via M-x
- [ ] M-x shows a completion list that narrows as the user types
- [ ] Selecting and executing a command via M-x produces the same result as its keybinding
- [ ] Minibuffer C-g cancels without side effects and returns to the previous editor state
- [ ] A plugin or user config can register a new command that immediately appears in M-x
- [ ] Invoking an unknown command name displays an error message in the minibuffer
- [ ] The minibuffer does not interfere with undo history -- commands invoked via M-x are undoable in the same way as keybinding-invoked commands

## Blocked by

- [ISSUE-011-configurable-keymap.md](ISSUE-011-configurable-keymap.md)

## User stories addressed

- User story 25 (M-x invoke any command)
- User story 26 (minibuffer)
- User story 48 (plugin registers command visible in M-x)
- User story 54 (plugin displays message in minibuffer)
