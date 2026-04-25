open Jeditor_buffer
open Jeditor_terminal

type mode =
  | Normal
  | PromptSaveAs
  | ConfirmQuit
  | PromptGotoLine
  | PromptMx
  | PromptSearch
  | PromptReplaceSearch
  | PromptReplaceWith
  | PromptReplaceConfirm

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
  | StartGotoLinePrompt | StartMx
  | ToggleMark | KillRegion | CopyRegion | Yank | Cancel
  | StartSearch of [ `Forward | `Backward ]
  | SearchNext of [ `Forward | `Backward ]
  | SearchConfirm | SearchCancel | StartQueryReplace
  | QueryReplaceConfirmSearch | QueryReplaceConfirmReplacement
  | QueryReplaceYes | QueryReplaceNo | QueryReplaceAll | QueryReplaceQuit
  | JumpToLine of int
  | Resize of { cols : int; rows : int }
  | Undo | Redo
  | Help | MinibufTab

type snapshot = {
  buffer : Buffer.t;
  cursor : Cursor.t;
}

type handler = app_state -> app_state * cmd

and app_state = {
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
  registry        : handler Registry.t;
  mark            : int option;
  kill_ring       : string option;
  last_action_was_kill : bool;
  search_query    : string;
  search_origin   : int option;
  search_direction : [ `Forward | `Backward ];
  search_matches  : (int * int) list;
  search_current  : int option;
  search_wrapped  : bool;
  replace_query   : string;
  replace_with    : string;
}

val initial_state : app_state
val state_with_file : path:string -> content:string -> app_state
val update : app_state -> action -> app_state * cmd
val handle_key : app_state -> Key.t -> app_state * cmd
(** Dispatch a single key event. In prompt modes uses hardcoded per-mode
    dispatch; in Normal mode looks up the key via the active keymap stack,
    accumulating pending prefix keys as needed. *)
