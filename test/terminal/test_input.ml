let check_parse name chars expected =
  let input = ref chars in
  let read_char () =
    match !input with
    | [] -> None
    | c :: cs -> input := cs; Some c
  in
  let k = Jeditor_terminal.Escape_parser.next_key read_char in
  Alcotest.(check (option string)) name
    (Some (Format.asprintf "%a" Jeditor_terminal.Key.pp expected))
    (Option.map (Format.asprintf "%a" Jeditor_terminal.Key.pp) k)

let test_char () =
  check_parse "char 'a'" ['a'] (Jeditor_terminal.Key.Char (Uchar.of_char 'a'))

let test_arrows () =
  check_parse "arrow up" ['\x1b'; '['; 'A'] (Jeditor_terminal.Key.Arrow `Up);
  check_parse "arrow down" ['\x1b'; '['; 'B'] (Jeditor_terminal.Key.Arrow `Down);
  check_parse "arrow right" ['\x1b'; '['; 'C'] (Jeditor_terminal.Key.Arrow `Right);
  check_parse "arrow left" ['\x1b'; '['; 'D'] (Jeditor_terminal.Key.Arrow `Left)

let test_escape () =
  check_parse "escape" ['\x1b'] Jeditor_terminal.Key.Escape

let test_controls () =
  check_parse "enter" ['\r'] Jeditor_terminal.Key.Enter;
  check_parse "tab" ['\t'] Jeditor_terminal.Key.Tab;
  check_parse "backspace" ['\x7f'] Jeditor_terminal.Key.Backspace;
  check_parse "ctrl-a" ['\x01'] (Jeditor_terminal.Key.Ctrl 'a')

let test_extended () =
  check_parse "delete" ['\x1b'; '['; '3'; '~'] Jeditor_terminal.Key.Delete;
  check_parse "home" ['\x1b'; '['; 'H'] Jeditor_terminal.Key.Home;
  check_parse "end" ['\x1b'; '['; 'F'] Jeditor_terminal.Key.End;
  check_parse "page up" ['\x1b'; '['; '5'; '~'] Jeditor_terminal.Key.Page_up;
  check_parse "page down" ['\x1b'; '['; '6'; '~'] Jeditor_terminal.Key.Page_down

(* UTF-8 multi-byte: "中" = 0xE4 0xB8 0xAD, "é" = 0xC3 0xA9, "𝄞" = 0xF0 0x9D 0x84 0x9E *)
let test_utf8 () =
  check_parse "CJK 3-byte" ['\xE4'; '\xB8'; '\xAD']
    (Jeditor_terminal.Key.Char (Uchar.of_int 0x4E2D));
  check_parse "Latin-ext 2-byte" ['\xC3'; '\xA9']
    (Jeditor_terminal.Key.Char (Uchar.of_int 0x00E9));
  check_parse "4-byte codepoint" ['\xF0'; '\x9D'; '\x84'; '\x9E']
    (Jeditor_terminal.Key.Char (Uchar.of_int 0x1D11E))

let () =
  Alcotest.run "Input"
    [ ( "Sequence Parsing"
      , [ Alcotest.test_case "Single char 'a'" `Quick test_char
        ; Alcotest.test_case "Arrows" `Quick test_arrows
        ; Alcotest.test_case "Escape" `Quick test_escape
        ; Alcotest.test_case "Controls" `Quick test_controls
        ; Alcotest.test_case "Extended" `Quick test_extended
        ; Alcotest.test_case "UTF-8 multi-byte" `Quick test_utf8
        ] ) ]

