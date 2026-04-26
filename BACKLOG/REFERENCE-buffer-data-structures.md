# Buffer Data Structure Reference Guide

> **Purpose**: This document is not a final decision, but a selection reference guide.
> When the project reaches a point where upgrading the buffer data structure becomes necessary,
> consult this document to make an informed choice based on the constraints at that time.

## Target Features (Design Constraints)

1. **High performance**: capable of handling files with millions of lines
2. **Multi-cursor**: maintain multiple independent cursors simultaneously; insert/delete must update all cursor positions in sync
3. **Extensibility**: OCaml plugin API needs access to buffer contents and coordinate conversion
4. **Cross-platform**: Windows / macOS / Linux, no platform-specific dependencies
5. **Unicode support**: stored internally as bytes; coordinate system uses byte offsets; display-width calculation is independent of the storage layer

## Candidate Data Structures

### 1. Array of Lines — current implementation

**Description**: `string array` where each element is one line of content (without the newline character).

**OCaml representation**:

```ocaml
type t = string array
```

**Operation complexity** (after a correct implementation):

| Operation                        | Complexity    | Notes                          |
| -------------------------------- | ------------- | ------------------------------ |
| `get_line i`                     | O(1)          | direct array index             |
| `line_count`                     | O(1)          | `Array.length`                 |
| `line_to_offset line`            | O(line)       | sum lengths of preceding lines |
| `offset_to_line_col`             | O(line_count) | linear scan                    |
| `insert` / `delete` (in-line)    | O(line_len)   | string concatenation           |
| `insert` / `delete` (cross-line) | O(line_count) | array reconstruction           |
| `slice`                          | O(length)     | string substring               |

**Pros**:

- Simplest implementation, highest readability
- Line-oriented operations (goto-line, rendering) are naturally efficient
- OCaml `string` is immutable, fits the functional style

**Cons**:

- `line_to_offset` / `offset_to_line_col` are both O(N); unacceptable for million-line files
- Cross-line insert/delete requires rebuilding the array, O(line_count)
- Multi-cursor: each edit must update row offsets for all cursors, O(cursor_count \* line_count)

**Suitable for**: files < 100K lines, single cursor or a small number of cursors. This is the correct current choice for jeditor, **but the implementation needs fixing** (see ISSUE-020).

**Comparable editor**: Vim (`memline`: array of lines + B-tree line index)

### 2. Gap Buffer

**Description**: A single contiguous byte array with a movable "gap" maintained at the cursor position. Insertion writes directly into the gap; moving the cursor moves the gap.

**OCaml representation**:

```ocaml
type t = {
  mutable buf       : bytes;
  mutable gap_start : int;
  mutable gap_end   : int;
}
```

**Operation complexity**:

| Operation            | Complexity     | Notes                                               |
| -------------------- | -------------- | --------------------------------------------------- |
| `insert` at gap      | O(1) amortized | writes directly; occasional reallocation            |
| `delete` at gap      | O(1)           | move gap boundary                                   |
| `move gap` to offset | O(distance)    | bytes must be shifted                               |
| `line_to_offset`     | O(N)           | must scan for newlines, unless a line index is kept |
| `offset_to_line_col` | O(N)           | same                                                |

**Pros**:

- Excellent performance for sequential editing (O(1) insert/delete)
- Good memory locality, CPU cache-friendly
- Relatively simple to implement (proven by Emacs over decades)

**Cons**:

- **Inherently hostile to multi-cursor**: there is only one gap; multi-cursor editing requires repeatedly moving the gap, O(cursor_count \* distance)
- Random access is expensive: every jump requires shifting the gap
- Line index must be maintained separately (typically an `int array` of line-start offsets)
- `Bytes.t` in OCaml is mutable, which conflicts with the functional style and makes testing and undo more complex

**Suitable for**: single-cursor, sequential-editing-heavy editors that do not require frequent random jumps. **Not recommended** for multi-cursor scenarios.

**Comparable editors**: Emacs (Gap Buffer + line cache), Scintilla

### 3. Piece Table

