type range = { head : int; anchor : int }
type t

val create : int -> t
val create_selection : head:int -> anchor:int -> t
val of_list : range list -> t
val to_list : t -> range list
val primary : t -> range
val apply_edit : offset:int -> deleted:int -> inserted:int -> t -> t
val add : range -> t -> t
