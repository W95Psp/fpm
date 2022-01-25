module JS.TypedObjects

/// This module consists in a layer above `JS.Primitives.Unsafe`,
/// providing typed javascript objects. The type `js_obj` is indexed
/// by a map from properties to types. This module also provides
/// functions to work with such typed objects.


open JS.Effect
module U = JS.Primitives.Unsafe
module L = FStar.List.Tot
module T = FStar.Tactics

irreducible let normMark = ()

(** A key can be either a string or a integer. TODO: support JS numbers and symbols. *)
type js_key
  = | StringJsKind: string -> js_key
    | IntJsKind:         int -> js_key

(** Converts a `js_key` to a js_any *)
[@@normMark]
let js_any_of_js_key (k: js_key): Js U.js_any
  = match k with
  | StringJsKind s -> U.inject (U.to_js_string s)
  | IntJsKind i -> U.inject i

(***** Types for typed objects. *)
(** TODO documentation. *)
[@@normMark]
noeq type js_obj_d = {
  [@@@normMark] props: js_key -> Type;
  [@@@normMark] fn_overloadings: list (list Type * Type)
}
(** A typed object is of type `js_obj f`, with `f` a map from keys of type `js_key` to types.
    Keys that does not belong to an object are to be mapped to `undefinedType`. *)
[@@normMark]
val js_obj': js_obj_d u#a u#b u#c -> Type u#c
(** The type of the `undefined` JavaScript value. *)
val undefinedType: Type
(** The type of the `null` JavaScript value. *)
val nullType: Type

unfold let js_obj d = norm [primops; iota; delta_attr [`%normMark]; delta_only [`%L.map;`%op_Equality]; zeta] (js_obj' d)

(** Utility function. *)
[@@normMark]
let rec list_to_map_rec (#key:eqtype) (l: list (key * Type)) (k: key): Type
  = match l with
  | [] -> undefinedType
  | (k',t)::tl -> if k=k' then t
                else list_to_map_rec tl k
[@@normMark]
let list_to_map (#key:eqtype) (l: list (key * Type)) (k: key): Type
  = match l with
  | [] -> undefinedType
  | (k0,v0)::[] -> if k0=k then v0 else undefinedType
  | (k0,v0)::(k1,v1)::[] -> if k0=k then v0 else if k1=k then v1 else undefinedType
  | (k0,v0)::(k1,v1)::(k2,v2)::[] -> if k0=k then v0 else if k1=k then v1 else if k2=k then v2 else undefinedType
  | _ -> list_to_map_rec l k

(***** Operations on typed objects. *)
(** Gets the property `k` (of type `js_key`) of an object `o`. Prefer (.[]) bellow. *)
val get (#d: _) (o: js_obj' d) (k: js_key): Js (d.props k)
(** Sets the property `k` (of type `js_key`) of an object `o` to the value `v`. Prefer (.[]<-) bellow. *)
val set (#d: _) (o: js_obj' d) (k: js_key) (v: d.props k): Js unit
(** Utility function converting property specifications and overaloadings to `obj_d`. *)
[@@normMark]
unfold let obj_d_of (map: list (string * Type)) fn_overloadings =
  {
    props = list_to_map (L.map (fun (k, t) -> (StringJsKind k,t)) map);
    fn_overloadings = fn_overloadings
  }
(** Creates a typed object litteral. *)
val obj (map: list (string * (t: Type & t)))
  : Js (js_obj (obj_d_of (L.map (fun (k, (|t, _|)) -> (k,t)) map) []))

(***** Overloaded operations on typed objects. *)
(** Typeclass for types that can be coerced into a `js_key`. *)
[@@normMark]
class has_key_coercion (k: Type) = { [@@@normMark] key_coercion: k -> js_key }

(** Values of type `string` can be coerced as `js_key`s. *)
[@@normMark]
instance string_key_coercion: has_key_coercion string = { key_coercion = (fun s -> StringJsKind s) }
(** Values of type `int` can be coerced as `js_key`s. *)
[@@normMark]
instance int_key_coercion: has_key_coercion int = { key_coercion = (fun i -> IntJsKind i) }


(** The expression `o.[k] <- v` sets the property `k` of object `o` to value `v`. *)
let (.[]<-) #d #key {| has_key_coercion key |} ($o: js_obj' d) (k: key)
  : norm [primops; iota; delta_attr [`%normMark]; delta_only [`%L.map;`%op_Equality]; zeta] (d.props (key_coercion k))
  -> Js unit
  = fun v -> set o (key_coercion k) v

