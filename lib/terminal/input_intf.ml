module type S = sig
  type t

  val create   : unit -> (t, string) result
  (** 进入 raw mode。失败时返回 Error 原因字符串，不抛出异常。 *)

  val next_key : t -> Key.t option
  (** 阻塞读取下一个完整按键事件。
      处理多字节 ESC 序列。返回 None 表示 EOF 或不可恢复错误。 *)

  val close    : t -> unit
  (** 恢复终端原始模式。多次调用安全（幂等）。 *)
end
