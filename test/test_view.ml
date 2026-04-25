open Jeditor_core

let test_gutter_width () =
  let check count expected =
    Alcotest.(check int) (Printf.sprintf "gutter for %d lines" count)
      expected (View.gutter_width ~line_count:count)
  in
  check 1 2;
  check 9 2;
  check 10 3;
  check 99 3;
  check 100 4;
  check 999 4;
  check 1000 5

let test_status_text () =
  let check ~file_path ~modified ~line ~col ~count ~cols expected =
    Alcotest.(check string) (Printf.sprintf "status bar width %d" cols)
      expected (View.status_text ~file_path ~modified ~cursor_line:line ~cursor_display_col:col ~line_count:count ~cols)
  in
  (* 1. Basic layout *)
  check ~file_path:None ~modified:false ~line:0 ~col:0 ~count:1 ~cols:40
    "[No Name]                       1:1  L 1";
  
  (* 2. Filename and modified indicator *)
  (* test.txt ** (12) + 6:11  L 100 (10) = 22. 40 - 22 = 18 spaces. *)
  check ~file_path:(Some "test.txt") ~modified:true ~line:5 ~col:10 ~count:100 ~cols:40
    "test.txt **                  6:11  L 100";
    
  (* 3. Truncation when cols is small *)
  (* The design says: "the whole string is padded or truncated to exactly [cols] columns."
     If it's too small, we might truncate the left side or both.
     Helix/Emacs usually truncate the filename. *)
  let result = View.status_text ~file_path:(Some "very_long_filename_that_wont_fit.txt") ~modified:false ~cursor_line:0 ~cursor_display_col:0 ~line_count:1 ~cols:20 in
  Alcotest.(check int) "truncated to 20" 20 (String.length result)

let () =
  let open Alcotest in
  run "View" [
    "gutter", [
      test_case "gutter_width" `Quick test_gutter_width;
    ];
    "status", [
      test_case "status_text" `Quick test_status_text;
    ];
  ]
