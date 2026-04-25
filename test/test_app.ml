open Jeditor_core
open Jeditor_buffer
open Jeditor_terminal
open App

(* Helper: apply update and discard effect *)
let upd state action = fst (update state action)

(* ── existing ISSUE-006 tests ────────────────────────────────────────── *)

let test_initial_state () =
  Alcotest.(check int) "initial cursor is 0" 0 (Cursor.primary initial_state.cursor).head;
  Alcotest.(check string) "initial buffer is empty" "" (Buffer.to_string initial_state.buffer)

let test_insert_char () =
  let state = upd initial_state (Insert (Uchar.of_char 'A')) in
  Alcotest.(check int) "cursor moved" 1 (Cursor.primary state.cursor).head;
  Alcotest.(check string) "buffer has A" "A" (Buffer.to_string state.buffer)

let test_backspace_empty () =
  let state = upd initial_state Backspace in
  Alcotest.(check int) "cursor unchanged" 0 (Cursor.primary state.cursor).head;
  Alcotest.(check string) "buffer still empty" "" (Buffer.to_string state.buffer)

let test_insert_then_backspace () =
  let state = upd initial_state (Insert (Uchar.of_char 'A')) in
  let state = upd state Backspace in
  Alcotest.(check int) "cursor back to 0" 0 (Cursor.primary state.cursor).head;
  Alcotest.(check string) "buffer empty again" "" (Buffer.to_string state.buffer)

let test_enter () =
  let state = upd initial_state Enter in
  Alcotest.(check int) "cursor moved by 1" 1 (Cursor.primary state.cursor).head;
  Alcotest.(check string) "buffer has newline" "\n" (Buffer.to_string state.buffer)

let test_quit () =
  let state = upd initial_state Quit in
  Alcotest.(check bool) "quit flag set" true state.quit

let test_backspace_cjk () =
  let state = upd initial_state (Insert (Uchar.of_int 0x4E2D)) in
  Alcotest.(check int) "cursor after CJK insert" 3 (Cursor.primary state.cursor).head;
  let state = upd state Backspace in
  Alcotest.(check int) "cursor back to 0 after CJK backspace" 0 (Cursor.primary state.cursor).head;
  Alcotest.(check string) "buffer empty after CJK backspace" "" (Buffer.to_string state.buffer)

(* ── ISSUE-007 tests ─────────────────────────────────────────────────── *)

let test_state_with_file () =
  let state = state_with_file ~path:"foo.txt" ~content:"hello\nworld" in
  Alcotest.(check string) "buffer content" "hello\nworld" (Buffer.to_string state.buffer);
  Alcotest.(check (option string)) "file_path set" (Some "foo.txt") state.file_path;
  Alcotest.(check bool) "not modified" false state.modified

let test_edit_sets_modified () =
  let s1 = upd initial_state (Insert (Uchar.of_char 'x')) in
  Alcotest.(check bool) "insert sets modified" true s1.modified;
  let s2 = upd s1 Backspace in
  Alcotest.(check bool) "backspace keeps modified" true s2.modified

let test_save_with_path () =
  let state = { (state_with_file ~path:"a.txt" ~content:"hi") with modified = true } in
  let (_, cmd) = update state Save in
  match cmd with
  | WriteFile { path; content } ->
      Alcotest.(check string) "path" "a.txt" path;
      Alcotest.(check string) "content" "hi" content
  | Noop -> Alcotest.fail "expected WriteFile"

let test_save_no_path () =
  let (state, cmd) = update initial_state Save in
  Alcotest.(check bool) "cmd is Noop" true (cmd = Noop);
  Alcotest.(check bool) "mode is PromptSaveAs" true (state.mode = PromptSaveAs)

let test_minibuf_append () =
  let st = { initial_state with mode = PromptSaveAs } in
  let st = upd st (MinibufAppend (Uchar.of_char 'f')) in
  Alcotest.(check string) "minibuf = f" "f" st.minibuf

let test_minibuf_backspace () =
  let st = { initial_state with mode = PromptSaveAs; minibuf = "foo" } in
  let st = upd st MinibufBackspace in
  Alcotest.(check string) "minibuf = fo" "fo" st.minibuf

let test_minibuf_confirm () =
  let st = { initial_state with mode = PromptSaveAs; minibuf = "out.txt";
             buffer = Buffer.of_string "data" } in
  let (st2, cmd) = update st MinibufConfirm in
  Alcotest.(check bool) "mode back to Normal" true (st2.mode = Normal);
  match cmd with
  | WriteFile { path; _ } -> Alcotest.(check string) "path" "out.txt" path
  | Noop -> Alcotest.fail "expected WriteFile"

let test_minibuf_cancel () =
  let st = { initial_state with mode = PromptSaveAs; minibuf = "tmp" } in
  let st2 = upd st MinibufCancel in
  Alcotest.(check bool) "mode = Normal" true (st2.mode = Normal)

let test_write_done () =
  let st = { initial_state with modified = true } in
  let st2 = upd st (WriteDone "saved.txt") in
  Alcotest.(check bool) "not modified" false st2.modified

let test_write_error () =
  let st = { initial_state with modified = true } in
  let st2 = upd st (WriteError "fail") in
  Alcotest.(check string) "message set" "fail" st2.message

let test_try_quit_modified () =
  let st = { initial_state with modified = true } in
  let st2 = upd st TryQuit in
  Alcotest.(check bool) "mode = ConfirmQuit" true (st2.mode = ConfirmQuit)

let test_try_quit_clean () =
  let st2 = upd initial_state TryQuit in
  Alcotest.(check bool) "clean quit" true st2.quit

let test_confirm_quit () =
  let st = { initial_state with mode = ConfirmQuit } in
  let st_y = upd st Quit in
  Alcotest.(check bool) "y quits" true st_y.quit

(* ── ISSUE-009 navigation and scrolling tests ───────────────────────── *)

