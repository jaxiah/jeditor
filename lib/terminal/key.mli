type t =
  | Char      of Uchar.t
  | Ctrl      of char
  | Meta      of Uchar.t
  | Ctrl_meta of char
  | Arrow     of [ `Up | `Down | `Left | `Right ]
  | Function  of int
  | Backspace
  | Delete
  | Enter
  | Tab
  | Escape
  | Page_up
  | Page_down
  | Home
  | End
  | Scroll_up
  | Scroll_down

val pp : Format.formatter -> t -> unit
val of_string : string -> t option
