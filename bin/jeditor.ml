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
  let frame_rows = rows in
  let selected_range =
    match state.App.mark with
    | None -> None
    | Some mark ->
        let head = (Cursor.primary state.App.cursor).head in
        if head = mark then None else Some (min mark head, max mark head)
  in
  let search_highlight_active =
    match state.App.mode with
    | App.PromptSearch | App.PromptReplaceConfirm -> true
    | _ -> false
  in
  let highlight_ranges =
    match selected_range, search_highlight_active with
    | Some range, _ -> [range]
    | None, true -> state.App.search_matches
    | None, false -> []
  in
  let selection_attr = { Attr.default with Attr.reverse = true } in
  let write_with_selection ~line_start text attr =
    let line_stop = line_start + String.length text in
    let ranges =
      highlight_ranges
      |> List.filter_map (fun (start, stop) ->
        let hi_start = max start line_start in
        let hi_stop = min stop line_stop in
        if hi_start < hi_stop then Some (hi_start - line_start, hi_stop - line_start)
        else None)
      |> List.sort compare
    in
    let rec write_chunks pos = function
      | [] ->
          if pos < String.length text then
            Terminal.write_string term
              (String.sub text pos (String.length text - pos))
              attr
      | (start, stop) :: rest ->
        if pos < start then
            Terminal.write_string term (String.sub text pos (start - pos)) attr;
          Terminal.write_string term (String.sub text start (stop - start)) selection_attr;
          write_chunks stop rest
    in
    if ranges = [] then Terminal.write_string term text attr
    else write_chunks 0 ranges
  in
  let prompt_status byte_line dcol width =
    match state.App.mode with
    | App.PromptSaveAs ->
        "Save as: " ^ state.App.minibuf ^ "_"
    | App.ConfirmQuit ->
        "Unsaved changes - quit anyway? (y/n)"
    | App.PromptGotoLine ->
        "Go to line: " ^ state.App.minibuf ^ "_"
    | App.PromptMx ->
        "M-x " ^ state.App.minibuf ^ "_"
    | App.PromptSearch ->
        let suffix = if state.App.search_wrapped then " [wrapped]" else "" in
        "I-search: " ^ state.App.minibuf ^ "_" ^ suffix
    | App.PromptReplaceSearch ->
        "Query replace: " ^ state.App.minibuf ^ "_"
    | App.PromptReplaceWith ->
        "Query replace " ^ state.App.replace_query ^ " with: " ^ state.App.minibuf ^ "_"
    | App.PromptReplaceConfirm ->
        "Replace " ^ state.App.replace_query ^ " with " ^ state.App.replace_with
        ^ "? (y/n/!/q)"
    | App.PromptSwitchBuffer ->
        "Switch to buffer: " ^ state.App.minibuf ^ "_"
    | App.PromptKillBuffer ->
        "Kill buffer: " ^ state.App.minibuf ^ "_"
    | App.ConfirmKillBuffer ->
        "Buffer modified - kill anyway? (y/n)"
    | _ ->
        if state.App.pending_keys <> [] then
          (* show accumulated prefix hint, e.g. "C-x ..." *)
          String.concat " " (List.map (Format.asprintf "%a" Key.pp) state.App.pending_keys) ^ " ..."
        else if state.App.message <> "" then state.App.message
        else View.status_text
          ~file_path:state.App.file_path
          ~modified:state.App.modified
          ~cursor_line:byte_line
          ~cursor_display_col:dcol
          ~line_count
          ~cols:width
  in

  Terminal.hide_cursor term;
  Terminal.clear_screen term;

  let (byte_line, byte_col) =
    Buffer.offset_to_line_col
      ~offset:(Cursor.primary state.App.cursor).head
      state.App.buffer
  in
  let line_start = Buffer.line_to_offset ~line:byte_line state.App.buffer in
  let line_to_cursor = Buffer.slice ~start:line_start ~length:byte_col state.App.buffer in
  let dcol = Wcwidth.display_col_of_byte_col line_to_cursor ~byte_col in

  let focused_id = state.App.frame.Frame.focused in
  let render_window (window, rect) =
    if rect.Frame.width > 0 && rect.height > 0 then begin
      let entry = Option.value ~default:(App.current_buffer state) (App.buffer_by_id window.Frame.buffer_id state) in
      let buffer = entry.App.buffer in
      let cursor = entry.App.cursor in
      let file_path = entry.App.file_path in
      let modified = entry.App.modified in
      let line_count = Buffer.line_count buffer in
      let gutter = View.gutter_width ~line_count in
      let text_cols = max 0 (rect.width - gutter) in
      let text_rows = max 0 (rect.height - 1) in
      for i = 0 to text_rows - 1 do
        let buffer_line_idx = i + window.Frame.scroll_top_line in
        Terminal.move_to term ~row:(rect.y + i) ~col:rect.x;
        Terminal.clear_line term;
        if buffer_line_idx < line_count then begin
          let gtext = Printf.sprintf "%*d " (gutter - 1) (buffer_line_idx + 1) in
          Terminal.write_string term gtext Attr.default;
          let line_start = Buffer.line_to_offset ~line:buffer_line_idx buffer in
          let next_line_start =
            if buffer_line_idx + 1 < line_count
            then Buffer.line_to_offset ~line:(buffer_line_idx + 1) buffer
            else Buffer.length buffer
          in
          let line_len = next_line_start - line_start in
          let display_len =
            if line_len > 0 then
              let last_char =
                Buffer.slice ~start:(next_line_start - 1) ~length:1 buffer
              in
              if last_char = "\n" then line_len - 1 else line_len
            else 0
          in
          let full_line = Buffer.slice ~start:line_start ~length:display_len buffer in
          let truncated =
            if String.length full_line > text_cols then String.sub full_line 0 text_cols
            else full_line
          in
          write_with_selection ~line_start truncated Attr.default
        end
      done;
      let status_attr =
        if window.id = focused_id then { Attr.default with Attr.reverse = true }
        else Attr.default
      in
      let status =
        if window.id = focused_id then prompt_status byte_line dcol rect.width
        else
          let (line, byte_col) = Buffer.offset_to_line_col ~offset:(Cursor.primary cursor).head buffer in
          let line_start = Buffer.line_to_offset ~line buffer in
          let line_to_cursor = Buffer.slice ~start:line_start ~length:byte_col buffer in
          let dcol = Wcwidth.display_col_of_byte_col line_to_cursor ~byte_col in
          View.status_text
            ~file_path
            ~modified
            ~cursor_line:line
            ~cursor_display_col:dcol
            ~line_count
            ~cols:rect.width
      in
      Terminal.move_to term ~row:(rect.y + rect.height - 1) ~col:rect.x;
      Terminal.write_string term status status_attr
    end
  in

  let rec draw_dividers rect = function
    | Frame.Leaf _ -> ()
    | Frame.Split (Frame.Horizontal, ratio, a, b) ->
        let first_h = max 1 (int_of_float (float rect.Frame.height *. ratio)) in
        let first_h = min first_h (max 1 (rect.height - 1)) in
        let second_h = max 1 (rect.height - first_h - 1) in
        let divider_y = rect.y + first_h in
        Terminal.move_to term ~row:divider_y ~col:rect.x;
        Terminal.write_string term (String.make rect.width '-') Attr.default;
        draw_dividers { rect with Frame.height = first_h } a;
        draw_dividers { Frame.x = rect.x; y = divider_y + 1; width = rect.width; height = second_h } b
    | Frame.Split (Frame.Vertical, ratio, a, b) ->
        let first_w = max 1 (int_of_float (float rect.Frame.width *. ratio)) in
        let first_w = min first_w (max 1 (rect.width - 1)) in
        let second_w = max 1 (rect.width - first_w - 1) in
        let divider_x = rect.x + first_w in
        for y = rect.y to rect.y + rect.height - 1 do
          Terminal.move_to term ~row:y ~col:divider_x;
          Terminal.write_string term "|" Attr.default
        done;
        draw_dividers { rect with Frame.width = first_w } a;
        draw_dividers { Frame.x = divider_x + 1; y = rect.y; width = second_w; height = rect.height } b
  in

  let frame_rect = { Frame.x = 0; y = 0; width = cols; height = frame_rows } in
  List.iter render_window (Frame.layouts ~cols ~rows:frame_rows state.App.frame);
  draw_dividers frame_rect state.App.frame.Frame.root;

  if state.App.mode = App.PromptMx && rows >= 2 then begin
    let completions =
      Registry.complete ~prefix:state.App.minibuf state.App.registry
      |> String.concat " "
    in
    let completion_text =
      if String.length completions > cols
      then String.sub completions 0 cols
      else completions
    in
    Terminal.move_to term ~row:(rows - 2) ~col:0;
    Terminal.clear_line term;
    Terminal.write_string term completion_text Attr.default
  end;

  (* 3. Position cursor relative to focused window viewport *)
  let focused_layout =
    Frame.layouts ~cols ~rows:frame_rows state.App.frame
    |> List.find_opt (fun (w, _) -> w.Frame.id = focused_id)
  in
  (match focused_layout with
   | Some (window, rect) ->
      let gutter = View.gutter_width ~line_count in
      let relative_line = byte_line - window.Frame.scroll_top_line in
      if relative_line >= 0 && relative_line < max 0 (rect.height - 1) then begin
        Terminal.move_to term ~row:(rect.y + relative_line) ~col:(rect.x + gutter + dcol);
        Terminal.show_cursor term
      end else
        Terminal.hide_cursor term
   | None ->
    Terminal.hide_cursor term
  );
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
    (* Initial resize sync *)
    let (c, r) = Terminal.size term in
    let (new_st, _) = App.update !state (App.Resize { cols = c; rows = r }) in
    state := new_st;

    render term !state;
    let running = ref true in
    while !running do
      if !needs_redraw then begin
        needs_redraw := false;
        let (c, r) = Terminal.size term in
        let (new_st, _) = App.update !state (App.Resize { cols = c; rows = r }) in
        state := new_st;
        render term !state
      end;
      match Input.next_key input with
      | None -> 
          (* Potential EINTR from SIGWINCH on Unix, or EOF *)
          if not !needs_redraw then () 
      | Some key ->
        let (new_state, cmd) = App.handle_key !state key in
        let new_state = run_io term new_state cmd in
        state := new_state;
        if !state.App.quit then running := false
        else render term !state
    done)
