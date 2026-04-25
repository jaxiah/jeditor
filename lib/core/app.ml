open Jeditor_buffer
open Jeditor_terminal

type mode =
  | Normal
  | PendingCx
  | PromptSaveAs
  | ConfirmQuit

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
  | KillLine
  | Resize of { cols : int; rows : int }

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
}

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
}

let state_with_file ~path ~content = {
  initial_state with
  buffer    = Buffer.of_string content;
  file_path = Some path;
}

let action_of_key mode key =
  match mode with
  | Normal -> (match key with
      | Key.Char c               -> Insert c
      | Key.Backspace            -> Backspace
      | Key.Delete               -> DeleteForward
      | Key.Enter                -> Enter
      | Key.Ctrl 'x'             -> PendingCx
      | Key.Ctrl 'c'             -> TryQuit
      | Key.Escape               -> Ignore
      | Key.Ctrl 'f' | Key.Arrow `Right -> Move CharF
      | Key.Ctrl 'b' | Key.Arrow `Left  -> Move CharB
      | Key.Ctrl 'n' | Key.Arrow `Down  -> Move LineN
      | Key.Ctrl 'p' | Key.Arrow `Up    -> Move LineP
      | Key.Meta (c) when Uchar.to_char c = 'f' -> Move WordF
      | Key.Meta (c) when Uchar.to_char c = 'b' -> Move WordB
      | Key.Meta (c) when Uchar.to_char c = '<' -> Move BufStart
      | Key.Meta (c) when Uchar.to_char c = '>' -> Move BufEnd
      | Key.Ctrl 'a'             -> Move LineStart
      | Key.Ctrl 'e'             -> Move LineEnd
      | Key.Ctrl 'd'             -> DeleteForward
      | Key.Ctrl 'k'             -> KillLine
      | _                        -> Ignore)
  | PendingCx -> (match key with
      | Key.Ctrl 's'             -> Save
      | Key.Ctrl 'w'             -> StartSaveAs
      | Key.Ctrl 'c'             -> TryQuit
      | _                        -> Ignore)
  | PromptSaveAs -> (match key with
      | Key.Enter                -> MinibufConfirm
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

let ensure_cursor_visible st =
  let (line, _) = Buffer.offset_to_line_col ~offset:(Cursor.primary st.cursor).head st.buffer in
  let viewport_height = st.rows - 1 in (* Bottom row reserved for status bar *)
  if line < st.scroll_top_line then
    { st with scroll_top_line = line }
  else if line >= st.scroll_top_line + viewport_height then
    { st with scroll_top_line = line - viewport_height + 1 }
  else
    st

let update state action =
  let st = { state with message = "" } in
  let (new_st, cmd) = match action with
  | Resize { cols; rows } ->
      { st with cols; rows }, Noop
  (* ── normal editing ─────────────────────────────────────────────── *)
  | Insert c ->
      let b = Stdlib.Buffer.create 4 in
      Stdlib.Buffer.add_utf_8_uchar b c;
      let s = Stdlib.Buffer.contents b in
      let offset = (Cursor.primary st.cursor).head in
      let buffer = Buffer.insert ~offset s st.buffer in
      let inserted = String.length s in
      let cursor = Cursor.apply_edit ~offset ~deleted:0 ~inserted st.cursor in
      { st with buffer; cursor; modified = true }, Noop
  | Backspace ->
      let offset = (Cursor.primary st.cursor).head in
      if offset > 0 then
        let char_len = utf8_char_length_before st.buffer offset in
        let edit_offset = offset - char_len in
        let buffer = Buffer.delete ~offset:edit_offset ~length:char_len st.buffer in
        let cursor = Cursor.apply_edit ~offset:edit_offset ~deleted:char_len ~inserted:0 st.cursor in
        { st with buffer; cursor; modified = true }, Noop
      else
        st, Noop
  | Enter ->
      let offset = (Cursor.primary st.cursor).head in
      let buffer = Buffer.insert ~offset "\n" st.buffer in
      let cursor = Cursor.apply_edit ~offset ~deleted:0 ~inserted:1 st.cursor in
      { st with buffer; cursor; modified = true }, Noop
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
      { st with cursor = Cursor.create new_head }, Noop
  | DeleteForward ->
      let offset = (Cursor.primary st.cursor).head in
      let char_len = utf8_char_length_at st.buffer offset in
      if char_len > 0 then
        let buffer = Buffer.delete ~offset ~length:char_len st.buffer in
        let cursor = Cursor.apply_edit ~offset ~deleted:char_len ~inserted:0 st.cursor in
        { st with buffer; cursor; modified = true }, Noop
      else st, Noop
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
        let buffer = Buffer.delete ~offset ~length:kill_len st.buffer in
        let cursor = Cursor.apply_edit ~offset ~deleted:kill_len ~inserted:0 st.cursor in
        { st with buffer; cursor; modified = true }, Noop
      else st, Noop
  (* ── C-x prefix ─────────────────────────────────────────────────── *)
  | PendingCx ->
      { st with mode = PendingCx }, Noop
  (* ── save ───────────────────────────────────────────────────────── *)
  | Save -> (match st.file_path with
      | Some path ->
          let content = Buffer.to_string st.buffer in
          { st with mode = Normal }, WriteFile { path; content }
      | None ->
          { st with mode = PromptSaveAs; minibuf = "" }, Noop)
  | StartSaveAs ->
      { st with mode = PromptSaveAs; minibuf = "" }, Noop
  (* ── minibuffer (save-as path entry) ────────────────────────────── *)
  | MinibufAppend c ->
      let b = Stdlib.Buffer.create 4 in
      Stdlib.Buffer.add_utf_8_uchar b c;
      { st with minibuf = st.minibuf ^ Stdlib.Buffer.contents b }, Noop
  | MinibufBackspace ->
      let len = String.length st.minibuf in
      let minibuf = if len > 0 then String.sub st.minibuf 0 (len - 1) else "" in
      { st with minibuf }, Noop
  | MinibufConfirm ->
      let path = st.minibuf in
      let content = Buffer.to_string st.buffer in
      { st with mode = Normal; minibuf = "" }, WriteFile { path; content }
  | MinibufCancel ->
      { st with mode = Normal; minibuf = "" }, Noop
  (* ── IO results ─────────────────────────────────────────────────── *)
  | WriteDone path ->
      { st with file_path = Some path; modified = false; message = "Saved." }, Noop
  | WriteError msg ->
      { st with message = msg }, Noop
  (* ── quit ───────────────────────────────────────────────────────── *)
  | TryQuit ->
      if st.modified
      then { st with mode = ConfirmQuit }, Noop
      else { st with quit = true }, Noop
  | Quit ->
      { st with quit = true }, Noop
  | Ignore ->
      (* Also resets PendingCx if an unrecognised second key arrives *)
      { st with mode = Normal }, Noop
  in
  (ensure_cursor_visible new_st, cmd)