(** The expression `o.[k]` gets the property `k` of object `o`. *)
let (.[]) #d #key {| has_key_coercion key |} ($o: js_obj' d) ($k: key)
  : Js (norm [primops; iota; delta_attr [`%normMark]; delta_only [`%L.map;`%op_Equality]; zeta] (d.props (key_coercion k)))
  = get o (key_coercion k)

val call
  (#d: _) (nth: nat) (o: js_obj d) (this: U.js_any)
  (args: list (t: Type & t) {
    match L.nth d.fn_overloadings nth with
    | Some (inT, outT) -> 
          L.length args == L.length inT
        /\ (forall i. dfst (L.index args i) `subtype_of` L.index inT i)
    | None -> False
  }): Js (snd (Some?.v (L.nth d.fn_overloadings nth)))

(***** From n-tuples to lists, TODO move somewhere else. *)
class tup_to_list (a: Type) = {
  extract_type_list: list Type;
  extract_values: (tup: a) -> (l:list (t:Type & t) {
      L.length extract_type_list == L.length l
    /\ (forall i. dfst (L.index l i) == L.index extract_type_list i)
  })
}

instance tup1_to_list a: tup_to_list a = {
  extract_type_list = [a];
  extract_values = (fun x -> [(|a,x|)]);
}

instance tup2_to_list a b: tup_to_list (a * b) = {
  extract_type_list = [a;b];
  extract_values = (fun (x, y) -> [(|a,x|); (|b,y|)]);
}
instance tup3_to_list a b c: tup_to_list (a * b * c) = {
  extract_type_list = [a;b;c];
  extract_values = (fun (x, y, z) -> [(|a,x|); (|b,y|); (|c,z|)]);
}
instance tup4_to_list a b c d: tup_to_list (a * b * c * d) = {
  extract_type_list = [a;b;c;d];
  extract_values = (fun (x, y, z, u) -> [(|a,x|); (|b,y|); (|c,z|); (|d,u|)]);
}
instance tup5_to_list a b c d e: tup_to_list (a * b * c * d * e) = {
  extract_type_list = [a;b;c;d;e];
  extract_values = (fun (x, y, z, u, v) -> [ (|a,x|); (|b,y|); (|c,z|)
                                        ; (|d,u|); (|e, v|)]);
}
instance tup6_to_list a b c d e f: tup_to_list (a*b*c*d*e*f) = {
  extract_type_list = [a;b;c;d;e;f];
  extract_values = (fun (x, y, z, u, v, w) -> [ (|a,x|); (|b,y|); (|c,z|)
                                           ; (|d,u|); (|e,v|); (|f,w|) ]);
}
instance tup7_to_list a b c d e f g: tup_to_list (a*b*c*d*e*f*g) = {
  extract_type_list = [a;b;c;d;e;f;g];
  extract_values = (fun (x, y, z, u, v, w, xx) -> 
                      [ (|a,x|); (|b,y|); (|c,z|)
                      ; (|d,u|); (|e,v|); (|f,w|) 
                      ; (|g,xx|)
                      ]);
}

open Js.TypedObjects.Utils
(***** Calling overloaded JavaScript funtions. *)
(** Calling a overloaded function `o` with arguments `v`.
    The meta-argument `nth` can be set manualy: the `nth` overloading of `o` will be called. *)
let call_overloaded
  (#d: _)
  (#inTup: Type) {| i: tup_to_list inTup |}
  (#[compute_fun_signature d.fn_overloadings i.extract_type_list]nth: nat {nth < L.length d.fn_overloadings})
  (o: js_obj d) (this: U.js_any)
  (v: inTup {normalize_term(
    let inputs, output = L.index d.fn_overloadings nth in
    L.length i.extract_type_list == L.length inputs /\
    (forall j. L.index i.extract_type_list j `subtype_of` L.index inputs j)
  )})
  : Js (normalize_term (snd (L.index d.fn_overloadings nth)))
  = let args = i.extract_values v in
    call #d nth o this args

(** Expression `f.(1,2,3)` calls the JS function `f` with parameters `1`, `2`, `3` *)
let (.())
  (#d: _)
  (#inTup: Type) {| i: tup_to_list inTup |}
  (#[compute_fun_signature d.fn_overloadings i.extract_type_list]nth: nat {nth < L.length d.fn_overloadings})
  (o: js_obj d)
  (v: inTup {normalize_term (
    let inputs, output = L.index d.fn_overloadings nth in
    L.length i.extract_type_list == L.length inputs /\
    (forall j. L.index i.extract_type_list j `subtype_of` L.index inputs j)
  )}) = call_overloaded #d #inTup #i #nth o U.undefined v

val coerce (#d: js_obj_d) (o: U.js_any): js_obj d

noextract 
let extract_descriptor_tac (t: T.term): T.Tac T.term =
    let t = T.norm_term [
      primops; iota; zeta;
      delta
      // delta_attr [`%normMark]; delta_only [`%L.map;`%op_Equality;`%js_obj]
    ] t in
    let fn, args = T.collect_app t in
    let fn = T.inspect fn in
    if not (T.Tv_FVar? fn) then T.fail ("[extract_descriptor_tac:E0] Expected an application, got" ^ T.term_to_string fn);
    let fn = T.implode_qn (T.inspect_fv (T.Tv_FVar?.v fn)) in
    if fn <> `%js_obj' then T.fail ("[extract_descriptor_tac:E1] Expected an application like `js_obj' …`, got `"^fn^" …`");
    match args with
    | [d,_] -> d
    | _ -> T.fail "[extract_descriptor_tac:E2] TODO: write error message"

// let _ = 
//   T.run_tactic (fun _ -> 
//     let t = quote (js_obj (obj_d_of [] [])) in
//     let t = extract_descriptor_tac t in
//     T.print (T.term_to_string t)
//   )

// TODO: unify `o.(|…|)` and `o.(…)`
// pretty easy: take `o` of any type `t`, meta-program decide wether `t` is a tuple
//   - if `t` tuple, then we should behave like `.(|…|)`
//   - otherwise, `.(…)`
let (.(||))
  (#d0: js_obj_d u#0 u#0 u#0)
  (#inTup: Type) {| i: tup_to_list inTup |}
  ($oTup: js_obj d0 * string)
  (#[T.exact (extract_descriptor_tac (quote (d0.props (StringJsKind (snd oTup)))))] d: js_obj_d {
    normalize_term (js_obj d == d0.props (StringJsKind (snd oTup)))
  })
  (#[compute_fun_signature d.fn_overloadings i.extract_type_list]nth: nat {nth < L.length d.fn_overloadings})
  (v: inTup {normalize_term (
    let inputs, output = L.index d.fn_overloadings nth in
    L.length i.extract_type_list == L.length inputs /\
    (forall j. L.index i.extract_type_list j `subtype_of` L.index inputs j)
  )}) = 
    let o, key = oTup in
    let f = o.[key] in
    call_overloaded #d #inTup #i #nth f (U.inject o) v

