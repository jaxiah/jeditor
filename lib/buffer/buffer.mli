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

  val is_word_char : Uchar.t -> bool
  val first_non_whitespace : line:int -> t -> int
  val next_word_boundary : offset:int -> t -> int
  val prev_word_boundary : offset:int -> t -> int
end

(** The current buffer implementation. The underlying representation is
    abstract; callers must not depend on it. To swap implementations,
    change [buffer.ml] only -- this interface is the stable contract. *)
include S
