open Jeditor_terminal

type binding =
  | Command of string  (** leaf: a named command *)
  | Prefix  of t       (** internal node: sub-keymap *)

and t = (Key.t * binding) list
(** Prefix trie stored as an association list. *)

type lookup_result =
  | Matched of string  (** command name ready to dispatch *)
  | Pending            (** valid prefix so far -- wait for next key *)
  | Unbound            (** no binding in any layer *)

val empty : t
val bind : Key.t list -> string -> t -> t
(** [bind keys cmd km] adds a binding for [keys] (length >= 1) to [cmd].
    Intermediate Prefix nodes are created or extended as needed. *)

val lookup : t list -> Key.t list -> lookup_result
(** [lookup layers keys] looks up [keys] across [layers] (head = highest
    priority).  The first layer that has a binding for the first key owns
    the sequence entirely. *)

val emacs_default : t
(** Built-in Emacs-style keymap covering all commands from
    ISSUE-006 through ISSUE-010. *)
