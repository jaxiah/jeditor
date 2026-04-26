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
  | Insert of Uchar.t
  | Backspace
  | Enter
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
  | DeleteWordForward
  | KillLine
  | StartGotoLinePrompt
  | StartMx
  | ToggleMark
  | KillRegion
  | CopyRegion
  | Yank
  | Cancel
  | AddNextOccurrence
  | AddCursorBelow
  | StartSearch of [ `Forward | `Backward ]
  | SearchNext of [ `Forward | `Backward ]
  | SearchConfirm
  | SearchCancel
  | StartQueryReplace
  | QueryReplaceConfirmSearch
  | QueryReplaceConfirmReplacement
  | QueryReplaceYes
  | QueryReplaceNo
  | QueryReplaceAll
  | QueryReplaceQuit
  | SplitWindowHorizontal
  | SplitWindowVertical
  | FocusNextWindow
  | CloseWindow
  | CloseOtherWindows
  | StartSwitchBuffer
  | SwitchBuffer of string
  | ShowBufferList
  | StartKillBuffer
  | KillBuffer of string
  | KillBufferConfirmed
  | JumpToLine of int
  | Resize of { cols : int; rows : int }
  | Undo
  | Redo
  | Help
  | MinibufTab
  | ScrollPage  of [ `Down | `Up ]
  | ScrollLines of [ `Down | `Up ]

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

let run_plugin_hooks hooks st =
  List.fold_left
    (fun st hook ->
      try hook st with exn ->
        { st with message = "Plugin error: " ^ Printexc.to_string exn })
    st hooks

let basename path =
  match List.rev (String.split_on_char '/' (String.map (fun c -> if c = '\\' then '/' else c) path)) with
  | name :: _ when name <> "" -> name
  | _ -> path

let snapshot_current_buffer st =
  { id = st.current_buffer_id;
    name = "";
    file_path = st.file_path;
    buffer = st.buffer;
    cursor = st.cursor;
    modified = st.modified;
    undo_stack = st.undo_stack;
    redo_stack = st.redo_stack }

let save_current_buffer st =
  let current = snapshot_current_buffer st in
  let buffers =
    List.map
      (fun b -> if b.id = st.current_buffer_id then { current with name = b.name } else b)
      st.buffers
  in
  { st with buffers }

let buffer_by_id id st =
  List.find_opt (fun b -> b.id = id) st.buffers

let current_buffer st =
  match buffer_by_id st.current_buffer_id st with
  | Some b -> b
  | None -> snapshot_current_buffer st

let activate_buffer_entry (entry : buffer_entry) st =
  { st with
    current_buffer_id = entry.id;
    buffer = entry.buffer;
    cursor = entry.cursor;
    file_path = entry.file_path;
    modified = entry.modified;
    undo_stack = entry.undo_stack;
    redo_stack = entry.redo_stack;
    mark = None;
    search_matches = [];
    search_current = None;
    search_origin = None;
    scroll_top_line = (Frame.focused_window st.frame).scroll_top_line }

let activate_buffer_id id st =
  match buffer_by_id id st with
  | Some entry -> activate_buffer_entry entry st
  | None -> st

let open_file ~path ~content st =
  let st = save_current_buffer st in
  match List.find_opt (fun (b : buffer_entry) -> b.file_path = Some path) st.buffers with
  | Some entry ->
      let frame = Frame.set_focused_buffer ~buffer_id:entry.id st.frame in
      activate_buffer_entry entry { st with frame }
  | None ->
      let id = st.next_buffer_id in
      let entry =
        { id; name = basename path; file_path = Some path;
          buffer = Buffer.of_string content; cursor = Cursor.create 0;
          modified = false; undo_stack = []; redo_stack = [] }
      in
      let frame = Frame.set_focused_buffer ~buffer_id:id st.frame in
      let st = activate_buffer_entry entry
        { st with buffers = st.buffers @ [entry]; next_buffer_id = id + 1; frame }
      in
      run_plugin_hooks st.after_open_hooks st

let buffer_names st =
  st.buffers |> List.map (fun (b : buffer_entry) -> b.name) |> List.sort_uniq String.compare

let complete_buffer_name ~prefix st =
  buffer_names st |> List.filter (fun name -> String.starts_with ~prefix name)

let switch_to_buffer_name name st =
  let st = save_current_buffer st in
  match List.find_opt (fun (b : buffer_entry) -> b.name = name) st.buffers with
  | None -> { st with message = "No buffer: " ^ name; mode = Normal; minibuf = "" }
  | Some entry ->
      let frame = Frame.set_focused_buffer ~buffer_id:entry.id st.frame in
      activate_buffer_entry entry { st with frame; mode = Normal; minibuf = "" }

let buffer_list_text buffers =
  let line (b : buffer_entry) =
    let modified = if b.modified then "*" else " " in
    let path = Option.value ~default:"" b.file_path in
    Printf.sprintf "%s %-20s %s" modified b.name path
  in
  "Modified Name                 File\n"
  ^ String.concat "\n" (List.map line buffers)
  ^ "\n"

let show_buffer_list st =
  let st = save_current_buffer st in
  let name = "*Buffer List*" in
  let content = buffer_list_text st.buffers in
  let existing = List.find_opt (fun (b : buffer_entry) -> b.name = name) st.buffers in
  let entry, buffers, next_buffer_id =
    match existing with
    | Some b ->
        let entry = { b with buffer = Buffer.of_string content; cursor = Cursor.create 0; modified = false } in
        entry,
        List.map (fun (x : buffer_entry) -> if x.id = b.id then entry else x) st.buffers,
        st.next_buffer_id
    | None ->
        let entry =
          { id = st.next_buffer_id; name; file_path = None; buffer = Buffer.of_string content;
            cursor = Cursor.create 0; modified = false; undo_stack = []; redo_stack = [] }
        in
        entry, st.buffers @ [entry], st.next_buffer_id + 1
  in
  let frame = Frame.set_focused_buffer ~buffer_id:entry.id st.frame in
  activate_buffer_entry entry { st with buffers; next_buffer_id; frame; mode = Normal; minibuf = "" }

