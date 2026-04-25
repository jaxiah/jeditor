open Jeditor_terminal

let draw_grid term cols rows =
  Terminal.clear_screen term;
  for r = 0 to rows - 1 do
    Terminal.move_to term ~row:r ~col:0;
    for c = 0 to cols - 1 do
      let color =
        if r mod 2 = 0 then Attr.Rgb (255, 0, 0)
        else Attr.Rgb (0, 255, 0)
      in
      let attr = { Attr.default with bg = color; fg = Attr.White } in
      let char = if c mod 2 = 0 then '#' else ' ' in
      Terminal.write_char term (Uchar.of_char char) attr
    done
  done;
  Terminal.move_to term ~row:(rows / 2) ~col:(cols / 2 - 10);
  Terminal.write_string term " Press any key (q to quit) " { Attr.default with fg = Attr.Black; bg = Attr.White };
  Terminal.flush term

let rec loop input term =
  match Input.next_key input with
  | Some (Key.Char c) when Uchar.to_char c = 'q' -> ()
  | Some key ->
      let _cols, rows = Terminal.size term in
      Terminal.move_to term ~row:(rows - 1) ~col:0;
      Terminal.clear_line term;
      let msg = Format.asprintf "Key pressed: %a" Key.pp key in
      Terminal.write_string term msg { Attr.default with fg = Attr.Yellow };
      Terminal.flush term;
      loop input term
  | None -> ()

let () =
  match Input.create () with
  | Error err -> Printf.eprintf "Input init failed: %s\n" err
  | Ok input ->
      match Terminal.create () with
      | Error err -> Printf.eprintf "Terminal init failed: %s\n" err
      | Ok term ->
          Terminal.hide_cursor term;
          let cols, rows = Terminal.size term in
          draw_grid term cols rows;
          loop input term;
          Terminal.show_cursor term;
          Terminal.close term;
          Input.close input