let test_navigation () =
  let content = "abc\ndef\nghi" in
  let st = state_with_file ~path:"test.txt" ~content in
  (* Start at (0,0), offset 0 *)
  let st = upd st (Move CharF) in
  Alcotest.(check int) "Move CharF" 1 (Cursor.primary st.cursor).head;
  let st = upd st (Move LineN) in (* line 1, col 1 -> offset 4+1=5 *)
  Alcotest.(check int) "Move LineN" 5 (Cursor.primary st.cursor).head;
  let st = upd st (Move LineStart) in (* line 1, col 0 -> offset 4 *)
  Alcotest.(check int) "Move LineStart" 4 (Cursor.primary st.cursor).head;
  let st = upd st (Move LineEnd) in (* line 1, end -> offset 7 *)
  Alcotest.(check int) "Move LineEnd" 7 (Cursor.primary st.cursor).head;
  let st = upd st (Move BufEnd) in
  Alcotest.(check int) "Move BufEnd" 11 (Cursor.primary st.cursor).head

let test_scrolling () =
  let content = String.concat "\n" ["1"; "2"; "3"; "4"; "5"; "6"; "7"; "8"; "9"; "10"] in
  let st = { (state_with_file ~path:"test.txt" ~content) with rows = 5 } in
  (* Viewport height = 4 (rows - 1). initially scroll_top_line = 0 *)
  let st = upd st (Move LineN) in (* line 1 *)
  let st = upd st (Move LineN) in (* line 2 *)
  let st = upd st (Move LineN) in (* line 3 *)
  Alcotest.(check int) "still scroll 0 at line 3" 0 st.scroll_top_line;
  let st = upd st (Move LineN) in (* line 4 - edge *)
  Alcotest.(check int) "scrolls down to line 4" 1 st.scroll_top_line;
  let st = upd st (Move BufStart) in
  Alcotest.(check int) "scrolls back to start" 0 st.scroll_top_line

(* ── ISSUE-010 undo/redo tests ────────────────────────────────────────── *)

let test_undo_redo () =
  let st = initial_state in
  (* 1. Simple undo *)
  let st1 = upd st (Insert (Uchar.of_char 'a')) in
  Alcotest.(check string) "inserted a" "a" (Buffer.to_string st1.buffer);
  let st2 = upd st1 Undo in
  Alcotest.(check string) "undo returns to empty" "" (Buffer.to_string st2.buffer);
  Alcotest.(check int) "undo restores cursor" 0 (Cursor.primary st2.cursor).head;
  
  (* 2. Redo *)
  let st3 = upd st2 Redo in
  Alcotest.(check string) "redo restores a" "a" (Buffer.to_string st3.buffer);
  Alcotest.(check int) "redo restores cursor" 1 (Cursor.primary st3.cursor).head;

  (* 3. Undo chain *)
  let st_chain = upd st1 (Insert (Uchar.of_char 'b')) in (* "ab" *)
  let st_chain = upd st_chain (Insert (Uchar.of_char 'c')) in (* "abc" *)
  Alcotest.(check string) "buffer is abc" "abc" (Buffer.to_string st_chain.buffer);
  let st_u1 = upd st_chain Undo in (* "ab" *)
  Alcotest.(check string) "undo 1: ab" "ab" (Buffer.to_string st_u1.buffer);
  let st_u2 = upd st_u1 Undo in (* "a" *)
  Alcotest.(check string) "undo 2: a" "a" (Buffer.to_string st_u2.buffer);
  
  (* 4. History forking (Edit after Undo clears Redo) *)
  let st_fork = upd st_u1 (Insert (Uchar.of_char 'z')) in (* "abz" *)
  Alcotest.(check int) "redo stack cleared after edit" 0 (List.length st_fork.redo_stack);
  let st_no_redo = upd st_fork Redo in
  Alcotest.(check string) "redo does nothing after fork" "abz" (Buffer.to_string st_no_redo.buffer)

(* ── ISSUE-011: handle_key tests ─────────────────────────────────────── *)

let test_handle_key_self_insert () =
  let (st, _) = App.handle_key initial_state (Key.Char (Uchar.of_char 'x')) in
  Alcotest.(check string) "x inserted" "x" (Buffer.to_string st.buffer)

let test_handle_key_command () =
  (* C-f should move cursor forward *)
  let st = state_with_file ~path:"t" ~content:"hello" in
  let (st, _) = App.handle_key st (Key.Ctrl 'f') in
  Alcotest.(check int) "cursor moved forward" 1 (Cursor.primary st.cursor).head

let test_handle_key_prefix_then_command () =
  (* C-x C-s should dispatch Save → WriteFile *)
  let st = { (state_with_file ~path:"a.txt" ~content:"hi") with modified = true } in
  let (st, _) = App.handle_key st (Key.Ctrl 'x') in
  Alcotest.(check bool) "pending after C-x" true (st.pending_keys <> []);
  let (_, cmd) = App.handle_key st (Key.Ctrl 's') in
  (match cmd with
   | App.WriteFile { path; _ } -> Alcotest.(check string) "save path" "a.txt" path
   | App.Noop -> Alcotest.fail "expected WriteFile")

let test_handle_key_cg_cancels_pending () =
  let st = state_with_file ~path:"t" ~content:"hi" in
  let (st, _) = App.handle_key st (Key.Ctrl 'x') in
  Alcotest.(check bool) "pending after C-x" true (st.pending_keys <> []);
  let (st, _) = App.handle_key st (Key.Ctrl 'g') in
  Alcotest.(check bool) "pending cleared" true (st.pending_keys = []);
  Alcotest.(check bool) "mode still Normal" true (st.mode = App.Normal)

let test_handle_key_unbound_shows_message () =
  (* F5 is not bound in emacs_default *)
  let (st, _) = App.handle_key initial_state (Key.Function 5) in
  Alcotest.(check bool) "message set" true (st.message <> "")

let test_handle_key_user_rebind () =
  let my_layer = Keymap.bind [Key.Ctrl 'f'] "backward-delete-char" Keymap.empty in
  let st = { (state_with_file ~path:"t" ~content:"hello") with
             cursor = Cursor.create 3;
             keymap = [my_layer; Keymap.emacs_default] } in
  let (st, _) = App.handle_key st (Key.Ctrl 'f') in
  (* "backward-delete-char" deletes char before cursor, not moves forward *)
  Alcotest.(check int) "cursor not moved forward" 2 (Cursor.primary st.cursor).head

