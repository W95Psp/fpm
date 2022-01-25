{ nixlib, mkDerivation, writeText, fstar-dependencies, fstar-bin, z3-bin,
  fstar-bin-flags-of-lib, findutils, ... }:
let
  mkder = import ./library-derivation.nix { inherit nixlib mkDerivation fstar-dependencies findutils fstar-bin-flags-of-lib; };
  generate-checked = lib:
    let
      src = mkder lib;
      bash-list-of = l: nixlib.concatMapStringsSep " " (x: nixlib.escapeShellArg "${x}") l;
      module-names = (map nixlib.head
                          (builtins.filter
                            (x: !(isNull x))
                            (map
                              (path: builtins.match "^(.*\\.fsti?)$" (builtins.baseNameOf path))
                              lib.modules
                            )
                          )
                        );
    in
      # TODO: this won't work for real
      # Gotta generate a dependency file, then a makefile
      # then run make so that we generate checked in a correct order
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
          if [ -z "$FPM_DEBUG_WRAPPER" ]; then
             set -x
          fi
          export PLUGINS_PATH='${src}/plugins'
          export MODULES_PATH='${src}/modules'
          export MODULES_NAMES='${nixlib.concatStringsSep " " module-names}'
          make -f ${writeText "Makefile" ''
FSTAR=fstar.exe --include $(PLUGINS_PATH) --include $(MODULES_PATH) \
                --cache_checked_modules --cache_dir ./checked \
                --warn_error -321

all: $(addprefix checked/,$(MODULES_NAMES:=.checked))

.depends:
	$(FSTAR) --dep full $(MODULES_NAMES) > .depends
include .depends

checked/%.checked:
	$(FSTAR) --cache_checked_modules "$*"
''} all
          ''
         }
      '';
      installPhase = "mv checked $out";
    }
  ;
in
generate-checked

