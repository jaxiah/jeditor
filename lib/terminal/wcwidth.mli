val char_width : Uchar.t -> int
(** Display width of a single Unicode character: 2 for wide chars (CJK,
    full-width forms, etc.), 0 for control/combining, 1 for everything else.
    Delegates to [Uucp.Break.tty_width_hint]. *)

val string_display_width : string -> int
(** Total display column width of a UTF-8 string. *)

val display_col_of_byte_col : string -> byte_col:int -> int
(** Given a UTF-8 line string and a byte offset within it, return the
    corresponding display column (sum of [char_width] for all codepoints
    before [byte_col]). Used to map cursor byte offset -> terminal column. *)
