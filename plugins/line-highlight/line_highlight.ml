open Jeditor_plugin

let () =
  Plugin_api.register_command "line-highlight-enable" Plugin_api.enable_line_highlight;
  Plugin_api.register_hook Plugin_api.After_open Plugin_api.enable_line_highlight