let ensure_replacement_buffer killed_id st =
  match List.find_opt (fun (b : buffer_entry) -> b.id <> killed_id) st.buffers with
  | Some b -> b, st
  | None ->
      let entry =
        { id = st.next_buffer_id; name = "*scratch*"; file_path = None; buffer = Buffer.empty;
          cursor = Cursor.create 0; modified = false; undo_stack = []; redo_stack = [] }
      in
      entry, { st with buffers = [entry]; next_buffer_id = entry.id + 1 }

let kill_buffer_name ?(force=false) name st =
  let st = save_current_buffer st in
  match List.find_opt (fun (b : buffer_entry) -> b.name = name) st.buffers with
  | None -> { st with mode = Normal; minibuf = ""; message = "No buffer: " ^ name }
  | Some target when target.modified && not force ->
      { st with mode = ConfirmKillBuffer; minibuf = target.name }
  | Some target ->
      let replacement, st = ensure_replacement_buffer target.id st in
      let buffers = List.filter (fun (b : buffer_entry) -> b.id <> target.id) st.buffers in
      let frame = Frame.replace_buffer ~old_id:target.id ~new_id:replacement.id st.frame in
      let st = { st with buffers; frame; mode = Normal; minibuf = "" } in
      if st.current_buffer_id = target.id then activate_buffer_entry replacement st else st

let prompt_action_of_key mode key =
  let is_backspace = function
    | Key.Backspace | Key.Delete | Key.Ctrl 'h' -> true
    | Key.Char c ->
        let code = Uchar.to_int c in
        code = 0x08 || code = 0x7f
    | _ -> false
  in
  let is_prompt_char c =
    let code = Uchar.to_int c in
    code >= 0x20 && code <> 0x7f
  in
  let prompt_text_action key =
    match key with
    | Key.Enter | Key.Ctrl 'm' -> MinibufConfirm
    | key when is_backspace key -> MinibufBackspace
    | Key.Ctrl 'g' -> MinibufCancel
    | Key.Tab | Key.Ctrl 'i' -> MinibufTab
    | Key.Char c when is_prompt_char c -> MinibufAppend c
    | _ -> Ignore
  in
  match mode with
  | PromptSaveAs -> prompt_text_action key
  | ConfirmQuit -> (match key with
      | Key.Char c when
          Uchar.to_int c = Char.code 'y' ||
          Uchar.to_int c = Char.code 'Y' -> Quit
      | _                        -> MinibufCancel)
  | PromptGotoLine -> (match key with
      | Key.Enter | Key.Ctrl 'm' -> MinibufConfirm
      | key when is_backspace key -> MinibufBackspace
      | Key.Ctrl 'g'             -> MinibufCancel
      | Key.Char c when
          let i = Uchar.to_int c in i >= 48 && i <= 57 -> MinibufAppend c
      | _                        -> Ignore)
  | PromptMx -> prompt_text_action key
  | PromptSearch -> (match key with
      | Key.Enter | Key.Ctrl 'm' -> SearchConfirm
      | key when is_backspace key -> MinibufBackspace
      | Key.Ctrl 'g'             -> SearchCancel
      | Key.Ctrl 's'             -> SearchNext `Forward
      | Key.Ctrl 'r'             -> SearchNext `Backward
      | Key.Char c when is_prompt_char c -> MinibufAppend c
      | _                        -> Ignore)
  | PromptReplaceSearch -> (match prompt_text_action key with
      | MinibufConfirm -> QueryReplaceConfirmSearch
      | MinibufCancel -> QueryReplaceQuit
      | action -> action)
  | PromptReplaceWith -> (match prompt_text_action key with
      | MinibufConfirm -> QueryReplaceConfirmReplacement
      | MinibufCancel -> QueryReplaceQuit
      | action -> action)
  | PromptReplaceConfirm -> (match key with
      | Key.Char c when Uchar.to_int c = Char.code 'y' -> QueryReplaceYes
      | Key.Char c when Uchar.to_int c = Char.code 'n' -> QueryReplaceNo
      | Key.Char c when Uchar.to_int c = Char.code '!' -> QueryReplaceAll
      | Key.Char c when Uchar.to_int c = Char.code 'q' -> QueryReplaceQuit
      | Key.Ctrl 'g'             -> QueryReplaceQuit
      | _                        -> Ignore)
  | PromptSwitchBuffer -> prompt_text_action key
  | PromptKillBuffer -> prompt_text_action key
  | ConfirmKillBuffer -> (match key with
      | Key.Char c when Uchar.to_int c = Char.code 'y' || Uchar.to_int c = Char.code 'Y' ->
          KillBufferConfirmed
      | Key.Ctrl 'g' -> MinibufCancel
      | _ -> MinibufCancel)
  | Normal       -> Ignore  (* not a prompt mode *)

