module JS.TypedObjects

module U = JS.Primitives.Unsafe
module L = FStar.List.Tot
open JS.Effect

noeq
type js_obj' (d: js_obj_d u#a u#b u#c) = | JsObj : v:U.js_any -> js_obj' d
let undefinedType = U.js_any
let nullType = U.js_any

let unsafe_coerce #t (v: 'a): Js t = U.js_expr "(function(x){return x;})"
let unsafe_coerce_pure #t (v: 'a): t = U.js_expr_pure "(function(x){return x;})"

let get o k   = unsafe_coerce (U.get (JsObj?.v o) (js_any_of_js_key k))
let set o k v = U.set (JsObj?.v o) (js_any_of_js_key k) (unsafe_coerce v)

let obj map
  = let o = U.obj (L.map (fun (key, (|_, v|)) -> key, unsafe_coerce_pure v) map) in
    unsafe_coerce o

irreducible let t_list _ = unit

let call #d nth o this args
  = unsafe_coerce (U.call (unsafe_coerce o) (unsafe_coerce this) (unsafe_coerce args))

let coerce (#d: js_obj_d) (o: U.js_any): js_obj' d
  = JsObj (unsafe_coerce_pure o)