(* ── ISSUE-009 补充：DeleteWordBack + GotoLine ───────────────────────── *)

let test_delete_word_forward () =
  (* "hello world", cursor before "world" at offset 6 *)
  let st = state_with_file ~path:"t" ~content:"hello world" in
  let st = { st with cursor = Cursor.create 6 } in
  let st = upd st App.DeleteWordForward in
  Alcotest.(check string) "world deleted" "hello " (Buffer.to_string st.buffer);
  Alcotest.(check int) "cursor unchanged" 6 (Cursor.primary st.cursor).head

let test_delete_word_forward_at_end () =
  let st = state_with_file ~path:"t" ~content:"hi" in
  let st = { st with cursor = Cursor.create 2 } in
  let st = upd st App.DeleteWordForward in
  Alcotest.(check string) "unchanged at end" "hi" (Buffer.to_string st.buffer)

let test_delete_word_back () =
  (* "hello world", cursor after "world" at offset 11 *)
  let st = state_with_file ~path:"t" ~content:"hello world" in
  let st = { st with cursor = Cursor.create 11 } in
  let st = upd st App.DeleteWordBack in
  Alcotest.(check string) "world deleted" "hello " (Buffer.to_string st.buffer);
  Alcotest.(check int) "cursor at 6" 6 (Cursor.primary st.cursor).head

let test_delete_word_back_at_start () =
  let st = state_with_file ~path:"t" ~content:"hi" in
  let st = { st with cursor = Cursor.create 0 } in
  let st = upd st App.DeleteWordBack in
  Alcotest.(check string) "unchanged" "hi" (Buffer.to_string st.buffer);
  Alcotest.(check int) "cursor unchanged" 0 (Cursor.primary st.cursor).head

let test_goto_line_via_handle_key () =
  (* M-g g via handle_key enters PromptGotoLine *)
  let st = state_with_file ~path:"t" ~content:"a\nb\nc" in
  let (st, _) = App.handle_key st (Key.Meta (Uchar.of_char 'g')) in
  Alcotest.(check bool) "pending after M-g" true (st.pending_keys <> []);
  let (st, _) = App.handle_key st (Key.Char (Uchar.of_char 'g')) in
  Alcotest.(check bool) "mode = PromptGotoLine" true (st.mode = App.PromptGotoLine)

let test_goto_line_with_held_alt () =
  (* Some users keep Alt held for the second g, producing M-g M-g. *)
  let st = state_with_file ~path:"t" ~content:"a\nb\nc" in
  let (st, _) = App.handle_key st (Key.Meta (Uchar.of_char 'g')) in
  Alcotest.(check bool) "pending after first M-g" true (st.pending_keys <> []);
  let (st, _) = App.handle_key st (Key.Meta (Uchar.of_char 'g')) in
  Alcotest.(check bool) "mode = PromptGotoLine" true (st.mode = App.PromptGotoLine)

let test_goto_line_jump () =
  let content = "line1\nline2\nline3\nline4" in
  let st = state_with_file ~path:"t" ~content in
  (* Enter PromptGotoLine, type "3", confirm *)
  let st = { st with mode = App.PromptGotoLine; minibuf = "3" } in
  let st = upd st App.MinibufConfirm in
  Alcotest.(check bool) "mode = Normal" true (st.mode = App.Normal);
  (* line3 starts at offset 12 *)
  Alcotest.(check int) "cursor at line 3" 12 (Cursor.primary st.cursor).head

let test_goto_line_clamp () =
  let content = "a\nb\nc" in
  let st = { (state_with_file ~path:"t" ~content) with mode = App.PromptGotoLine; minibuf = "999" } in
  let st = upd st App.MinibufConfirm in
  (* Should clamp to last line = line 3, offset 4 *)
  Alcotest.(check int) "clamped to last line" 4 (Cursor.primary st.cursor).head

(* ── ISSUE-012: M-x / command registry ─────────────────────────────── *)

let key_mx = Key.Meta (Uchar.of_char 'x')

let test_mx_opens_prompt () =
  let st = fst (handle_key initial_state key_mx) in
  Alcotest.(check bool) "mode is PromptMx" true (st.mode = PromptMx);
  Alcotest.(check string) "minibuf empty" "" st.minibuf

let test_mx_execute_known_command () =
  (* "move-forward-char" via M-x should move cursor same as C-f *)
  let buf_content = "hello" in
  let st0 = { (state_with_file ~path:"f" ~content:buf_content)
              with cols = 80; rows = 24 } in
  (* via keybinding C-f *)
  let st_key = fst (handle_key st0 (Key.Ctrl 'f')) in
  (* via M-x *)
  let st_mx = fst (handle_key st0 key_mx) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'm'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'o'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'v'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'e'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char '-'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'f'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'o'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'r'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'w'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'a'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'r'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'd'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char '-'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'c'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'h'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'a'))) in
  let st_mx = fst (handle_key st_mx (Key.Char (Uchar.of_char 'r'))) in
  let st_mx = fst (handle_key st_mx Key.Enter) in
  Alcotest.(check int) "cursor same as C-f"
    (Cursor.primary st_key.cursor).head
    (Cursor.primary st_mx.cursor).head;
  Alcotest.(check bool) "mode back to Normal" true (st_mx.mode = Normal)

let test_mx_unknown_command_error () =
  let st = fst (handle_key initial_state key_mx) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'n'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'o'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'p'))) in
  let st = fst (handle_key st Key.Enter) in
  Alcotest.(check bool) "mode back to Normal" true (st.mode = Normal);
  Alcotest.(check bool) "error message set" true (st.message <> "")

let test_mx_cg_cancel () =
  let st0 = { (state_with_file ~path:"f" ~content:"hello")
              with cols = 80; rows = 24 } in
  let st = fst (handle_key st0 key_mx) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'x'))) in
  let st = fst (handle_key st (Key.Ctrl 'g')) in
  Alcotest.(check bool) "mode Normal" true (st.mode = Normal);
  Alcotest.(check string) "buffer unchanged"
    (Buffer.to_string st0.buffer) (Buffer.to_string st.buffer);
  Alcotest.(check string) "minibuf cleared" "" st.minibuf

