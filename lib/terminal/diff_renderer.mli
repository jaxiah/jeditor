type cell = {
  text : string;
  attr : Attr.t;
}

type frame
type state

val blank_cell : cell
val blank : cols:int -> rows:int -> frame
val build : cols:int -> rows:int -> (set_cell:(row:int -> col:int -> cell -> unit) -> unit) -> frame
val set : row:int -> col:int -> cell -> frame -> frame
val get : row:int -> col:int -> frame -> cell
val dimensions : frame -> int * int
val empty_state : state
val render : ?force:bool -> state -> frame -> string * state
