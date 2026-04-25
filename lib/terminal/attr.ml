type color =
  | Default
  | Black | Red | Green | Yellow | Blue | Magenta | Cyan | White
  | Bright of [ `Black | `Red | `Green | `Yellow
              | `Blue  | `Magenta | `Cyan | `White ]
  | Rgb of int * int * int

type t = {
  fg        : color;
  bg        : color;
  bold      : bool;
  italic    : bool;
  reverse   : bool;
  underline : bool;
}

let default = {
  fg        = Default;
  bg        = Default;
  bold      = false;
  italic    = false;
  reverse   = false;
  underline = false;
}