let command_of_name name =
  match name with
  | "move-forward-char"    -> Move CharF
  | "move-backward-char"   -> Move CharB
  | "move-next-line"       -> Move LineN
  | "move-prev-line"       -> Move LineP
  | "move-forward-word"    -> Move WordF
  | "move-backward-word"   -> Move WordB
  | "move-line-start"      -> Move LineStart
  | "move-line-end"        -> Move LineEnd
  | "move-buf-start"       -> Move BufStart
  | "move-buf-end"         -> Move BufEnd
  | "delete-forward-char"  -> DeleteForward
  | "backward-delete-char" -> Backspace
  | "delete-word-back"     -> DeleteWordBack
  | "kill-word-forward"   -> DeleteWordForward
  | "kill-line"            -> KillLine
  | "new-line"             -> Enter
  | "save"                 -> Save
  | "save-as"              -> StartSaveAs
  | "quit"                 -> TryQuit
  | "undo"                 -> Undo
  | "redo"                 -> Redo
  | "goto-line"            -> StartGotoLinePrompt
  | "help"                 -> Help
  | "execute-extended-command" -> StartMx
  | "set-mark-command"     -> ToggleMark
  | "kill-region"          -> KillRegion
  | "copy-region"          -> CopyRegion
  | "yank"                 -> Yank
  | "add-next-occurrence"  -> AddNextOccurrence
  | "add-cursor-below"     -> AddCursorBelow
  | "isearch-forward"      -> StartSearch `Forward
  | "isearch-backward"     -> StartSearch `Backward
  | "query-replace"        -> StartQueryReplace
  | "split-window-below"   -> SplitWindowHorizontal
  | "split-window-right"   -> SplitWindowVertical
  | "other-window"         -> FocusNextWindow
  | "delete-window"        -> CloseWindow
  | "delete-other-windows" -> CloseOtherWindows
  | "switch-to-buffer"     -> StartSwitchBuffer
  | "list-buffers"         -> ShowBufferList
  | "kill-buffer"          -> StartKillBuffer
  | "cancel"               -> Cancel
  | "scroll-page-down"     -> ScrollPage  `Down
  | "scroll-page-up"       -> ScrollPage  `Up
  | "scroll-line-down"     -> ScrollLines `Down
  | "scroll-line-up"       -> ScrollLines `Up
  | _                      -> Ignore

(** Return the byte length of the UTF-8 codepoint ending at [offset]. *)
let utf8_char_length_before buf offset =
  let s = Buffer.to_string buf in
  let rec go i =
    if i <= 0 then offset
    else if Char.code s.[i] land 0xC0 = 0x80 then go (i - 1)
    else offset - i
  in
  if offset <= 0 then 0
  else go (offset - 1)

