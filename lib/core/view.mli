val gutter_width : line_count:int -> int
(** Column width of the line-number gutter for a buffer with [line_count] lines.
    Format: right-aligned number + one space.
    Examples: 1-9 -> 2, 10-99 -> 3, 100-999 -> 4. *)

val status_text :
  file_path:string option ->
  modified:bool ->
  cursor_line:int ->
  cursor_display_col:int ->
  line_count:int ->
  cols:int ->
  string
(** Returns a string of exactly [cols] display-columns for the status bar.
    Layout: left side = "{filename|[No Name]}{' **' if modified}"
            right side = "{line+1}:{col+1}  L {line_count}"
    The two sides are separated by spaces; the whole string is padded or
    truncated to exactly [cols] columns. *)
