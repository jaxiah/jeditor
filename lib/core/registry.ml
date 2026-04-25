module StringMap = Map.Make(String)

type 'a t = 'a StringMap.t

let empty = StringMap.empty

let register name handler t = StringMap.add name handler t

let lookup name t = StringMap.find_opt name t

let names t = StringMap.fold (fun k _ acc -> k :: acc) t [] |> List.rev

let complete ~prefix t =
  StringMap.fold (fun k _ acc ->
    if String.length k >= String.length prefix
    && String.sub k 0 (String.length prefix) = prefix
    then k :: acc
    else acc
  ) t []
  |> List.rev
