module JS.Effect

new_effect JS = DIV
effect Js (a: Type) = JS a (pure_null_wp a)

unfold let lift_div_js (a:Type) (wp:pure_wp a) = wp
sub_effect DIV ~> JS = lift_div_js
