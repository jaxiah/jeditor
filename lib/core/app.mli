open Jeditor_buffer
open Jeditor_terminal

type mode =
  | Normal
  | PromptSaveAs
  | ConfirmQuit
  | PromptGotoLine

type move_target =
  | CharF | CharB | LineN | LineP
  | WordF | WordB
  | LineStart | LineEnd
  | BufStart | BufEnd

type cmd =
  | Noop
  | WriteFile of { path : string; content : string }

type action =
  | Insert of Uchar.t | Backspace | Enter
  | Save | StartSaveAs | TryQuit
  | MinibufAppend of Uchar.t | MinibufBackspace | MinibufConfirm | MinibufCancel
  | WriteDone of string | WriteError of string | Quit | Ignore
  | Move of move_target
  | DeleteForward | DeleteWordBack | DeleteWordForward | KillLine
  | StartGotoLinePrompt
  | JumpToLine of int
  | Resize of { cols : int; rows : int }
  | Undo | Redo
  | Help

type snapshot = {
  buffer : Buffer.t;
  cursor : Cursor.t;
}

type app_state = {
  buffer          : Buffer.t;
  cursor          : Cursor.t;
  quit            : bool;
  file_path       : string option;
  modified        : bool;
  mode            : mode;
  minibuf         : string;
  message         : string;
  scroll_top_line : int;
  cols            : int;
  rows            : int;
  undo_stack      : snapshot list;
  redo_stack      : snapshot list;
  pending_keys    : Key.t list;
  keymap          : Keymap.t list;
}

val initial_state : app_state
val state_with_file : path:string -> content:string -> app_state
val update : app_state -> action -> app_state * cmd
val handle_key : app_state -> Key.t -> app_state * cmd
(** Dispatch a single key event. In prompt modes uses hardcoded per-mode
    dispatch; in Normal mode looks up the key via the active keymap stack,
    accumulating pending prefix keys as needed. *)
