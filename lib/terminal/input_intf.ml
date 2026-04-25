module type S = sig
  type t

  val create   : unit -> (t, string) result
  (** Enter raw mode. Returns an Error with a reason string on failure, does not throw exceptions. *)

  val next_key : t -> Key.t option
  (** Blocks and reads the next full key event.
      Handles multi-byte ESC sequences. Returns None for EOF or unrecoverable errors. *)

  val close    : t -> unit
  (** Restore terminal to original mode. Safe to call multiple times (idempotent). *)
end
