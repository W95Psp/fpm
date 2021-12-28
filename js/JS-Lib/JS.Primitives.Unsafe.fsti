module JS.Primitives.Unsafe

open JS.Effect
module L = FStar.List.Tot

val js_string: Type
val js_bool: Type
val js_array: Type -> Type
val js_any: Type

val to_js_bool (b: bool): Js bool
val of_js_bool (b: js_bool): Js bool
val to_js_string (s: string): Js (js_string)
val of_js_string (s: js_string): Js string
val to_js_array (a: list 'a): Js (array 'a)
val of_js_array (a: js_array 'a): Js (list 'a)

val js_expr_pure: (#a: Type) -> string -> a
unfold let js_expr: (#a: Type) -> string -> Js a
  = js_expr_pure

val get (o: js_any) (k: js_any): Js js_any
val set (o: js_any) (k: js_any) (v: js_any): Js unit
val delete (o: js_any) (k: js_any): Js unit
val call (f: js_any) (this: js_any) (args: list js_any): Js js_any
val fun_call (f: js_any) (args: list js_any): Js js_any
val meth_call (f: js_any) (k: Prims.string) (args: list js_any): Js js_any
val new_obj (f: js_any) (args: list js_any): Js js_any

val obj (values: list (string * js_any)): js_any
val global: js_any

val null: js_any
val undefined: js_any
val inject: (#a:Type u#a) -> a -> Js js_any

val wrap_fun (f:'a -> Js 'b): Js js_any

val debugger: unit -> Js unit
