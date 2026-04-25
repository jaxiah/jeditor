## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Activate the multi-cursor capabilities that `Cursor` (ISSUE-004) already supports at the data structure level. Add the two entry points for spawning additional cursors: next-occurrence selection and column expansion. All existing editing commands automatically operate on all cursors because they go through `Cursor.apply_edit`.

**Next occurrence**: with text selected (mark active), a dedicated command finds the next occurrence of the selected text in the buffer and adds a new cursor+selection there. Repeated invocations find further occurrences. The cursor list is kept sorted and deduplicated by the Cursor module.

**Column expansion**: a dedicated command duplicates the primary cursor one line downward at the same column, creating a vertical block of cursors. Repeated invocations extend the block further.

## Acceptance criteria

- [ ] With a region selected, invoking next-occurrence adds a cursor at the next match and keeps the original selection active
- [ ] Repeated next-occurrence invocations add further cursors without disturbing existing ones
- [ ] Column expansion adds a cursor one line below at the same display column; repeated calls extend the column
- [ ] Column expansion at the last line of the buffer does nothing
- [ ] All cursors insert, delete, and navigate simultaneously
- [ ] Cursors that collide after an edit are automatically merged (inherited from Cursor module)
- [ ] C-g dismisses all secondary cursors and leaves a single primary cursor
- [ ] All cursors are visually distinct from each other and from the background text (e.g. each cursor cell is highlighted)

## Blocked by

- [ISSUE-004-cursor-module.md](ISSUE-004-cursor-module.md)
- [ISSUE-013-selection-clipboard.md](ISSUE-013-selection-clipboard.md)

## User stories addressed

- User story 40 (next occurrence cursor)
- User story 41 (column expansion)
- User story 42 (simultaneous edits)
- User story 43 (cursor merge)
- User story 44 (C-g dismiss secondary cursors)
