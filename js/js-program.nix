{ nixlib, mkDerivation, writeShellScriptBin, fstar-bin-flags-of-lib,
  z3-bin, fstar-dependencies, findutils, mkShell, js_of_ocaml, js_of_ocaml-ppx,
  zarith_stubs_js, ...
}@args:
let
  ocaml-program = import ../ocaml-program.nix args;
in
ocaml-prog:
let
  ocaml-byte = ocaml-program (ocaml-prog // {
    target = "byte";
    lflags = "-g -w -31 ${ocaml-prog.lflags or ""}";
    dependencies = (ocaml-prog.dependencies or [])
                   ++ [ (import ./JS-Lib) ];
    ocaml-packages = (ocaml-prog.ocaml-packages or []) ++ [
      {package = js_of_ocaml; name = "js_of_ocaml";}
      {package = js_of_ocaml-ppx; name = "js_of_ocaml-ppx";}
    ];
  });
in
mkDerivation {
  name = "${ocaml-prog.name}.js";
  phases = ["buildPhase" "installPhase"];
  buildInputs = [js_of_ocaml];
  buildPhase = ''
    ln -s ${ocaml-byte} Program.byte
    js_of_ocaml ${./compat.es5.js} ${zarith_stubs_js}/biginteger.js ${zarith_stubs_js}/runtime.js Program.byte --disable genprim
  '';
  installPhase = ''
    cp Program.js $out
  '';
}

