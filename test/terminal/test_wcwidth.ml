open Jeditor_terminal

let test_char_width () =
  let check c expected =
    Alcotest.(check int) (Printf.sprintf "width of U+%04X" (Uchar.to_int c))
      expected (Wcwidth.char_width c)
  in
  check (Uchar.of_char 'a') 1;
  check (Uchar.of_int 0x4E2D) 2; (* 中 *)
  check (Uchar.of_int 0x0001) 0; (* Start of heading (control) *)
  check (Uchar.of_int 0x0300) 0  (* Combining grave accent *)

let test_display_col () =
  let check s byte_col expected =
    Alcotest.(check int) (Printf.sprintf "display col of %S at %d" s byte_col)
      expected (Wcwidth.display_col_of_byte_col s ~byte_col)
  in
  check "abc" 0 0;
  check "abc" 1 1;
  check "abc" 3 3;
  (* 你好 - each is 3 bytes, 2 columns *)
  check "你好" 0 0;
  check "你好" 3 2;
  check "你好" 6 4;
  (* Mixed: a你b好 *)
  check "a你b好" 0 0;
  check "a你b好" 1 1;
  check "a你b好" 4 3;
  check "a你b好" 5 4;
  check "a你b好" 8 6

let () =
  let open Alcotest in
  run "Wcwidth" [
    "width", [
      test_case "char_width" `Quick test_char_width;
      test_case "display_col_of_byte_col" `Quick test_display_col;
    ];
  ]
