open Jeditor_core

let check_int = Alcotest.(check int)
let check_bool = Alcotest.(check bool)

let test_single () =
  let f = Frame.single ~buffer_id:0 in
  check_int "one leaf" 1 (List.length (Frame.leaves f));
  check_int "focused id" (Frame.focused_window f).id f.focused

let test_split_horizontal () =
  let f = Frame.single ~buffer_id:0 |> Frame.split_focused Frame.Horizontal in
  let leaves = Frame.leaves f in
  check_int "two leaves" 2 (List.length leaves);
  check_bool "same buffer" true (List.for_all (fun w -> w.Frame.buffer_id = 0) leaves)

let test_nested_split () =
  let f =
    Frame.single ~buffer_id:0
    |> Frame.split_focused Frame.Horizontal
    |> Frame.split_focused Frame.Vertical
  in
  check_int "three leaves" 3 (List.length (Frame.leaves f))

let test_focus_next_cycles () =
  let f = Frame.single ~buffer_id:0 |> Frame.split_focused Frame.Horizontal in
  let first = f.focused in
  let f = Frame.focus_next f in
  check_bool "focus changed" true (f.focused <> first);
  let f = Frame.focus_next f in
  check_int "wrapped focus" first f.focused

let test_close_focused () =
  let f = Frame.single ~buffer_id:0 |> Frame.split_focused Frame.Horizontal in
  let f = Frame.close_focused f in
  check_int "one leaf after close" 1 (List.length (Frame.leaves f));
  let f = Frame.close_focused f in
  check_int "last close no-op" 1 (List.length (Frame.leaves f))

let test_close_others () =
  let f =
    Frame.single ~buffer_id:0
    |> Frame.split_focused Frame.Horizontal
    |> Frame.split_focused Frame.Vertical
    |> Frame.focus_next
  in
  let focused = f.focused in
  let f = Frame.close_others f in
  check_int "one leaf" 1 (List.length (Frame.leaves f));
  check_int "same focus" focused f.focused

let test_update_focused_scroll () =
  let f = Frame.single ~buffer_id:0 |> Frame.split_focused Frame.Horizontal in
  let focused = f.focused in
  let f = Frame.update_focused (fun w -> { w with Frame.scroll_top_line = 7 }) f in
  let leaves = Frame.leaves f in
  check_int "focused scroll" 7 (Frame.focused_window f).scroll_top_line;
  check_bool "other unchanged" true
    (List.exists (fun w -> w.Frame.id <> focused && w.scroll_top_line = 0) leaves)

let test_layouts () =
  let f = Frame.single ~buffer_id:0 |> Frame.split_focused Frame.Vertical in
  let layouts = Frame.layouts ~cols:80 ~rows:24 f in
  check_int "two layouts" 2 (List.length layouts);
  check_bool "positive rectangles" true
    (List.for_all (fun (_, r) -> r.Frame.width > 0 && r.height > 0) layouts)

let () =
  Alcotest.run "Frame" [
    "frame", [
      Alcotest.test_case "single" `Quick test_single;
      Alcotest.test_case "split_horizontal" `Quick test_split_horizontal;
      Alcotest.test_case "nested_split" `Quick test_nested_split;
      Alcotest.test_case "focus_next_cycles" `Quick test_focus_next_cycles;
      Alcotest.test_case "close_focused" `Quick test_close_focused;
      Alcotest.test_case "close_others" `Quick test_close_others;
      Alcotest.test_case "update_focused_scroll" `Quick test_update_focused_scroll;
      Alcotest.test_case "layouts" `Quick test_layouts;
    ];
  ]
