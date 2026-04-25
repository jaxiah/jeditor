open Jeditor_core
open Jeditor_buffer
open Jeditor_terminal
open Jeditor_plugin

let setup () =
  Plugin_api.clear_registrations ();
  App.initial_state

let test_registered_command_appears_and_runs () =
  let st = setup () in
  Plugin_api.register_command "plugin-hello"
    (fun st -> Plugin_api.message "hello from plugin" st);
  let st = Plugin_loader.apply_registered st in
  Alcotest.(check bool) "command appears" true
    (List.mem "plugin-hello" (Registry.names st.App.registry));
  let st = fst (Option.get (Registry.lookup "plugin-hello" st.registry) st) in
  Alcotest.(check string) "message" "hello from plugin" st.message

let test_keybinding_dispatches_plugin_command () =
  let st = setup () in
  Plugin_api.register_command "plugin-key"
    (fun st -> Plugin_api.message "key ran" st);
  Plugin_api.bind_key [Key.Ctrl 'q'] "plugin-key";
  let st = Plugin_loader.apply_registered st in
  let st = fst (App.handle_key st (Key.Ctrl 'q')) in
  Alcotest.(check string) "message" "key ran" st.message

let test_hooks_run () =
  let st = setup () |> App.open_file ~path:"a.txt" ~content:"a" in
  Plugin_api.register_hook Plugin_api.Before_save
    (fun st -> Plugin_api.message "before-save" st);
  Plugin_api.register_hook Plugin_api.On_cursor_move
    (fun st -> Plugin_api.message "cursor-moved" st);
  let st = Plugin_loader.apply_registered st in
  let st, _ = App.update st App.Save in
  Alcotest.(check string) "before save hook" "before-save" st.message;
  let st = fst (App.update st (App.Move App.BufEnd)) in
  Alcotest.(check string) "cursor hook" "cursor-moved" st.message

let test_after_open_hook_runs () =
  let st = setup () in
  Plugin_api.register_hook Plugin_api.After_open
    (fun st -> Plugin_api.message "after-open" st);
  let st = Plugin_loader.apply_registered st in
  let st = App.open_file ~path:"a.txt" ~content:"a" st in
  Alcotest.(check string) "after open hook" "after-open" st.message

let test_buffer_and_cursor_accessors_are_undoable () =
  let st = setup () |> App.open_file ~path:"a.txt" ~content:"abc" in
  let id = st.current_buffer_id in
  Alcotest.(check (option string)) "content" (Some "abc")
    (Plugin_api.buffer_content id st);
  let st = Plugin_api.insert ~buffer_id:id ~offset:1 ~text:"X" st in
  Alcotest.(check string) "inserted" "aXbc" (Buffer.to_string st.buffer);
  let st = fst (App.update st App.Undo) in
  Alcotest.(check string) "undo plugin insert" "abc" (Buffer.to_string st.buffer);
  let st = Plugin_api.set_cursor_positions ~buffer_id:id ~positions:[2] st in
  Alcotest.(check (option (list int))) "cursor set" (Some [2])
    (Plugin_api.cursor_positions id st)

let test_plugin_crash_reported () =
  let st = setup () in
  Plugin_api.register_command "plugin-crash" (fun _ -> failwith "boom");
  let st = Plugin_loader.apply_registered st in
  let st = fst (Option.get (Registry.lookup "plugin-crash" st.registry) st) in
  Alcotest.(check bool) "error reported" true (String.contains st.message 'b')

let test_load_error_reported () =
  let st = setup () in
  let st = Plugin_loader.load_paths ["missing-plugin.cmxs"] st in
  Alcotest.(check bool) "load error" true (String.contains st.message 'm')

let test_line_highlight_flag () =
  let st = setup () in
  Plugin_api.register_command "line-highlight-enable" Plugin_api.enable_line_highlight;
  let st = Plugin_loader.apply_registered st in
  let st = fst (Option.get (Registry.lookup "line-highlight-enable" st.registry) st) in
  Alcotest.(check bool) "enabled" true st.line_highlight_enabled

let () =
  Alcotest.run "Plugin" [
    "plugin", [
      Alcotest.test_case "registered_command_appears_and_runs" `Quick test_registered_command_appears_and_runs;
      Alcotest.test_case "keybinding_dispatches_plugin_command" `Quick test_keybinding_dispatches_plugin_command;
      Alcotest.test_case "hooks_run" `Quick test_hooks_run;
      Alcotest.test_case "after_open_hook_runs" `Quick test_after_open_hook_runs;
      Alcotest.test_case "buffer_and_cursor_accessors_are_undoable" `Quick test_buffer_and_cursor_accessors_are_undoable;
      Alcotest.test_case "plugin_crash_reported" `Quick test_plugin_crash_reported;
      Alcotest.test_case "load_error_reported" `Quick test_load_error_reported;
      Alcotest.test_case "line_highlight_flag" `Quick test_line_highlight_flag;
    ];
  ]
