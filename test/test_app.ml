open Jeditor_core
open Jeditor_buffer
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
  ]
