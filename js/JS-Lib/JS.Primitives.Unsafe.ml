open Js_of_ocaml

type js_string = Js.js_string Js.t
type js_bool = bool Js.t
type 'a js_array = 'a Js.js_array Js.t
type js_any = Js.Unsafe.any

let to_js_bool (b: Prims.bool): js_bool = Js.bool b
let of_js_bool (b: js_bool): Prims.bool = Js.to_bool b
let to_js_string (s: Prims.string): js_string = Js.string s
let of_js_string (s: js_string): Prims.string = Js.to_string s

let to_js_array (a: 'a list): 'a js_array = Js.array (Array.of_list a)
let of_js_array (a: 'a js_array): 'a list = Array.to_list (Js.to_array a)

let get (o: js_any) (k: js_any): js_any = Js.Unsafe.get o k
let set (o: js_any) (k: js_any) (v: js_any): unit = Js.Unsafe.set o k v
let delete (o: js_any) (k: js_any): unit = Js.Unsafe.delete o k
let call (f: js_any) (this: js_any) (args: js_any list): js_any
  = Js.Unsafe.call f this (Array.of_list args)
let fun_call (f: js_any) (args: js_any list): js_any
  = Js.Unsafe.fun_call f (Array.of_list args)
let meth_call (f: js_any) (k: Prims.string) (args: js_any list): js_any
  = Js.Unsafe.meth_call f k (Array.of_list args)
let new_obj (f: js_any) (args: js_any list): js_any
  = Js.Unsafe.new_obj f (Array.of_list args)
(* let new_obj_arr (f: js_any) (args: js_any js_array): js_any
 *   = Js.Unsafe.new_obj_arr f args *)

let obj (values: (string * js_any) list): js_any
  = Js.Unsafe.obj (Array.of_list values)

let global: js_any = Js.Unsafe.js_expr "(globalThis || window || global)"

let null: js_any = Js.Unsafe.js_expr "null"
let undefined: js_any = Js.Unsafe.js_expr "undefined"

let inject (x: 'a): js_any = Js.Unsafe.js_expr "(function(x){return x;})" x

let wrap_fun (f: 'a -> 'b): js_any
   = Js.Unsafe.js_expr "(function(x){return x;})" (Js.wrap_callback f)

(* let obj (keys: (string * any) list)
 *   = Js.Unsafe.obj (Array.of_list keys) *)

let debugger = Js.debugger

let js_expr_pure (s: string): 'a
  = Js.Unsafe.js_expr s