let test_mx_undo_works () =
  (* Execute "new-line" via M-x, then undo; buffer should be back to original. *)
  let st0 = { (state_with_file ~path:"f" ~content:"hello")
              with cols = 80; rows = 24 } in
  let st = fst (handle_key st0 key_mx) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'n'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'e'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'w'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char '-'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'l'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'i'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'n'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'e'))) in
  let st = fst (handle_key st Key.Enter) in
  (* buffer should now contain a newline *)
  Alcotest.(check bool) "newline inserted"
    true (Buffer.to_string st.buffer <> Buffer.to_string st0.buffer);
  (* undo *)
  let st = fst (handle_key st (Key.Ctrl '/')) in
  Alcotest.(check string) "buffer restored after undo"
    (Buffer.to_string st0.buffer) (Buffer.to_string st.buffer)

let test_mx_register_new_command () =
  (* Register a new command handler — verifies registration and M-x dispatch. *)
  let reg = Registry.register "test-insert-x"
              (fun st -> App.update st (Insert (Uchar.of_char 'x')))
              initial_state.registry in
  (* command must appear in completion *)
  Alcotest.(check bool) "appears in complete" true
    (List.mem "test-insert-x" (Registry.complete ~prefix:"test-" reg));
  (* execute via M-x *)
  let st = { initial_state with registry = reg } in
  let type_str s st = String.fold_left
    (fun st c -> fst (handle_key st (Key.Char (Uchar.of_char c)))) st s in
  let st = fst (handle_key st key_mx) in
  let st = type_str "test-insert-x" st in
  let st = fst (handle_key st Key.Enter) in
  Alcotest.(check string) "action ran" "x" (Buffer.to_string st.buffer)

let test_mx_all_builtins_reachable () =
  (* Every command name from emacs_default must exist in initial_state.registry *)
  let reg_names = Registry.names initial_state.registry in
  let keymap_commands =
    let rec collect_commands km =
      List.concat_map (fun (_, binding) ->
        match binding with
        | Keymap.Command name -> [name]
        | Keymap.Prefix sub   -> collect_commands sub
      ) km
    in
    collect_commands Keymap.emacs_default
    |> List.sort_uniq String.compare
    |> List.filter (fun n -> n <> "cancel" && n <> "help")
    (* "cancel" and "help" are UI-only, not necessarily in registry *)
  in
  List.iter (fun name ->
    Alcotest.(check bool) ("registry has " ^ name) true
      (List.mem name reg_names)
  ) keymap_commands

let test_mx_tab_lcp () =
  (* Tab completes to the longest common prefix when matches share one. *)
  let st = fst (handle_key initial_state key_mx) in
  let type_str s st =
    String.fold_left (fun st c ->
      fst (handle_key st (Key.Char (Uchar.of_char c)))
    ) st s
  in
  let st = type_str "move-f" st in
  let st = fst (handle_key st Key.Tab) in
  Alcotest.(check string) "minibuf extended to LCP"
    "move-forward-" st.minibuf

(* ── ISSUE-013: selection / clipboard ──────────────────────────────── *)

let test_mark_toggle () =
  let st = { initial_state with cursor = Cursor.create 3 } in
  let st = fst (handle_key st (Key.Ctrl '@')) in
  Alcotest.(check (option int)) "mark set" (Some 3) st.mark;
  let st = fst (handle_key st (Key.Ctrl '@')) in
  Alcotest.(check (option int)) "mark cleared" None st.mark

let test_kill_region_forward_undo () =
  let st = state_with_file ~path:"t" ~content:"abcdef" in
  let st = { st with cursor = Cursor.create 2 } in
  let st = upd st ToggleMark in
  let st = { st with cursor = Cursor.create 5 } in
  let st = upd st KillRegion in
  Alcotest.(check string) "region deleted" "abf" (Buffer.to_string st.buffer);
  Alcotest.(check (option string)) "kill ring" (Some "cde") st.kill_ring;
  Alcotest.(check (option int)) "mark cleared" None st.mark;
  Alcotest.(check int) "cursor at region start" 2 (Cursor.primary st.cursor).head;
  let st = upd st Undo in
  Alcotest.(check string) "undo restores buffer" "abcdef" (Buffer.to_string st.buffer)

let test_copy_region_backward () =
  let st = state_with_file ~path:"t" ~content:"abcdef" in
  let st = { st with cursor = Cursor.create 5 } in
  let st = upd st ToggleMark in
  let st = { st with cursor = Cursor.create 2 } in
  let st = upd st CopyRegion in
  Alcotest.(check string) "buffer unchanged" "abcdef" (Buffer.to_string st.buffer);
  Alcotest.(check (option string)) "kill ring" (Some "cde") st.kill_ring;
  Alcotest.(check int) "undo stack unchanged" 0 (List.length st.undo_stack)

let test_yank_at_cursor () =
  let st = { (state_with_file ~path:"t" ~content:"ab")
             with cursor = Cursor.create 1; kill_ring = Some "XY" } in
  let st = upd st Yank in
  Alcotest.(check string) "yanked" "aXYb" (Buffer.to_string st.buffer);
  Alcotest.(check int) "cursor after yank" 3 (Cursor.primary st.cursor).head

let test_yank_multiple_cursors () =
  let cursor =
    Cursor.of_list [
      { Cursor.head = 1; anchor = 1 };
      { Cursor.head = 3; anchor = 3 };
    ]
  in
  let st = { (state_with_file ~path:"t" ~content:"abcd")
             with cursor; kill_ring = Some "x" } in
  let st = upd st Yank in
  Alcotest.(check string) "yanked at each cursor" "axbcxd"
    (Buffer.to_string st.buffer)

