module type S = sig
  type t
  val empty : t
  val of_string : string -> t
  val to_string : t -> string
  val insert : offset:int -> string -> t -> t
  val delete : offset:int -> length:int -> t -> t
  val slice : start:int -> length:int -> t -> string
  val length : t -> int
  val line_count : t -> int
  val line_to_offset : line:int -> t -> int
  val offset_to_line_col : offset:int -> t -> (int * int)
end

module SimpleBuffer = struct
  type t = string array

  let empty = [| "" |]

  let of_string s =
    Array.of_list (String.split_on_char '\n' s)

  let to_string t =
    String.concat "\n" (Array.to_list t)

  let insert ~offset s t =
    let full_str = to_string t in
    let len = String.length full_str in
    let offset = max 0 (min offset len) in
    let before = String.sub full_str 0 offset in
    let after = String.sub full_str offset (len - offset) in
    of_string (before ^ s ^ after)

  let delete ~offset ~length:del_len t =
    let full_str = to_string t in
    let len = String.length full_str in
    let offset = max 0 (min offset len) in
    let del_len = max 0 (min del_len (len - offset)) in
    let before = String.sub full_str 0 offset in
    let after = String.sub full_str (offset + del_len) (len - offset - del_len) in
    of_string (before ^ after)

  let slice ~start ~length:slice_len t =
    let full_str = to_string t in
    let len = String.length full_str in
    let start = max 0 (min start len) in
    let slice_len = max 0 (min slice_len (len - start)) in
    String.sub full_str start slice_len

  let length t =
    let rec sum acc i =
      if i = Array.length t then acc
      else sum (acc + String.length t.(i)) (i + 1)
    in
    let num_lines = Array.length t in
    if num_lines = 0 then 0
    else sum 0 0 + (num_lines - 1)

  let line_count t = Array.length t

  let line_to_offset ~line t =
    let rec calc acc i =
      if i >= line || i >= Array.length t then acc
      else calc (acc + String.length t.(i) + 1) (i + 1)
    in
    calc 0 0

  let offset_to_line_col ~offset t =
    let rec find_line i current_offset =
      if i >= Array.length t then
        if Array.length t = 0 then (0, 0)
        else (Array.length t - 1, String.length t.(Array.length t - 1))
      else
        let len = String.length t.(i) in
        if current_offset <= len then
          (i, current_offset)
        else
          find_line (i + 1) (current_offset - len - 1)
    in
    if offset < 0 then (0, 0)
    else find_line 0 offset
end

include SimpleBuffer
