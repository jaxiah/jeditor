open Jeditor_terminal

let cell ch = { Diff_renderer.text = String.make 1 ch; attr = Attr.default }
let cursor_cell ch = { Diff_renderer.text = String.make 1 ch; attr = { Attr.default with reverse = true } }

let contains haystack needle =
  let hlen = String.length haystack in
  let nlen = String.length needle in
  let rec loop i =
    if i + nlen > hlen then false
    else if String.sub haystack i nlen = needle then true
    else loop (i + 1)
  in
  nlen = 0 || loop 0

let test_static_second_render_writes_zero_bytes () =
  let frame = Diff_renderer.blank ~cols:2 ~rows:1 |> Diff_renderer.set ~row:0 ~col:0 (cell 'a') in
  let first, state = Diff_renderer.render Diff_renderer.empty_state frame in
  let second, _ = Diff_renderer.render state frame in
  Alcotest.(check bool) "first writes" true (String.length first > 0);
  Alcotest.(check string) "second static render empty" "" second

let test_single_cell_change_updates_one_cell () =
  let frame1 = Diff_renderer.blank ~cols:2 ~rows:1 |> Diff_renderer.set ~row:0 ~col:0 (cell 'a') in
  let _, state = Diff_renderer.render Diff_renderer.empty_state frame1 in
  let frame2 = Diff_renderer.set ~row:0 ~col:1 (cell 'b') frame1 in
  let out, _ = Diff_renderer.render state frame2 in
  Alcotest.(check bool) "moves to changed cell" true (contains out "\x1b[1;2H");
  Alcotest.(check bool) "does not redraw first cell" false (contains out "\x1b[1;1H")

let test_cursor_move_updates_previous_and_new_cells () =
  let frame1 =
    Diff_renderer.blank ~cols:2 ~rows:1
    |> Diff_renderer.set ~row:0 ~col:0 (cursor_cell 'a')
    |> Diff_renderer.set ~row:0 ~col:1 (cell 'b')
  in
  let _, state = Diff_renderer.render Diff_renderer.empty_state frame1 in
  let frame2 =
    Diff_renderer.blank ~cols:2 ~rows:1
    |> Diff_renderer.set ~row:0 ~col:0 (cell 'a')
    |> Diff_renderer.set ~row:0 ~col:1 (cursor_cell 'b')
  in
  let out, _ = Diff_renderer.render state frame2 in
  Alcotest.(check bool) "old cursor cell" true (contains out "\x1b[1;1H");
  Alcotest.(check bool) "new cursor cell" true (contains out "\x1b[1;2H")

let test_force_redraw_resyncs () =
  let frame = Diff_renderer.blank ~cols:1 ~rows:1 |> Diff_renderer.set ~row:0 ~col:0 (cell 'x') in
  let _, state = Diff_renderer.render Diff_renderer.empty_state frame in
  let forced, state = Diff_renderer.render ~force:true state frame in
  let stable, _ = Diff_renderer.render state frame in
  Alcotest.(check bool) "clear screen" true (contains forced "\x1b[2J");
  Alcotest.(check string) "resynced" "" stable

let test_resize_invalidates_previous_frame () =
  let small = Diff_renderer.blank ~cols:1 ~rows:1 in
  let _, state = Diff_renderer.render Diff_renderer.empty_state small in
  let large = Diff_renderer.blank ~cols:2 ~rows:1 in
  let out, _ = Diff_renderer.render state large in
  Alcotest.(check bool) "resize full redraw" true (contains out "\x1b[2J")

let () =
  Alcotest.run "Diff_renderer" [
    "diff", [
      Alcotest.test_case "static_second_render_writes_zero_bytes" `Quick test_static_second_render_writes_zero_bytes;
      Alcotest.test_case "single_cell_change_updates_one_cell" `Quick test_single_cell_change_updates_one_cell;
      Alcotest.test_case "cursor_move_updates_previous_and_new_cells" `Quick test_cursor_move_updates_previous_and_new_cells;
      Alcotest.test_case "force_redraw_resyncs" `Quick test_force_redraw_resyncs;
      Alcotest.test_case "resize_invalidates_previous_frame" `Quick test_resize_invalidates_previous_frame;
    ];
  ]
