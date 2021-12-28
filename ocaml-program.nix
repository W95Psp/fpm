{ nixlib, mkDerivation, writeShellScriptBin, writeShellScript, fstar-bin-flags-of-lib, z3-bin, fstar-dependencies, findutils, mkShell, ... }:
let
  validator = import ./validator.nix nixlib;
  library-derivation = import ./library-derivation.nix {
    inherit nixlib mkDerivation fstar-dependencies fstar-bin-flags-of-lib findutils;
  };
  checked = import ./checked.nix {
    inherit nixlib mkDerivation fstar-dependencies fstar-bin-flags-of-lib z3-bin findutils;
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
  fstar-bin-flags = fstar-bin-flags-of-lib lib;
  modules-path = nixlib.escapeShellArg "${der}/modules/";
in
validator' lib
  (mkDerivation {
    name = "${name}";
    phases = ["extractionPhase" "buildPhase" "installPhase"];
    buildInputs = [fstar-bin-flags.bin] ++ fstar-dependencies ++ (map (p: p.package) ocaml-packages);
    extractionPhase = ''
      mkdir ocaml-sources
      fstar.exe ${fstar-bin-flags.flags}\
                --include ${modules-path} \
                --include ${nixlib.escapeShellArg "${der}/plugins/"} \
                $(cat ${nixlib.escapeShellArg "${der}/plugin-modules"} | xargs -IX -- echo "--load_cmxs X" | paste -sd " " -) \
                --extract "* -FStar" --odir ocaml-sources --codegen OCaml \
                ${nixlib.escapeShellArg (builtins.baseNameOf entrypoint)}
    '';
    buildPhase = ''
      # Copy (and possibly overwrite) OCaml modules
      find ${modules-path} \( -name "*.ml" -or -name "*.mli" \) -printf "%P\0" | 
        while IFS= read -r -d ''' filename; do
            modulename="''${filename%.*}"
            ocamlname="''${modulename//./_}.ml"
            if test -f ${modules-path}/"$modulename.fsti" \
               || test -f ${modules-path}/"$modulename.fst"; then
               ln -fs ${modules-path}/"$filename" ocaml-sources/"$ocamlname"
            else
               ln -fs ${modules-path}/"$filename" ocaml-sources/
            fi
        done
      # echo "let _ = exit (if Main.main (Array.to_list Sys.argv) then 0 else 1)" > 
      cd ocaml-sources
      ${
        if isNull driver
        then ''echo "let _ = ${nixlib.head (builtins.match "^(.*)\.fst$" (builtins.baseNameOf entrypoint))}.main ()"''
        else
          if builtins.isString driver
          then "echo ${nixlib.escapeShellArg driver}"
          else
            if builtins.isPath driver
            then "cat ${nixlib.escapeShellArg driver}"
            else throw "`driver` is of type ${builtins.typeOf driver}, expected null, a string or a path."
      } > ${nixlib.escapeShellArg driver-name}.ml
      ocamlbuild -use-ocamlfind -lflags ${nixlib.escapeShellArg lflags} \
                 ${nixlib.concatMapStringsSep " " (p: "-package ${nixlib.escapeShellArg p}") (["fstarlib"] ++ map (p: p.name) ocaml-packages)} \
                 ${nixlib.escapeShellArg "${driver-name}.${target}"}
      cd ..
    '';
    installPhase = ''
      cp ocaml-sources/${nixlib.escapeShellArg "${driver-name}.${target}"} $out
    '';
  })


