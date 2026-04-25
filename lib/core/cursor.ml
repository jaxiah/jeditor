type range = { head : int; anchor : int }
type t = range list

let create pos = [ { head = pos; anchor = pos } ]
let create_selection ~head ~anchor = [ { head; anchor } ]

let start r = min r.head r.anchor
let stop r = max r.head r.anchor

let merge r1 r2 =
  if stop r1 >= start r2 then
    let new_start = min (start r1) (start r2) in
    let new_stop = max (stop r1) (stop r2) in
    let new_head, new_anchor =
      if r1.head > r1.anchor then (new_stop, new_start)
      else (new_start, new_stop)
    in
    Some { head = new_head; anchor = new_anchor }
  else None

let of_list lst =
  let sorted = List.sort (fun a b -> compare (start a) (start b)) lst in
  let rec merge_list acc current lst =
    match lst with
    | [] -> List.rev (current :: acc)
    | hd :: tl ->
      match merge current hd with
      | Some merged -> merge_list acc merged tl
      | None -> merge_list (current :: acc) hd tl
  in
  match sorted with
  | [] -> []
  | hd :: tl -> merge_list [] hd tl

let to_list t = t
let primary t = List.hd t

let add range t =
  of_list (range :: t)

let apply_edit ~offset ~deleted ~inserted t =
  let shift pos =
    if pos < offset then
      pos
    else if pos < offset + deleted then
      offset
    else
      pos + inserted - deleted
  in
  List.map (fun r -> { head = shift r.head; anchor = shift r.anchor }) t
  |> of_list
