## Parent Issue

[ISSUE-005-windows-terminal-backend.md](ISSUE-005-windows-terminal-backend.md)

## Interfaces

### `Key.t`

```ocaml
(* lib/terminal/key.ml *)

type t =
  | Char      of Uchar.t
  (** 无修饰键的可打印字符，如普通字母、数字、标点 *)

  | Ctrl      of char
  (** Control + 任意 ASCII 字符。
      覆盖 C-a ~ C-z 以及 C-[  C-]  C-\  C-^  C-_ 等符号键。
      char 的值为对应 ASCII 字符本身（不是控制码），
      例如 C-a = Ctrl 'a'，C-[ = Ctrl '[' *)

  | Meta      of Uchar.t
  (** Meta/Alt + 字符，如 M-a、M-x、M-< *)

  | Ctrl_meta of char
  (** Control + Meta + ASCII 字符，如 C-M-x *)

  | Arrow     of [ `Up | `Down | `Left | `Right ]
  | Function  of int
  (** F1~F12，值为 1~12 *)

  | Backspace
  | Delete
  | Enter
  | Tab
  | Escape
  | Page_up
  | Page_down
  | Home
  | End

val pp : Format.formatter -> t -> unit
(** 输出人类可读的表示，如 "C-x"、"M-a"、"F5"、"<backspace>"。
    用于状态栏显示未绑定按键信息。 *)

val of_string : string -> t option
(** 从配置文件中的字符串解析键名，如 "C-x"、"M-x"、"<f5>"。
    返回 None 表示无法识别。 *)
```

---

### `Attr.t`

```ocaml
(* lib/terminal/attr.ml *)

type color =
  | Default
  | Black | Red | Green | Yellow | Blue | Magenta | Cyan | White
  | Bright of [ `Black | `Red | `Green | `Yellow
              | `Blue  | `Magenta | `Cyan | `White ]
  | Rgb of int * int * int
  (** 真彩色。终端不支持时降级为最近的 256 色。 *)

type t = {
  fg        : color;
  bg        : color;
  bold      : bool;
  italic    : bool;
  reverse   : bool;  (** 前景/背景互换，用于光标和选中区高亮 *)
  underline : bool;
}

val default : t
(** fg = Default, bg = Default, 所有修饰均为 false *)
```

---

### `Input.S`（module type）

```ocaml
(* lib/terminal/input_intf.ml *)

module type S = sig
  type t

  val create   : unit -> (t, string) result
  (** 进入 raw mode（Windows: 关闭 ENABLE_PROCESSED_INPUT，
      开启 ENABLE_VIRTUAL_TERMINAL_INPUT；
      Unix: tcsetattr TCSANOW 设置 raw flags）。
      失败时返回 Error 原因字符串，不抛出异常。 *)

  val next_key : t -> Key.t option
  (** 阻塞读取下一个完整按键事件。
      处理多字节 ESC 序列（方向键、Fn 键、Meta via ESC prefix）。
      返回 None 表示 EOF 或不可恢复错误。 *)

  val close    : t -> unit
  (** 恢复终端原始模式。多次调用安全（幂等）。 *)
end
```

---

### `Terminal.S`（module type）

