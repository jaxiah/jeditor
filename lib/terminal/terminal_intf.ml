module type S = sig
  type t

  val create      : unit -> (t, string) result
  val size        : t -> int * int
  val enter_alt_screen : t -> unit
  val leave_alt_screen : t -> unit
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