let test_cancel_clears_mark () =
  let st = { initial_state with mark = Some 0; cursor = Cursor.create 4 } in
  let st = fst (handle_key st (Key.Ctrl 'g')) in
  Alcotest.(check (option int)) "mark cleared" None st.mark

let test_kill_line_appends_to_kill_ring () =
  let st = state_with_file ~path:"t" ~content:"a\nb\nc" in
  let st = upd st KillLine in
  Alcotest.(check string) "first kill" "\nb\nc" (Buffer.to_string st.buffer);
  Alcotest.(check (option string)) "first kill ring" (Some "a") st.kill_ring;
  let st = upd st KillLine in
  Alcotest.(check string) "second kill removes newline" "b\nc"
    (Buffer.to_string st.buffer);
  Alcotest.(check (option string)) "appended kill ring" (Some "a\n") st.kill_ring

let test_selection_commands_in_registry () =
  let names = Registry.names initial_state.registry in
  List.iter (fun name ->
    Alcotest.(check bool) ("registry has " ^ name) true (List.mem name names)
  ) [ "set-mark-command"; "kill-region"; "copy-region"; "yank" ]

(* ── ISSUE-014: search / replace ───────────────────────────────────── *)

let type_keys s st =
  String.fold_left
    (fun st c -> fst (handle_key st (Key.Char (Uchar.of_char c))))
    st s

let test_search_opens_and_finds () =
  let st = state_with_file ~path:"t" ~content:"one two one" in
  let st = { st with cursor = Cursor.create 1 } in
  let st = fst (handle_key st (Key.Ctrl 's')) in
  Alcotest.(check bool) "mode PromptSearch" true (st.mode = PromptSearch);
  let st = type_keys "one" st in
  Alcotest.(check int) "cursor at next one" 8 (Cursor.primary st.cursor).head;
  Alcotest.(check int) "all matches" 2 (List.length st.search_matches)

let test_search_next_wraps () =
  let st = state_with_file ~path:"t" ~content:"one two one" in
  let st = fst (handle_key st (Key.Ctrl 's')) |> type_keys "one" in
  let st = fst (handle_key st (Key.Ctrl 's')) in
  Alcotest.(check int) "next match" 8 (Cursor.primary st.cursor).head;
  let st = fst (handle_key st (Key.Ctrl 's')) in
  Alcotest.(check int) "wrapped to first" 0 (Cursor.primary st.cursor).head;
  Alcotest.(check bool) "wrapped flag" true st.search_wrapped

let test_search_backward () =
  let st = { (state_with_file ~path:"t" ~content:"one two one")
             with cursor = Cursor.create 11 } in
  let st = fst (handle_key st (Key.Ctrl 'r')) |> type_keys "one" in
  Alcotest.(check int) "previous match" 8 (Cursor.primary st.cursor).head;
  let st = fst (handle_key st (Key.Ctrl 'r')) in
  Alcotest.(check int) "previous previous match" 0 (Cursor.primary st.cursor).head

let test_search_cancel_restores_origin () =
  let st = { (state_with_file ~path:"t" ~content:"one two one")
             with cursor = Cursor.create 4 } in
  let st = fst (handle_key st (Key.Ctrl 's')) |> type_keys "one" in
  let st = fst (handle_key st (Key.Ctrl 'g')) in
  Alcotest.(check bool) "mode Normal" true (st.mode = Normal);
  Alcotest.(check int) "origin restored" 4 (Cursor.primary st.cursor).head

let test_search_confirm_keeps_match () =
  let st = state_with_file ~path:"t" ~content:"one two one" in
  let st = fst (handle_key st (Key.Ctrl 's')) |> type_keys "two" in
  let st = fst (handle_key st Key.Enter) in
  Alcotest.(check bool) "mode Normal" true (st.mode = Normal);
  Alcotest.(check int) "cursor at match" 4 (Cursor.primary st.cursor).head

let test_search_smart_case () =
  let st = state_with_file ~path:"t" ~content:"Foo foo" in
  let st_lower = fst (handle_key st (Key.Ctrl 's')) |> type_keys "foo" in
  Alcotest.(check int) "lowercase matches both" 2 (List.length st_lower.search_matches);
  let st_upper = fst (handle_key st (Key.Ctrl 's')) |> type_keys "Foo" in
  Alcotest.(check int) "uppercase exact" 1 (List.length st_upper.search_matches)

let test_search_utf8 () =
  let st = state_with_file ~path:"t" ~content:"abc你好def你好" in
  let st = fst (handle_key st (Key.Ctrl 's')) in
  let st = fst (handle_key st (Key.Char (Uchar.of_int 0x4F60))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_int 0x597D))) in
  Alcotest.(check int) "first CJK match" 3 (Cursor.primary st.cursor).head;
  Alcotest.(check int) "two CJK matches" 2 (List.length st.search_matches)

let test_query_replace_prompts () =
  let st = fst (handle_key initial_state (Key.Meta (Uchar.of_char '%'))) in
  Alcotest.(check bool) "search prompt" true (st.mode = PromptReplaceSearch);
  let st = type_keys "foo" st in
  let st = fst (handle_key st Key.Enter) in
  Alcotest.(check bool) "replacement prompt" true (st.mode = PromptReplaceWith);
  Alcotest.(check string) "stored query" "foo" st.replace_query

let test_query_replace_yes_no_quit () =
  let st = state_with_file ~path:"t" ~content:"foo foo foo" in
  let st = fst (handle_key st (Key.Meta (Uchar.of_char '%'))) in
  let st = type_keys "foo" st |> fun st -> fst (handle_key st Key.Enter) in
  let st = type_keys "bar" st |> fun st -> fst (handle_key st Key.Enter) in
  Alcotest.(check bool) "confirm mode" true (st.mode = PromptReplaceConfirm);
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'y'))) in
  Alcotest.(check string) "first replaced" "bar foo foo" (Buffer.to_string st.buffer);
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'n'))) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'q'))) in
  Alcotest.(check bool) "quit normal" true (st.mode = Normal);
  Alcotest.(check string) "second skipped" "bar foo foo" (Buffer.to_string st.buffer)

