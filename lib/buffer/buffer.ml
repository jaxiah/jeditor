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

  let length t =
    let n = Array.length t in
    if n = 0 then 0
    else
      let rec sum acc i =
        if i >= n then acc
        else sum (acc + String.length t.(i)) (i + 1)
      in
      sum 0 0 + (n - 1)

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

  (* Insert string [s] at byte [offset].
     Operates at the line-array level: no full flatten/split. *)
  let insert ~offset s t =
    if s = "" then t
    else
      let total = length t in
      let offset = max 0 (min offset total) in
      let (line, col) = offset_to_line_col ~offset t in
      let cur = t.(line) in
      let before_col = String.sub cur 0 col in
      let after_col  = String.sub cur col (String.length cur - col) in
      let parts = String.split_on_char '\n' s in
      (match parts with
       | [] -> t
       | [single] ->
           let result = Array.copy t in
           result.(line) <- before_col ^ single ^ after_col;
           result
       | first :: rest ->
           let n_rest   = List.length rest in
           let last     = List.nth rest (n_rest - 1) in
           let middle   = List.filteri (fun i _ -> i < n_rest - 1) rest in
           let new_lines =
             Array.concat [
               [| before_col ^ first |];
               Array.of_list middle;
               [| last ^ after_col |];
             ]
           in
           Array.concat [
             Array.sub t 0 line;
             new_lines;
             Array.sub t (line + 1) (Array.length t - line - 1);
           ])

  (* Delete [del_len] bytes starting at [offset].
     Operates at the line-array level: no full flatten/split. *)
  let delete ~offset ~length:del_len t =
    if del_len <= 0 then t
    else
      let total = length t in
      let offset  = max 0 (min offset total) in
      let del_len = max 0 (min del_len (total - offset)) in
      if del_len = 0 then t
      else
        let end_offset = offset + del_len in
        let (sl, sc) = offset_to_line_col ~offset t in
        let (el, ec) = offset_to_line_col ~offset:end_offset t in
        if sl = el then begin
          (* Deletion within a single line *)
          let cur = t.(sl) in
          let result = Array.copy t in
          result.(sl) <- String.sub cur 0 sc ^
                         String.sub cur ec (String.length cur - ec);
          result
        end else begin
          (* Deletion spans multiple lines: merge head of sl with tail of el *)
          let merged = String.sub t.(sl) 0 sc ^
                       String.sub t.(el) ec (String.length t.(el) - ec) in
          Array.concat [
            Array.sub t 0 sl;
            [| merged |];
            Array.sub t (el + 1) (Array.length t - el - 1);
          ]
        end

  (* Slice [slice_len] bytes starting at [start].
     Operates at the line-array level: no full flatten. *)
  let slice ~start ~length:slice_len t =
    let total = length t in
    let start     = max 0 (min start total) in
    let slice_len = max 0 (min slice_len (total - start)) in
    if slice_len = 0 then ""
    else
      let end_offset = start + slice_len in
      let (sl, sc) = offset_to_line_col ~offset:start t in
      let (el, ec) = offset_to_line_col ~offset:end_offset t in
      if sl = el then
        String.sub t.(sl) sc (ec - sc)
      else begin
        let buf = Stdlib.Buffer.create slice_len in
        Stdlib.Buffer.add_string buf (String.sub t.(sl) sc (String.length t.(sl) - sc));
        for i = sl + 1 to el - 1 do
          Stdlib.Buffer.add_char   buf '\n';
          Stdlib.Buffer.add_string buf t.(i)
        done;
        Stdlib.Buffer.add_char   buf '\n';
        Stdlib.Buffer.add_string buf (String.sub t.(el) 0 ec);
        Stdlib.Buffer.contents buf
      end

  let is_word_char c =
    let n = Uchar.to_int c in
    (n >= Char.code 'a' && n <= Char.code 'z') ||
    (n >= Char.code 'A' && n <= Char.code 'Z') ||
    (n >= Char.code '0' && n <= Char.code '9')

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

  (* Read the char AT position (line, col), returning
     Some (is_word_char, next_line, next_col) or None at end of buffer.
     A newline between lines counts as a non-word char. *)
  let next_char t line col =
    if line >= Array.length t then None
    else
      let s   = t.(line) in
      let slen = String.length s in
      if col < slen then begin
        let b = Char.code s.[col] in
        if b < 0x80 then
          let is_word = (b >= Char.code 'a' && b <= Char.code 'z')
                     || (b >= Char.code 'A' && b <= Char.code 'Z')
                     || (b >= Char.code '0' && b <= Char.code '9') in
          Some (is_word, line, col + 1)
        else
          let sub = String.sub s col (slen - col) in
          let dec = Uutf.decoder (`String sub) in
          (match Uutf.decode dec with
           | `Uchar c -> Some (is_word_char c, line, col + Uutf.decoder_byte_count dec)
           | _ -> None)
      end else if line + 1 < Array.length t then
        Some (false, line + 1, 0)   (* the '\n' between lines: non-word *)
      else
        None

  (* Read the char BEFORE position (line, col), returning
     Some (is_word_char, new_line, new_col) where (new_line, new_col) is
     the start position of that char. Returns None at start of buffer. *)
  let prev_char t line col =
    if line = 0 && col = 0 then None
    else if col = 0 then
      (* The '\n' at end of previous line: non-word *)
      Some (false, line - 1, String.length t.(line - 1))
    else
      let s = t.(line) in
      let rec find_start j =
        if j <= 0 then 0
        else if Char.code s.[j] land 0xC0 = 0x80 then find_start (j - 1)
        else j
      in
      let cp_start = find_start (col - 1) in
      let b = Char.code s.[cp_start] in
      if b < 0x80 then
        let is_word = (b >= Char.code 'a' && b <= Char.code 'z')
                   || (b >= Char.code 'A' && b <= Char.code 'Z')
                   || (b >= Char.code '0' && b <= Char.code '9') in
        Some (is_word, line, cp_start)
      else
        let sub = String.sub s cp_start (String.length s - cp_start) in
        let dec = Uutf.decoder (`String sub) in
        (match Uutf.decode dec with
         | `Uchar c -> Some (is_word_char c, line, cp_start)
         | _ -> None)

  (* next_word_boundary: if at a word char, skip to end of word;
     if at non-word, skip non-words then skip the next whole word.
     Mirrors the original flat-string logic but works on the line array. *)
  let next_word_boundary ~offset t =
    let total = length t in
    if offset >= total then total
    else
      let (init_line, init_col) = offset_to_line_col ~offset t in
      let to_off l c = line_to_offset ~line:l t + c in
      let rec skip_words l c =
        match next_char t l c with
        | Some (true,  nl, nc) -> skip_words nl nc
        | _ -> to_off l c
      in
      let rec skip_non_words l c =
        match next_char t l c with
        | Some (false, nl, nc) -> skip_non_words nl nc
        | Some (true,  _,  _ ) -> (l, c)
        | None                 -> (-1, 0)
      in
      let rec find_next l c =
        match next_char t l c with
        | None                  -> total
        | Some (true,  _,  _ )  -> skip_words l c
        | Some (false, _,  _ )  ->
            let (wl, wc) = skip_non_words l c in
            if wl < 0 then total else find_next wl wc
      in
      find_next init_line init_col

  (* prev_word_boundary: skip backward past non-word chars,
     then skip backward through word chars.
     Returns the start offset of the word found. *)
  let prev_word_boundary ~offset t =
    if offset <= 0 then 0
    else
      let (init_line, init_col) = offset_to_line_col ~offset t in
      let to_off l c = line_to_offset ~line:l t + c in
      let rec skip_non_words l c =
        match prev_char t l c with
        | None                  -> (0, 0)
        | Some (true,  _,  _ )  -> (l, c)
        | Some (false, pl, pc)  -> skip_non_words pl pc
      in
      let rec skip_words l c =
        match prev_char t l c with
        | None                  -> (0, 0)
        | Some (false, _,  _ )  -> (l, c)
        | Some (true,  pl, pc)  -> skip_words pl pc
      in
      let (l1, c1) = skip_non_words init_line init_col in
      let (l2, c2) = skip_words l1 c1 in
      to_off l2 c2
end

include SimpleBuffer
