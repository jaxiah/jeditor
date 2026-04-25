let test_roundtrip name str_repr expected_ctor =
  let key_opt = Jeditor_terminal.Key.of_string str_repr in
  Alcotest.(check (option bool)) ("parsed " ^ name) (Some true) (Option.map (fun _ -> true) key_opt);
  let key = Option.get key_opt in
  Alcotest.(check bool) ("correct ctor for " ^ name) true (key = expected_ctor);
  let formatted = Format.asprintf "%a" Jeditor_terminal.Key.pp key in
  Alcotest.(check string) ("formats back to " ^ str_repr) str_repr formatted

let () =
  Alcotest.run "Key"
    [ ( "roundtrip"
      , [ Alcotest.test_case "Ctrl key" `Quick (fun () -> test_roundtrip "Ctrl key" "C-x" (Jeditor_terminal.Key.Ctrl 'x'))
        ; Alcotest.test_case "Char key" `Quick (fun () -> test_roundtrip "Char key" "a" (Jeditor_terminal.Key.Char (Uchar.of_char 'a')))
        ; Alcotest.test_case "Meta key" `Quick (fun () -> test_roundtrip "Meta key" "M-x" (Jeditor_terminal.Key.Meta (Uchar.of_char 'x')))
        ; Alcotest.test_case "Ctrl_meta key" `Quick (fun () -> test_roundtrip "Ctrl_meta key" "C-M-x" (Jeditor_terminal.Key.Ctrl_meta 'x'))
        ; Alcotest.test_case "Arrow Up" `Quick (fun () -> test_roundtrip "Arrow Up" "<up>" (Jeditor_terminal.Key.Arrow `Up))
        ; Alcotest.test_case "Arrow Down" `Quick (fun () -> test_roundtrip "Arrow Down" "<down>" (Jeditor_terminal.Key.Arrow `Down))
        ; Alcotest.test_case "Function F5" `Quick (fun () -> test_roundtrip "Function F5" "<f5>" (Jeditor_terminal.Key.Function 5))
        ; Alcotest.test_case "Backspace" `Quick (fun () -> test_roundtrip "Backspace" "<backspace>" Jeditor_terminal.Key.Backspace)
        ; Alcotest.test_case "Enter" `Quick (fun () -> test_roundtrip "Enter" "<enter>" Jeditor_terminal.Key.Enter)
        ; Alcotest.test_case "Escape" `Quick (fun () -> test_roundtrip "Escape" "<esc>" Jeditor_terminal.Key.Escape)
        ] ) ]
