type 'a t
(** Parametric name-to-handler map. Internally a sorted balanced tree;
    all operations are O(log n). *)

val empty    : 'a t
val register : string -> 'a -> 'a t -> 'a t
(** [register name handler t] returns a registry with [name] bound to
    [handler].  Duplicate names are silently overwritten. *)

val lookup   : string -> 'a t -> 'a option
(** Exact-match lookup. *)

val names    : 'a t -> string list
(** All registered names in alphabetical order. *)

val complete : prefix:string -> 'a t -> string list
(** All names whose prefix matches [prefix], in alphabetical order. *)
