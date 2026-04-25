## Parent Issue

[ISSUE-002-project-scaffold.md](ISSUE-002-project-scaffold.md)

## Interfaces

### Directory Structure and Dune Library Names

```
jeditor/
├── dune-project                  (* (lang dune 3.x) (name jeditor) *)
├── jeditor.opam
├── .ocamlformat                  (* (version 0.26) *)
├── bin/
│   ├── dune                      (* (executable (name jeditor) (public_name jeditor) (libraries jeditor_core jeditor_terminal)) *)
│   └── jeditor.ml                (* The only file allowed to hold an app_state ref, entry point for the main loop *)
├── lib/
│   ├── buffer/
│   │   └── dune                  (* (library (name jeditor_buffer)) *)
│   ├── core/
│   │   └── dune                  (* (library (name jeditor_core) (libraries jeditor_buffer jeditor_terminal)) *)
│   ├── terminal/
│   │   └── dune                  (* (library (name jeditor_terminal) (libraries uutf uuseg)) *)
│   └── plugin/
│       └── dune                  (* (library (name jeditor_plugin) (libraries jeditor_core)) *)
└── test/
    ├── dune                      (* (test (name test_main) (libraries jeditor_buffer alcotest)) *)
    └── test_placeholder.ml       (* At least one passing placeholder test *)
```

### `bin/jeditor.ml` Skeleton (Interface Convention)

```ocaml
(* jeditor.ml is the only file allowed to have side effects.
   Its structural convention is as follows; subsequent issues will only extend the loop without changing the top-level shape. *)

let () =
  let term   = Terminal.create () |> Result.get_ok in
  let input  = Input.create ()    |> Result.get_ok in
  let state  = ref App_state.empty in
  Fun.protect
    ~finally:(fun () -> Terminal.close term; Input.close input)
    (fun () ->
       Terminal.write_string term "jeditor loaded" Attr.default;
       Terminal.flush term;
       match Input.next_key input with
       | Some _ | None -> ())
```

### opam Dependency List

| Package    | Purpose                                                   | dev-only |
| ---------- | --------------------------------------------------------- | -------- |
| `uutf`     | UTF-8 encoding/decoding                                   | No       |
| `uuseg`    | Grapheme cluster segmentation (display width calculation) | No       |
| `alcotest` | Unit testing framework                                    | Yes      |

**Does not include Notty** -- the terminal backend is self-implemented in ISSUE-005.

### OCaml Version

Targeting **OCaml 5.4+**. Declared in `dune-project`:

```
(lang dune 3.16)
(using ocamlformat 0.1)
```

`.ocaml-version` file written as `5.4.1`.

## Module Boundaries

- `jeditor_buffer`: No external dependencies, purely functional, first to be testable.
- `jeditor_terminal`: Depends only on `uutf`/`uuseg`, does not depend on any other jeditor library.
- `jeditor_core`: Depends on buffer + terminal, contains App_state and Update.
- `jeditor_plugin`: Depends on core, exposes the plugin API.
- `bin/main.ml`: Depends on core + terminal, the only entry point for side effects.

## Deep Module Opportunities

This issue itself does not introduce deep modules, but the scaffolding phase needs to establish a convention: **The root module of each library (`jeditor_buffer/buffer.ml`, `jeditor_terminal/terminal.ml`, etc.) should only re-export the library's public interface and not expose internal implementation modules.** This convention is enforced from day one to avoid abstraction leaks later on.

## Testing Priorities

1. `dune build` succeeds with no warnings.
2. `dune test` runs placeholder tests and reports 0 failures.
3. `dune exec jeditor` starts and exits in Windows Terminal, with terminal state fully restored.

## Open Questions

None.
