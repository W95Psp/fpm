module Js.TypedObjects.Utils

module U = JS.Primitives.Unsafe
module L = FStar.List.Tot
module T = FStar.Tactics
module S = FStar.String

let debug_subtype_tac = false
(** Decide wether a type is a subtype of another.
    The result can be wrong; i.e. int is seen as a subtype of nat :(
    But this is enough for choosing a correct overloading.
  *)
let subtype_tac (t0 t1: Type): T.Tac bool =
  let t0_ = T.norm_term [primops; iota; delta; zeta] (quote t0) in
  let t1_ = T.norm_term [primops; iota; delta; zeta] (quote t1) in
  let expr = T.pack (T.mk_app (`magic) [t0_,T.Q_Implicit;(`()),T.Q_Explicit]) in
  let ascribtion = T.Tv_AscribedT expr t1_ None in
  let t = T.pack ascribtion in
  let r = T.trytac (fun _ -> T.tc (T.top_env ()) t) in
  if debug_subtype_tac && Some? r then 
    T.print ( "[subtype_tac] tc result: " ^ T.term_to_string (Some?.v r));
  let r = Some? r in
  if debug_subtype_tac then (
    T.print ( "[subtype_tac] crafted term is: "
            ^  "`" ^ T.term_to_string (quote t) ^  "`"
            );
    T.print ( "[subtype_tac] `subtype_tac ("
            ^ T.term_to_string t0_^") ("
            ^ T.term_to_string t1_^")` ↝ "
            ^ string_of_bool r
            )
  );
  r

#push-options "--print_implicits"
let _ = 
  // assert (true) by (
  T.run_tactic (fun _ ->
    T.guard (subtype_tac int int);
    T.guard (subtype_tac nat int);
    T.guard (subtype_tac (x:int{x > 323}) int);
    T.guard (not (subtype_tac string nat));
    // :(
    T.guard (subtype_tac int nat);
    ()
  )
#pop-options

// [F*] TAC>> [subtype_tac] `subtype_tac (Prims.int <: Prims.Tot Type0) (Prims.int <: Prims.Tot Type0)` ↝ true
// [F*] TAC>> [subtype_tac] `subtype_tac (Prims.int <: Prims.Tot Type0) (Prims.string <: Prims.Tot Type0)` ↝ true


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



(** Meta-program that chooses the appropriate overloading for a JavaScript function. 
    Given `sigs` a list of overloadings, and `inputs` the inputs arguments, returns the index of most appropriate overloading (in `sigs`). *)
#push-options "--z3rlimit 400"
let rec while_multiple (error_header: nat -> string) (inputs_str: _ -> T.Tac _) (nb: nat) (len: nat)
      (inputs:_{L.length inputs == len}) (i: nat{i<=len})
      (l: list (nat * (list Type * Type)) {
        ( forall i. L.memP i l ==> (
            L.length (fst (snd i)) == len /\
            fst i < nb
          ))
        /\ Cons? l
      })
     : T.Tac (n: nat{n < nb})
     = if i=len then
          match l with
        | [hd] -> fst hd 
        | _::_ ->
          T.fail ( error_header 3 ^ "A JavaScript function was called with "^string_of_int len^" arguments"
                 ^ ", but it has multiple overloadings with exactly "^string_of_int len^" arguments. "
                 ^ "The meta-program was not able to distinguish between them: you should "
                 ^ "set manually the meta-argument `nth` when calling the function."
                 ^ "The "^string_of_int len^"-arguments overloadings of this JavaScript function are:\n"
                 ^ S.concat "\n" (T.map (fun (nth,(inT, outT)) -> 
                                       "• [nth="^string_of_int (nth <: nat)^"]"
                                       ^ "(" ^ S.concat ", " (T.map (fun t -> T.term_to_string (quote t)) inT) ^ "): " ^ T.term_to_string (quote outT)
                                 ) l)
                 )
       else match l with
       | [hd] -> fst hd
       | _ -> let f (tt: _ {L.memP tt l}): T.Tac bool = subtype_tac (L.index inputs i) (L.index (fst (snd tt)) i) in
             let l' = tfilter l f in
             if Nil? l' then
               ( let inputs_str: string = inputs_str () in
                 let details = S.concat "\n" (T.map (fun (nth,(inT, outT)) ->
                                              "• [nth="^string_of_int (nth <: nat)^"]"
                                              ^ "(" ^ S.concat ", " (T.map (fun t -> T.term_to_string (quote t)) inT) ^ "): " ^ T.term_to_string (quote outT)
                                        ) l) in
                 T.fail ( error_header 4 ^ "Subtyping error: when calling a JavaScript function with "^string_of_int len^" arguments"
                        ^ ", none of the following types matched the supplied arguments ("^inputs_str^"):\n"
                        ));
             while_multiple error_header inputs_str nb len inputs (i+1) l'

let resolve_fun_signature
  (sigs: list (list Type * Type)) (inputs: list Type)
  : T.Tac (n:int{n < L.length sigs})
  = let len = L.length inputs in
    let sigs': l: list (nat * (list Type * Type)) {
        forall x. L.memP x l ==> fst x < L.length sigs
      } = withIndex sigs in
    let correct_size: l: list (nat * (list Type * Type)) {
        forall x. L.memP x l ==> (
            L.length (fst (snd x)) == len
          /\ fst x < L.length sigs'
        )
      }
      = L.filter (fun (i, (inT, outT)) -> L.length inT = len) sigs' in
    let inputs_str (): T.Tac string =
      FStar.String.concat ", " (T.map (fun t -> "`" ^ T.term_to_string (quote t) ^ "`") inputs)
    in
    let error_header (code: nat) = "[resolve_fun_signature:E"^string_of_int code^"] " in
    // let error (s: string): T.Tac unit = T.fail ( ^ s) in
    if Nil? correct_size then
      T.fail ( error_header 1 ^ "A JavaScript function was called with "
             ^ string_of_int (L.length inputs) ^ " arguments ("
             ^ inputs_str () ^ "), but the function in stake has " 
             ^ string_of_int (L.length sigs)
             ^ " overloadings, and none of them are of arity " ^ string_of_int (L.length inputs)
             ^ "."
             ^ "The overloadings of this JavaScript function are:\n"
             ^ S.concat "\n" (T.map (fun (inT, outT) -> 
                                   "• " ^ "(" ^ S.concat ", " (T.map (fun t -> T.term_to_string (quote t)) inT) ^ "): " ^ T.term_to_string (quote outT)
                             ) sigs)
             );
    if len = 0 && L.length correct_size <> 1 then
      T.fail ( error_header 2 ^ "A JavaScript function was called without argument"
             ^ ", but it has multiple overloadings with zero arguments. "
             ^ "The meta-program was not able to distinguish between them: you should "
             ^ "set manually the meta-argument `nth` when calling the function."
             ^ "The zero-arguments overloadings of this JavaScript function are:\n"
             ^ S.concat "\n" (T.map (fun (nth,(inT, outT)) -> 
                                   "• [nth="^string_of_int (nth <: nat)^"]"
                                   ^ "(" ^ S.concat ", " (T.map (fun t -> T.term_to_string (quote t)) inT) ^ "): " ^ T.term_to_string (quote outT)
                             ) correct_size)
             );
    while_multiple error_header inputs_str (L.length sigs') len inputs 0 correct_size

(** Meta-programs that crafts a term w.r.t. `resolve_fun_signature`. *)
let compute_fun_signature
  (sigs: list (list Type * Type)) (inputs: list Type)
  : T.Tac unit
  = let n = resolve_fun_signature sigs inputs in
    let n = quote n in
    T.exact n

