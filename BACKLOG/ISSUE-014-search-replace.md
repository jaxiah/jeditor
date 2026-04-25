## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement incremental search and search-and-replace, both driven through the Minibuffer. Search is incremental: the viewport and cursor jump to each match as the user types, without requiring Enter. All matches are highlighted simultaneously.

**C-s (forward)**: opens minibuffer in isearch mode. Each character narrows the match. C-s again jumps to the next match. C-r reverses direction. Enter confirms and leaves cursor at match. C-g cancels and returns cursor to its pre-search position.

**M-% (query replace)**: minibuffer prompts for search string, then replacement string. For each match: `y` replaces and advances, `n` skips, `!` replaces all remaining, `q` or C-g quits.

## Acceptance criteria

- [ ] C-s opens isearch and highlights the first match as the user types
- [ ] All current matches in the visible area are highlighted simultaneously
- [ ] C-s during isearch jumps to the next match; wraps around end of buffer with a visual indicator
- [ ] C-r during isearch searches backward
- [ ] C-g during isearch returns cursor to its pre-search position with no buffer changes
- [ ] Enter during isearch confirms, leaving the cursor at the current match
- [ ] M-% prompts for both strings via sequential minibuffer inputs
- [ ] M-% y/n/!/q behavior matches the acceptance criteria description above
- [ ] Search is case-insensitive when the search string is all lowercase (Emacs smart-case behavior)
- [ ] Search handles multi-byte UTF-8 characters correctly

## Blocked by

- [ISSUE-012-command-registry-mx-minibuffer.md](ISSUE-012-command-registry-mx-minibuffer.md)
- [ISSUE-009-basic-editing-commands.md](ISSUE-009-basic-editing-commands.md)

## User stories addressed

- User story 21 (C-s incremental forward search)
- User story 22 (C-r backward search)
- User story 23 (M-% search and replace)
