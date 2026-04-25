# jeditor

A cross-platform TUI text editor written in OCaml, emphasizing functional programming style (built by an AI agent).

## Features Implemented

- **Cross-platform TUI Backend**: Supports native VT sequences on both Windows (Win32 API) and Unix platforms.
- **UTF-8 Safe Buffer**: Purely functional text management supporting multi-line editing and CJK character parsing.
- **Modern Cursor Model**: Adopts a separated Selection/Cursor design, supporting automatic cursor merging and adaptive positioning after edits.
- **Core Editing Operations**: Supports character insertion, deletion, line breaks, and basic file I/O (open, save, save as).
- **Emacs-style Keymap**: Built-in support for standard Emacs navigation and editing chords. See [KEYMAP.md](KEYMAP.md) for a full list.
- **Interactive Feedback**: Features a basic status bar display and prompts for unsaved changes.
