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
  val is_word_char : Uchar.t -> bool
  val first_non_whitespace : line:int -> t -> int
  val next_word_boundary : offset:int -> t -> int
  val prev_word_boundary : offset:int -> t -> int
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

  let is_word_char c =
    let c_int = Uchar.to_int c in
    (c_int >= Char.code 'a' && c_int <= Char.code 'z') ||
    (c_int >= Char.code 'A' && c_int <= Char.code 'Z') ||
    (c_int >= Char.code '0' && c_int <= Char.code '9')

  let first_non_whitespace ~line t =
    if line < 0 || line >= Array.length t then 0
    else
      let s = t.(line) in
      let rec loop i =
        if i >= String.length s then String.length s
        else if s.[i] = ' ' || s.[i] = '\t' then loop (i + 1)
        else i
      in
      loop 0

  let next_word_boundary ~offset t =
    let s = to_string t in
    let len = String.length s in
    let rec skip_non_words i =
      if i >= len then len
      else
        let decoder = Uutf.decoder (`String (String.sub s i (len - i))) in
        match Uutf.decode decoder with
        | `Uchar c -> if is_word_char c then i else skip_non_words (i + (Uutf.decoder_byte_count decoder))
        | _ -> len
    in
    let rec skip_words i =
      if i >= len then len
      else
        let decoder = Uutf.decoder (`String (String.sub s i (len - i))) in
        match Uutf.decode decoder with
        | `Uchar c -> if not (is_word_char c) then i else skip_words (i + (Uutf.decoder_byte_count decoder))
        | _ -> len
    in
    let rec find_next i =
      if i >= len then len
      else
        let decoder = Uutf.decoder (`String (String.sub s i (len - i))) in
        match Uutf.decode decoder with
        | `Uchar c ->
            if is_word_char c then skip_words i
            else find_next (skip_non_words i)
        | _ -> len
    in
    find_next offset

  let prev_word_boundary ~offset t =
    let s = to_string t in
    let is_word_at i =
      if i < 0 then false
      else
        let rec find_start j =
          if j <= 0 then 0
          else if Char.code s.[j] land 0xC0 = 0x80 then find_start (j - 1)
          else j
        in
        let start = find_start i in
        let decoder = Uutf.decoder (`String (String.sub s start (String.length s - start))) in
        match Uutf.decode decoder with
        | `Uchar c -> is_word_char c
        | _ -> false
    in
    let rec skip_non_words i =
      if i <= 0 then 0
      else if is_word_at (i - 1) then i
      else skip_non_words (i - 1)
    in
    let rec skip_words i =
      if i <= 0 then 0
      else if not (is_word_at (i - 1)) then i
      else skip_words (i - 1)
    in
    let i = skip_non_words offset in
    skip_words i
end

include SimpleBuffer
