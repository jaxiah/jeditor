type orientation = Horizontal | Vertical

type window = {
  id : int;
  buffer_id : int;
  scroll_top_line : int;
}

type rect = {
  x : int;
  y : int;
  width : int;
  height : int;
}

type node =
  | Leaf of window
  | Split of orientation * float * node * node

type t = {
  root : node;
  focused : int;
  next_id : int;
}

val single : buffer_id:int -> t
val leaves : t -> window list
val focused_window : t -> window
val update_focused : (window -> window) -> t -> t
val set_focused_buffer : buffer_id:int -> t -> t
val replace_buffer : old_id:int -> new_id:int -> t -> t
val split_focused : orientation -> t -> t
val focus_next : t -> t
val close_focused : t -> t
val close_others : t -> t
val layouts : cols:int -> rows:int -> t -> (window * rect) list
