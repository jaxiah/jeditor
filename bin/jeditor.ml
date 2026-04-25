open Jeditor_terminal
open Jeditor_core
open Jeditor_buffer

let needs_redraw = ref false

(* SIGWINCH: set flag; safe to call on Windows (signal never fires there) *)
let () =
  try
    Sys.set_signal Sys.sigwinch
      (Sys.Signal_handle (fun _ -> needs_redraw := true))
  with _ -> ()

let render term state =
  let (cols, rows) = Terminal.size term in
  let line_count = Buffer.line_count state.App.buffer in
  let gutter = View.gutter_width ~line_count in
  let text_cols = cols - gutter in

  Terminal.hide_cursor term;
  Terminal.clear_screen term;

  (* 1. Render text area with gutter *)
  for i = 0 to rows - 2 do
    if i < line_count then begin
      Terminal.move_to term ~row:i ~col:0;
      (* Write gutter: right-aligned line number *)
      let gtext = Printf.sprintf "%*d " (gutter - 1) (i + 1) in
      Terminal.write_string term gtext Attr.default;
      
      (* Write line content (truncated to text_cols) *)
      let line_start = Buffer.line_to_offset ~line:i state.App.buffer in
      let next_line_start = 
        if i + 1 < line_count then Buffer.line_to_offset ~line:(i + 1) state.App.buffer
        else Buffer.length state.App.buffer
      in
      let line_len = next_line_start - line_start in
      (* Strip trailing newline if present for display *)
      let display_len = if line_len > 0 then
          let last_char = Buffer.slice ~start:(next_line_start - 1) ~length:1 state.App.buffer in
          if last_char = "\n" then line_len - 1 else line_len
        else 0
      in
      let full_line = Buffer.slice ~start:line_start ~length:display_len state.App.buffer in
      (* Simple truncation for now; ideally would use display width *)
      let truncated = if String.length full_line > text_cols then String.sub full_line 0 text_cols else full_line in
      Terminal.write_string term truncated Attr.default
    end
  done;

  (* 2. Render status bar *)
  let (byte_line, byte_col) =
    Buffer.offset_to_line_col
      ~offset:(Cursor.primary state.App.cursor).head
      state.App.buffer
  in
  let line_start = Buffer.line_to_offset ~line:byte_line state.App.buffer in
  let line_to_cursor = Buffer.slice ~start:line_start ~length:byte_col state.App.buffer in
  let dcol = Wcwidth.display_col_of_byte_col line_to_cursor ~byte_col in
  
  let stext = match state.App.mode with
    | App.PromptSaveAs ->
        View.status_text ~file_path:None ~modified:false ~cursor_line:0 ~cursor_display_col:0 ~line_count:0 ~cols
        |> fun _ -> "Save as: " ^ state.App.minibuf ^ "_"
    | App.ConfirmQuit ->
        "Unsaved changes \xe2\x80\x94 quit anyway? (y/n)"
    | _ ->
        if state.App.message <> "" then state.App.message
        else View.status_text
          ~file_path:state.App.file_path
          ~modified:state.App.modified
          ~cursor_line:byte_line
          ~cursor_display_col:dcol
          ~line_count
          ~cols
  in
  Terminal.move_to term ~row:(rows - 1) ~col:0;
  Terminal.clear_line term;
  Terminal.write_string term stext Attr.default;

  (* 3. Position cursor *)
  if byte_line < rows - 1 then begin
    Terminal.move_to term ~row:byte_line ~col:(gutter + dcol);
    Terminal.show_cursor term
  end else begin
    Terminal.hide_cursor term
  end;
  Terminal.flush term

let run_io _term state action =
  match action with
  | App.WriteFile { path; content } ->
      (try
        Out_channel.(with_open_text path (fun oc -> output_string oc content));
        fst (App.update state (App.WriteDone path))
      with exn ->
        fst (App.update state (App.WriteError (Printexc.to_string exn))))
  | App.Noop -> state

let () =
  let term = Terminal.create () |> Result.get_ok in
  let input = Input.create () |> Result.get_ok in
  let cleanup () =
    Terminal.close term;
    Input.close input
  in
  Sys.set_signal Sys.sigint
    (Sys.Signal_handle (fun _ -> cleanup (); exit 0));
  Fun.protect ~finally:cleanup (fun () ->
    let state = ref (match Sys.argv with
      | [| _; path |] ->
          (try
            let content = In_channel.(with_open_text path input_all) in
            App.state_with_file ~path ~content
          with exn ->
            { App.initial_state with
              App.message = "Error opening file: " ^ Printexc.to_string exn })
      | _ -> App.initial_state)
    in
    render term !state;
    let running = ref true in
    while !running do
      if !needs_redraw then begin
        needs_redraw := false;
        render term !state
      end;
      match Input.next_key input with
      | None -> 
          (* Potential EINTR from SIGWINCH on Unix, or EOF *)
          if not !needs_redraw then () (* True EOF or error if no redraw pending *)
      | Some key ->
        let action = App.action_of_key !state.App.mode key in
        let (new_state, cmd) = App.update !state action in
        let new_state = run_io term new_state cmd in
        state := new_state;
        if !state.App.quit then running := false
        else render term !state
    done)
