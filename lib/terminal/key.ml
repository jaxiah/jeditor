type t =
  | Char      of Uchar.t
  | Ctrl      of char
  | Meta      of Uchar.t
  | Ctrl_meta of char
  | Arrow     of [ `Up | `Down | `Left | `Right ]
  | Function  of int
  | Backspace
  | Delete
  | Enter
  | Tab
  | Escape
  | Page_up
  | Page_down
  | Home
  | End

let pp fmt t =
  match t with
  | Char c ->
      let c_int = Uchar.to_int c in
      if c_int >= 32 && c_int <= 126 then
        Format.fprintf fmt "%c" (char_of_int c_int)
      else
        Format.fprintf fmt "U+%04X" c_int
  | Ctrl c -> Format.fprintf fmt "C-%c" c
  | Meta c ->
      let c_int = Uchar.to_int c in
      if c_int >= 32 && c_int <= 126 then
        Format.fprintf fmt "M-%c" (char_of_int c_int)
      else
        Format.fprintf fmt "M-U+%04X" c_int
  | Ctrl_meta c -> Format.fprintf fmt "C-M-%c" c
  | Arrow `Up -> Format.fprintf fmt "<up>"
  | Arrow `Down -> Format.fprintf fmt "<down>"
  | Arrow `Left -> Format.fprintf fmt "<left>"
  | Arrow `Right -> Format.fprintf fmt "<right>"
  | Function n -> Format.fprintf fmt "<f%d>" n
  | Backspace -> Format.fprintf fmt "<backspace>"
  | Delete -> Format.fprintf fmt "<delete>"
  | Enter -> Format.fprintf fmt "<enter>"
  | Tab -> Format.fprintf fmt "<tab>"
  | Escape -> Format.fprintf fmt "<esc>"
  | Page_up -> Format.fprintf fmt "<page_up>"
  | Page_down -> Format.fprintf fmt "<page_down>"
  | Home -> Format.fprintf fmt "<home>"
  | End -> Format.fprintf fmt "<end>"

let of_string s =
  let len = String.length s in
  if len = 1 then
    Some (Char (Uchar.of_char s.[0]))
  else if len = 3 && s.[0] = 'C' && s.[1] = '-' then
    Some (Ctrl s.[2])
  else if len = 3 && s.[0] = 'M' && s.[1] = '-' then
    Some (Meta (Uchar.of_char s.[2]))
  else if len = 5 && s.[0] = 'C' && s.[1] = '-' && s.[2] = 'M' && s.[3] = '-' then
    Some (Ctrl_meta s.[4])
  else if s = "<up>" then Some (Arrow `Up)
  else if s = "<down>" then Some (Arrow `Down)
  else if s = "<left>" then Some (Arrow `Left)
  else if s = "<right>" then Some (Arrow `Right)
  else if len >= 4 && s.[0] = '<' && s.[1] = 'f' && s.[len-1] = '>' then
    (try Some (Function (int_of_string (String.sub s 2 (len - 3)))) with Failure _ -> None)
  else if s = "<backspace>" then Some Backspace
  else if s = "<delete>" then Some Delete
  else if s = "<enter>" then Some Enter
  else if s = "<tab>" then Some Tab
  else if s = "<esc>" then Some Escape
  else if s = "<page_up>" then Some Page_up
  else if s = "<page_down>" then Some Page_down
  else if s = "<home>" then Some Home
  else if s = "<end>" then Some End
  else None
