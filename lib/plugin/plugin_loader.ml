open Jeditor_core

let apply_registered st =
  Plugin_api.apply_registered st

let load_one st path =
  try
    Dynlink.loadfile path;
    Plugin_api.apply_registered st
  with exn ->
    { st with App.message = "Plugin load failed: " ^ path ^ ": " ^ Printexc.to_string exn }

let load_paths paths st =
  List.fold_left load_one st paths
