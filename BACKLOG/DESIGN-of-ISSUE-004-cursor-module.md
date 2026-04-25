## Parent Issue

[ISSUE-004-cursor-module.md](ISSUE-004-cursor-module.md)

## Interfaces

```ocaml
module Cursor : sig
  type range = { head : int; anchor : int }
  type t

  (* Constructors *)
  val create : int -> t
  val create_selection : head:int -> anchor:int -> t
  val of_list : range list -> t

  (* Accessors *)
  val to_list : t -> range list
  val primary : t -> range

  (* Operations *)
  val apply_edit : offset:int -> deleted:int -> inserted:int -> t -> t
  val add : range -> t -> t
end
```

## Module Boundaries

We will create a new `Cursor` module in `lib/core/cursor.ml` and `lib/core/cursor.mli`.
It will encapsulate all logic for moving, shifting, and merging cursors, keeping the list sorted and non-overlapping.

## Testing Priorities

1. Single cursor: create, to_list — covers: `Cursor.t` is opaque; `create` and `to_list` in public interface.
2. Single cursor edit: apply_edit before, after, and exactly at edit point — covers: `apply_edit` correctly handles all three cursor-relative-to-edit cases.
3. Single cursor edit: apply_edit inside deleted range (clamped) — covers: `apply_edit` correctly handles cursor inside deleted range.
4. Selection anchor: apply_edit preserving anchor, clamping if deleted — covers: selection anchor is preserved correctly through edits.
5. Multi-cursor: of_list sorts and deduplicates — covers: sorted, non-overlapping invariant.
6. Multi-cursor edit: atomic update shifts some, clamps others — covers: `apply_edit` on list with multiple cursors updates all atomically.
7. Collision and merge: edits that cause cursors to overlap merge them into one — covers: cursors that collide after an edit are merged into one.

## Open Questions

- When two selections merge, how is the direction (head vs anchor) determined?
  Decision: The resulting merged selection will span from `min(all_starts)` to `max(all_ends)`. The direction will match the first (left-most) selection involved in the merge.
