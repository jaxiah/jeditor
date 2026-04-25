# JEditor Keymap

Emacs-style keybindings. All bindings live in `Keymap.emacs_default` and
can be overridden by adding a higher-priority layer to `app_state.keymap`.

## 1. Navigation

| Key                   | Command                | Description                                              |
| --------------------- | ---------------------- | -------------------------------------------------------- |
| `C-f` / `Right`       | `move-forward-char`    | Move forward one character                               |
| `C-b` / `Left`        | `move-backward-char`   | Move backward one character                              |
| `C-n` / `Down`        | `move-next-line`       | Move to next line                                        |
| `C-p` / `Up`          | `move-prev-line`       | Move to previous line                                    |
| `M-f`                 | `move-forward-word`    | Move forward one word                                    |
| `M-b`                 | `move-backward-word`   | Move backward one word                                   |
| `C-a`                 | `move-line-start`      | Move to indentation; second press moves to column 0      |
| `C-e`                 | `move-line-end`        | Move to end of line                                      |
| `M-<`                 | `move-buf-start`       | Move to beginning of buffer                              |
| `M->`                 | `move-buf-end`         | Move to end of buffer                                    |
| `M-g g`               | `goto-line`            | Prompt for line number and jump                          |

## 2. Editing & Deletion

| Key                   | Command                | Description                                              |
| --------------------- | ---------------------- | -------------------------------------------------------- |
| `Backspace`           | `backward-delete-char` | Delete character before cursor (UTF-8 aware)             |
| `C-d` / `Delete`      | `delete-forward-char`  | Delete character at cursor                               |
| `M-Backspace`         | `delete-word-back`     | Delete word before cursor                                |
| `M-d`                 | `kill-word-forward`    | Delete word after cursor                                 |
| `C-k`                 | `kill-line`            | Kill to end of line (kills newline if at end of line)    |
| `C-Space` / `C-@`     | `set-mark-command`     | Set or clear the mark for region selection               |
| `C-w`                 | `kill-region`          | Cut selected region into the kill ring                   |
| `M-w`                 | `copy-region`          | Copy selected region into the kill ring                  |
| `C-y`                 | `yank`                 | Insert kill ring content at the cursor                   |
| `Enter`               | `new-line`             | Insert newline                                           |

## 3. Undo / Redo

| Key          | Command  | Description                   |
| ------------ | -------- | ----------------------------- |
| `C-/` / `C-_` | `undo`  | Undo last buffer-modifying action |
| `M-_`        | `redo`   | Redo last undone action        |

## 4. File Operations (C-x prefix)

| Key       | Command    | Description                        |
| --------- | ---------- | ---------------------------------- |
| `C-x C-s` | `save`     | Save current file                  |
| `C-x C-w` | `save-as`  | Save as (prompts for filename)      |
| `C-x C-c` | `quit`     | Quit (prompts if unsaved changes)  |

## 5. Global

| Key       | Command   | Description                                         |
| --------- | --------- | --------------------------------------------------- |
| `C-c`     | `quit`    | Quit (prompts if unsaved changes)                   |
| `C-g`     | `cancel`  | Cancel prompt or pending prefix                     |
| `Escape`  | `cancel`  | Cancel prompt or pending prefix                     |
| `M-x`     | `execute-extended-command` | Prompt for and execute a named command |

## Notes

- **Prefix hint**: while typing a multi-key sequence (e.g. after `C-x`), the
  status bar shows the keys typed so far (`C-x ...`).
- **M-x completion**: while entering a command name, matching registered
  commands are shown above the minibuffer; `Tab` extends to the longest common
  prefix when possible.
- **Region selection**: `C-Space` (`C-@` in terminal notation) toggles the mark.
  The region between mark and cursor is highlighted; `C-g` clears the active
  mark.
- **Unbound keys**: non-printable unbound keys display `"Key not bound"` in
  the status bar.
- **Self-insert**: any printable `Key.Char` not bound in the keymap is
  inserted as a character.
- **Rebinding**: prepend a custom `Keymap.t` to `app_state.keymap` to
  override any binding without touching `emacs_default`.
