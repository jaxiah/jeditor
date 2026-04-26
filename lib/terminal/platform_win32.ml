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
  | 0x7FFE, _ -> Some Key.Scroll_up
  | 0x7FFF, _ -> Some Key.Scroll_down
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
  | _, 0x7F -> Some Key.Backspace
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

  (* Read the next VT char event (VK=0, char_code>0).
     VK-only events (navigation keys arriving alongside VT sequences) are
     silently skipped here — in practice, VT char events for a single key
     press all arrive atomically before the next key is pressed. *)
  let read_vt_char () =
    let rec loop () =
      match read_key_event () with
      | None -> None
      | Some (code, 0, _) when code > 0 -> Some (char_of_int code)
      | _ -> loop ()   (* skip VK-only or null events while parsing a sequence *)
    in
    loop ()

  (* Parse the rest of a CSI / ESC sequence after the initial ESC has been
     consumed.  Mirrors escape_parser.ml so that PageUp (\x1b[5~), F-keys,
     arrows, and Meta+letter sequences all map to the right Key.t values. *)
  let parse_after_esc () =
    match read_vt_char () with
    | None -> Key.Escape
    | Some '[' ->
        let rec read_params acc =
          match read_vt_char () with
          | None -> Key.Escape
          | Some c when c >= '0' && c <= '9' ->
              read_params (acc ^ String.make 1 c)
          | Some ';' ->
              (* Extended params (e.g. modifiers): consume rest and return Escape *)
              let rec consume () =
                match read_vt_char () with
                | None | Some 'M' | Some 'm' -> ()
                | Some c when c >= '@' && c <= '~' -> ignore c
                | _ -> consume ()
              in
              consume (); Key.Escape
          | Some '<' ->
              (* SGR mouse sequence \x1b[<Pb;Px;PyM: consume and discard *)
              let rec consume () =
                match read_vt_char () with
                | None | Some 'M' | Some 'm' -> ()
                | _ -> consume ()
              in
              consume (); Key.Escape
          | Some '~' ->
              (match acc with
               | "3"  -> Key.Delete
               | "5"  -> Key.Page_up
               | "6"  -> Key.Page_down
               | "11" -> Key.Function 1
               | "12" -> Key.Function 2
               | "13" -> Key.Function 3
               | "14" -> Key.Function 4
               | "15" -> Key.Function 5
               | "17" -> Key.Function 6
               | "18" -> Key.Function 7
               | "19" -> Key.Function 8
               | "20" -> Key.Function 9
               | "21" -> Key.Function 10
               | "23" -> Key.Function 11
               | "24" -> Key.Function 12
               | _    -> Key.Escape)
          | Some 'A' -> Key.Arrow `Up
          | Some 'B' -> Key.Arrow `Down
          | Some 'C' -> Key.Arrow `Right
          | Some 'D' -> Key.Arrow `Left
          | Some 'H' -> Key.Home
          | Some 'F' -> Key.End
          | Some _   -> Key.Escape
        in
        read_params ""
    | Some 'O' ->
        (match read_vt_char () with
         | Some 'P' -> Key.Function 1
         | Some 'Q' -> Key.Function 2
         | Some 'R' -> Key.Function 3
         | Some 'S' -> Key.Function 4
         | _        -> Key.Escape)
    | Some '\r' | Some '\n' -> Key.Ctrl_meta 'm'
    | Some '\t'             -> Key.Ctrl_meta 'i'
    | Some '\x7f'           -> Key.Ctrl_meta 'h'
    | Some '\x1f'           -> Key.Ctrl_meta '/'
    | Some c when c >= '\x00' && c <= '\x1f' ->
        let code = int_of_char c in
        let base =
          if code >= 1 && code <= 26 then char_of_int (code + 96)
          else if code = 0 then '@'
          else char_of_int (code + 64)
        in
        Key.Ctrl_meta base
    | Some c -> Key.Meta (Uchar.of_char c)

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
        (* ESC char event (char=27, VK=0): parse the full escape / CSI sequence.
           ENABLE_VIRTUAL_TERMINAL_INPUT delivers PageUp as \x1b[5~, Alt+letter
           as \x1b+letter, arrows as \x1b[A etc. — all via char events with VK=0.
           A single-char pending_esc flag is not enough; we need the full parser. *)
        (match key_of_win32_event effective_event with
         | Some (Key.Ctrl '[') -> Some (parse_after_esc ())
         | Some key            -> Some key
         | None                -> next_key input)

  let close _ = disable_vt ()
end

module Terminal : Terminal_intf.S = struct
  type t = Buffer.t

  let create () = Ok (Buffer.create 4096)

  let size _ = get_term_size ()

  let enter_alt_screen t = Buffer.add_string t "\x1b[?1049h"
  let leave_alt_screen t = Buffer.add_string t "\x1b[?1049l"

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

  let write_raw t s = Buffer.add_string t s

  let clear_line t = Buffer.add_string t "\x1b[K"
  let clear_screen t = Buffer.add_string t "\x1b[2J\x1b[H"

  let flush t =
    output_string stdout (Buffer.contents t);
    flush_all ();
    Buffer.clear t

  let close t =
    leave_alt_screen t;
    show_cursor t;
    flush t
end