(** Return the byte length of the UTF-8 codepoint starting at [offset]. *)
let utf8_char_length_at buf offset =
  let s = Buffer.to_string buf in
  let len = String.length s in
  if offset >= len then 0
  else
    let decoder = Uutf.decoder (`String (String.sub s offset (len - offset))) in
    match Uutf.decode decoder with
    | `Uchar _ -> Uutf.decoder_byte_count decoder
    | `Malformed _ -> 1
    | _ -> 0

let longest_common_prefix = function
  | [] -> ""
  | first :: rest ->
      let lcp_len = ref (String.length first) in
      List.iter (fun s ->
        let i = ref 0 in
        while !i < !lcp_len && !i < String.length s && first.[!i] = s.[!i] do
          incr i
        done;
        lcp_len := !i
      ) rest;
      String.sub first 0 !lcp_len

let primary_head st = (Cursor.primary st.cursor).head

let region_bounds st =
  match st.mark with
  | None -> None
  | Some mark ->
      let head = primary_head st in
      if head = mark then None
      else Some (min mark head, max mark head)

let range_start (r : Cursor.range) = min r.head r.anchor
let range_stop (r : Cursor.range) = max r.head r.anchor

let selected_text st =
  match region_bounds st with
  | Some (start, stop) -> Some (Buffer.slice ~start ~length:(stop - start) st.buffer)
  | None ->
      (match Cursor.primary st.cursor with
       | r when r.head <> r.anchor ->
           let start = range_start r in
           let stop = range_stop r in
           Some (Buffer.slice ~start ~length:(stop - start) st.buffer)
       | _ -> None)

let clear_kill_sequence st = { st with last_action_was_kill = false }

let with_kill_ring ~killed st =
  let kill_ring =
    if st.last_action_was_kill then
      Some (Option.value ~default:"" st.kill_ring ^ killed)
    else
      Some killed
  in
  { st with kill_ring; last_action_was_kill = true }

let apply_insert_all text st =
  let ranges = Cursor.to_list st.cursor |> List.sort (fun a b -> compare (range_start a) (range_start b)) in
  let inserted = String.length text in
  let buffer, cursor, _shift =
    List.fold_left
      (fun (buffer, cursor, shift) range ->
        let start = range_start range + shift in
        let stop = range_stop range + shift in
        let deleted = stop - start in
        let buffer =
          if deleted > 0 then Buffer.delete ~offset:start ~length:deleted buffer else buffer
        in
        let buffer = Buffer.insert ~offset:start text buffer in
        let cursor = Cursor.apply_edit ~offset:start ~deleted ~inserted cursor in
        buffer, cursor, shift + inserted - deleted)
      (st.buffer, st.cursor, 0) ranges
  in
  buffer, cursor

let apply_delete_ranges edits st =
  let edits = List.sort (fun (a, _) (b, _) -> compare a b) edits in
  let buffer, cursor, _shift =
    List.fold_left
      (fun (buffer, cursor, shift) (offset, length) ->
        let offset = offset + shift in
        let buffer = Buffer.delete ~offset ~length buffer in
        let cursor = Cursor.apply_edit ~offset ~deleted:length ~inserted:0 cursor in
        buffer, cursor, shift - length)
      (st.buffer, st.cursor, 0) edits
  in
  buffer, cursor

let search_is_smart_case_insensitive query =
  not (String.exists (fun c -> c >= 'A' && c <= 'Z') query)

let find_all_matches ~query buffer =
  if query = "" then []
  else
    let haystack = Buffer.to_string buffer in
    let needle = query in
    let searchable_haystack, searchable_needle =
      if search_is_smart_case_insensitive query then
        String.lowercase_ascii haystack, String.lowercase_ascii needle
      else
        haystack, needle
    in
    let hay_len = String.length searchable_haystack in
    let needle_len = String.length searchable_needle in
    let rec loop offset acc =
      if offset + needle_len > hay_len then List.rev acc
      else if String.sub searchable_haystack offset needle_len = searchable_needle then
        loop (offset + max 1 needle_len) ((offset, offset + needle_len) :: acc)
      else
        loop (offset + 1) acc
    in
    loop 0 []

let add_next_occurrence st =
  match selected_text st with
  | None | Some "" -> st
  | Some query ->
      let matches = find_all_matches ~query st.buffer in
      let after =
        Cursor.to_list st.cursor
        |> List.fold_left (fun acc r -> max acc (range_stop r)) (primary_head st)
      in
      let candidate =
        matches
        |> List.find_opt (fun (start, _) ->
          start >= after
          && not (List.exists (fun r -> range_start r = start) (Cursor.to_list st.cursor)))
      in
      (match candidate with
       | None -> st
       | Some (start, stop) ->
           let cursor = Cursor.add { Cursor.head = stop; anchor = start } st.cursor in
           { st with cursor })

let add_cursor_below st =
  let ranges = Cursor.to_list st.cursor in
  let bottom =
    List.fold_left
      (fun acc r -> if r.Cursor.head > acc.Cursor.head then r else acc)
      (Cursor.primary st.cursor) ranges
  in
  let line, col = Buffer.offset_to_line_col ~offset:bottom.Cursor.head st.buffer in
  if line + 1 >= Buffer.line_count st.buffer then st
  else
    let next_line_start = Buffer.line_to_offset ~line:(line + 1) st.buffer in
    let next_line_end =
      if line + 2 < Buffer.line_count st.buffer then
        Buffer.line_to_offset ~line:(line + 2) st.buffer - 1
      else Buffer.length st.buffer
    in
    let head = min (next_line_start + col) next_line_end in
    { st with cursor = Cursor.add { Cursor.head; anchor = head } st.cursor }

let choose_match ~from ~direction matches =
  match matches with
  | [] -> None, false
  | _ ->
      (match direction with
       | `Forward ->
           (match List.find_opt (fun (start, _) -> start >= from) matches with
            | Some m -> Some m, false
            | None -> Some (List.hd matches), true)
       | `Backward ->
           let before = List.filter (fun (start, _) -> start <= from) matches in
           match List.rev before with
           | m :: _ -> Some m, false
           | [] -> Some (List.hd (List.rev matches)), true)

let set_search_match ~from ~direction st =
  let matches = find_all_matches ~query:st.search_query st.buffer in
  let chosen, wrapped = choose_match ~from ~direction matches in
  match chosen with
  | None ->
      let cursor =
        match st.search_origin with
        | Some origin -> Cursor.create origin
        | None -> st.cursor
      in
      { st with search_matches = []; search_current = None;
                search_wrapped = false; cursor }
  | Some (start, _stop) ->
      { st with search_matches = matches; search_current = Some start;
                search_wrapped = wrapped; cursor = Cursor.create start }

let append_minibuf_char st c =
  let b = Stdlib.Buffer.create 4 in
  Stdlib.Buffer.add_utf_8_uchar b c;
  { st with minibuf = st.minibuf ^ Stdlib.Buffer.contents b }

let clear_search_state st =
  { st with search_query = ""; search_origin = None; search_matches = [];
            search_current = None; search_wrapped = false }

let ensure_cursor_visible st =
  let (line, _) = Buffer.offset_to_line_col ~offset:(Cursor.primary st.cursor).head st.buffer in
  let focused_window = Frame.focused_window st.frame in
  let reserved_rows =
    match st.mode with
    | PromptMx -> 2
    | _ -> 1
  in
  let viewport_height = max 1 (st.rows - reserved_rows) in
  let scroll_top_line =
    if line < focused_window.scroll_top_line then
      line
    else if line >= focused_window.scroll_top_line + viewport_height then
      line - viewport_height + 1
    else
      focused_window.scroll_top_line
  in
  let frame =
    Frame.update_focused
      (fun w -> { w with Frame.scroll_top_line })
      st.frame
  in
  { st with scroll_top_line; frame }

let rec update state action =
  let st = { state with message = "" } in
  let take_snapshot st = { buffer = st.buffer; cursor = st.cursor } in
  let (new_st, cmd) = match action with
  | Resize { cols; rows } ->
      { st with cols; rows }, Noop
  | ScrollPage dir ->
      let line_count = Buffer.line_count st.buffer in
      let reserved_rows = match st.mode with PromptMx -> 2 | _ -> 1 in
      let viewport_height = max 1 (st.rows - reserved_rows) in
      let page_size = max 1 (viewport_height - 1) in
      let focused_window = Frame.focused_window st.frame in
      let new_scroll_top =
        match dir with
        | `Down -> min (max 0 (line_count - 1)) (focused_window.scroll_top_line + page_size)
        | `Up   -> max 0 (focused_window.scroll_top_line - page_size)
      in
      let new_cursor_line = min new_scroll_top (max 0 (line_count - 1)) in
      let frame =
        Frame.update_focused (fun w -> { w with Frame.scroll_top_line = new_scroll_top }) st.frame
      in
      { st with
        cursor = Cursor.create (Buffer.line_to_offset ~line:new_cursor_line st.buffer);
        scroll_top_line = new_scroll_top;
        frame }, Noop
  | ScrollLines dir ->
      let line_count = Buffer.line_count st.buffer in
      let scroll_amount = 3 in
      let focused_window = Frame.focused_window st.frame in
      let new_scroll_top =
        match dir with
        | `Down -> min (max 0 (line_count - 1)) (focused_window.scroll_top_line + scroll_amount)
        | `Up   -> max 0 (focused_window.scroll_top_line - scroll_amount)
      in
      let frame =
        Frame.update_focused (fun w -> { w with Frame.scroll_top_line = new_scroll_top }) st.frame
      in
      { st with scroll_top_line = new_scroll_top; frame }, Noop
  | SplitWindowHorizontal ->
      let frame = Frame.split_focused Frame.Horizontal st.frame in
      { st with frame }, Noop
  | SplitWindowVertical ->
      let frame = Frame.split_focused Frame.Vertical st.frame in
      { st with frame }, Noop
  | FocusNextWindow ->
      let st = save_current_buffer st in
      let frame = Frame.focus_next st.frame in
      let scroll_top_line = (Frame.focused_window frame).scroll_top_line in
      let st = { st with frame; scroll_top_line } in
      activate_buffer_id (Frame.focused_window frame).buffer_id st, Noop
  | CloseWindow ->
      let st = save_current_buffer st in
      let frame = Frame.close_focused st.frame in
      let scroll_top_line = (Frame.focused_window frame).scroll_top_line in
      let st = { st with frame; scroll_top_line } in
      activate_buffer_id (Frame.focused_window frame).buffer_id st, Noop
  | CloseOtherWindows ->
      let st = save_current_buffer st in
      let frame = Frame.close_others st.frame in
      let scroll_top_line = (Frame.focused_window frame).scroll_top_line in
      let st = { st with frame; scroll_top_line } in
      activate_buffer_id (Frame.focused_window frame).buffer_id st, Noop
  | StartSwitchBuffer ->
      clear_kill_sequence { st with mode = PromptSwitchBuffer; minibuf = "" }, Noop
  | SwitchBuffer name ->
      switch_to_buffer_name name st, Noop
  | ShowBufferList ->
      show_buffer_list st, Noop
  | StartKillBuffer ->
      clear_kill_sequence { st with mode = PromptKillBuffer; minibuf = (current_buffer st).name }, Noop
  | KillBuffer name ->
      kill_buffer_name name st, Noop
  | KillBufferConfirmed ->
      kill_buffer_name ~force:true st.minibuf { st with mode = Normal }, Noop
  | Undo ->
      (match st.undo_stack with
       | [] -> st, Noop
       | snap :: rest ->
           let current = take_snapshot st in
           { st with buffer = snap.buffer; cursor = snap.cursor;
                     mark = None; last_action_was_kill = false;
                     undo_stack = rest; redo_stack = current :: st.redo_stack }, Noop)
  | Redo ->
      (match st.redo_stack with
       | [] -> st, Noop
       | snap :: rest ->
           let current = take_snapshot st in
           { st with buffer = snap.buffer; cursor = snap.cursor;
                     mark = None; last_action_was_kill = false;
                     redo_stack = rest; undo_stack = current :: st.undo_stack }, Noop)
  | Help ->
      clear_kill_sequence { st with message = "Welcome to JEditor! (C-x C-c to quit)" }, Noop
  (* ── normal editing ─────────────────────────────────────────────── *)
  | Insert c ->
      let snap = take_snapshot st in
      let b = Stdlib.Buffer.create 4 in
      Stdlib.Buffer.add_utf_8_uchar b c;
      let s = Stdlib.Buffer.contents b in
      let buffer, cursor = apply_insert_all s st in
      { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
  | Backspace ->
      let edits =
        Cursor.to_list st.cursor
        |> List.filter_map (fun (range : Cursor.range) ->
          if range.head <> range.anchor then
            Some (range_start range, range_stop range - range_start range)
          else if range.head > 0 then
            let char_len = utf8_char_length_before st.buffer range.head in
            Some (range.head - char_len, char_len)
          else None)
      in
      if edits <> [] then
        let snap = take_snapshot st in
        let buffer, cursor = apply_delete_ranges edits st in
        { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                  undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
      else
        clear_kill_sequence st, Noop
  | Enter ->
      let snap = take_snapshot st in
      let buffer, cursor = apply_insert_all "\n" st in
      { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
  (* ── navigation ─────────────────────────────────────────────────── *)
  | Move target ->
      let buf = st.buffer in
      let move_head head = match target with
        | CharF -> min (Buffer.length buf) (head + utf8_char_length_at buf head)
        | CharB -> max 0 (head - utf8_char_length_before buf head)
        | LineN ->
            let (l, c) = Buffer.offset_to_line_col ~offset:head buf in
            if l + 1 < Buffer.line_count buf then
              let next_line_start = Buffer.line_to_offset ~line:(l + 1) buf in
              let next_line_len = 
                if l + 2 < Buffer.line_count buf 
                then Buffer.line_to_offset ~line:(l + 2) buf - next_line_start - 1
                else Buffer.length buf - next_line_start
              in
              next_line_start + min c next_line_len
            else head
        | LineP ->
            let (l, c) = Buffer.offset_to_line_col ~offset:head buf in
            if l > 0 then
              let prev_line_start = Buffer.line_to_offset ~line:(l - 1) buf in
              let prev_line_len = Buffer.line_to_offset ~line:l buf - prev_line_start - 1 in
              prev_line_start + min c prev_line_len
            else head
        | WordF -> Buffer.next_word_boundary ~offset:head buf
        | WordB -> Buffer.prev_word_boundary ~offset:head buf
        | LineStart ->
            let (l, c) = Buffer.offset_to_line_col ~offset:head buf in
            let first_non_ws = Buffer.first_non_whitespace ~line:l buf in
            let line_start = Buffer.line_to_offset ~line:l buf in
            if c = first_non_ws then line_start else line_start + first_non_ws
        | LineEnd ->
            let (l, _) = Buffer.offset_to_line_col ~offset:head buf in
            if l + 1 < Buffer.line_count buf 
            then Buffer.line_to_offset ~line:(l + 1) buf - 1
            else Buffer.length buf
        | BufStart -> 0
        | BufEnd -> Buffer.length buf
      in
      let cursor =
        Cursor.to_list st.cursor
        |> List.map (fun r ->
          let head = move_head r.Cursor.head in
          { Cursor.head; anchor = head })
        |> Cursor.of_list
      in
      run_plugin_hooks st.on_cursor_move_hooks (clear_kill_sequence { st with cursor }), Noop
  | DeleteForward ->
      let edits =
        Cursor.to_list st.cursor
        |> List.filter_map (fun (range : Cursor.range) ->
          if range.head <> range.anchor then
            Some (range_start range, range_stop range - range_start range)
          else
            let char_len = utf8_char_length_at st.buffer range.head in
            if char_len > 0 then Some (range.head, char_len) else None)
      in
      if edits <> [] then
        let snap = take_snapshot st in
        let buffer, cursor = apply_delete_ranges edits st in
        { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                  undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
      else clear_kill_sequence st, Noop
  | DeleteWordBack ->
      let offset = (Cursor.primary st.cursor).head in
      let word_start = Buffer.prev_word_boundary ~offset st.buffer in
      let del_len = offset - word_start in
      if del_len > 0 then
        let snap = take_snapshot st in
        let buffer = Buffer.delete ~offset:word_start ~length:del_len st.buffer in
        let cursor = Cursor.apply_edit ~offset:word_start ~deleted:del_len ~inserted:0 st.cursor in
        { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                  undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
      else clear_kill_sequence st, Noop
  | DeleteWordForward ->
      let offset = (Cursor.primary st.cursor).head in
      let word_end = Buffer.next_word_boundary ~offset st.buffer in
      let del_len = word_end - offset in
      if del_len > 0 then
        let snap = take_snapshot st in
        let buffer = Buffer.delete ~offset ~length:del_len st.buffer in
        let cursor = Cursor.apply_edit ~offset ~deleted:del_len ~inserted:0 st.cursor in
        { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                  undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
      else clear_kill_sequence st, Noop
  | KillLine ->
      let offset = (Cursor.primary st.cursor).head in
      let (l, _) = Buffer.offset_to_line_col ~offset st.buffer in
      let line_end = 
        if l + 1 < Buffer.line_count st.buffer 
        then Buffer.line_to_offset ~line:(l + 1) st.buffer - 1
        else Buffer.length st.buffer
      in
      let kill_len = if offset = line_end then
          if l + 1 < Buffer.line_count st.buffer then 1 else 0
        else line_end - offset
      in
      if kill_len > 0 then
        let snap = take_snapshot st in
        let killed = Buffer.slice ~start:offset ~length:kill_len st.buffer in
        let buffer = Buffer.delete ~offset ~length:kill_len st.buffer in
        let cursor = Cursor.apply_edit ~offset ~deleted:kill_len ~inserted:0 st.cursor in
        { (with_kill_ring ~killed st) with buffer; cursor; modified = true; mark = None;
                  undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
      else clear_kill_sequence st, Noop
  | ToggleMark ->
      let mark = match st.mark with None -> Some (primary_head st) | Some _ -> None in
      clear_kill_sequence { st with mark }, Noop
  | CopyRegion ->
      (match region_bounds st with
       | None -> clear_kill_sequence st, Noop
       | Some (start, stop) ->
           let killed = Buffer.slice ~start ~length:(stop - start) st.buffer in
           { st with kill_ring = Some killed; last_action_was_kill = false }, Noop)
  | KillRegion ->
      (match region_bounds st with
       | None -> clear_kill_sequence st, Noop
       | Some (start, stop) ->
           let snap = take_snapshot st in
           let len = stop - start in
           let killed = Buffer.slice ~start ~length:len st.buffer in
           let buffer = Buffer.delete ~offset:start ~length:len st.buffer in
           { st with buffer; kill_ring = Some killed; cursor = Cursor.create start;
                     mark = None; modified = true; last_action_was_kill = false;
                     undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop)
  | Yank ->
      (match st.kill_ring with
       | None | Some "" -> clear_kill_sequence st, Noop
       | Some text ->
           let snap = take_snapshot st in
           let inserted = String.length text in
           let ranges =
             Cursor.to_list st.cursor
             |> List.sort (fun a b -> compare a.Cursor.head b.Cursor.head)
           in
           let buffer, cursor, _shift =
             List.fold_left (fun (buffer, cursor, shift) range ->
               let offset = range.Cursor.head + shift in
               let buffer = Buffer.insert ~offset text buffer in
               let cursor = Cursor.apply_edit ~offset ~deleted:0 ~inserted cursor in
               buffer, cursor, shift + inserted
             ) (st.buffer, st.cursor, 0) ranges
           in
           { st with buffer; cursor; mark = None; modified = true;
                     last_action_was_kill = false;
                     undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop)
  | AddNextOccurrence ->
      clear_kill_sequence (add_next_occurrence st), Noop
  | AddCursorBelow ->
      clear_kill_sequence (add_cursor_below st), Noop
  (* ── M-x ────────────────────────────────────────────────────────── *)
  | StartMx ->
      clear_kill_sequence { st with mode = PromptMx; minibuf = "" }, Noop
  (* ── goto-line ──────────────────────────────────────────────────── *)
  | StartGotoLinePrompt ->
      clear_kill_sequence { st with mode = PromptGotoLine; minibuf = "" }, Noop
  | JumpToLine n ->
      let line_count = Buffer.line_count st.buffer in
      let line = max 0 (min (n - 1) (line_count - 1)) in
      let offset = Buffer.line_to_offset ~line st.buffer in
      clear_kill_sequence { st with mode = Normal; minibuf = ""; cursor = Cursor.create offset }, Noop
  (* ── save ───────────────────────────────────────────────────────── *)
  | Save -> (match st.file_path with
      | Some path ->
          let st = run_plugin_hooks st.before_save_hooks st in
          let content = Buffer.to_string st.buffer in
          clear_kill_sequence { st with mode = Normal }, WriteFile { path; content }
      | None ->
          clear_kill_sequence { st with mode = PromptSaveAs; minibuf = "" }, Noop)
  | StartSaveAs ->
      clear_kill_sequence { st with mode = PromptSaveAs; minibuf = "" }, Noop
  (* ── minibuffer (save-as path entry) ────────────────────────────── *)
  | MinibufAppend c ->
      let st = append_minibuf_char st c in
      (match st.mode with
       | PromptSearch ->
           let st = { st with search_query = st.minibuf } in
           let from = Option.value ~default:(primary_head st) st.search_origin in
           set_search_match ~from ~direction:st.search_direction st, Noop
       | _ -> st, Noop)
  | MinibufBackspace ->
      let len = String.length st.minibuf in
      let minibuf = if len > 0 then String.sub st.minibuf 0 (len - 1) else "" in
      let st = { st with minibuf } in
      (match st.mode with
       | PromptSearch ->
           let st = { st with search_query = minibuf } in
           let from = Option.value ~default:(primary_head st) st.search_origin in
           set_search_match ~from ~direction:st.search_direction st, Noop
       | _ -> st, Noop)
  | MinibufConfirm ->
      (match st.mode with
       | PromptGotoLine ->
           let n = Option.value ~default:1 (int_of_string_opt st.minibuf) in
           fst (update { st with mode = Normal; minibuf = "" } (JumpToLine n)), Noop
       | PromptMx ->
           let name = String.trim st.minibuf in
           let st' = { st with mode = Normal; minibuf = "" } in
           (match Registry.lookup name st'.registry with
            | None         -> { st' with message = "No command: " ^ name }, Noop
            | Some handler -> handler st')
       | PromptSwitchBuffer ->
           switch_to_buffer_name (String.trim st.minibuf) st, Noop
       | PromptKillBuffer ->
           fst (update st (KillBuffer (String.trim st.minibuf))), Noop
       | _ ->
           let path = st.minibuf in
           let content = Buffer.to_string st.buffer in
           { st with mode = Normal; minibuf = "" }, WriteFile { path; content })
  | MinibufCancel ->
      clear_kill_sequence { st with mode = Normal; minibuf = "" }, Noop
  | MinibufTab ->
      (match st.mode with
       | PromptMx ->
           let matches = Registry.complete ~prefix:st.minibuf st.registry in
           let lcp = longest_common_prefix matches in
           if String.length lcp > String.length st.minibuf
           then { st with minibuf = lcp }, Noop
           else st, Noop
       | PromptSwitchBuffer | PromptKillBuffer ->
           let matches = complete_buffer_name ~prefix:st.minibuf st in
           let lcp = longest_common_prefix matches in
           if String.length lcp > String.length st.minibuf
           then { st with minibuf = lcp }, Noop
           else st, Noop
       | _ -> st, Noop)
  (* ── IO results ─────────────────────────────────────────────────── *)
  | WriteDone path ->
      clear_kill_sequence { st with file_path = Some path; modified = false; message = "Saved." }, Noop
  | WriteError msg ->
      clear_kill_sequence { st with message = msg }, Noop
  (* ── quit ───────────────────────────────────────────────────────── *)
  | TryQuit ->
      if st.modified
      then clear_kill_sequence { st with mode = ConfirmQuit }, Noop
      else clear_kill_sequence { st with quit = true }, Noop
  | Quit ->
      clear_kill_sequence { st with quit = true }, Noop
  | Cancel ->
      let primary = Cursor.primary st.cursor in
      { st with mark = None; message = ""; last_action_was_kill = false;
                cursor = Cursor.create primary.head }, Noop
  | StartSearch direction ->
      let origin = primary_head st in
      { (clear_kill_sequence st) with mode = PromptSearch; minibuf = "";
             search_query = ""; search_origin = Some origin;
             search_direction = direction; search_matches = [];
             search_current = None; search_wrapped = false }, Noop
  | SearchNext direction ->
      let from =
        match st.search_current, direction with
        | Some pos, `Forward -> pos + 1
        | Some pos, `Backward -> max 0 (pos - 1)
        | None, _ -> primary_head st
      in
      set_search_match ~from ~direction { st with search_direction = direction }, Noop
  | SearchConfirm ->
      clear_search_state { st with mode = Normal; minibuf = "" }, Noop
  | SearchCancel ->
      let cursor =
        match st.search_origin with
        | Some origin -> Cursor.create origin
        | None -> st.cursor
      in
      clear_search_state { st with mode = Normal; minibuf = ""; cursor }, Noop
  | StartQueryReplace ->
      { (clear_kill_sequence st) with mode = PromptReplaceSearch; minibuf = "";
             replace_query = ""; replace_with = ""; search_matches = [];
             search_current = None; search_wrapped = false }, Noop
  | QueryReplaceConfirmSearch ->
      { st with mode = PromptReplaceWith; replace_query = st.minibuf; minibuf = "" }, Noop
  | QueryReplaceConfirmReplacement ->
      let st = { st with mode = PromptReplaceConfirm; replace_with = st.minibuf; minibuf = "";
                         search_query = st.replace_query; search_origin = Some (primary_head st);
                         search_direction = `Forward } in
      set_search_match ~from:(primary_head st) ~direction:`Forward st, Noop
  | QueryReplaceYes ->
      (match st.search_current with
       | None -> clear_search_state { st with mode = Normal }, Noop
       | Some start ->
           let query_len = String.length st.replace_query in
           let snap = take_snapshot st in
           let buffer = Buffer.delete ~offset:start ~length:query_len st.buffer in
           let buffer = Buffer.insert ~offset:start st.replace_with buffer in
           let cursor = Cursor.create (start + String.length st.replace_with) in
           let st = { st with buffer; cursor; modified = true; mark = None;
                              undo_stack = snap :: st.undo_stack; redo_stack = [];
                              search_query = st.replace_query } in
           let from = start + String.length st.replace_with in
           let st = set_search_match ~from ~direction:`Forward st in
           let st = if st.search_current = None then clear_search_state { st with mode = Normal } else st in
           st, Noop)
  | QueryReplaceNo ->
      let from = Option.value ~default:(primary_head st) st.search_current + 1 in
      let st = set_search_match ~from ~direction:`Forward st in
      let st = if st.search_current = None then clear_search_state { st with mode = Normal } else st in
      st, Noop
  | QueryReplaceAll ->
      let matches = find_all_matches ~query:st.replace_query st.buffer in
      let start_from = Option.value ~default:(primary_head st) st.search_current in
      let remaining = List.filter (fun (start, _) -> start >= start_from) matches in
      if remaining = [] then clear_search_state { st with mode = Normal }, Noop
      else
        let snap = take_snapshot st in
        let query_len = String.length st.replace_query in
        let repl_len = String.length st.replace_with in
        let buffer, _shift =
          List.fold_left (fun (buffer, shift) (start, _) ->
            let offset = start + shift in
            let buffer = Buffer.delete ~offset ~length:query_len buffer in
            let buffer = Buffer.insert ~offset st.replace_with buffer in
            buffer, shift + repl_len - query_len
          ) (st.buffer, 0) remaining
        in
        clear_search_state
          { st with mode = Normal; buffer; modified = true; mark = None;
                    undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
  | QueryReplaceQuit ->
      clear_search_state { st with mode = Normal; minibuf = "" }, Noop
  | Ignore ->
      clear_kill_sequence st, Noop
  in
  let should_preserve_window_scroll =
    match action with
    | SplitWindowHorizontal | SplitWindowVertical | FocusNextWindow
    | CloseWindow | CloseOtherWindows -> true
    | _ -> false
  in
  let new_st =
    if should_preserve_window_scroll then new_st else ensure_cursor_visible new_st
  in
  save_current_buffer new_st, cmd

(** Registry pre-loaded with all built-in commands. *)
let default_registry =
  let names = [
    "move-forward-char"; "move-backward-char"; "move-next-line";
    "move-prev-line"; "move-forward-word"; "move-backward-word";
    "move-line-start"; "move-line-end"; "move-buf-start"; "move-buf-end";
    "delete-forward-char"; "backward-delete-char"; "delete-word-back";
    "kill-word-forward"; "kill-line"; "new-line"; "save"; "save-as";
    "quit"; "undo"; "redo"; "goto-line"; "execute-extended-command";
    "set-mark-command"; "kill-region"; "copy-region"; "yank";
    "add-next-occurrence"; "add-cursor-below";
    "isearch-forward"; "isearch-backward"; "query-replace";
    "split-window-below"; "split-window-right"; "other-window";
    "delete-window"; "delete-other-windows"; "switch-to-buffer";
    "list-buffers"; "kill-buffer";
    "scroll-page-down"; "scroll-page-up";
    "scroll-line-down"; "scroll-line-up";
  ] in
  List.fold_left (fun r name ->
    let action = command_of_name name in
    Registry.register name (fun st -> update st action) r
  ) Registry.empty names

let initial_state = {
  buffer    = Buffer.empty;
  cursor    = Cursor.create 0;
  quit      = false;
  file_path = None;
  modified  = false;
  mode      = Normal;
  minibuf   = "";
  message   = "";
  scroll_top_line = 0;
  cols      = 80;
  rows      = 24;
  undo_stack   = [];
  redo_stack   = [];
  pending_keys = [];
  keymap       = [Keymap.emacs_default];
  registry     = default_registry;
  mark         = None;
  kill_ring    = None;
  last_action_was_kill = false;
  search_query = "";
  search_origin = None;
  search_direction = `Forward;
  search_matches = [];
  search_current = None;
  search_wrapped = false;
  replace_query = "";
  replace_with = "";
  frame = Frame.single ~buffer_id:0;
  buffers = [
    { id = 0; name = "*scratch*"; file_path = None; buffer = Buffer.empty;
      cursor = Cursor.create 0; modified = false; undo_stack = []; redo_stack = [] }
  ];
  current_buffer_id = 0;
  next_buffer_id = 1;
  before_save_hooks = [];
  after_open_hooks = [];
  on_cursor_move_hooks = [];
  line_highlight_enabled = false;
}

