# This file provides a recursive function `mk`, that maps a library
# declaration to a library derivation.

# Given `lib` a library, the resulting library derivation is a folder
# with the following structure:

# `./modules/`: contains symbolic links to the F* or OCaml (or JS,
#               C...) modules from the library `lib` itself, and from
#               every of its dependencies;

# `./plugins/`: contains native F* plugins (i.e. OCaml native
#               `*.cmxs`) declared in the library (attribute
#               `lib.plugin-entrypoints`), along with symbolic links
#               to every F* plugins from any of `lib`'s dependencies;

# `./plugin-modules`: a file containing a listing of available plugins.

{ nixlib, mkDerivation, fstar-dependencies, findutils, fstar-bin-flags-of-lib, ... }:
let
  mk = fstar-bin-flags: lib: let
    plugin-entrypoints = lib.plugin-entrypoints or [];
    bash-list-of = l: nixlib.concatMapStringsSep " " (x: nixlib.escapeShellArg "${x}") l;
  in mkDerivation {
    name = "${lib.name}-lib";
    phases = [ "buildPhase" "installPhase" ];
    buildInputs = [findutils fstar-bin-flags.bin] ++ fstar-dependencies;
    buildPhase = ''
      # Prepare folder structure
      mkdir modules plugins
      touch plugin-modules
      echo 'fstar binary: ${fstar-bin-flags.bin}' > debug
      echo 'fstar flags: ${fstar-bin-flags.flags}' >> debug
      
      # Deal with dependencies: create symbolic links
      for dependency in ${bash-list-of (map (mk fstar-bin-flags) lib.dependencies)}; do
         echo "dependency: $dependency" >> debug
         find "$dependency/modules/" \( -type f -or -type l \) -exec ln -fs '{}' ./modules/ \;
         find "$dependency/plugins/" \( -type f -or -type l \) -exec ln -fs '{}' ./plugins/ \;
         cat "$dependency/plugin-modules" >> plugin-modules
      done
      pluginModules=$(cat "plugin-modules" | xargs -IP echo "--load_cmxs P " | paste -sd " ")

      # Deal with `lib`'s own modules
      ${
        nixlib.concatMapStringsSep "\n" (path:
          ''ln -s ${path} ./modules/${nixlib.escapeShellArg (builtins.baseNameOf path)}''
        ) lib.modules
      }

      # Deal with `lib`'s own plugins
      for filename in ${bash-list-of (map builtins.baseNameOf plugin-entrypoints)}; do
         modulename="''${filename%.*}"        # Name of the module (e.g. `A.fst` → `A`)
         echo "$modulename" >> plugin-modules # We register the module in `./plugin-modules`
         ocamlname="''${modulename//./_}"     # `A.B.C.D.fst` is translated as `A_B_C_D.ml`
                                              # here, variable `ocamlname` has no extension
         cmxsname="$ocamlname.cmxs"           # `A.B.C.D.fst` → `A_B_C_D.
         mkdir out                            # Temporary `out`put folder for F*
         # We extract OCaml code from the module declared in file `filename`
         echo "Plugins to load: $(find ./plugins/ \( -type f -or -type l \) -printf "--load_cmxs %P ")"
         fstar.exe ${fstar-bin-flags.flags} \
                   --include ./modules/ --include ./plugins/ \
                   $(echo "$pluginModules") \
                   --extract "* -FStar" --odir out --codegen Plugin "$filename"
         # Before compiling, we link every OCaml module we might dependend on
         cd out
         find ../modules/ \( -type f -or -type l \) \( -name '*.ml' -or -name '*.ml' \) \
              -printf '%P\0' | while IFS= read -r -d ''' f; do
              rm -f "./out/$f" # always prefer the modules given by `lib` or by its dependencies
              ln -s "../modules/$f" "./$f"
         done
         # Compile OCaml extracted code
         ocamlbuild -use-ocamlfind -cflag -g -package fstar-tactics-lib "$cmxsname"
         # Save the CMXS native OCaml library (that is, the native F* plugin)
         cp "_build/$cmxsname" "../plugins/$cmxsname"
         cd ..
         # Remove temporary files
         rm -rf out
      done
    '';
    installPhase = ''
      mkdir $out
      # Make sure no native plugin is mentioned twice (TODO: this should never happen. Throw error?)
      cat plugin-modules | sort -u > $out/plugin-modules
      cp debug $out/debug
      mv modules $out/modules # we install modules
      mv plugins $out/plugins # we install plugins
    '';
  };
in
lib: mk (fstar-bin-flags-of-lib lib) lib
