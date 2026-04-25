open Jeditor_buffer

let test_empty_buffer () =
  let b = Buffer.empty in
  Alcotest.(check int) "empty buffer length is 0" 0 (Buffer.length b);
  Alcotest.(check int) "empty buffer has 1 line" 1 (Buffer.line_count b);
  Alcotest.(check string) "empty buffer string is empty" "" (Buffer.to_string b)

let test_of_to_string_single_line () =
  let text = "hello world" in
  let b = Buffer.of_string text in
  Alcotest.(check string) "round-trip single line" text (Buffer.to_string b);
  Alcotest.(check int) "length is correct" (String.length text) (Buffer.length b);
  Alcotest.(check int) "line count is 1" 1 (Buffer.line_count b)

let test_of_to_string_multi_line () =
  let text = "hello\nworld\n!" in
  let b = Buffer.of_string text in
  Alcotest.(check string) "round-trip multi line" text (Buffer.to_string b);
  Alcotest.(check int) "length is correct" (String.length text) (Buffer.length b);
  Alcotest.(check int) "line count is 3" 3 (Buffer.line_count b)

let test_insert_single_line () =
  let b = Buffer.of_string "world" in
  let b = Buffer.insert ~offset:0 "hello " b in
  Alcotest.(check string) "insert at start" "hello world" (Buffer.to_string b);
  let b = Buffer.insert ~offset:11 "!" b in
  Alcotest.(check string) "insert at end" "hello world!" (Buffer.to_string b);
  let b = Buffer.insert ~offset:5 "," b in
  Alcotest.(check string) "insert in middle" "hello, world!" (Buffer.to_string b)

let test_insert_multi_line () =
  let b = Buffer.of_string "helloworld" in
  let b = Buffer.insert ~offset:5 "\n" b in
  Alcotest.(check string) "insert newline" "hello\nworld" (Buffer.to_string b);
  Alcotest.(check int) "line count increased" 2 (Buffer.line_count b)

let test_delete_multi_line () =
  let b = Buffer.of_string "hello\nworld\n!" in
  let b = Buffer.delete ~offset:5 ~length:6 b in
  Alcotest.(check string) "delete spanning lines" "hello\n!" (Buffer.to_string b);
  Alcotest.(check int) "line count decreased" 2 (Buffer.line_count b)

let test_coordinate_mapping () =
  let text = "abc\ndefg\nh" in
  let b = Buffer.of_string text in
  (* line 0: abc (length 3), offset: 0 *)
  (* line 1: defg (length 4), offset: 4 *)
  (* line 2: h (length 1), offset: 9 *)
  Alcotest.(check int) "line 0 to offset" 0 (Buffer.line_to_offset ~line:0 b);
  Alcotest.(check int) "line 1 to offset" 4 (Buffer.line_to_offset ~line:1 b);
  Alcotest.(check int) "line 2 to offset" 9 (Buffer.line_to_offset ~line:2 b);

  let check_offset offset expected_line expected_col =
    let (l, c) = Buffer.offset_to_line_col ~offset b in
    Alcotest.(check int) (Printf.sprintf "offset %d line" offset) expected_line l;
    Alcotest.(check int) (Printf.sprintf "offset %d col" offset) expected_col c
  in
  check_offset 0 0 0;
  check_offset 2 0 2;
  check_offset 3 0 3; (* before newline on line 0 *)
  check_offset 4 1 0; (* start of line 1 *)
  check_offset 6 1 2;
  check_offset 8 1 4; (* before newline on line 1 *)
  check_offset 9 2 0; (* start of line 2 *)
  check_offset 10 2 1 (* end of file *)

let test_cjk () =
  let text = "你好\n世界" in
  let b = Buffer.of_string text in
  Alcotest.(check int) "length is in bytes" 13 (Buffer.length b); (* 2*3 + 1 + 2*3 *)
  Alcotest.(check int) "line 1 offset" 7 (Buffer.line_to_offset ~line:1 b);
  let (l, c) = Buffer.offset_to_line_col ~offset:7 b in
  Alcotest.(check int) "CJK offset 7 line" 1 l;
  Alcotest.(check int) "CJK offset 7 col" 0 c;
  (* slice first character *)
  Alcotest.(check string) "slice CJK char" "你" (Buffer.slice ~start:0 ~length:3 b)

let test_multiple_edits () =
  let text = "123\n456" in
  let b = Buffer.of_string text in
  let b = Buffer.insert ~offset:3 "0" b in (* 1230\n456 *)
  let b = Buffer.delete ~offset:0 ~length:2 b in (* 30\n456 *)
  let b = Buffer.insert ~offset:3 "A\nB" b in (* 30\nA\nB456 *)
  Alcotest.(check string) "round-trip multiple edits" "30\nA\nB456" (Buffer.to_string b)

let tests = [
  "Empty buffer properties", `Quick, test_empty_buffer;
  "of/to string single line", `Quick, test_of_to_string_single_line;
  "of/to string multi line", `Quick, test_of_to_string_multi_line;
  "insert single line", `Quick, test_insert_single_line;
  "insert multi line", `Quick, test_insert_multi_line;
  "delete multi line", `Quick, test_delete_multi_line;
  "coordinate mapping", `Quick, test_coordinate_mapping;
  "CJK support", `Quick, test_cjk;
  "multiple edits", `Quick, test_multiple_edits;
]

let () =
  Alcotest.run "Buffer tests" [
    "Buffer", tests;
  ]