**Description**: Maintains two read-only byte pools (`original` = the file's initial content, `added` = an append-only buffer for all insertions). The logical content is described by a list/tree of "pieces", each pointing to a range in one of the two pools.

**OCaml representation** (simplified):

```ocaml
type source = Original | Added

type piece = {
  source : source;
  start  : int;
  length : int;
  (* if using an augmented tree, also store newline_count for O(log N) line indexing *)
}

type t = {
  original : string;
  added    : Buffer.t;    (* append-only *)
  pieces   : piece list;  (* or a balanced tree *)
}
```

**Operation complexity** (pieces stored in a balanced tree with `newline_count` augmentation):

| Operation            | Complexity        | Notes                              |
| -------------------- | ----------------- | ---------------------------------- |
| `insert`             | O(log N)          | split one piece, append to `added` |
| `delete`             | O(log N)          | split / remove pieces              |
| `line_to_offset`     | O(log N)          | uses the augmented newline counts  |
| `offset_to_line_col` | O(log N)          | same                               |
| `slice`              | O(log N + length) | tree traversal + copy              |
| `undo`               | O(1)              | restore an old piece-tree snapshot |

**Pros**:

- **Million-line files**: all coordinate operations are O(log N)
- **Multi-cursor**: all cursors are logical offsets; they do not interfere with each other and are updated uniformly after each edit
- **Undo/Redo naturally efficient**: the piece tree is a persistent data structure; old versions are nearly free
- **Excellent OCaml fit**: functional balanced trees (analogous to `Map.Make`) are OCaml's strong suit; immutable nodes are GC-friendly
- The `added` buffer is append-only and never modified — maps perfectly to OCaml's `Buffer.t`

**Cons**:

- Highest implementation complexity (especially maintaining the augmented tree)
- Piece fragmentation: many small edits produce many small pieces; periodic compaction (`compact`) is needed
- `slice` across multiple pieces requires string concatenation — a one-time O(length) allocation

**Suitable for**: **jeditor's long-term target**. For million-line files, multi-cursor, undo history, and read-only plugin access, Piece Table is the most balanced choice.

**Comparable editors**: VS Code, AbiWord

### 4. Rope

**Description**: A binary tree where leaf nodes store short string chunks and internal nodes store the byte count of the left subtree (for O(log N) random access).

**OCaml representation**:

```ocaml
type t =
  | Leaf of string
  | Node of { left: t; right: t; weight: int; height: int }
```

**Operation complexity**:

| Operation           | Complexity                                         |
| ------------------- | -------------------------------------------------- |
| `insert` / `delete` | O(log N)                                           |
| `concat`            | O(log N)                                           |
| `slice`             | O(log N + length)                                  |
| `line_to_offset`    | O(log N) (requires newline count stored in leaves) |

**Pros**:

- Fits OCaml ADTs perfectly; code reads naturally and elegantly
- Naturally immutable; undo/redo can exploit structural sharing
- Multi-cursor friendly (same as Piece Table)

**Cons**:

- **High GC pressure**: many small heap nodes; frequent GC cycles
- **Cache-unfriendly**: tree nodes are scattered across the heap; poor memory access locality
- In practice slower than Piece Table (more pointer indirections)
- Rebalancing (AVL / weight-balanced) adds implementation complexity

**Suitable for**: academic or research-oriented editors. For jeditor, Piece Table is the more pragmatic choice.

**Comparable editors**: Xi editor (early versions)

## Decision Matrix

| Requirement               | Array of Lines (fixed) | Gap Buffer            | Piece Table | Rope |
| ------------------------- | ---------------------- | --------------------- | ----------- | ---- |
| Performance < 100K lines  | **good**               | good                  | good        | good |
| Million-line performance  | poor (O(N) line index) | poor                  | **good**    | good |
| Multi-cursor              | fair                   | poor                  | **good**    | good |
| OCaml fit                 | good                   | fair (needs mutation) | **good**    | good |
| Implementation complexity | **low**                | medium                | high        | high |
| Undo efficiency           | fair                   | fair                  | **good**    | good |
| Plugin API friendliness   | good                   | fair                  | **good**    | good |
| GC pressure               | low                    | **low**               | low         | high |

## Recommended Upgrade Path

```
Phase 1 (current)
  Array of Lines (with implementation fixed)
  → appropriate for the PRD-001 feature-completeness phase
  → ceiling: ~50K lines, small number of cursors

Phase 2 (once performance requirements are concrete)
  Piece Table (augmented balanced tree)
  → trigger: files exceeding 100K lines, or multi-cursor editing hits a performance wall
  → interface unchanged (buffer.mli); only buffer.ml is replaced
  → suggestion: implement the non-augmented version first (piece list),
    validate against the interface, then upgrade to a tree

Phase 3 (optional, may never be needed)
  Rope or B-Tree of Pieces
  → trigger: need O(1) concat (large-file merging, macro operations)
  → not required by jeditor's current roadmap
```

## Core Design Principles (tied to this project's features)

### Unicode

All data structures use **byte offsets** as the internal coordinate system. `offset_to_line_col` returns a byte column; display column width is computed separately by the `Wcwidth` module. This principle does not change with the data structure.

### Multi-cursor

Cursors are **logical byte offsets**, decoupled from the data structure. The data structure only needs to expose `apply_edit : edit -> int -> int` (map an old offset to a new offset given an edit operation) after each insert/delete. The `Cursor` module already implements this contract.

### Plugin API

Plugins access the buffer through the `Buffer.S` signature and do not depend on the concrete implementation. Upgrading the data structure requires no changes to the plugin interface.

### Immutable vs. Mutable

- Array of Lines and Piece Table can be made purely functional (each operation returns a new value), which simplifies testing and undo
- Gap Buffer is inherently mutable and requires extra wrapping
- Prefer structures that can be made functional unless performance measurements prove that a mutable version is necessary

_Last updated: 2026-04-26_
