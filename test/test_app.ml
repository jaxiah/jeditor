open Jeditor_core
open Jeditor_buffer
open App

(* Helper: apply update and discard effect *)
let upd state action = fst (update state action)

(* ── existing ISSUE-006 tests (update signature fixed) ───────────────── *)

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

(* Test 1 - tracer bullet: state_with_file *)
let test_state_with_file () =
  let state = state_with_file ~path:"foo.txt" ~content:"hello\nworld" in
  Alcotest.(check string) "buffer content" "hello\nworld" (Buffer.to_string state.buffer);
  Alcotest.(check (option string)) "file_path set" (Some "foo.txt") state.file_path;
  Alcotest.(check bool) "not modified" false state.modified;
  Alcotest.(check bool) "not quit" false state.quit

(* Test 2 - Insert/Backspace/Enter set modified=true *)
let test_edit_sets_modified () =
  let s1 = upd initial_state (Insert (Uchar.of_char 'x')) in
  Alcotest.(check bool) "insert sets modified" true s1.modified;
  let s2 = upd s1 Backspace in
  Alcotest.(check bool) "backspace keeps modified" true s2.modified;
  let s3 = upd initial_state Enter in
  Alcotest.(check bool) "enter sets modified" true s3.modified

(* Test 3 - Save with file_path -> WriteFile cmd *)
let test_save_with_path () =
  let state = { (state_with_file ~path:"a.txt" ~content:"hi") with modified = true } in
  let (_, cmd) = update state Save in
  match cmd with
  | WriteFile { path; content } ->
      Alcotest.(check string) "path" "a.txt" path;
      Alcotest.(check string) "content" "hi" content
  | Noop -> Alcotest.fail "expected WriteFile, got Noop"

(* Test 4 - Save without file_path -> PromptSaveAs mode *)
let test_save_no_path () =
  let (state, cmd) = update initial_state Save in
  Alcotest.(check bool) "cmd is Noop" true (cmd = Noop);
  Alcotest.(check bool) "mode is PromptSaveAs" true (state.mode = PromptSaveAs);
  Alcotest.(check string) "minibuf empty" "" state.minibuf

(* Test 5 - MinibufAppend accumulates minibuf *)
let test_minibuf_append () =
  let st = { initial_state with mode = PromptSaveAs } in
  let st = upd st (MinibufAppend (Uchar.of_char 'f')) in
  let st = upd st (MinibufAppend (Uchar.of_char 'o')) in
  let st = upd st (MinibufAppend (Uchar.of_char 'o')) in
  Alcotest.(check string) "minibuf = foo" "foo" st.minibuf

(* Test 6 - MinibufBackspace trims minibuf *)
let test_minibuf_backspace () =
  let st = { initial_state with mode = PromptSaveAs; minibuf = "foo" } in
  let st = upd st MinibufBackspace in
  Alcotest.(check string) "minibuf = fo" "fo" st.minibuf;
  let st = upd { initial_state with mode = PromptSaveAs; minibuf = "" } MinibufBackspace in
  Alcotest.(check string) "empty minibuf stays empty" "" st.minibuf

(* Test 7 - MinibufConfirm -> WriteFile with path=minibuf *)
let test_minibuf_confirm () =
  let st = { initial_state with mode = PromptSaveAs; minibuf = "out.txt";
             buffer = Buffer.of_string "data" } in
  let (st2, cmd) = update st MinibufConfirm in
  Alcotest.(check bool) "mode back to Normal" true (st2.mode = Normal);
  Alcotest.(check string) "minibuf cleared" "" st2.minibuf;
  match cmd with
  | WriteFile { path; content } ->
      Alcotest.(check string) "path from minibuf" "out.txt" path;
      Alcotest.(check string) "content" "data" content
  | Noop -> Alcotest.fail "expected WriteFile"

(* Test 8 - MinibufCancel -> Normal, minibuf cleared *)
let test_minibuf_cancel () =
  let st = { initial_state with mode = PromptSaveAs; minibuf = "tmp" } in
  let st2 = upd st MinibufCancel in
  Alcotest.(check bool) "mode = Normal" true (st2.mode = Normal);
  Alcotest.(check string) "minibuf cleared" "" st2.minibuf

(* Test 9 - WriteDone -> modified=false, file_path updated, message *)
let test_write_done () =
  let st = { initial_state with modified = true } in
  let st2 = upd st (WriteDone "saved.txt") in
  Alcotest.(check bool) "not modified" false st2.modified;
  Alcotest.(check (option string)) "file_path set" (Some "saved.txt") st2.file_path;
  Alcotest.(check string) "message" "Saved." st2.message

(* Test 10 - WriteError -> message set, modified unchanged *)
let test_write_error () =
  let st = { initial_state with modified = true } in
  let st2 = upd st (WriteError "permission denied") in
  Alcotest.(check string) "message set" "permission denied" st2.message;
  Alcotest.(check bool) "modified unchanged" true st2.modified

(* Test 11 - TryQuit when modified -> ConfirmQuit mode *)
let test_try_quit_modified () =
  let st = { initial_state with modified = true } in
  let st2 = upd st TryQuit in
  Alcotest.(check bool) "mode = ConfirmQuit" true (st2.mode = ConfirmQuit);
  Alcotest.(check bool) "not quit yet" false st2.quit

(* Test 12 - TryQuit when clean -> quit; ConfirmQuit y -> quit; ConfirmQuit n -> Normal *)
let test_try_quit_clean () =
  let st2 = upd initial_state TryQuit in
  Alcotest.(check bool) "clean quit" true st2.quit

let test_confirm_quit () =
  let st = { initial_state with mode = ConfirmQuit } in
  let st_y = upd st Quit in
  Alcotest.(check bool) "y quits" true st_y.quit;
  let st_n = upd st MinibufCancel in
  Alcotest.(check bool) "n cancels" false st_n.quit;
  Alcotest.(check bool) "n -> Normal" true (st_n.mode = Normal)

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
  ]
