type orientation = Horizontal | Vertical

type window = {
  id : int;
  buffer_id : int;
  scroll_top_line : int;
}

type rect = {
  x : int;
  y : int;
  width : int;
  height : int;
}

type node =
  | Leaf of window
  | Split of orientation * float * node * node

type t = {
  root : node;
  focused : int;
  next_id : int;
}

let single ~buffer_id =
  { root = Leaf { id = 0; buffer_id; scroll_top_line = 0 };
    focused = 0;
    next_id = 1 }

let rec leaves_node = function
  | Leaf w -> [w]
  | Split (_, _, a, b) -> leaves_node a @ leaves_node b

let leaves t = leaves_node t.root

let focused_window t =
  match List.find_opt (fun w -> w.id = t.focused) (leaves t) with
  | Some w -> w
  | None -> List.hd (leaves t)

let rec map_focused focused f = function
  | Leaf w when w.id = focused -> Leaf (f w)
  | Leaf w -> Leaf w
  | Split (o, r, a, b) ->
      Split (o, r, map_focused focused f a, map_focused focused f b)

let update_focused f t =
  { t with root = map_focused t.focused f t.root }

let set_focused_buffer ~buffer_id t =
  update_focused (fun w -> { w with buffer_id; scroll_top_line = 0 }) t

let replace_buffer ~old_id ~new_id t =
  let rec replace = function
    | Leaf w when w.buffer_id = old_id -> Leaf { w with buffer_id = new_id; scroll_top_line = 0 }
    | Leaf w -> Leaf w
    | Split (o, r, a, b) -> Split (o, r, replace a, replace b)
  in
  { t with root = replace t.root }

let split_focused orientation t =
  let new_id = t.next_id in
  let rec split = function
    | Leaf w when w.id = t.focused ->
        let sibling = { w with id = new_id; scroll_top_line = w.scroll_top_line } in
        Split (orientation, 0.5, Leaf w, Leaf sibling)
    | Leaf w -> Leaf w
    | Split (o, r, a, b) -> Split (o, r, split a, split b)
  in
  { root = split t.root; focused = new_id; next_id = new_id + 1 }

let focus_next t =
  match leaves t with
  | [] -> t
  | ws ->
      let ids = List.map (fun w -> w.id) ws in
      let rec next = function
        | [] -> List.hd ids
        | [x] when x = t.focused -> List.hd ids
        | x :: y :: _ when x = t.focused -> y
        | _ :: rest -> next rest
      in
      { t with focused = next ids }

let close_focused t =
  match leaves t with
  | [] | [_] -> t
  | _ ->
      let rec close = function
        | Leaf w when w.id = t.focused -> None
        | Leaf w -> Some (Leaf w)
        | Split (_, _, a, b) ->
            (match close a, close b with
             | None, None -> None
             | Some a, None -> Some a
             | None, Some b -> Some b
             | Some a, Some b -> Some (Split (Horizontal, 0.5, a, b)))
      in
      (match close t.root with
       | None -> t
       | Some root ->
           let focused =
             match leaves_node root with
             | [] -> t.focused
             | w :: _ -> w.id
           in
           { t with root; focused })

let close_others t =
  let w = focused_window t in
  { t with root = Leaf w; focused = w.id }

let layouts ~cols ~rows t =
  let rec layout rect = function
    | Leaf w -> [w, rect]
    | Split (Horizontal, ratio, a, b) ->
        let first_h = max 1 (int_of_float (float rect.height *. ratio)) in
        let first_h = min first_h (max 1 (rect.height - 1)) in
        let second_h = max 1 (rect.height - first_h - 1) in
        let ra = { rect with height = first_h } in
        let rb = { x = rect.x; y = rect.y + first_h + 1;
                   width = rect.width; height = second_h } in
        layout ra a @ layout rb b
    | Split (Vertical, ratio, a, b) ->
        let first_w = max 1 (int_of_float (float rect.width *. ratio)) in
        let first_w = min first_w (max 1 (rect.width - 1)) in
        let second_w = max 1 (rect.width - first_w - 1) in
        let ra = { rect with width = first_w } in
        let rb = { x = rect.x + first_w + 1; y = rect.y;
                   width = second_w; height = rect.height } in
        layout ra a @ layout rb b
  in
  if cols <= 0 || rows <= 0 then []
  else layout { x = 0; y = 0; width = cols; height = rows } t.root
