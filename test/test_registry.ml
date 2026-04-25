open Jeditor_core

let check_opt = Alcotest.(check (option int))
let check_list = Alcotest.(check (list string))

(* Use int as handler type for pure Registry tests — no App dependency *)

let test_lookup_hit () =
  let r = Registry.(empty |> register "foo" 42) in
  check_opt "found" (Some 42) (Registry.lookup "foo" r)

let test_lookup_miss () =
  let r = Registry.(empty |> register "foo" 42) in
  check_opt "miss" None (Registry.lookup "bar" r)

let test_lookup_overwrite () =
  let r = Registry.(empty |> register "foo" 1 |> register "foo" 2) in
  check_opt "overwritten" (Some 2) (Registry.lookup "foo" r)

let test_names_sorted () =
  let r = Registry.(empty |> register "zebra" 1 |> register "apple" 2 |> register "mango" 3) in
  check_list "sorted" ["apple"; "mango"; "zebra"] (Registry.names r)

let test_names_empty () =
  check_list "empty" [] (Registry.names Registry.empty)

let test_complete_empty_prefix () =
  let r = Registry.(empty |> register "foo" 1 |> register "bar" 2 |> register "baz" 3) in
  check_list "all" ["bar"; "baz"; "foo"] (Registry.complete ~prefix:"" r)

let test_complete_prefix_narrows () =
  let r = Registry.(empty |> register "move-forward-char" 1
                         |> register "move-backward-char" 2
                         |> register "kill-line" 3) in
  check_list "move-" ["move-backward-char"; "move-forward-char"]
    (Registry.complete ~prefix:"move" r)

let test_complete_no_match () =
  let r = Registry.(empty |> register "foo" 1) in
  check_list "no match" [] (Registry.complete ~prefix:"xyz" r)

let test_complete_exact_match () =
  let r = Registry.(empty |> register "foo" 1 |> register "foobar" 2) in
  check_list "exact prefix" ["foo"; "foobar"] (Registry.complete ~prefix:"foo" r)

let () =
  Alcotest.run "Registry" [
    "lookup", [
      Alcotest.test_case "hit"       `Quick test_lookup_hit;
      Alcotest.test_case "miss"      `Quick test_lookup_miss;
      Alcotest.test_case "overwrite" `Quick test_lookup_overwrite;
    ];
    "names", [
      Alcotest.test_case "sorted" `Quick test_names_sorted;
      Alcotest.test_case "empty"  `Quick test_names_empty;
    ];
    "complete", [
      Alcotest.test_case "empty_prefix"   `Quick test_complete_empty_prefix;
      Alcotest.test_case "prefix_narrows" `Quick test_complete_prefix_narrows;
      Alcotest.test_case "no_match"       `Quick test_complete_no_match;
      Alcotest.test_case "exact_prefix"   `Quick test_complete_exact_match;
    ];
  ]
