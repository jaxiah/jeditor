open Jeditor_core
open Jeditor_terminal

(* ── Cycle 1: exact single-key match ─────────────────────────────────── *)
let test_exact_match () =
  let km = Keymap.bind [Key.Ctrl 'f'] "move-forward-char" Keymap.empty in
  Alcotest.(check string) "C-f matched"
    "move-forward-char"
    (match Keymap.lookup [km] [Key.Ctrl 'f'] with
     | Keymap.Matched s -> s
     | _ -> "WRONG")

(* ── Cycle 2: first key of prefix returns Pending ────────────────────── *)
let test_prefix_pending () =
  let km = Keymap.bind [Key.Ctrl 'x'; Key.Ctrl 's'] "save" Keymap.empty in
  Alcotest.(check bool) "C-x alone is Pending"
    true
    (Keymap.lookup [km] [Key.Ctrl 'x'] = Keymap.Pending)

(* ── Cycle 3: two-key sequence returns Matched ───────────────────────── *)
let test_two_key_sequence () =
  let km = Keymap.bind [Key.Ctrl 'x'; Key.Ctrl 's'] "save" Keymap.empty in
  Alcotest.(check string) "C-x C-s matched"
    "save"
    (match Keymap.lookup [km] [Key.Ctrl 'x'; Key.Ctrl 's'] with
     | Keymap.Matched s -> s
     | _ -> "WRONG")

(* ── Cycle 4: unbound returns Unbound ────────────────────────────────── *)
let test_unbound () =
  Alcotest.(check bool) "unbound key"
    true
    (Keymap.lookup [Keymap.empty] [Key.Ctrl 'z'] = Keymap.Unbound)

(* ── Cycle 5: higher-priority layer shadows lower ────────────────────── *)
let test_layer_shadow () =
  let layer1 = Keymap.bind [Key.Ctrl 'f'] "my-forward" Keymap.empty in
  let layer2 = Keymap.bind [Key.Ctrl 'f'] "move-forward-char" Keymap.empty in
  Alcotest.(check string) "layer1 shadows layer2"
    "my-forward"
    (match Keymap.lookup [layer1; layer2] [Key.Ctrl 'f'] with
     | Keymap.Matched s -> s
     | _ -> "WRONG")

(* ── Cycle 6: emacs_default spot-checks ─────────────────────────────── *)
let test_emacs_default () =
  let check key expected =
    match Keymap.lookup [Keymap.emacs_default] key with
    | Keymap.Matched s -> Alcotest.(check string) (String.concat " " (List.map (Format.asprintf "%a" Key.pp) key)) expected s
    | Keymap.Pending   -> Alcotest.fail "got Pending"
    | Keymap.Unbound   -> Alcotest.fail "got Unbound"
  in
  check [Key.Ctrl 'f']              "move-forward-char";
  check [Key.Ctrl 'n']              "move-next-line";
  check [Key.Ctrl 'k']              "kill-line";
  check [Key.Ctrl 'w']              "kill-region";
  check [Key.Ctrl 'y']              "yank";
  check [Key.Ctrl 's']              "isearch-forward";
  check [Key.Ctrl 'r']              "isearch-backward";
  check [Key.Ctrl 'x'; Key.Ctrl 's'] "save";
  check [Key.Ctrl 'x'; Key.Ctrl 'c'] "quit";
  check [Key.Ctrl 'x'; Key.Char (Uchar.of_char '2')] "split-window-below";
  check [Key.Ctrl 'x'; Key.Char (Uchar.of_char '3')] "split-window-right";
  check [Key.Meta (Uchar.of_char 'g'); Key.Char (Uchar.of_char 'g')] "goto-line";
  check [Key.Meta (Uchar.of_char 'g'); Key.Meta (Uchar.of_char 'g')] "goto-line"

let test_bare_ctrl_c_is_not_quit () =
  Alcotest.(check bool) "bare C-c is unbound"
    true
    (Keymap.lookup [Keymap.emacs_default] [Key.Ctrl 'c'] = Keymap.Unbound)

let () =
  let open Alcotest in
  run "Keymap" [
    "lookup", [
      test_case "exact_match"      `Quick test_exact_match;
      test_case "prefix_pending"   `Quick test_prefix_pending;
      test_case "two_key_sequence" `Quick test_two_key_sequence;
      test_case "unbound"          `Quick test_unbound;
      test_case "layer_shadow"     `Quick test_layer_shadow;
    ];
    "emacs_default", [
      test_case "spot_checks"      `Quick test_emacs_default;
      test_case "bare_ctrl_c_is_not_quit" `Quick test_bare_ctrl_c_is_not_quit;
    ];
  ]
