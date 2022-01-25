module HelloJS

open JS.Effect
open JS.TypedObjects
open JS.Window
module U = JS.Primitives.Unsafe

let any_of_js_string (v: U.js_string): Js U.js_any
  = U.js_expr #(_ -> _) "(function(v){return v;})" v

let console_log (s: U.js_string): Js unit
  = (console, "log").(| s |)
    // let _ = meth_call (global `get` (any_of_js_string (to_js_string "console"))) "log" [s] in
    // ()

let test (): Js unit = 
  console_log (U.to_js_string "Hello (JS) world!")

let main (): Js unit = 
  let _ = test () in
  ()
  // set global (any_of_js_string (to_js_string "hi")) (wrap_fun test)

