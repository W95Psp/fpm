module JS.TypedObjects.Tests

open JS.Effect
open JS.TypedObjects

// TODO: Without `Js _` effect annoation this fails with
//       "Expected 'τ' but … was of type 'τ <: Type'"
[@@expect_failure [12]]
let test0 () =
  let o0: js_obj (obj_d_of ["a", int; "b", int] []) = obj ["a", (|int, 3|); "b", (|int, 34|)] in
  let o: js_obj (obj_d_of ["o",js_obj (obj_d_of ["a", int; "b", int] [])] []) = obj ["o",(|js_obj (obj_d_of ["a", int; "b", int] []), o0|)] in
  let xx: js_obj (obj_d_of ["a", int; "b", int] []) = o.["o"] in
  ()

let test1 (): Js _ =
  let o0 = obj ["a", (|int, 3|); "b", (|int, 34|)] in
  let o = obj ["o",(|js_obj (obj_d_of ["a", int; "b", int] []), o0|)] in
  let y = o.["o"] in
  let xx = o.["o"] in
  ()

assume val test_o0: js_obj (obj_d_of ["a",int;"b",int] [
    ([int;int;int], string);
    ([int;int], string);
    ([int;string], string);
    ([nat], string);
    ([int], string);
    ([string], string)
  ])

let test2 (): Js _ =
  let a = obj ["a", (|int, 3|); "b", (|int, 34|)] in
  let b = obj ["c", (|js_obj (obj_d_of ["a",int;"b",int] []), a|)] in
  let x: js_obj (obj_d_of ["a",int;"b",int] []) = b.["c"] in
  let x = x.["b"] in
  test_o0.["a"] <- (test_o0.["a"] + test_o0.["b"]);
  let x: string = (test_o0).(4,"x") in
  ()

assume val test_o1: js_obj u#0 u#0 u#0 (obj_d_of ["obj", js_obj (
  obj_d_of ["a",int;"b",int] [
    ([int;int;int], string);
    ([int;int], string);
    ([int;string], string);
    ([nat], string);
    ([int], string);
    ([string], string)
  ]
)] [])

unfold let ( @: ) = Mktuple2

let test3 (): Js _ =
  let x: string = (test_o1 @: "obj").(|3,"4"|) in
  ()

