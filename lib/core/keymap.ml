open Jeditor_terminal

type binding =
  | Command of string
  | Prefix  of t

and t = (Key.t * binding) list

type lookup_result = Matched of string | Pending | Unbound

let empty = []

let rec bind keys cmd km =
  match keys with
  | [] -> invalid_arg "Keymap.bind: empty key sequence"
  | [k] ->
      let rest = List.filter (fun (k', _) -> k' <> k) km in
      (k, Command cmd) :: rest
  | k :: tl ->
      let sub = match List.assoc_opt k km with
        | Some (Prefix sub) -> sub
        | _ -> empty
      in
      let sub' = bind tl cmd sub in
      let rest = List.filter (fun (k', _) -> k' <> k) km in
      (k, Prefix sub') :: rest

let lookup_one km keys =
  let rec go km = function
    | [] -> Pending
    | [k] ->
        (match List.assoc_opt k km with
         | Some (Command c) -> Matched c
         | Some (Prefix _)  -> Pending
         | None             -> Unbound)
    | k :: tl ->
        (match List.assoc_opt k km with
         | Some (Prefix sub) -> go sub tl
         | Some (Command _)  -> Unbound
         | None              -> Unbound)
  in
  go km keys

let lookup layers keys =
  let rec try_layers = function
    | [] -> Unbound
    | layer :: rest ->
        (match lookup_one layer keys with
         | Unbound -> try_layers rest
         | result  -> result)
  in
  try_layers layers

let emacs_default =
  let m c = Key.Meta (Uchar.of_char c) in
  empty
  |> bind [Key.Ctrl 'f']          "move-forward-char"
  |> bind [Key.Arrow `Right]      "move-forward-char"
  |> bind [Key.Ctrl 'b']          "move-backward-char"
  |> bind [Key.Arrow `Left]       "move-backward-char"
  |> bind [Key.Ctrl 'n']          "move-next-line"
  |> bind [Key.Arrow `Down]       "move-next-line"
  |> bind [Key.Ctrl 'p']          "move-prev-line"
  |> bind [Key.Arrow `Up]         "move-prev-line"
  |> bind [m 'f']                 "move-forward-word"
  |> bind [m 'b']                 "move-backward-word"
  |> bind [m '<']                 "move-buf-start"
  |> bind [m '>']                 "move-buf-end"
  |> bind [Key.Ctrl 'a']          "move-line-start"
  |> bind [Key.Ctrl 'e']          "move-line-end"
  |> bind [Key.Ctrl 'd']          "delete-forward-char"
  |> bind [Key.Delete]            "delete-forward-char"
  |> bind [Key.Backspace]         "backward-delete-char"
  |> bind [Key.Ctrl_meta 'h']     "delete-word-back"
  |> bind [m 'd']                 "kill-word-forward"
  |> bind [Key.Ctrl 'k']          "kill-line"
  |> bind [Key.Ctrl 'w']          "kill-region"
  |> bind [m 'w']                 "copy-region"
  |> bind [Key.Ctrl 'y']          "yank"
  |> bind [m 'n']                 "add-next-occurrence"
  |> bind [m 'N']                 "add-cursor-below"
  |> bind [Key.Ctrl '@']          "set-mark-command"
  |> bind [Key.Enter]             "new-line"
  |> bind [Key.Ctrl 'm']         "new-line"
  |> bind [Key.Ctrl '/']          "undo"
  |> bind [Key.Ctrl '_']          "undo"
  |> bind [m '_']                 "redo"
  |> bind [Key.Ctrl 'g']          "cancel"
  |> bind [Key.Escape]            "cancel"
  |> bind [Key.Ctrl 's']          "isearch-forward"
  |> bind [Key.Ctrl 'r']          "isearch-backward"
  |> bind [Key.Ctrl 'x'; Key.Ctrl 's'] "save"
  |> bind [Key.Ctrl 'x'; Key.Ctrl 'w'] "save-as"
  |> bind [Key.Ctrl 'x'; Key.Ctrl 'c'] "quit"
  |> bind [Key.Ctrl 'x'; Key.Char (Uchar.of_char 'b')] "switch-to-buffer"
  |> bind [Key.Ctrl 'x'; Key.Ctrl 'b'] "list-buffers"
  |> bind [Key.Ctrl 'x'; Key.Char (Uchar.of_char 'k')] "kill-buffer"
  |> bind [Key.Ctrl 'x'; Key.Char (Uchar.of_char 'g')] "goto-line"
  |> bind [Key.Ctrl 'x'; Key.Char (Uchar.of_char '2')] "split-window-below"
  |> bind [Key.Ctrl 'x'; Key.Char (Uchar.of_char '3')] "split-window-right"
  |> bind [Key.Ctrl 'x'; Key.Char (Uchar.of_char 'o')] "other-window"
  |> bind [Key.Ctrl 'x'; Key.Char (Uchar.of_char '0')] "delete-window"
  |> bind [Key.Ctrl 'x'; Key.Char (Uchar.of_char '1')] "delete-other-windows"
  |> bind [Key.Ctrl 'h']          "help"
  |> bind [m 'g'; Key.Char (Uchar.of_char 'g')] "goto-line"
  |> bind [m 'g'; m 'g']          "goto-line"
  |> bind [m 'x']                 "execute-extended-command"
  |> bind [m '%']                 "query-replace"
