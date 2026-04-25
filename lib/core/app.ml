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

let initial_state = {
  buffer    = Buffer.empty;
  cursor    = Cursor.create 0;
  quit      = false;
  file_path = None;
  modified  = false;
  mode      = Normal;
  minibuf   = "";
  message   = "";
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
      | Key.Backspace
      | Key.Delete               -> Backspace
      | Key.Enter                -> Enter
      | Key.Ctrl 'x'             -> PendingCx
      | Key.Ctrl 'c'
      | Key.Escape               -> TryQuit
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

let update state action =
  let st = { state with message = "" } in
  match action with
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