let test_query_replace_all () =
  let st = state_with_file ~path:"t" ~content:"foo foo foo" in
  let st = fst (handle_key st (Key.Meta (Uchar.of_char '%'))) in
  let st = type_keys "foo" st |> fun st -> fst (handle_key st Key.Enter) in
  let st = type_keys "bar" st |> fun st -> fst (handle_key st Key.Enter) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char '!'))) in
  Alcotest.(check bool) "mode Normal" true (st.mode = Normal);
  Alcotest.(check string) "all replaced" "bar bar bar" (Buffer.to_string st.buffer)

(* ── ISSUE-015: window splitting ───────────────────────────────────── *)

let test_window_split_dispatch () =
  let st = fst (handle_key initial_state (Key.Ctrl 'x')) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char '2'))) in
  Alcotest.(check int) "two windows" 2 (List.length (Frame.leaves st.frame));
  let st = fst (handle_key st (Key.Ctrl 'x')) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char '3'))) in
  Alcotest.(check int) "three windows" 3 (List.length (Frame.leaves st.frame))

let test_window_focus_and_close () =
  let st = upd initial_state SplitWindowHorizontal in
  let first_focus = st.frame.focused in
  let st = upd st FocusNextWindow in
  Alcotest.(check bool) "focus changed" true (st.frame.focused <> first_focus);
  let st = upd st CloseWindow in
  Alcotest.(check int) "closed focused" 1 (List.length (Frame.leaves st.frame));
  let st = upd st CloseWindow in
  Alcotest.(check int) "last close no-op" 1 (List.length (Frame.leaves st.frame))

let test_close_other_windows () =
  let st = upd initial_state SplitWindowHorizontal in
  let st = upd st SplitWindowVertical in
  let focused = st.frame.focused in
  let st = upd st CloseOtherWindows in
  Alcotest.(check int) "one window" 1 (List.length (Frame.leaves st.frame));
  Alcotest.(check int) "focused kept" focused st.frame.focused

let test_focused_window_scroll_independent () =
  let content = String.concat "\n" ["0"; "1"; "2"; "3"; "4"; "5"; "6"; "7"] in
  let st = { (state_with_file ~path:"t" ~content) with rows = 4 } in
  let st = upd st SplitWindowHorizontal in
  let first = st.frame.focused in
  let st = upd st (Move LineN) in
  let st = upd st (Move LineN) in
  let st = upd st (Move LineN) in
  let first_scroll = (Frame.focused_window st.frame).scroll_top_line in
  let st = upd st FocusNextWindow in
  let second = Frame.focused_window st.frame in
  Alcotest.(check bool) "first scrolled" true (first_scroll > 0);
  Alcotest.(check bool) "different focus" true (second.id <> first);
  Alcotest.(check int) "other window still top" 0 second.scroll_top_line

let test_window_commands_in_registry () =
  let names = Registry.names initial_state.registry in
  List.iter (fun name ->
    Alcotest.(check bool) ("registry has " ^ name) true (List.mem name names)
  ) [ "split-window-below"; "split-window-right"; "other-window";
      "delete-window"; "delete-other-windows" ]

(* ── ISSUE-016: multi-buffer management ────────────────────────────── *)

let test_initial_scratch_buffer () =
  Alcotest.(check string) "default buffer name" "*scratch*" (App.current_buffer initial_state).name;
  Alcotest.(check int) "single open buffer" 1 (List.length initial_state.buffers)

let test_open_file_reuses_existing_buffer () =
  let st = initial_state |> App.open_file ~path:"a.txt" ~content:"one" in
  let st = upd st (Move BufEnd) in
  let st = upd st (Insert (Uchar.of_char '!')) in
  let st = App.open_file ~path:"b.txt" ~content:"two" st in
  let st = App.open_file ~path:"a.txt" ~content:"ignored" st in
  Alcotest.(check int) "no duplicate" 3 (List.length st.buffers);
  Alcotest.(check string) "existing content kept" "one!"
    (Buffer.to_string st.buffer)

let test_switch_buffer_prompt_and_completion () =
  let st = initial_state |> App.open_file ~path:"alpha.txt" ~content:"a" in
  let st = App.open_file ~path:"beta.txt" ~content:"b" st in
  let st = fst (handle_key st (Key.Ctrl 'x')) in
  let st = fst (handle_key st (Key.Char (Uchar.of_char 'b'))) in
  Alcotest.(check bool) "switch prompt" true (st.mode = PromptSwitchBuffer);
  let st = type_keys "al" st in
  let st = fst (handle_key st Key.Tab) in
  Alcotest.(check string) "completed alpha" "alpha.txt" st.minibuf;
  let st = fst (handle_key st Key.Enter) in
  Alcotest.(check string) "switched content" "a" (Buffer.to_string st.buffer);
  Alcotest.(check string) "current name" "alpha.txt" (App.current_buffer st).name

let test_buffer_list_contains_file_and_modified_state () =
  let st = initial_state |> App.open_file ~path:"alpha.txt" ~content:"a" in
  let st = upd st (Move BufEnd) |> fun st -> upd st (Insert (Uchar.of_char '!')) in
  let st = App.open_file ~path:"beta.txt" ~content:"b" st in
  let st = upd st ShowBufferList in
  let text = Buffer.to_string st.buffer in
  Alcotest.(check string) "current list buffer" "*Buffer List*" (App.current_buffer st).name;
  Alcotest.(check bool) "lists alpha" true (String.contains text '*');
  Alcotest.(check bool) "lists path" true (String.contains text 'a')

let test_kill_dirty_buffer_requires_confirmation_and_replaces_windows () =
  let st = initial_state |> App.open_file ~path:"alpha.txt" ~content:"a" in
  let alpha_id = st.current_buffer_id in
  let st = upd st (Move BufEnd) |> fun st -> upd st (Insert (Uchar.of_char '!')) in
  let st = App.open_file ~path:"beta.txt" ~content:"b" st in
  let beta_id = st.current_buffer_id in
  let st = { st with frame = Frame.replace_buffer ~old_id:beta_id ~new_id:alpha_id st.frame } in
  let st = upd st (KillBuffer "alpha.txt") in
  Alcotest.(check bool) "confirmation mode" true (st.mode = ConfirmKillBuffer);
  let st = upd st KillBufferConfirmed in
  Alcotest.(check bool) "alpha removed" false
    (List.exists (fun (b : App.buffer_entry) -> b.id = alpha_id) st.buffers);
  let live_ids = List.map (fun (b : App.buffer_entry) -> b.id) st.buffers in
  Alcotest.(check bool) "windows replaced" true
    (Frame.leaves st.frame
     |> List.for_all (fun w -> w.Frame.buffer_id <> alpha_id && List.mem w.Frame.buffer_id live_ids))

