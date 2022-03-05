{ nixlib, mkDerivation, writeText,
  # runCommand,
  fstar-options-tools, z3-bin, fstar-bin, fstar-dependencies, findutils, mkShell, ... }:
let
  validator = import ./validator.nix nixlib;
  library-derivation = import ./library-derivation.nix {
    inherit nixlib mkDerivation fstar-dependencies fstar-options-tools findutils;
  };
  generate-checked = (import ./checked.nix {
    inherit nixlib mkDerivation fstar-dependencies fstar-options-tools
      writeText z3-bin findutils fstar-bin;
  });
  get-ocaml = {
      name,
      modules ? [],
      dependencies,
      entrypoint,
      driver ? null,
      assets ? null, 
      lflags ? "",
      cmi ? false,
      ocaml-packages ? [],
      target ? "native"
  }:
    let
      lib = {
        name = "${name}-ocaml-program";
        inherit dependencies;
        modules = modules;
        # modules = nixlib.unique ([entrypoint] ++ modules);
      };
      fstar-bin-flags = fstar-options-tools.mk-fstar (fstar-options-tools.options-of-lib lib);
      der = library-derivation fstar-bin-flags lib;
      driver-name = "OCamlDriver";
      validator' = lib: next:
        builtins.deepSeq
          ( if nixlib.elem target ["native" "byte"]
            then true
            else throw ''`target` was expected to be "byte" or "native", got "${toString target}"''
          )
          (validator lib next);
      modules-path = nixlib.escapeShellArg "${der}/modules/";
      implemented-interfaces = nixlib.filter (x:
        builtins.trace ">>>>>>>>>>" (
          let x-path = toString x; in nixlib.any (y:
                builtins.trace ("compare " + x-path + " with " + y)
                  x-path + "i" == toString y
              ) lib.modules)
      ) lib.modules;
    in
      validator' lib
        (mkDerivation {
          name = "${name}";
          phases = ["extractionPhase" "buildPhase" "installPhase"];
      buildInputs = [fstar-bin-flags.bin] ++ fstar-dependencies ++ (map (p: p.package) ocaml-packages);
      extractionPhase = ''
        mkdir ocaml-sources
        if [ ! -z "$FPM_DEBUG_WRAPPER" ]; then
          # set -x
          echo 'skip'
        fi
        echo ${""
          # builtins.readFile (
          #   runCommand "date" {
          #     FSTAR_INCLUDES = [modules-path "${der}/plugins/"];
          #     FSTAR_PLUGINS = (nixlib.splitString "\n" (builtins.readFile "${der}/plugin-modules"));
          #     FSTAR_IN_MODULES = [];
          #   } ''
              
          #   ''
          # )
        }
        # echo "#################################3"
        # echo "#################################3"
        # echo "#################################3"
        # echo '${nixlib.concatMapStringsSep " " nixlib.escapeShellArg (implemented-interfaces ++ [(builtins.baseNameOf entrypoint)])}'
        # echo "#################################3"
        # echo "#################################3"
        # echo "#################################3"
        # TODO: add flag to use cmi: `--cmi --cache_dir $ {nixlib.escapeShellArg (generate-checked TODO-opts lib)}`
        for module in ${nixlib.concatMapStringsSep " " nixlib.escapeShellArg (implemented-interfaces ++ [(builtins.baseNameOf entrypoint)])}; do
          fstar.exe ${fstar-bin-flags.flags}\
                    --include ${modules-path} \
                    --include ${nixlib.escapeShellArg "${der}/plugins/"} \
                    $(cat ${nixlib.escapeShellArg "${der}/plugin-modules"} | xargs -IX -- echo "--load_cmxs X" | paste -sd " " -) \
                    --extract "* -FStar" --odir ocaml-sources --codegen OCaml \
                    "$module"
        done
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
    });
in get-ocaml
