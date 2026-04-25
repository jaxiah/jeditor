## Parent Issue

[ISSUE-014-search-replace.md](ISSUE-014-search-replace.md)

## Goal

Add incremental search and query replace through the existing minibuffer. Search
updates as the user types, moves the cursor to the active match, and highlights
all visible matches. Query replace collects the search text and replacement text
with sequential minibuffer prompts, then asks for a decision at each match.

## App State

Add search-specific fields to `App.app_state`:

```ocaml
search_query : string;
search_origin : int option;
search_direction : [ `Forward | `Backward ];
search_matches : (int * int) list;
search_current : int option;
search_wrapped : bool;
replace_query : string;
replace_with : string;
```

`search_matches` stores byte ranges. This matches the rest of the editor's
buffer/cursor model. Exact UTF-8 strings work because UTF-8 codepoint boundaries
are preserved by string search.

Smart-case behavior:

- If the query contains no ASCII uppercase letters, compare lowercased strings.
- If the query contains any ASCII uppercase letters, compare exactly.

## Modes

Extend `mode`:

```ocaml
| PromptSearch
| PromptReplaceSearch
| PromptReplaceWith
| PromptReplaceConfirm
```

Prompt behavior:

- `PromptSearch`: printable chars append to the query; Backspace removes one
  byte; `C-s` advances forward; `C-r` advances backward; Enter confirms; `C-g`
  cancels and restores `search_origin`.
- `PromptReplaceSearch`: collects the search string for `M-%`.
- `PromptReplaceWith`: collects replacement text.
- `PromptReplaceConfirm`: handles `y`, `n`, `!`, `q`, and `C-g`.

## Actions

Add actions:

```ocaml
| StartSearch of [ `Forward | `Backward ]
| SearchNext of [ `Forward | `Backward ]
| SearchConfirm
| SearchCancel
| StartQueryReplace
| QueryReplaceConfirmSearch
| QueryReplaceConfirmReplacement
| QueryReplaceYes
| QueryReplaceNo
| QueryReplaceAll
| QueryReplaceQuit
```

`MinibufAppend` and `MinibufBackspace` remain shared actions; their behavior is
mode-specific inside `update`.

## Search Algorithm

For each query update:

1. Recompute all non-overlapping matches in buffer order.
2. Pick the first match at or after the current cursor for forward search.
3. Pick the last match at or before the current cursor for backward search.
4. If none exists, wrap to the first/last match and set `search_wrapped = true`.
5. Move the cursor to the match start.

Empty query has no matches and leaves the cursor at the search origin.

## Query Replace

After `M-%`, the editor prompts for search string, then replacement. After both
are confirmed, it enters `PromptReplaceConfirm` at the first match.

- `y`: replace current match and advance to next match after replacement.
- `n`: skip current match and advance.
- `!`: replace all remaining matches from the current match onward as one undo
  snapshot.
- `q` or `C-g`: quit replace mode without changing remaining matches.

Each `y` replacement is undoable as one operation. `!` is undoable as one bulk
operation.

## Rendering

`bin/jeditor.ml` reuses its chunked writer to apply reverse-video highlighting
to either the active region or search matches. Region highlighting takes
precedence when both are active. Search matches are highlighted in search and
replace modes.

## Tests

1. `C-s` opens search mode and typing moves to the first match.
2. All matches are tracked in `search_matches`.
3. `C-s` during search jumps to the next match and wraps.
4. `C-r` during search searches backward.
5. `C-g` restores the pre-search cursor.
6. Enter confirms at current match.
7. Smart-case lower query is case-insensitive; uppercase query is exact.
8. UTF-8 search finds a CJK match.
9. `M-%` prompts for search and replacement strings.
10. Query replace supports `y`, `n`, `!`, and `q`.

## Manual Test

1. Open a file containing repeated words.
2. Press `C-s`, type the word, observe cursor jump and all visible matches
   highlighted.
3. Press `C-s` repeatedly to cycle forward; press `C-r` to go backward.
4. Press `C-g` and confirm the cursor returns to its starting position.
5. Press `M-%`, enter search and replacement strings, then use `y`, `n`, `!`,
   and `q` on matches.