let test_independent_undo_per_buffer () =
  let st = initial_state |> App.open_file ~path:"alpha.txt" ~content:"a" in
  let st = upd st (Move BufEnd) |> fun st -> upd st (Insert (Uchar.of_char '!')) in
  let st = App.open_file ~path:"beta.txt" ~content:"b" st in
  let st = upd st (Move BufEnd) |> fun st -> upd st (Insert (Uchar.of_char '?')) in
  let st = upd st Undo in
  Alcotest.(check string) "beta undo only" "b" (Buffer.to_string st.buffer);
  let st = upd st (SwitchBuffer "alpha.txt") in
  Alcotest.(check string) "alpha still edited" "a!" (Buffer.to_string st.buffer);
  let st = upd st Undo in
  Alcotest.(check string) "alpha undo separate" "a" (Buffer.to_string st.buffer)

let test_focus_window_activates_its_buffer () =
  let st = initial_state |> App.open_file ~path:"alpha.txt" ~content:"a" in
  let alpha_id = st.current_buffer_id in
  let st = App.open_file ~path:"beta.txt" ~content:"b" st in
  let beta_id = st.current_buffer_id in
  let st = upd st SplitWindowHorizontal in
  let st = { st with frame = Frame.replace_buffer ~old_id:beta_id ~new_id:alpha_id st.frame } in
  let st = upd st FocusNextWindow in
  Alcotest.(check int) "focused buffer loaded" alpha_id st.current_buffer_id;
  Alcotest.(check string) "alpha content active" "a" (Buffer.to_string st.buffer)

(* ── ISSUE-017: multi-cursor ───────────────────────────────────────── *)

let test_next_occurrence_adds_selection_cursor () =
  let st = state_with_file ~path:"t" ~content:"foo bar foo baz foo" in
  let st = upd { st with cursor = Cursor.create 0 } ToggleMark in
  let st = { st with cursor = Cursor.create 3 } in
  let st = upd st AddNextOccurrence in
  let ranges = Cursor.to_list st.cursor in
  Alcotest.(check int) "two selections" 2 (List.length ranges);
  Alcotest.(check (option int)) "mark kept" (Some 0) st.mark;
  let second = List.nth ranges 1 in
  Alcotest.(check int) "second match start" 8 (min second.Cursor.head second.anchor)

let test_repeated_next_occurrence_adds_further_cursors () =
  let st = state_with_file ~path:"t" ~content:"foo bar foo baz foo" in
  let st = upd { st with cursor = Cursor.create 0 } ToggleMark in
  let st = { st with cursor = Cursor.create 3 } in
  let st = upd st AddNextOccurrence |> fun st -> upd st AddNextOccurrence in
  Alcotest.(check int) "three selections" 3 (List.length (Cursor.to_list st.cursor))

let test_column_expansion_and_last_line_noop () =
  let st = state_with_file ~path:"t" ~content:"ab\ncd\nef" in
  let st = { st with cursor = Cursor.create 1 } in
  let st = upd st AddCursorBelow in
  let heads = Cursor.to_list st.cursor |> List.map (fun r -> r.Cursor.head) in
  Alcotest.(check (list int)) "same column below" [1; 4] heads;
  let st = upd st AddCursorBelow in
  let heads = Cursor.to_list st.cursor |> List.map (fun r -> r.Cursor.head) in
  Alcotest.(check (list int)) "third line added" [1; 4; 7] heads;
  let st = upd st AddCursorBelow in
  Alcotest.(check int) "last line noop" 3 (List.length (Cursor.to_list st.cursor))

let test_all_cursors_insert_delete_and_move () =
  let cursor =
    Cursor.of_list [
      { Cursor.head = 1; anchor = 1 };
      { Cursor.head = 3; anchor = 3 };
    ]
  in
  let st = { (state_with_file ~path:"t" ~content:"abcd") with cursor } in
  let st = upd st (Insert (Uchar.of_char 'X')) in
  Alcotest.(check string) "insert at all cursors" "aXbcXd" (Buffer.to_string st.buffer);
  let st = upd st Backspace in
  Alcotest.(check string) "delete at all cursors" "abcd" (Buffer.to_string st.buffer);
  let st = upd st (Move CharF) in
  let heads = Cursor.to_list st.cursor |> List.map (fun r -> r.Cursor.head) in
  Alcotest.(check (list int)) "move all cursors" [2; 4] heads

let test_cancel_dismisses_secondary_cursors () =
  let cursor =
    Cursor.of_list [
      { Cursor.head = 1; anchor = 1 };
      { Cursor.head = 3; anchor = 3 };
    ]
  in
  let st = upd { initial_state with cursor } Cancel in
  Alcotest.(check int) "single cursor" 1 (List.length (Cursor.to_list st.cursor))

