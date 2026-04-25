## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Implement the full set of basic navigation and deletion commands. After this issue the editor supports all single-cursor movement and deletion that an Emacs user would expect in everyday editing -- without yet having a configurable keymap (that comes in ISSUE-011).

**Navigation**: character movement (C-f, C-b, C-n, C-p, arrow keys), word movement (M-f, M-b), line boundaries (C-a, C-e), buffer boundaries (M-<, M->), jump to line (M-g g with a numeric prompt).

**Deletion**: forward character (C-d), backward word (M-Backspace), kill to end of line (C-k). Kill ring is a single slot at this stage (no kill ring history needed until ISSUE-013).

**Viewport scrolling**: the view follows the cursor -- if the cursor moves off the top or bottom of the visible area, the viewport scrolls to keep it visible (scroll-follows-cursor invariant).

## Acceptance criteria

- [x] All navigation commands move the cursor to the correct byte offset as verified by the status bar position display
- [x] C-n/C-p on the last/first line do nothing (no wrap-around)
- [x] M-f/M-b skip punctuation and whitespace consistently (Emacs word boundary semantics)
- [x] C-a moves to the first non-whitespace character; a second C-a moves to column 0 (Emacs `back-to-indentation` behavior)
- [x] C-d at end of buffer does nothing
- [x] C-k on an empty line deletes the newline; C-k on a non-empty line kills to end of line but leaves the newline
- [x] M-g g prompts for a line number in the minibuffer stub and jumps correctly
- [x] Viewport scrolls to keep cursor visible after every navigation command
- [x] All commands behave correctly on a buffer with a single line and on a buffer with a single character

## Completed

2026-04-25 — all acceptance criteria met. Implemented via TDD. Added Emacs-like navigation (C-f/b/n/p, M-f/b, etc.) and deletion (C-d, C-k, M-Backspace, M-d). Implemented viewport scrolling logic in `App.update` and the renderer. Added `Resize` action to sync terminal dimensions. M-g g goto-line implemented with `PromptGotoLine` mode (keymap-driven after ISSUE-011).

## Blocked by

- [ISSUE-006-minimal-edit-loop.md](ISSUE-006-minimal-edit-loop.md)

## User stories addressed

- User story 5 (C-f/b/n/p + arrows)
- User story 6 (M-f/b word movement)
- User story 7 (C-a/e line boundaries)
- User story 8 (M-</M-> buffer boundaries)
- User story 11 (C-d forward delete)
- User story 12 (M-Backspace delete word)
- User story 13 (C-k kill line)
- User story 28 (M-g g jump to line)
