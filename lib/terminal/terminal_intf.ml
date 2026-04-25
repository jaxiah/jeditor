module type S = sig
  type t

  val create      : unit -> (t, string) result
  val size        : t -> int * int
  val move_to     : t -> row:int -> col:int -> unit
  val hide_cursor : t -> unit
  val show_cursor : t -> unit
  val write_char  : t -> Uchar.t -> Attr.t -> unit
  val write_string : t -> string -> Attr.t -> unit
  val write_raw   : t -> string -> unit
  val clear_line  : t -> unit
  val clear_screen : t -> unit
  val flush       : t -> unit
  val close       : t -> unit
end
