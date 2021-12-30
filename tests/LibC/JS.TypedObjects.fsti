module JS.TypedObjects

/// This module consists in a layer above `JS.Primitives.Unsafe`,
/// providing typed javascript objects. The type `js_obj` is indexed
/// by a map from properties to types. This module also provides
/// functions to work with such typed objects.


open JS.Effect
module U = JS.Primitives.Unsafe
module L = FStar.List.Tot
module T = FStar.Tactics

(** A key can be either a string or a integer. TODO: support JS numbers and symbols. *)
type js_key
  = | StringJsKind: string -> js_key
    | IntJsKind:         int -> js_key

(** Converts a `js_key` to a js_any *)
let js_any_of_js_key (k: js_key): Js U.js_any
  = match k with
  | StringJsKind s -> U.inject (U.to_js_string s)
  | IntJsKind i -> U.inject i

(***** Types for typed objects. *)
(** TODO documentation. *)
noeq type js_obj_d = {
  props: js_key -> Type;
  callable: list (list Type * Type)
}
(** A typed object is of type `js_obj f`, with `f` a map from keys of type `js_key` to types.
    Keys that does not belong to an object are to be mapped to `undefinedType`. *)
val js_obj: js_obj_d -> Type
(** The type of the `undefined` JavaScript value. *)
val undefinedType: Type
(** The type of the `null` JavaScript value. *)
val nullType: Type

