let main_: list string -> FStar.All.ML int =
  _ by ( 
    let open FStar.Tactics in
    let term_eq (t0 t1: term): Tac bool
      = let norm = norm_term [primops; iota; delta; zeta] in
        compare_term (norm t0) (norm t1) = FStar.Order.Eq in
    let i, o = match collect_arr (tc (top_env ()) (`main)) with
    | ([t], c) -> t, ( match inspect_comp c with
                    | C_Total ret _ -> ret
                    | C_GTotal _ _ -> fail "`main` cannot be a ghost computation!"
                    | C_Lemma _ _ _ -> fail "`main` cannot be a lemma!"
                    | C_Eff _ e ret _ -> (match implode_qn e with
                                        | "FStar.All.ML" -> ret
                                        | eff -> fail ("The function `main` should live either in the total or ML effect, not in effect `"^eff^"`")))
    | _ -> fail "`main` should be a unary function" in
    let iF = if term_eq i (`(list string)) then (`(fun v -> v))
        else if term_eq i (`unit)          then (`(fun v -> ()))
        else fail "The argument of `main` should be of type `unit` or `list string`" in
    let oF = if term_eq o (`int)     then (`(fun v -> v))
        else if term_eq o (`nat)     then (`(fun (v: nat) -> v <: int))
        else if term_eq o (`unit)  then (`(fun v -> 0))
        else if term_eq o (`bool)  then (`(function | true -> 0 | _ -> 1))
        else fail "The output type of `main` should be `nat`, `int`, `unit` or `bool`" in
    exact (`(let f (args: list string): FStar.All.ML int = (`#oF) (main ((`#iF) args)) in f))
  )
