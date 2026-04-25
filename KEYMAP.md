# JEditor Keymap

This document lists the currently supported Emacs-style keybindings in JEditor.

## 1. Navigation

| Key                   | Action           | Description                                              |
| --------------------- | ---------------- | -------------------------------------------------------- |
| `C-f` / `Right Arrow` | `Move CharF`     | Move forward one character                               |
| `C-b` / `Left Arrow`  | `Move CharB`     | Move backward one character                              |
| `C-n` / `Down Arrow`  | `Move LineN`     | Move to the next line                                    |
| `C-p` / `Up Arrow`    | `Move LineP`     | Move to the previous line                                |
| `M-f`                 | `Move WordF`     | Move forward one word                                    |
| `M-b`                 | `Move WordB`     | Move backward one word                                   |
| `C-a`                 | `Move LineStart` | Move to indentation; second press moves to start of line |
| `C-e`                 | `Move LineEnd`   | Move to the end of the line                              |
| `M-<`                 | `Move BufStart`  | Move to the beginning of the buffer                      |
| `M->`                 | `Move BufEnd`    | Move to the end of the buffer                            |

## 2. Editing & Deletion

| Key              | Action          | Description                             |
| ---------------- | --------------- | --------------------------------------- |
| `Backspace`      | `Backspace`     | Delete character before the cursor      |
| `C-d` / `Delete` | `DeleteForward` | Delete character at the cursor          |
| `C-k`            | `KillLine`      | Kill from cursor to the end of the line |
| `Enter`          | `Enter`         | Insert a newline                        |

## 3. File Operations (C-x Prefix)

| Key       | Action        | Description                       |
| --------- | ------------- | --------------------------------- |
| `C-x C-s` | `Save`        | Save the current file             |
| `C-x C-w` | `StartSaveAs` | Save as... (prompts for filename) |

## 4. System & Global

| Key       | Action    | Description                                         |
| --------- | --------- | --------------------------------------------------- |
| `C-x C-c` | `TryQuit` | Quit JEditor (prompts if there are unsaved changes) |
| `C-g`     | `Cancel`  | Cancel current prompt or operation                  |
| `Esc`     | `Ignore`  | (In Normal mode) Currently mapped to ignore         |
