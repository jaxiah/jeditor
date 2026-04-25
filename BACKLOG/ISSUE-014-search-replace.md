## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement incremental search and search-and-replace, both driven through the Minibuffer. Search is incremental: the viewport and cursor jump to each match as the user types, without requiring Enter. All matches are highlighted simultaneously.

**C-s (forward)**: opens minibuffer in isearch mode. Each character narrows the match. C-s again jumps to the next match. C-r reverses direction. Enter confirms and leaves cursor at match. C-g cancels and returns cursor to its pre-search position.

**M-% (query replace)**: minibuffer prompts for search string, then replacement string. For each match: `y` replaces and advances, `n` skips, `!` replaces all remaining, `q` or C-g quits.

## Acceptance criteria

- [x] C-s opens isearch and highlights the first match as the user types
- [x] All current matches in the visible area are highlighted simultaneously
- [x] C-s during isearch jumps to the next match; wraps around end of buffer with a visual indicator
- [x] C-r during isearch searches backward
- [x] C-g during isearch returns cursor to its pre-search position with no buffer changes
- [x] Enter during isearch confirms, leaving the cursor at the current match
- [x] M-% prompts for both strings via sequential minibuffer inputs
- [x] M-% y/n/!/q behavior matches the acceptance criteria description above
- [x] Search is case-insensitive when the search string is all lowercase (Emacs smart-case behavior)
- [x] Search handles multi-byte UTF-8 characters correctly

## Blocked by

- [ISSUE-012-command-registry-mx-minibuffer.md](ISSUE-012-command-registry-mx-minibuffer.md)
- [ISSUE-009-basic-editing-commands.md](ISSUE-009-basic-editing-commands.md)

## User stories addressed

- User story 21 (C-s incremental forward search)
- User story 22 (C-r backward search)
- User story 23 (M-% search and replace)

## Status

2026-04-25 -- all acceptance criteria met. Implemented incremental forward and
backward search through the minibuffer, smart-case matching, UTF-8 exact string
search, simultaneous visible match highlighting, wrapped-search indicator,
cancel/confirm semantics, and `M-%` query replace with `y`, `n`, `!`, and `q`.