let () =
  let open Alcotest in
  run "App" [
    "update", [
      test_case "initial_state"          `Quick test_initial_state;
      test_case "insert_char"            `Quick test_insert_char;
      test_case "backspace_empty"        `Quick test_backspace_empty;
      test_case "insert_then_backspace"  `Quick test_insert_then_backspace;
      test_case "enter"                  `Quick test_enter;
      test_case "quit"                   `Quick test_quit;
      test_case "backspace_cjk"          `Quick test_backspace_cjk;
    ];
    "file", [
      test_case "state_with_file"        `Quick test_state_with_file;
      test_case "edit_sets_modified"     `Quick test_edit_sets_modified;
      test_case "save_with_path"         `Quick test_save_with_path;
      test_case "save_no_path"           `Quick test_save_no_path;
      test_case "minibuf_append"         `Quick test_minibuf_append;
      test_case "minibuf_backspace"      `Quick test_minibuf_backspace;
      test_case "minibuf_confirm"        `Quick test_minibuf_confirm;
      test_case "minibuf_cancel"         `Quick test_minibuf_cancel;
      test_case "write_done"             `Quick test_write_done;
      test_case "write_error"            `Quick test_write_error;
      test_case "try_quit_modified"      `Quick test_try_quit_modified;
      test_case "try_quit_clean"         `Quick test_try_quit_clean;
      test_case "confirm_quit"           `Quick test_confirm_quit;
    ];
    "nav", [
      test_case "navigation"             `Quick test_navigation;
      test_case "scrolling"              `Quick test_scrolling;
    ];
    "history", [
      test_case "undo_redo"              `Quick test_undo_redo;
    ];
    "handle_key", [
      test_case "self_insert"            `Quick test_handle_key_self_insert;
      test_case "command_dispatch"       `Quick test_handle_key_command;
      test_case "prefix_then_command"    `Quick test_handle_key_prefix_then_command;
      test_case "cg_cancels_pending"     `Quick test_handle_key_cg_cancels_pending;
      test_case "unbound_shows_message"  `Quick test_handle_key_unbound_shows_message;
      test_case "user_rebind"            `Quick test_handle_key_user_rebind;
    ];
    "delete_word_back", [
      test_case "delete_word_back"       `Quick test_delete_word_back;
      test_case "delete_word_back_start" `Quick test_delete_word_back_at_start;
    ];
    "delete_word_forward", [
      test_case "delete_word_forward"     `Quick test_delete_word_forward;
      test_case "delete_word_forward_end" `Quick test_delete_word_forward_at_end;
    ];
    "goto_line", [
      test_case "goto_via_handle_key"    `Quick test_goto_line_via_handle_key;
      test_case "goto_with_held_alt"     `Quick test_goto_line_with_held_alt;
      test_case "jump_to_line"           `Quick test_goto_line_jump;
      test_case "jump_clamp"             `Quick test_goto_line_clamp;
    ];
    "mx", [
      test_case "opens_prompt"           `Quick test_mx_opens_prompt;
      test_case "execute_known_command"  `Quick test_mx_execute_known_command;
      test_case "unknown_command_error"  `Quick test_mx_unknown_command_error;
      test_case "cg_cancel"              `Quick test_mx_cg_cancel;
      test_case "undo_works"             `Quick test_mx_undo_works;
      test_case "register_new_command"   `Quick test_mx_register_new_command;
      test_case "all_builtins_reachable" `Quick test_mx_all_builtins_reachable;
      test_case "tab_lcp"                `Quick test_mx_tab_lcp;
    ];
    "selection_clipboard", [
      test_case "mark_toggle"            `Quick test_mark_toggle;
      test_case "kill_region_forward_undo" `Quick test_kill_region_forward_undo;
      test_case "copy_region_backward"   `Quick test_copy_region_backward;
      test_case "yank_at_cursor"         `Quick test_yank_at_cursor;
      test_case "yank_multiple_cursors"  `Quick test_yank_multiple_cursors;
      test_case "cancel_clears_mark"     `Quick test_cancel_clears_mark;
      test_case "kill_line_appends"      `Quick test_kill_line_appends_to_kill_ring;
      test_case "commands_in_registry"   `Quick test_selection_commands_in_registry;
    ];
    "search_replace", [
      test_case "search_opens_and_finds" `Quick test_search_opens_and_finds;
      test_case "search_next_wraps"      `Quick test_search_next_wraps;
      test_case "search_backward"        `Quick test_search_backward;
      test_case "search_cancel"          `Quick test_search_cancel_restores_origin;
      test_case "search_confirm"         `Quick test_search_confirm_keeps_match;
      test_case "search_smart_case"      `Quick test_search_smart_case;
      test_case "search_utf8"            `Quick test_search_utf8;
      test_case "replace_prompts"        `Quick test_query_replace_prompts;
      test_case "replace_yes_no_quit"    `Quick test_query_replace_yes_no_quit;
      test_case "replace_all"            `Quick test_query_replace_all;
    ];
    "windows", [
      test_case "split_dispatch"         `Quick test_window_split_dispatch;
      test_case "focus_and_close"        `Quick test_window_focus_and_close;
      test_case "close_others"           `Quick test_close_other_windows;
      test_case "independent_scroll"     `Quick test_focused_window_scroll_independent;
      test_case "commands_in_registry"   `Quick test_window_commands_in_registry;
    ];
    "buffers", [
      test_case "initial_scratch_buffer" `Quick test_initial_scratch_buffer;
      test_case "open_file_reuses_existing_buffer" `Quick test_open_file_reuses_existing_buffer;
      test_case "switch_buffer_prompt_and_completion" `Quick test_switch_buffer_prompt_and_completion;
      test_case "buffer_list_contains_file_and_modified_state" `Quick test_buffer_list_contains_file_and_modified_state;
      test_case "kill_dirty_buffer_requires_confirmation_and_replaces_windows" `Quick test_kill_dirty_buffer_requires_confirmation_and_replaces_windows;
      test_case "independent_undo_per_buffer" `Quick test_independent_undo_per_buffer;
      test_case "focus_window_activates_its_buffer" `Quick test_focus_window_activates_its_buffer;
    ];
    "multi_cursor", [
      test_case "next_occurrence_adds_selection_cursor" `Quick test_next_occurrence_adds_selection_cursor;
      test_case "repeated_next_occurrence_adds_further_cursors" `Quick test_repeated_next_occurrence_adds_further_cursors;
      test_case "column_expansion_and_last_line_noop" `Quick test_column_expansion_and_last_line_noop;
      test_case "all_cursors_insert_delete_and_move" `Quick test_all_cursors_insert_delete_and_move;
      test_case "cancel_dismisses_secondary_cursors" `Quick test_cancel_dismisses_secondary_cursors;
    ];
  ]
