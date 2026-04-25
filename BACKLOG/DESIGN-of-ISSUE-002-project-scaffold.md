## Parent Issue

[ISSUE-002-project-scaffold.md](ISSUE-002-project-scaffold.md)

## Interfaces

### 目录结构与 dune 库名

```
jeditor/
├── dune-project                  (* (lang dune 3.x) (name jeditor) *)
├── jeditor.opam
├── .ocamlformat                  (* (version 0.26) *)
├── bin/
│   ├── dune                      (* (executable (name jeditor) (public_name jeditor) (libraries jeditor_core jeditor_terminal)) *)
│   └── jeditor.ml                (* 唯一持有 app_state ref 的文件，主循环入口 *)
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
    └── test_placeholder.ml       (* 至少一个通过的占位测试 *)
```

### `bin/jeditor.ml` 骨架（接口约定）

```ocaml
(* jeditor.ml 是唯一允许存在副作用的文件。
   它的结构约定如下，后续 issue 只扩展 loop，不改变顶层形状。 *)

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

### opam 依赖清单

| 包 | 用途 | dev-only |
|----|------|----------|
| `uutf` | UTF-8 编解码 | 否 |
| `uuseg` | 字素簇分割（显示宽度计算） | 否 |
| `alcotest` | 单元测试框架 | 是 |

**不包含 Notty** — 终端后端由 ISSUE-005 自行实现。

### OCaml 版本

目标 **OCaml 5.4+**。`dune-project` 中声明：
```
(lang dune 3.16)
(using ocamlformat 0.1)
```
`.ocaml-version` 文件写入 `5.4.1`。

## Module Boundaries

- `jeditor_buffer`：无任何外部依赖，纯函数式，最先可测试
- `jeditor_terminal`：只依赖 `uutf`/`uuseg`，不依赖任何其他 jeditor 库
- `jeditor_core`：依赖 buffer + terminal，包含 App_state 和 Update
- `jeditor_plugin`：依赖 core，对外暴露插件 API
- `bin/main.ml`：依赖 core + terminal，是唯一的副作用入口

## Deep Module Opportunities

此 issue 本身不引入深模块，但脚手架阶段需要确立一个约定：**每个库的根模块（`jeditor_buffer/buffer.ml`、`jeditor_terminal/terminal.ml` 等）只重导出本库的公开接口，不暴露内部实现模块。** 这一约定从第一天起执行，避免后续出现抽象泄漏。

## Testing Priorities

1. `dune build` 成功，无警告
2. `dune test` 运行占位测试并报告 0 failures
3. `dune exec jeditor` 在 Windows Terminal 中启动并退出，终端状态完全恢复

## Open Questions

无。
