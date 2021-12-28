module HelloJS

open JS.Effect
open JS.Primitives.Unsafe

let any_of_js_string (v: js_string): Js js_any
  = js_expr #(_ -> _) "(function(v){return v;})" v

let console_log (s: js_any): Js unit
  = let _ = meth_call (global `get` (any_of_js_string (to_js_string "console"))) "log" [s] in
    ()

let test (): Js unit = 
  console_log (any_of_js_string (to_js_string "Hello (JS) world!"))

let main (): Js unit = 
  let _ = test () in
  set global (any_of_js_string (to_js_string "hi")) (wrap_fun test)