let state_with_file ~path ~content =
  let buffer = Buffer.of_string content in
  let entry =
    { id = 0; name = basename path; file_path = Some path; buffer;
      cursor = Cursor.create 0; modified = false; undo_stack = []; redo_stack = [] }
  in
  { initial_state with
    buffer;
    file_path = Some path;
    buffers = [entry];
    frame = Frame.single ~buffer_id:0 }

let handle_key state key =
  match state.mode with
  | PromptSaveAs | ConfirmQuit | PromptGotoLine | PromptMx
  | PromptSearch | PromptReplaceSearch | PromptReplaceWith | PromptReplaceConfirm
  | PromptSwitchBuffer | PromptKillBuffer | ConfirmKillBuffer ->
      let action = prompt_action_of_key state.mode key in
      update state action
  | Normal ->
      (* C-g with pending keys cancels the prefix *)
      if state.pending_keys <> [] && key = Key.Ctrl 'g' then
        { state with pending_keys = []; message = "" }, Noop
      else
        let keys = state.pending_keys @ [key] in
        (match Keymap.lookup state.keymap keys with
         | Keymap.Pending ->
             { state with pending_keys = keys }, Noop
         | Keymap.Matched cmd ->
             let st = { state with pending_keys = [] } in
             (match Registry.lookup cmd st.registry with
              | Some handler -> handler st
              | None ->
                  let action = command_of_name cmd in
                  update st action)
         | Keymap.Unbound ->
             let st = { state with pending_keys = [] } in
             (match key with
              | Key.Char c -> update st (Insert c)
              | _ -> { st with message = "Key not bound" }, Noop))
