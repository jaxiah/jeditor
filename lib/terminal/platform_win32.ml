external enable_vt : unit -> bool = "jeditor_enable_vt"
external disable_vt : unit -> unit = "jeditor_disable_vt"
external get_term_size : unit -> int * int = "jeditor_get_term_size"

module Input : Input_intf.S = struct
  type t = unit

  let create () =
    if enable_vt () then Ok ()
    else Error "Failed to enable virtual terminal processing"

  let next_key () =
    let buf = Bytes.create 1 in
    let rec read_char () =
      try
        let n = Unix.read Unix.stdin buf 0 1 in
        if n = 0 then None else Some (Bytes.get buf 0)
      with Unix.Unix_error (Unix.EINTR, _, _) -> read_char ()
    in
    Escape_parser.next_key read_char

  let close () = disable_vt ()
end

module Terminal : Terminal_intf.S = struct
  type t = Buffer.t

  let create () = Ok (Buffer.create 4096)

  let size _ = get_term_size ()

  let move_to t ~row ~col =
    Printf.bprintf t "\x1b[%d;%dH" (row + 1) (col + 1)

  let hide_cursor t = Buffer.add_string t "\x1b[?25l"
  let show_cursor t = Buffer.add_string t "\x1b[?25h"

  let color_to_ansi is_bg c =
    let prefix = if is_bg then "4" else "3" in
    let prefix9 = if is_bg then "10" else "9" in
    match c with
    | Attr.Default -> if is_bg then "49" else "39"
    | Attr.Black -> prefix ^ "0"
    | Attr.Red -> prefix ^ "1"
    | Attr.Green -> prefix ^ "2"
    | Attr.Yellow -> prefix ^ "3"
    | Attr.Blue -> prefix ^ "4"
    | Attr.Magenta -> prefix ^ "5"
    | Attr.Cyan -> prefix ^ "6"
    | Attr.White -> prefix ^ "7"
    | Attr.Bright `Black -> prefix9 ^ "0"
    | Attr.Bright `Red -> prefix9 ^ "1"
    | Attr.Bright `Green -> prefix9 ^ "2"
    | Attr.Bright `Yellow -> prefix9 ^ "3"
    | Attr.Bright `Blue -> prefix9 ^ "4"
    | Attr.Bright `Magenta -> prefix9 ^ "5"
    | Attr.Bright `Cyan -> prefix9 ^ "6"
    | Attr.Bright `White -> prefix9 ^ "7"
    | Attr.Rgb (r, g, b) -> Printf.sprintf "%s8;2;%d;%d;%d" prefix r g b

  let apply_attr t attr =
    let { Attr.fg; bg; bold; italic; reverse; underline } = attr in
    let acc = [] in
    let acc = if bold then "1" :: acc else acc in
    let acc = if italic then "3" :: acc else acc in
    let acc = if underline then "4" :: acc else acc in
    let acc = if reverse then "7" :: acc else acc in
    let acc = color_to_ansi false fg :: acc in
    let acc = color_to_ansi true bg :: acc in
    Printf.bprintf t "\x1b[0;%sm" (String.concat ";" (List.rev acc))

  let write_char t c attr =
    apply_attr t attr;
    let buf = Buffer.create 4 in
    Uutf.Buffer.add_utf_8 buf c;
    Buffer.add_string t (Buffer.contents buf)

  let write_string t s attr =
    apply_attr t attr;
    Buffer.add_string t s

  let clear_line t = Buffer.add_string t "\x1b[K"
  let clear_screen t = Buffer.add_string t "\x1b[2J\x1b[H"

  let flush t =
    output_string stdout (Buffer.contents t);
    flush_all ();
    Buffer.clear t

  let close t =
    show_cursor t;
    flush t
end
