open Jeditor_terminal

let pp_key_opt fmt = function
  | None -> Format.fprintf fmt "None"
  | Some key -> Format.fprintf fmt "Some %a" Key.pp key

let key_opt =
  Alcotest.testable pp_key_opt ( = )

let test_modifier_only_alt_is_ignored () =
  Alcotest.check key_opt "left alt down" None
    (Platform.key_of_win32_event (0, 0x12, 0x0002))

let test_alt_letter_from_virtual_key () =
  Alcotest.check key_opt "alt-g" (Some (Key.Meta (Uchar.of_char 'g')))
    (Platform.key_of_win32_event (0, 0x47, 0x0002))

let test_del_char_code_is_backspace () =
  Alcotest.check key_opt "DEL char code" (Some Key.Backspace)
    (Platform.key_of_win32_event (0x7F, 0, 0))

let () =
  Alcotest.run "Win32 input"
    [ ( "key event mapping"
      , [ Alcotest.test_case "modifier_only_alt_is_ignored" `Quick
            test_modifier_only_alt_is_ignored
        ; Alcotest.test_case "alt_letter_from_virtual_key" `Quick
            test_alt_letter_from_virtual_key
        ; Alcotest.test_case "del_char_code_is_backspace" `Quick
            test_del_char_code_is_backspace
        ] )
    ]
