let test_create () =
  let c = Jeditor_core.Cursor.create 5 in
  let lst = Jeditor_core.Cursor.to_list c in
  Alcotest.(check int) "length is 1" 1 (List.length lst);
  let r = List.hd lst in
  Alcotest.(check int) "head is 5" 5 r.Jeditor_core.Cursor.head;
  Alcotest.(check int) "anchor is 5" 5 r.Jeditor_core.Cursor.anchor

let test_apply_edit_before () =
  let c = Jeditor_core.Cursor.create 5 in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:10 ~deleted:0 ~inserted:5 c in
  let r = List.hd (Jeditor_core.Cursor.to_list c2) in
  Alcotest.(check int) "unchanged" 5 r.Jeditor_core.Cursor.head

let test_apply_edit_after () =
  let c = Jeditor_core.Cursor.create 15 in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:10 ~deleted:0 ~inserted:5 c in
  let r = List.hd (Jeditor_core.Cursor.to_list c2) in
  Alcotest.(check int) "shifted" 20 r.Jeditor_core.Cursor.head

let test_apply_edit_at () =
  let c = Jeditor_core.Cursor.create 10 in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:10 ~deleted:0 ~inserted:5 c in
  let r = List.hd (Jeditor_core.Cursor.to_list c2) in
  Alcotest.(check int) "shifted" 15 r.Jeditor_core.Cursor.head

let test_apply_edit_inside_deleted () =
  let c = Jeditor_core.Cursor.create 12 in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:10 ~deleted:5 ~inserted:0 c in
  let r = List.hd (Jeditor_core.Cursor.to_list c2) in
  Alcotest.(check int) "clamped to edit start" 10 r.Jeditor_core.Cursor.head

let test_apply_edit_after_deleted () =
  let c = Jeditor_core.Cursor.create 15 in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:10 ~deleted:5 ~inserted:0 c in
  let r = List.hd (Jeditor_core.Cursor.to_list c2) in
  Alcotest.(check int) "shifted by -5" 10 r.Jeditor_core.Cursor.head

let test_apply_edit_selection () =
  let c = Jeditor_core.Cursor.create_selection ~head:15 ~anchor:10 in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:12 ~deleted:0 ~inserted:5 c in
  let r = List.hd (Jeditor_core.Cursor.to_list c2) in
  Alcotest.(check int) "head shifted" 20 r.Jeditor_core.Cursor.head;
  Alcotest.(check int) "anchor unchanged" 10 r.Jeditor_core.Cursor.anchor

let test_of_list_sorts () =
  let lst = [
    { Jeditor_core.Cursor.head = 20; anchor = 20 };
    { head = 10; anchor = 10 }
  ] in
  let c = Jeditor_core.Cursor.of_list lst in
  let lst_out = Jeditor_core.Cursor.to_list c in
  Alcotest.(check int) "length is 2" 2 (List.length lst_out);
  Alcotest.(check int) "first is 10" 10 (List.nth lst_out 0).head;
  Alcotest.(check int) "second is 20" 20 (List.nth lst_out 1).head

let test_of_list_merges () =
  let lst = [
    { Jeditor_core.Cursor.head = 15; anchor = 10 };
    { head = 20; anchor = 12 }
  ] in
  let c = Jeditor_core.Cursor.of_list lst in
  let lst_out = Jeditor_core.Cursor.to_list c in
  Alcotest.(check int) "length is 1" 1 (List.length lst_out);
  Alcotest.(check int) "head is 20" 20 (List.hd lst_out).head;
  Alcotest.(check int) "anchor is 10" 10 (List.hd lst_out).anchor

let test_multi_cursor_edit () =
  let lst = [
    { Jeditor_core.Cursor.head = 5; anchor = 5 };
    { head = 15; anchor = 15 }
  ] in
  let c = Jeditor_core.Cursor.of_list lst in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:10 ~deleted:0 ~inserted:5 c in
  let lst_out = Jeditor_core.Cursor.to_list c2 in
  Alcotest.(check int) "first is 5" 5 (List.nth lst_out 0).head;
  Alcotest.(check int) "second is 20" 20 (List.nth lst_out 1).head

let test_collision_merge () =
  let lst = [
    { Jeditor_core.Cursor.head = 5; anchor = 5 };
    { head = 10; anchor = 10 }
  ] in
  let c = Jeditor_core.Cursor.of_list lst in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:5 ~deleted:5 ~inserted:0 c in
  let lst_out = Jeditor_core.Cursor.to_list c2 in
  Alcotest.(check int) "length is 1" 1 (List.length lst_out);
  Alcotest.(check int) "merged at 5" 5 (List.hd lst_out).head

let test_multiple_cursors_overlap_edit () =
  let lst = [
    { Jeditor_core.Cursor.head = 5; anchor = 5 };
    { head = 10; anchor = 10 };
    { head = 15; anchor = 15 }
  ] in
  let c = Jeditor_core.Cursor.of_list lst in
  let c2 = Jeditor_core.Cursor.apply_edit ~offset:8 ~deleted:8 ~inserted:0 c in
  let lst_out = Jeditor_core.Cursor.to_list c2 in
  Alcotest.(check int) "length is 2" 2 (List.length lst_out);
  Alcotest.(check int) "first is 5" 5 (List.nth lst_out 0).head;
  Alcotest.(check int) "second is 8" 8 (List.nth lst_out 1).head

let () =
  let open Alcotest in
  run "Cursor" [
    "create", [
      test_case "create and to_list" `Quick test_create;
      test_case "of_list sorts" `Quick test_of_list_sorts;
      test_case "of_list merges" `Quick test_of_list_merges;
    ];
    "apply_edit", [
      test_case "before edit point" `Quick test_apply_edit_before;
      test_case "after edit point" `Quick test_apply_edit_after;
      test_case "at edit point" `Quick test_apply_edit_at;
      test_case "inside deleted" `Quick test_apply_edit_inside_deleted;
      test_case "after deleted" `Quick test_apply_edit_after_deleted;
      test_case "selection edit" `Quick test_apply_edit_selection;
      test_case "multi-cursor edit" `Quick test_multi_cursor_edit;
      test_case "collision and merge" `Quick test_collision_merge;
      test_case "multiple overlap edit" `Quick test_multiple_cursors_overlap_edit;
    ]
  ]
