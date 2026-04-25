open Jeditor_core
open Jeditor_buffer
open Jeditor_terminal

type editor = App.app_state
type event = Before_save | After_open | On_cursor_move
type command = editor -> editor
type hook = editor -> editor

module type PLUGIN = sig
  val name : string
end

type registration =
  | Command of string * command
  | Keybinding of Key.t list * string
  | Hook of event * hook

let registrations : registration list ref = ref []

let register_command name command =
  registrations := Command (name, command) :: !registrations

let bind_key keys command_name =
  registrations := Keybinding (keys, command_name) :: !registrations

let register_hook event hook =
  registrations := Hook (event, hook) :: !registrations

let clear_registrations () = registrations := []

let buffer_ids (st : editor) =
  List.map (fun (b : App.buffer_entry) -> b.id) st.buffers

let buffer_content id (st : editor) =
  App.buffer_by_id id st |> Option.map (fun (b : App.buffer_entry) -> Buffer.to_string b.buffer)

let update_buffer_entry id f st =
  let buffers =
    List.map
      (fun (b : App.buffer_entry) -> if b.id = id then f b else b)
      st.App.buffers
  in
  let st = { st with App.buffers } in
  match App.buffer_by_id st.current_buffer_id st with
  | Some current ->
      { st with buffer = current.buffer; cursor = current.cursor;
                file_path = current.file_path; modified = current.modified;
                undo_stack = current.undo_stack; redo_stack = current.redo_stack }
  | None -> st

let insert ~buffer_id ~offset ~text st =
  update_buffer_entry buffer_id
    (fun (b : App.buffer_entry) ->
      let snap = { App.buffer = b.buffer; cursor = b.cursor } in
      let buffer = Buffer.insert ~offset text b.buffer in
      let cursor =
        Cursor.apply_edit ~offset ~deleted:0 ~inserted:(String.length text) b.cursor
      in
      { b with buffer; cursor; modified = true; undo_stack = snap :: b.undo_stack;
               redo_stack = [] })
    st

let delete ~buffer_id ~offset ~length st =
  update_buffer_entry buffer_id
    (fun (b : App.buffer_entry) ->
      let snap = { App.buffer = b.buffer; cursor = b.cursor } in
      let buffer = Buffer.delete ~offset ~length b.buffer in
      let cursor = Cursor.apply_edit ~offset ~deleted:length ~inserted:0 b.cursor in
      { b with buffer; cursor; modified = true; undo_stack = snap :: b.undo_stack;
               redo_stack = [] })
    st

let cursor_positions id st =
  App.buffer_by_id id st
  |> Option.map (fun (b : App.buffer_entry) ->
    Cursor.to_list b.cursor |> List.map (fun r -> r.Cursor.head))

let set_cursor_positions ~buffer_id ~positions st =
  update_buffer_entry buffer_id
    (fun (b : App.buffer_entry) ->
      let cursor =
        positions
        |> List.map (fun head -> { Cursor.head; anchor = head })
        |> Cursor.of_list
      in
      { b with cursor })
    st

let message text st = { st with App.message = text }

let enable_line_highlight st = { st with App.line_highlight_enabled = true }

let safe_command name command st =
  try command st with exn ->
    message ("Plugin command " ^ name ^ " failed: " ^ Printexc.to_string exn) st

let safe_hook event hook st =
  try hook st with exn ->
    let event_name =
      match event with
      | Before_save -> "before-save"
      | After_open -> "after-open"
      | On_cursor_move -> "on-cursor-move"
    in
    message ("Plugin hook " ^ event_name ^ " failed: " ^ Printexc.to_string exn) st

let apply_registration st = function
  | Command (name, command) ->
      let registry =
        Registry.register name
          (fun st -> safe_command name command st, App.Noop)
          st.App.registry
      in
      { st with App.registry }
  | Keybinding (keys, command_name) ->
      let layer = Keymap.bind keys command_name Keymap.empty in
      { st with App.keymap = layer :: st.keymap }
  | Hook (event, hook) ->
      (match event with
       | Before_save ->
           { st with App.before_save_hooks = safe_hook event hook :: st.before_save_hooks }
       | After_open ->
           { st with App.after_open_hooks = safe_hook event hook :: st.after_open_hooks }
       | On_cursor_move ->
           { st with App.on_cursor_move_hooks = safe_hook event hook :: st.on_cursor_move_hooks })

let apply_registered st =
  List.fold_left apply_registration st (List.rev !registrations)
