let char_width c =
  max 0 (Uucp.Break.tty_width_hint c)

let string_display_width s =
  let decoder = Uutf.decoder (`String s) in
  let rec loop acc =
    match Uutf.decode decoder with
    | `Uchar c -> loop (acc + char_width c)
    | `End -> acc
    | `Malformed _ -> loop (acc + 1)
    | `Await -> acc
  in
  loop 0

let display_col_of_byte_col s ~byte_col =
  let decoder = Uutf.decoder (`String s) in
  let rec loop acc =
    let pos = Uutf.decoder_byte_count decoder in
    if pos >= byte_col then acc
    else
      match Uutf.decode decoder with
      | `Uchar c -> loop (acc + char_width c)
      | `End -> acc
      | `Malformed _ -> loop (acc + 1)
      | `Await -> acc
  in
  loop 0
