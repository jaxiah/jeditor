open Jeditor_buffer
open Jeditor_terminal

type mode =
  | Normal
  | PendingCx
  | PromptSaveAs
  | ConfirmQuit

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

type app_state = {
  buffer    : Buffer.t;
  cursor    : Cursor.t;
  quit      : bool;
  file_path : string option;
  modified  : bool;
  mode      : mode;
  minibuf   : string;
  message   : string;
}

val initial_state : app_state
val state_with_file : path:string -> content:string -> app_state
val action_of_key : mode -> Key.t -> action
val update : app_state -> action -> app_state * cmd
