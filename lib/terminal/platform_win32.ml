external enable_vt : unit -> bool = "jeditor_enable_vt"
external disable_vt : unit -> unit = "jeditor_disable_vt"
external get_term_size : unit -> int * int = "jeditor_get_term_size"
external read_key_event : unit -> (int * int * int) option = "jeditor_read_key_event"

let right_alt_pressed = 0x0001
let left_alt_pressed = 0x0002
let right_ctrl_pressed = 0x0004
let left_ctrl_pressed = 0x0008

let has_flag flags flag = flags land flag <> 0

let key_of_control_code code =
  let base =
    if code >= 1 && code <= 26 then char_of_int (code + 96)
    else if code = 0 then '@'
    else char_of_int (code + 64)
  in
  Key.Ctrl base

let key_of_win32_event (char_code, virtual_key, control_state) =
  let alt =
    has_flag control_state right_alt_pressed
    || has_flag control_state left_alt_pressed
  in
  let ctrl =
    has_flag control_state right_ctrl_pressed
    || has_flag control_state left_ctrl_pressed
  in
  match virtual_key, char_code with
  | (0x10 | 0x11 | 0x12), 0 -> None
  | 0x25, _ -> Some (Key.Arrow `Left)
  | 0x26, _ -> Some (Key.Arrow `Up)
  | 0x27, _ -> Some (Key.Arrow `Right)
  | 0x28, _ -> Some (Key.Arrow `Down)
  | 0x21, _ -> Some Key.Page_up
  | 0x22, _ -> Some Key.Page_down
  | 0x24, _ -> Some Key.Home
  | 0x23, _ -> Some Key.End
  | 0x2E, _ -> Some Key.Delete
  | 0x1B, _ -> Some Key.Escape
  | 0x0D, _ when alt && ctrl -> Some (Key.Ctrl_meta 'm')
  | 0x0D, _ -> Some Key.Enter
  | 0x09, _ when alt && ctrl -> Some (Key.Ctrl_meta 'i')
  | 0x09, _ -> Some Key.Tab
  | 0x08, _ when alt && ctrl -> Some (Key.Ctrl_meta 'h')
  | 0x08, _ -> Some Key.Backspace
  | vk, _ when vk >= 0x70 && vk <= 0x7B -> Some (Key.Function (vk - 0x6F))
  | vk, 0 when alt && vk >= 0x41 && vk <= 0x5A ->
      Some (Key.Meta (Uchar.of_char (char_of_int (vk + 32))))
  | _, code when code >= 0 && code <= 31 && alt ->
      let key = key_of_control_code code in
      (match key with
       | Key.Ctrl c -> Some (Key.Ctrl_meta c)
       | _ -> None)
  | _, code when code >= 0 && code <= 31 -> Some (key_of_control_code code)
  | _, code when code > 0 && code <= 255 && alt && ctrl ->
      Some (Key.Ctrl_meta (Char.lowercase_ascii (char_of_int code)))
  | _, code when code > 0 && alt -> Some (Key.Meta (Uchar.of_int code))
  | _, code when code > 0 -> Some (Key.Char (Uchar.of_int code))
  | _ -> None

module Input : Input_intf.S = struct
  type t = { mutable pending_alt : bool }

  let create () =
    if enable_vt () then Ok { pending_alt = false }
    else Error "Failed to enable virtual terminal processing"

  let rec next_key input =
    match read_key_event () with
    | None -> None
    | Some ((char_code, virtual_key, control_state) as event) ->
        let is_alt_down =
          has_flag control_state right_alt_pressed
          || has_flag control_state left_alt_pressed
        in
        let effective_event =
          if input.pending_alt && not is_alt_down && char_code > 0 then
            (char_code, virtual_key, control_state lor left_alt_pressed)
          else event
        in
        input.pending_alt <- is_alt_down && virtual_key = 0x12 && char_code = 0;
        (match key_of_win32_event effective_event with
         | Some key -> Some key
         | None -> next_key input)

  let close _ = disable_vt ()
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
