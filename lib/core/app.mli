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
  | PromptSwitchBuffer
  | PromptKillBuffer
  | ConfirmKillBuffer

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
  | AddNextOccurrence | AddCursorBelow
  | StartSearch of [ `Forward | `Backward ]
  | SearchNext of [ `Forward | `Backward ]
  | SearchConfirm | SearchCancel | StartQueryReplace
  | QueryReplaceConfirmSearch | QueryReplaceConfirmReplacement
  | QueryReplaceYes | QueryReplaceNo | QueryReplaceAll | QueryReplaceQuit
  | SplitWindowHorizontal | SplitWindowVertical | FocusNextWindow
  | CloseWindow | CloseOtherWindows
  | StartSwitchBuffer | SwitchBuffer of string | ShowBufferList
  | StartKillBuffer | KillBuffer of string | KillBufferConfirmed
  | JumpToLine of int
  | Resize of { cols : int; rows : int }
  | Undo | Redo
  | Help | MinibufTab

type snapshot = {
  buffer : Buffer.t;
  cursor : Cursor.t;
}

type buffer_entry = {
  id : int;
  name : string;
  file_path : string option;
  buffer : Buffer.t;
  cursor : Cursor.t;
  modified : bool;
  undo_stack : snapshot list;
  redo_stack : snapshot list;
}

type handler = app_state -> app_state * cmd
and plugin_hook = app_state -> app_state
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
  frame           : Frame.t;
  buffers         : buffer_entry list;
  current_buffer_id : int;
  next_buffer_id  : int;
  before_save_hooks : plugin_hook list;
  after_open_hooks : plugin_hook list;
  on_cursor_move_hooks : plugin_hook list;
  line_highlight_enabled : bool;
}

val initial_state : app_state
val state_with_file : path:string -> content:string -> app_state
val current_buffer : app_state -> buffer_entry
val buffer_by_id : int -> app_state -> buffer_entry option
val open_file : path:string -> content:string -> app_state -> app_state
val update : app_state -> action -> app_state * cmd
val handle_key : app_state -> Key.t -> app_state * cmd
(** Dispatch a single key event. In prompt modes uses hardcoded per-mode
    dispatch; in Normal mode looks up the key via the active keymap stack,
    accumulating pending prefix keys as needed. *)