```ocaml
(* lib/terminal/terminal_intf.ml *)

module type S = sig
  type t

  val create      : unit -> (t, string) result
  (** 初始化输出端：
      Windows: SetConsoleMode 开启 ENABLE_VIRTUAL_TERMINAL_PROCESSING；
      Unix: 直接写 ANSI 序列，无需额外初始化。
      内部维护输出缓冲区，所有写操作先写入缓冲，flush 时一次性输出。 *)

  val size        : t -> int * int
  (** 返回 (cols, rows)，当前终端物理尺寸。
      Windows: GetConsoleScreenBufferInfo；
      Unix: ioctl TIOCGWINSZ。 *)

  val move_to     : t -> row:int -> col:int -> unit
  (** 移动光标到 (row, col)，均从 0 开始计数。 *)

  val hide_cursor : t -> unit
  val show_cursor : t -> unit

  val write_char  : t -> Uchar.t -> Attr.t -> unit
  (** 在当前光标位置写入一个 Unicode 字符并应用样式。
      CJK 等宽字符（display width = 2）占两列，调用方负责列计数。 *)

  val write_string : t -> string -> Attr.t -> unit
  (** 写入 UTF-8 字符串。字符串必须是合法 UTF-8，否则行为未定义。
      等价于对每个 Uchar 调用 write_char，但实现上更高效。 *)

  val clear_line  : t -> unit
  (** 从当前光标位置清除到行尾（ESC[K）。 *)

  val clear_screen : t -> unit
  (** 清除整个屏幕并将光标移到左上角。用于强制全量重绘。 *)

  val flush       : t -> unit
  (** 将内部缓冲区一次性写入 stdout。每帧调用一次。 *)

  val close       : t -> unit
  (** 恢复终端状态（显示光标、重置样式）。多次调用安全。 *)
end
```

---

### 平台分发（编译期）

```
lib/terminal/
├── key.ml
├── attr.ml
├── input_intf.ml
├── terminal_intf.ml
├── platform_unix.ml      (* 实现 Input.S + Terminal.S，依赖 Unix 模块 *)
├── platform_win32.ml     (* 实现 Input.S + Terminal.S，通过 C stub 调用 Win32 API *)
└── dune
```

`dune` 文件中用 `select` 在编译期选择平台实现：

```
(select platform.ml from
 ((= %{ocaml-config:system} "win32") -> platform_win32.ml)
 (-> platform_unix.ml))
```

`platform.ml` 不存在于源码中，由 dune 在构建时生成为所选平台文件的副本。Win32 C stub 代码仅在 Windows 下编译，Linux 构建完全不包含 Win32 代码。

---

### 验证用 smoke test 程序

```
bin/term_test/
├── dune    (* (executable (name term_test) (libraries jeditor_terminal)) *)
└── main.ml (* 绘制彩色网格 + 响应按键，验证两个后端均正常工作 *)
```

此程序不进入最终发行版，仅用于手动验证 ISSUE-005 的验收标准。

## Module Boundaries

| 模块 | 对外暴露 | 隐藏 |
|------|---------|------|
| `Key` | `Key.t`、`pp`、`of_string` | ESC 序列解析表、状态机 |
| `Attr` | `Attr.t`、`Attr.default`、`color` | — |
| `Input` | `Input.S` module type，`Input.create/next_key/close` | platform_unix/win32 内部实现 |
| `Terminal` | `Terminal.S` module type，`Terminal.create/...` | 输出缓冲区、ANSI 序列拼接、Win32 API 调用 |

`jeditor_terminal` 库对外只暴露这四个模块。`platform_unix.ml` 和 `platform_win32.ml` 不出现在库的公开接口中。

## Deep Module Opportunities

**`Input` 的 ESC 序列状态机** 是本 issue 最深的复杂度来源。终端发送的原始字节序列（如 `\x1b[A` 表示上箭头，`\x1b[1;5C` 表示 Ctrl+右箭头）需要一个带超时的状态机来区分"单独的 Escape 键"和"ESC 序列的开头"。这个状态机完全隐藏在 `next_key` 后面，调用方永远只看到 `Key.t`。

## Testing Priorities

1. **`Key.of_string` / `Key.pp` 往返测试** — 纯函数，无需终端，最先写
2. **`Input` 序列解析** — 构造原始字节序列，验证 `next_key` 输出正确的 `Key.t`（可用管道模拟 stdin，无需真实终端）
3. **`Terminal` 输出缓冲** — 验证 `flush` 前无字节写入 stdout，`flush` 后字节符合预期 ANSI 序列
4. **`term_test` 手动验证** — 在真实 Windows Terminal 中运行，目测彩色网格和按键响应

## Open Questions

- Win32 的 `ReadConsoleInput` 返回鼠标事件和窗口大小事件，需要在 `next_key` 中静默丢弃鼠标事件，将窗口大小事件转为内部通知（或暂时丢弃，等 ISSUE-008 再处理）。此行为在实现时确认。
