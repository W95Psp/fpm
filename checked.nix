{ nixlib, mkDerivation, fstar-dependencies, fstar-bin, z3-bin, findutils }:
let
  mkder = import ./library-derivation.nix { inherit nixlib mkDerivation fstar-dependencies findutils; };
  generate-checked = lib:
    let
      src = mkder lib;
      bash-list-of = l: nixlib.concatMapStringsSep " " (x: nixlib.escapeShellArg "${x}") l;
    in
    mkDerivation {
      name = "${lib.name}-checked";
      buildInputs = [fstar-bin z3-bin findutils];
      phases = ["buildPhase" "installPhase"];
      buildPhase = ''
        mkdir checked
        for dependency in ${bash-list-of (map generate-checked lib.dependencies)}; do
           find "$dependency/" \( -type f -or -type l \) -exec ln -fs '{}' ./checked \;
        done
        ${if nixlib.length lib.modules == 0
          then ""
          else ''
          fstar.exe --include ${src}/plugins --include ${src}/modules \
                    --cache_checked_modules --cache_dir ./checked \
                    ${
                      nixlib.concatStringsSep " "
                        (map nixlib.head
                          (builtins.filter
                            (x: !(isNull x))
                            (map
                              (path: builtins.match "^(.*\\.fst)$" (builtins.baseNameOf path))
                              lib.modules
                            )
                          )
                        )
                    }
          ''
         }
      '';
      installPhase = "mv checked $out";
    }
  ;
in
generate-checked

