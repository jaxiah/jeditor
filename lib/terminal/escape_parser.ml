let next_key read_char =
  match read_char () with
  | None -> None
  | Some '\x1b' ->
      (match read_char () with
       | None -> Some Key.Escape
       | Some '[' ->
           let rec read_params acc =
             match read_char () with
             | Some c when c >= '0' && c <= '9' -> read_params (acc ^ String.make 1 c)
             | Some '~' ->
                 (match acc with
                  | "3" -> Some Key.Delete
                  | "5" -> Some Key.Page_up
                  | "6" -> Some Key.Page_down
                  | "11" -> Some (Key.Function 1)
                  | "12" -> Some (Key.Function 2)
                  | "13" -> Some (Key.Function 3)
                  | "14" -> Some (Key.Function 4)
                  | "15" -> Some (Key.Function 5)
                  | "17" -> Some (Key.Function 6)
                  | "18" -> Some (Key.Function 7)
                  | "19" -> Some (Key.Function 8)
                  | "20" -> Some (Key.Function 9)
                  | "21" -> Some (Key.Function 10)
                  | "23" -> Some (Key.Function 11)
                  | "24" -> Some (Key.Function 12)
                  | _ -> Some Key.Escape)
             | Some 'A' -> Some (Key.Arrow `Up)
             | Some 'B' -> Some (Key.Arrow `Down)
             | Some 'C' -> Some (Key.Arrow `Right)
             | Some 'D' -> Some (Key.Arrow `Left)
             | Some 'H' -> Some Key.Home
             | Some 'F' -> Some Key.End
             | _ -> Some Key.Escape
           in
           read_params ""
       | Some 'O' ->
           (match read_char () with
            | Some 'P' -> Some (Key.Function 1)
            | Some 'Q' -> Some (Key.Function 2)
            | Some 'R' -> Some (Key.Function 3)
            | Some 'S' -> Some (Key.Function 4)
            | _ -> Some Key.Escape)
       | Some '\r' | Some '\n' -> Some (Key.Ctrl_meta 'm')
       | Some '\t' -> Some (Key.Ctrl_meta 'i')
       | Some '\x7f' | Some '\x08' -> Some (Key.Ctrl_meta 'h')
       | Some '\x1f' -> Some (Key.Ctrl_meta '/')
       | Some c when c >= '\x00' && c <= '\x1f' ->
           let code = int_of_char c in
           let base =
             if code >= 1 && code <= 26 then char_of_int (code + 96)
             else if code = 0 then '@'
             else char_of_int (code + 64)
           in
           Some (Key.Ctrl_meta base)
       | Some c -> Some (Key.Meta (Uchar.of_char c)))
  | Some '\r' | Some '\n' -> Some Key.Enter
  | Some '\t' -> Some Key.Tab
  | Some '\x7f' | Some '\x08' -> Some Key.Backspace
  | Some '\x1f' -> Some (Key.Ctrl '/')
  | Some c when c >= '\x00' && c <= '\x1f' ->
      let code = int_of_char c in
      let base =
        if code >= 1 && code <= 26 then char_of_int (code + 96)
        else if code = 0 then '@'
        else char_of_int (code + 64)
      in
      Some (Key.Ctrl base)
  | Some c when Char.code c < 0x80 -> Some (Key.Char (Uchar.of_char c))
  | Some c ->
      (* Multi-byte UTF-8 sequence: decode continuation bytes *)
      let b0 = Char.code c in
      let n_more =
        if b0 land 0xE0 = 0xC0 then 1
        else if b0 land 0xF0 = 0xE0 then 2
        else if b0 land 0xF8 = 0xF0 then 3
        else 0
      in
      let buf = Bytes.make (1 + n_more) c in
      let ok = ref (n_more > 0) in
      for i = 1 to n_more do
        match read_char () with
        | Some b -> Bytes.set buf i b
        | None   -> ok := false
      done;
      if not !ok then None
      else
        let dec = Uutf.decoder ~encoding:`UTF_8 (`String (Bytes.to_string buf)) in
        (match Uutf.decode dec with
         | `Uchar u -> Some (Key.Char u)
         | _        -> None)
