let gutter_width ~line_count =
  String.length (string_of_int line_count) + 1

let status_text ~file_path ~modified ~cursor_line ~cursor_display_col ~line_count ~cols =
  let name = match file_path with Some p -> p | None -> "[No Name]" in
  let mod_indicator = if modified then " **" else "" in
  let left = name ^ mod_indicator in
  let right = Printf.sprintf "%d:%d  L %d" (cursor_line + 1) (cursor_display_col + 1) line_count in
  let left_len = String.length left in
  let right_len = String.length right in
  if left_len + right_len > cols then
    (* Truncate left side if it doesn't fit *)
    let available_left = max 0 (cols - right_len) in
    let truncated_left = if left_len > available_left then String.sub left 0 available_left else left in
    truncated_left ^ right
  else
    let padding = String.make (cols - left_len - right_len) ' ' in
    left ^ padding ^ right
