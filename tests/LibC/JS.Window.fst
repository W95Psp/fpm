module JS.Window

module U = JS.Primitives.Unsafe
open JS.Effect
open JS.TypedObjects

let console: js_obj (obj_d_of [
    "log", js_obj (obj_d_of [] [
      [string], unit;
      [U.js_string], unit;
      [string;string], unit;
      [U.js_string;U.js_string], unit;
    ])
  ] []) 
  = U.js_expr_pure "console"


