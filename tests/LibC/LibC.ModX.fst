module LibC.ModX
open LibA.Native

open FStar.Tactics

let xLibCModX = 123

let _ = run_tactic (fun _ -> 
    let x = `(sum 123456) in
    let x = norm_term [primops; iota; delta; zeta_full] x in
    print (term_to_string x);
    let x = `(sum 123456) in
    let x = norm_term [primops; iota; delta; zeta_full] x in
    print (term_to_string x);
    let x = `(sum 123456) in
    let x = norm_term [primops; iota; delta; zeta_full] x in
    print (term_to_string x);
    let x = `(sum 123456) in
    let x = norm_term [primops; iota; delta; zeta_full] x in
    print (term_to_string x);
    let x = `(sum 123456) in
    let x = norm_term [primops; iota; delta; zeta_full] x in
    print (term_to_string x);
    let x = `(sum 123456) in
    let x = norm_term [primops; iota; delta; zeta_full] x in
    print (term_to_string x)
  )

