module JS.Primitives.Unsafe

/// This module provides basic bindings to the Unsafe module of the
/// "js_of_ocaml" OCaml library.  (See
/// https://ocsigen.org/js_of_ocaml/latest/api/js_of_ocaml/Js_of_ocaml/Js/Unsafe/index.html)
///
/// Note this module is very basic, and provides no type abstractions or safety features.

open Prims
open JS.Effect
module L = FStar.List.Tot

(***** Types for JavaScript values which encoded differently in F*, or which have no F* equivalent. *)
(** The type of JavaScript strings. *)
val js_string: Type

(** The type of JavaScript booleans. *)
val js_bool: Type

(** The type of JavaScript arrays. *)
val js_array: Type -> Type

(** The type of any other JavaScript value. *)
val js_any: Type

(***** Conversion function for primitive JavaScript types. *)
(** Converts an F* boolean to a JavaScript one. *)
val to_js_bool (b: bool): Js js_bool
(** Converts a JavaScript boolean to an F* one. *)
val of_js_bool (b: js_bool): Js bool

(** Converts an F* string to a JavaScript one. *)
val to_js_string (s: string): Js (js_string)
(** Converts a JavaScript string to an F* one. *)
val of_js_string (s: js_string): Js string

(** Converts an F* list to a JavaScript array. *)
val to_js_array (a: list 'a): Js (array 'a)
(** Converts a JavaScript array to an F* list. *)
val of_js_array (a: js_array 'a): Js (list 'a)

(***** Inject JavaScript expressions. (unsafe) *)
(** Inject a JavaScript expression given a string as a pure computation. (highly unsafe) *)
val js_expr_pure: (#a: Type) -> string -> a
(** Inject a JavaScript expression given a string as a JS computation. (unsafe) *)
unfold let js_expr: (#a: Type) -> string -> Js a
  = js_expr_pure
(** Coerce any value as a `js_any` *)
val inject: (#a:Type u#a) -> a -> Js js_any

(***** Operations on JavaScript objects. *)
(** Gets the property `k` of object `o`. *)
val get (o: js_any) (k: js_any): Js js_any
(** Sets the property `k` of object `o` to `v`. *)
val set (o: js_any) (k: js_any) (v: js_any): Js unit
(** Delete the property `k` of object `o`. *)
val delete (o: js_any) (k: js_any): Js unit
(** Create a new object using constructor `f` and arguments `args`. (basically `new [f]([...args])`) *)
val new_obj (f: js_any) (args: list js_any): Js js_any
(** Creates an object litteral given `values` a list of values. *)
val obj (values: list (string * js_any)): js_any

(***** Dealing with functions. *)
(** Calls a function `f` binding `this` with arguments `args`. *)
val call (f: js_any) (this: js_any) (args: list js_any): Js js_any
(** Calls a function `f` with arguments `args`. (without binding `this`) *)
val fun_call (f: js_any) (args: list js_any): Js js_any
(** Calls the method `f[k]` with arguments `args`. *)
val meth_call (f: js_any) (k: Prims.string) (args: list js_any): Js js_any
(** Wraps the F* unary function `f` as a JavaScript function. *)
val wrap_fun (f:'a -> Js 'b): Js js_any

(***** Global objects. *)
(** The `global` JavaScript object. Uses `globalThis`, `window` or `global`. *)
val global: js_any
(** The `null` JavaScript value. *)
val null: js_any
(** The `undefined` JavaScript value. *)
val undefined: js_any

(***** Dealing with the JavaScript debugger. *)
(** The `debugger` instruction. *)
val debugger: unit -> Js unit

