{ nixlib, mkDerivation, writeShellScriptBin, writeShellScript, fstar-bin, z3-bin, fstar-dependencies, findutils, mkShell }:
let
  validator = import ./validator.nix nixlib;
  library-derivation = import ./library-derivation.nix {
    inherit nixlib mkDerivation fstar-dependencies findutils;
  };
  checked = import ./checked.nix {
    inherit nixlib mkDerivation fstar-dependencies fstar-bin z3-bin findutils;
  };
in
{
  name,
  modules ? [],
  dependencies,
  entrypoint,
  driver ? null,
  assets ? null, 
  lflags ? "",
  ocaml-packages ? [],
  target ? "native"
}:
let
  lib = {
    inherit name modules dependencies;
  };
  der = library-derivation lib;
  driver-name = "OCamlDriver";
  validator' = lib: next:
    builtins.deepSeq
      ( if nixlib.elem target ["native" "byte"]
        then true
        else throw ''`target` was expected to be "byte" or "native", got "${toString target}"''
      )
      (validator lib next);
in
validator' lib
  (mkDerivation {
    name = "${name}";
    phases = ["extractionPhase" "buildPhase" "installPhase"];
    buildInputs = fstar-dependencies ++ (map (p: p.package) ocaml-packages);
    extractionPhase = ''
      mkdir ocaml-sources
      fstar.exe --include ${nixlib.escapeShellArg "${der}/modules/"} \
                --include ${nixlib.escapeShellArg "${der}/plugins/"} \
                $(cat ${nixlib.escapeShellArg "${der}/plugin-modules"} | xargs -IX -- echo "--load_cmxs X" | paste -sd " " -) \
                --extract "* -FStar" --odir ocaml-sources --codegen OCaml \
                ${nixlib.escapeShellArg (builtins.baseNameOf entrypoint)}
    '';
    buildPhase = ''
      # Copy (and possibly overwrite) OCaml modules
      find "${der}/modules/" \( -name "*.ml" -or -name "*.mli" \) -exec ln -fs {} ocaml-sources \;
      
      # echo "let _ = exit (if Main.main (Array.to_list Sys.argv) then 0 else 1)" > 
      cd ocaml-sources
      echo "let _ = ${nixlib.head (builtins.match "^(.*)\.fst$" (builtins.baseNameOf entrypoint))}.main ()" > ${nixlib.escapeShellArg driver-name}.ml

      ocamlbuild -use-ocamlfind -lflags ${nixlib.escapeShellArg lflags} \
                 ${nixlib.concatMapStringsSep " " (p: "-package ${nixlib.escapeShellArg p}") (["fstarlib"] ++ map (p: p.name) ocaml-packages)} \
                 ${nixlib.escapeShellArg "${driver-name}.${target}"}
      cd ..
    '';
    installPhase = ''
      cp ocaml-sources/${nixlib.escapeShellArg "${driver-name}.${target}"} $out
    '';
  })


