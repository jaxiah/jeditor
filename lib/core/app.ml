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
  | JumpToLine of int
  | Resize of { cols : int; rows : int }
  | Undo
  | Redo
  | Help
  | MinibufTab

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

let prompt_action_of_key mode key =
  match mode with
  | PromptSaveAs -> (match key with
      | Key.Enter | Key.Ctrl 'm' -> MinibufConfirm
      | Key.Backspace
      | Key.Delete               -> MinibufBackspace
      | Key.Ctrl 'g'             -> MinibufCancel
      | Key.Char c               -> MinibufAppend c
      | _                        -> Ignore)
  | ConfirmQuit -> (match key with
      | Key.Char c when
          Uchar.to_int c = Char.code 'y' ||
          Uchar.to_int c = Char.code 'Y' -> Quit
      | _                        -> MinibufCancel)
  | PromptGotoLine -> (match key with
      | Key.Enter | Key.Ctrl 'm' -> MinibufConfirm
      | Key.Backspace
      | Key.Delete               -> MinibufBackspace
      | Key.Ctrl 'g'             -> MinibufCancel
      | Key.Char c when
          let i = Uchar.to_int c in i >= 48 && i <= 57 -> MinibufAppend c
      | _                        -> Ignore)
  | PromptMx -> (match key with
      | Key.Enter | Key.Ctrl 'm' -> MinibufConfirm
      | Key.Backspace
      | Key.Delete               -> MinibufBackspace
      | Key.Ctrl 'g'             -> MinibufCancel
      | Key.Tab | Key.Ctrl 'i'   -> MinibufTab
      | Key.Char c               -> MinibufAppend c
      | _                        -> Ignore)
  | PromptSearch -> (match key with
      | Key.Enter | Key.Ctrl 'm' -> SearchConfirm
      | Key.Backspace
      | Key.Delete               -> MinibufBackspace
      | Key.Ctrl 'g'             -> SearchCancel
      | Key.Ctrl 's'             -> SearchNext `Forward
      | Key.Ctrl 'r'             -> SearchNext `Backward
      | Key.Char c               -> MinibufAppend c
      | _                        -> Ignore)
  | PromptReplaceSearch -> (match key with
      | Key.Enter | Key.Ctrl 'm' -> QueryReplaceConfirmSearch
      | Key.Backspace
      | Key.Delete               -> MinibufBackspace
      | Key.Ctrl 'g'             -> QueryReplaceQuit
      | Key.Char c               -> MinibufAppend c
      | _                        -> Ignore)
  | PromptReplaceWith -> (match key with
      | Key.Enter | Key.Ctrl 'm' -> QueryReplaceConfirmReplacement
      | Key.Backspace
      | Key.Delete               -> MinibufBackspace
      | Key.Ctrl 'g'             -> QueryReplaceQuit
      | Key.Char c               -> MinibufAppend c
      | _                        -> Ignore)
  | PromptReplaceConfirm -> (match key with
      | Key.Char c when Uchar.to_int c = Char.code 'y' -> QueryReplaceYes
      | Key.Char c when Uchar.to_int c = Char.code 'n' -> QueryReplaceNo
      | Key.Char c when Uchar.to_int c = Char.code '!' -> QueryReplaceAll
      | Key.Char c when Uchar.to_int c = Char.code 'q' -> QueryReplaceQuit
      | Key.Ctrl 'g'             -> QueryReplaceQuit
      | _                        -> Ignore)
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
  | "isearch-forward"      -> StartSearch `Forward
  | "isearch-backward"     -> StartSearch `Backward
  | "query-replace"        -> StartQueryReplace
  | "cancel"               -> Cancel
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

let clear_kill_sequence st = { st with last_action_was_kill = false }

let with_kill_ring ~killed st =
  let kill_ring =
    if st.last_action_was_kill then
      Some (Option.value ~default:"" st.kill_ring ^ killed)
    else
      Some killed
  in
  { st with kill_ring; last_action_was_kill = true }

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
  let reserved_rows =
    match st.mode with
    | PromptMx -> 2
    | _ -> 1
  in
  let viewport_height = max 1 (st.rows - reserved_rows) in
  if line < st.scroll_top_line then
    { st with scroll_top_line = line }
  else if line >= st.scroll_top_line + viewport_height then
    { st with scroll_top_line = line - viewport_height + 1 }
  else
    st

let rec update state action =
  let st = { state with message = "" } in
  let take_snapshot st = { buffer = st.buffer; cursor = st.cursor } in
  let (new_st, cmd) = match action with
  | Resize { cols; rows } ->
      { st with cols; rows }, Noop
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
      let offset = (Cursor.primary st.cursor).head in
      let buffer = Buffer.insert ~offset s st.buffer in
      let inserted = String.length s in
      let cursor = Cursor.apply_edit ~offset ~deleted:0 ~inserted st.cursor in
      { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
  | Backspace ->
      let offset = (Cursor.primary st.cursor).head in
      if offset > 0 then
        let snap = take_snapshot st in
        let char_len = utf8_char_length_before st.buffer offset in
        let edit_offset = offset - char_len in
        let buffer = Buffer.delete ~offset:edit_offset ~length:char_len st.buffer in
        let cursor = Cursor.apply_edit ~offset:edit_offset ~deleted:char_len ~inserted:0 st.cursor in
        { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                  undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
      else
        clear_kill_sequence st, Noop
  | Enter ->
      let snap = take_snapshot st in
      let offset = (Cursor.primary st.cursor).head in
      let buffer = Buffer.insert ~offset "\n" st.buffer in
      let cursor = Cursor.apply_edit ~offset ~deleted:0 ~inserted:1 st.cursor in
      { st with buffer; cursor; modified = true; mark = None; last_action_was_kill = false;
                undo_stack = snap :: st.undo_stack; redo_stack = [] }, Noop
  (* ── navigation ─────────────────────────────────────────────────── *)
  | Move target ->
      let buf = st.buffer in
      let cur = Cursor.primary st.cursor in
      let head = cur.head in
      let new_head = match target with
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
      clear_kill_sequence { st with cursor = Cursor.create new_head }, Noop
  | DeleteForward ->
      let offset = (Cursor.primary st.cursor).head in
      let char_len = utf8_char_length_at st.buffer offset in
      if char_len > 0 then
        let snap = take_snapshot st in
        let buffer = Buffer.delete ~offset ~length:char_len st.buffer in
        let cursor = Cursor.apply_edit ~offset ~deleted:char_len ~inserted:0 st.cursor in
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
      { st with mark = None; message = ""; last_action_was_kill = false }, Noop
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
  (ensure_cursor_visible new_st, cmd)

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
    "isearch-forward"; "isearch-backward"; "query-replace";
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
}

let state_with_file ~path ~content = {
  initial_state with
  buffer    = Buffer.of_string content;
  file_path = Some path;
}

let handle_key state key =
  match state.mode with
  | PromptSaveAs | ConfirmQuit | PromptGotoLine | PromptMx
  | PromptSearch | PromptReplaceSearch | PromptReplaceWith | PromptReplaceConfirm ->
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
             let action = command_of_name cmd in
             update { state with pending_keys = [] } action
         | Keymap.Unbound ->
             let st = { state with pending_keys = [] } in
             (match key with
              | Key.Char c -> update st (Insert c)
              | _ -> { st with message = "Key not bound" }, Noop))
