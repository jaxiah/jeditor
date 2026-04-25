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
  ]
