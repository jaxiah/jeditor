## Parent Issue

[ISSUE-003-buffer-implementation.md](ISSUE-003-buffer-implementation.md)

## Interfaces

```ocaml
module type S = sig
  type t

  val empty : t
  val of_string : string -> t
  val to_string : t -> string

  val insert : offset:int -> string -> t -> t
  val delete : offset:int -> length:int -> t -> t
  val slice : start:int -> length:int -> t -> string

  val length : t -> int
  val line_count : t -> int

  val line_to_offset : line:int -> t -> int
  val offset_to_line_col : offset:int -> t -> (int * int)
end

module SimpleBuffer : S
```

- `offset`, `line`, and `length` are 0-indexed integer byte values. `offset_to_line_col` returns `(line, column)` in 0-indexed byte offsets.
- `insert`: Inserts a string at the given byte offset.
- `delete`: Deletes `length` bytes starting at `offset`.
- `slice`: Returns a string of `length` bytes starting at `start`.
- Operations maintain valid UTF-8 sequences. If an operation splits a character, it should raise an exception or fail safely (in our case we assume valid inputs for offsets, or handle them gracefully).

## Module Boundaries

- `Buffer`: Defines the `S` signature and exposes `SimpleBuffer`. No other module interacts with `SimpleBuffer` directly.

## Deep Module Opportunities

- Offset to line/col and line to offset conversions are complex (especially with line endings and varying string arrays). The `S` interface completely hides whether the buffer uses a contiguous string, string array, rope, or piece tree.

## Testing Priorities

1. Empty buffer creation and properties (`length` = 0, `line_count` = 1, `to_string` = "") -- covers: `Buffer.S` signature includes `empty`, `length`, `line_count`, `to_string`; `SimpleBuffer` implements `Buffer.S`.
2. `of_string` and `to_string` round-tripping for single-line and multi-line strings -- covers: `of_string` and `to_string` in signature; `SimpleBuffer` implements `Buffer.S`.
3. `insert` at start, middle, and end of the buffer -- covers: `insert` in signature; operations return new `t` values (pure functions).
4. `delete` spanning line boundaries -- covers: `delete` in signature; operations spanning line boundaries.
5. Coordinate mapping: `line_to_offset` and `offset_to_line_col` accuracy on multi-line text -- covers: `line_to_offset` and `offset_to_line_col` in signature.
6. CJK (multi-byte UTF-8 sequences) correctness -- covers: all operations preserve valid UTF-8; no operation may split a multi-byte codepoint.
