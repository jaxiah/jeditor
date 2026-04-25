open Jeditor_terminal

type editor = Jeditor_core.App.app_state
type event = Before_save | After_open | On_cursor_move
type command = editor -> editor
type hook = editor -> editor

module type PLUGIN = sig
  val name : string
end

val register_command : string -> command -> unit
val bind_key : Key.t list -> string -> unit
val register_hook : event -> hook -> unit
val clear_registrations : unit -> unit

val buffer_ids : editor -> int list
val buffer_content : int -> editor -> string option
val insert : buffer_id:int -> offset:int -> text:string -> editor -> editor
val delete : buffer_id:int -> offset:int -> length:int -> editor -> editor
val cursor_positions : int -> editor -> int list option
val set_cursor_positions : buffer_id:int -> positions:int list -> editor -> editor
val message : string -> editor -> editor
val enable_line_highlight : editor -> editor

val apply_registered : editor -> editor
