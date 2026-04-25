open Jeditor_terminal
open Jeditor_core
open Jeditor_buffer

let render term state =
  let (cols, rows) = Terminal.size term in
  ignore cols;
  Terminal.hide_cursor term;
  Terminal.clear_screen term;
  (* Text area: all rows except the last (reserved for status/minibuf) *)
  Terminal.move_to term ~row:0 ~col:0;
  Terminal.write_string term (Buffer.to_string state.App.buffer) Attr.default;
  (* Bottom row: status / minibuf / message *)
  let bottom = rows - 1 in
  Terminal.move_to term ~row:bottom ~col:0;
  Terminal.clear_line term;
  let bottom_text = match state.App.mode with
    | App.PromptSaveAs ->
        "Save as: " ^ state.App.minibuf ^ "_"
    | App.ConfirmQuit ->
        "Unsaved changes \xe2\x80\x94 quit anyway? (y/n)"
    | _ ->
        let name = match state.App.file_path with
          | Some p -> p
          | None   -> "[No Name]"
        in
        let mod_flag = if state.App.modified then " *" else "" in
        if state.App.message <> "" then state.App.message
        else name ^ mod_flag
  in
  Terminal.write_string term bottom_text Attr.default;
  (* Cursor *)
  let (row, col) =
    Buffer.offset_to_line_col
      ~offset:(Cursor.primary state.App.cursor).head
      state.App.buffer
  in
  Terminal.move_to term ~row ~col;
  Terminal.show_cursor term;
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
      match Input.next_key input with
      | None -> running := false
      | Some key ->
        let action = App.action_of_key !state.App.mode key in
        let (new_state, cmd) = App.update !state action in
        let new_state = run_io term new_state cmd in
        state := new_state;
        if !state.App.quit then running := false
        else render term !state
    done)
