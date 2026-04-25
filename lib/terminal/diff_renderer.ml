type cell = {
  text : string;
  attr : Attr.t;
}

type frame = {
  cols : int;
  rows : int;
  cells : cell array;
}

type state = frame option

let blank_cell = { text = " "; attr = Attr.default }

let blank ~cols ~rows =
  let cols = max 0 cols in
  let rows = max 0 rows in
  { cols; rows; cells = Array.make (cols * rows) blank_cell }

let index frame ~row ~col = (row * frame.cols) + col

let in_bounds frame ~row ~col =
  row >= 0 && row < frame.rows && col >= 0 && col < frame.cols

let set ~row ~col cell frame =
  if not (in_bounds frame ~row ~col) then frame
  else
    let cells = Array.copy frame.cells in
    cells.(index frame ~row ~col) <- cell;
    { frame with cells }

let get ~row ~col frame =
  if in_bounds frame ~row ~col then frame.cells.(index frame ~row ~col)
  else blank_cell

let dimensions frame = frame.cols, frame.rows
let empty_state = None

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

let ansi_attr attr =
  let { Attr.fg; bg; bold; italic; reverse; underline } = attr in
  let acc = [] in
  let acc = if bold then "1" :: acc else acc in
  let acc = if italic then "3" :: acc else acc in
  let acc = if underline then "4" :: acc else acc in
  let acc = if reverse then "7" :: acc else acc in
  let acc = color_to_ansi false fg :: acc in
  let acc = color_to_ansi true bg :: acc in
  "\x1b[0;" ^ String.concat ";" (List.rev acc) ^ "m"

let move_to ~row ~col =
  Printf.sprintf "\x1b[%d;%dH" (row + 1) (col + 1)

let emit_cell row col cell =
  move_to ~row ~col ^ ansi_attr cell.attr ^ cell.text

let same_dimensions a b = a.cols = b.cols && a.rows = b.rows

let render_full frame =
  let b = Buffer.create (frame.cols * frame.rows) in
  Buffer.add_string b "\x1b[2J\x1b[H";
  for row = 0 to frame.rows - 1 do
    for col = 0 to frame.cols - 1 do
      Buffer.add_string b (emit_cell row col (get ~row ~col frame))
    done
  done;
  Buffer.contents b

let render_diff prev frame =
  let b = Buffer.create 128 in
  for row = 0 to frame.rows - 1 do
    for col = 0 to frame.cols - 1 do
      let old_cell = get ~row ~col prev in
      let new_cell = get ~row ~col frame in
      if old_cell <> new_cell then
        Buffer.add_string b (emit_cell row col new_cell)
    done
  done;
  Buffer.contents b

let render ?(force=false) state frame =
  let output =
    match state with
    | None -> render_full frame
    | Some prev when force || not (same_dimensions prev frame) -> render_full frame
    | Some prev -> render_diff prev frame
  in
  output, Some frame
