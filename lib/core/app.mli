open Jeditor_buffer
open Jeditor_terminal

type mode =
  | Normal
  | PendingCx
  | PromptSaveAs
  | ConfirmQuit
  | PendingMg
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
  | Insert of Uchar.t
  | Backspace
  | Enter
  | PendingCx
  | Save
  | StartSaveAs
  | TryQuit
  | MinibufAppend of Uchar.t
  | MinibufBackspace
  | MinibufConfirm
  | MinibufCancel
  | WriteDone of string
  | WriteError of string
  | Quit
  | Ignore
  | Move of move_target
  | DeleteForward
  | DeleteWordBack
  | KillLine
  | JumpToLinePrompt
  | StartGotoLinePrompt
  | JumpToLine of int
  | Resize of { cols : int; rows : int }
  | Undo
  | Redo

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
  }

val initial_state : app_state
val state_with_file : path:string -> content:string -> app_state
val action_of_key : mode -> Key.t -> action
val update : app_state -> action -> app_state * cmd