(** Utility function. *)
let rec list_to_map (#k:eqtype) (l: list (k * Type)): k -> Type
  = match l with
  | [] -> (fun _ -> undefinedType)
  | (k,t)::tl  -> (fun k' -> if k=k' then t
                                else list_to_map tl k')

(***** Operations on typed objects. *)
(** Gets the property `k` (of type `js_key`) of an object `o`. Prefer (.[]) bellow. *)
val get (#d: _) (o: js_obj d) (k: js_key): Js (d.props k)
(** Sets the property `k` (of type `js_key`) of an object `o` to the value `v`. Prefer (.[]<-) bellow. *)
val set (#d: _) (o: js_obj d) (k: js_key) (v: d.props k): Js unit
(** TODO doc. *)
unfold let desc_obj (map: list (string * (t: Type & t))) callable =
  normalize_term ({
    props = list_to_map (L.map (fun (k, (|t, _|)) -> (StringJsKind k,t)) map);
    callable = callable
  })
(** Creates a typed object litteral. *)
val obj (map: list (string * (t: Type & t)))
  : Js (js_obj (desc_obj map []))

(***** Overloaded operations on typed objects. *)
(** Typeclass for types that can be coerced into a `js_key`. *)
class has_key_coercion (k: Type) = { key_coercion: k -> js_key }

(** Values of type `string` can be coerced as `js_key`s. *)
instance string_key_coercion: has_key_coercion string = { key_coercion = (fun s -> StringJsKind s) }
(** Values of type `int` can be coerced as `js_key`s. *)
instance int_key_coercion: has_key_coercion int = { key_coercion = (fun i -> IntJsKind i) }

(** The expression `o.[k] <- v` sets the property `k` of object `o` to value `v`. *)
let (.[]<-) #d #key {| has_key_coercion key |} (o: js_obj d) (k: key): normalize_term (d.props (key_coercion k)) -> Js unit
  = fun v -> set o (key_coercion k) v

(** The expression `o.[k]` gets the property `k` of object `o`. *)
let (.[]) #d #key {| has_key_coercion key |} (o: js_obj d) (k: key): Js (normalize_term (d.props (key_coercion k)))
  = get o (key_coercion k)

val call
  (#d: _) (nth: nat) (o: js_obj d) (this: U.js_any)
  (args: list (t: Type & t) {
    match L.nth d.callable nth with
    | Some (inT, outT) -> 
          L.length args == L.length inT
        /\ (forall i. dfst (L.index args i) `subtype_of` L.index inT i)
    | None -> False
  }): Js (snd (Some?.v (L.nth d.callable nth)))

(***** From n-tuples to lists, TODO move somewhere else. *)
class tup_to_list (a: Type) = {
  extract_type_list: list Type;
  extract_values: (tup: a) -> (l:list (t:Type & t) {
      L.length extract_type_list == L.length l
    /\ (forall i. dfst (L.index l i) == L.index extract_type_list i)
  })
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

(***** Util. functions, TODO move somewhere else. *)

let subtype_tac (t0 t1: Type): T.Tac bool =
  let binder = T.fresh_binder (quote t0) in
  let body = T.Tv_AscribedT (T.binder_to_term binder) (quote t1) None in
  let t = T.pack (T.Tv_Abs binder (T.pack body)) in
  Some? (T.trytac (fun _ -> T.tc (T.top_env ()) t))

let rec tfilter_h (ref: list 'a) (f: (x:'a{L.memP x ref}) -> T.Tac bool) (l: list 'a{forall i. L.memP i l ==> L.memP i ref})
  : T.Tac (l': list 'a {forall x. L.memP x l' ==> L.memP x ref}) 
  = match l with
  | [] -> []
  | hd::tl -> if f hd then hd::(tfilter_h ref f tl) else tfilter_h ref f tl

let tfilter (ref: list 'a) (f: (x:'a{L.memP x ref}) -> T.Tac bool)
  : T.Tac (l': list 'a {forall x. L.memP x l' ==> L.memP x ref}) 
  = tfilter_h ref f ref

let rec withIndex_h
  (ref:list 'a)
  (n:nat{n<=L.length ref})
  (l:list 'a {n + L.length l = L.length ref})
  : Tot (r:list (nat*'a) {(forall x. L.memP x r ==> fst x < L.length ref) /\ L.length r == L.length l}) (decreases l)
= match l with
| [] -> []
| hd::tl -> (n, hd)::withIndex_h ref (n+1) tl

let withIndex (l: list 'a): r:list (nat * 'a){
    L.length l == L.length r /\ (forall x. L.memP x r ==> fst x < L.length l)
  } = withIndex_h l 0 l


let rec filter_lemma (l: list 'a) f
  : Lemma (forall x. L.memP x (L.filter f l) ==> L.memP x l)
          [SMTPat (L.filter f l)]
  = match l with | [] -> () | _::tl -> filter_lemma tl f
let rec lemma_nth (l: list 'a) (n: nat)
  : Lemma (requires n < L.length l) 
          (ensures 
              (Some? (L.nth l n))
            /\ (Some?.v (L.nth l n) == L.index l n)
          )
          [SMTPat (L.nth l n)]
  = match l,n with
  | _, 0 | [], _ -> ()
  | hd::tl, _ -> lemma_nth tl (n-1)

(***** Calling overloaded JavaScript funtions. *)
(** Meta-program that choose the appropriate overloading for a JavaScript function. 
    Given `sigs` a list of overloadings, and `inputs` the inputs arguments, returns the index of most appropriate overloading (in `sigs`). *)
let resolve_fun_signature
  (sigs: list (list Type * Type)) (inputs: list Type)
  : T.Tac (n:int{n < L.length sigs})
  = let len = L.length inputs in
    let sigs': l: list (nat * (list Type * Type)) {
        forall x. L.memP x l ==> fst x < L.length sigs
      } = withIndex sigs in
    assert (L.length sigs' == L.length sigs);
    let correct_size: l: list (nat * (list Type * Type)) {
        forall x. L.memP x l ==> (
            L.length (fst (snd x)) == len
          /\ fst x < L.length sigs'
        )
      }
      = L.filter (fun (i, (inT, outT)) -> L.length inT = len) sigs' in
    if Nil? correct_size then 
      T.fail "Bad arity for JS function.";
    if len = 0 && L.length correct_size <> 1 then
      T.fail "JS function call: cannot decide between TODO";
    let rec while_multiple (nb len: nat) 
      (inputs:_{L.length inputs == len}) (i: nat{i<=len})
      (l: list (nat * (list Type * Type)) {
        forall i. L.memP i l ==> (
          L.length (fst (snd i)) == len /\
          fst i < nb
        )
      })
     : T.Tac (n: nat{n < nb})
     = if i=len then T.fail "JS function call: could not distinguish."
       else match l with
       | [] -> T.fail "JS function call: wrong type."
       | hd::[] -> fst hd
       | _ -> let f (tt: _ {L.memP tt l}): T.Tac bool = subtype_tac (L.index inputs i) (L.index (fst (snd tt)) i) in
             while_multiple nb len inputs (i+1) (tfilter l f)
    in
    while_multiple (L.length sigs') len inputs 0 correct_size

(** Meta-programs that crafts a term w.r.t. `resolve_fun_signature`. *)
let compute_fun_signature
  (sigs: list (list Type * Type)) (inputs: list Type)
  : T.Tac unit
  = let n = resolve_fun_signature sigs inputs in
    let n = quote n in
    T.exact n

(** Calling a overloaded function `o` with arguments `v`.
    The meta-argument `nth` can be set manualy: the `nth` overloading of `o` will be called. *)
let call_overloaded
  (#d: _)
  (#inTup: Type) {| i: tup_to_list inTup |}
  (#[compute_fun_signature d.callable i.extract_type_list]nth: nat {nth < L.length d.callable})
  (o: js_obj d) (this: U.js_any)
  (v: inTup {normalize_term(
    let inputs, output = L.index d.callable nth in
    L.length i.extract_type_list == L.length inputs /\
    (forall j. L.index i.extract_type_list j `subtype_of` L.index inputs j)
  )})
  : Js (normalize_term (snd (L.index d.callable nth)))
  = let args = i.extract_values v in
    call #d nth o this args

(** Expression `f.(1,2,3)` calls the JS function `f` with parameters `1`, `2`, `3` *)
let (.())
  (#d: _)
  (#inTup: Type) {| i: tup_to_list inTup |}
  (#[compute_fun_signature d.callable i.extract_type_list]nth: nat {nth < L.length d.callable})
  (o: js_obj d)
  (v: inTup {normalize_term (
    let inputs, output = L.index d.callable nth in
    L.length i.extract_type_list == L.length inputs /\
    (forall j. L.index i.extract_type_list j `subtype_of` L.index inputs j)
  )}) = call_overloaded #d #inTup #i #nth o U.undefined v

let test () =
  let l = [
              ("a", (|int, 3|));
              ("b", (|int, 34|));
          ] in
  let o: js_obj (desc_obj l []) = obj l in
  let o: js_obj (desc_obj l [
    ([int;int], string)
  ]) = magic () in
  o.["a"] <- (o.["a"] + o.["b"]);
  let x: string = o.(4,5) in
  ()
