{ nixlib, mkDerivation, writeShellScriptBin, writeShellScript, fstar-bin-flags-of-lib, fstar-bin, z3-bin, fstar-dependencies, findutils, mkShell }:
let
  library-derivation = import ./library-derivation.nix {
    inherit nixlib mkDerivation fstar-dependencies fstar-bin-flags-of-lib findutils;
  };
  checked = import ./checked.nix {
    inherit nixlib mkDerivation fstar-dependencies fstar-bin fstar-bin-flags-of-lib z3-bin findutils;
  };
  FPM_LOCAL_MODULES-script = ''
    IFS=':' read -ra modules <<< "$FPM_LOCAL_MODULES"
    FPM_LIB_ROOT="$PWD"
    FSTAR_EXTRA_INCLUDES=$(
      ( for module in "''${modules[@]}"; do
          IFS='/' read -ra chunks <<< "$module"
          for i in $(seq 1 "''${#chunks[@]}"); do
              p="$FPM_LIB_ROOT/$(IFS=/ ; echo "''${chunks[*]:$i}")"
              test -f "$p" && { 
                dirname "$p"
                break
              }
          done
        done
      ) | sort -u | paste -sd ":" -
    )
    SEP=":"
    if test -z "$FSTAR_EXTRA_INCLUDES" || test -z "$FSTAR_INCLUDES"; then
       SEP=":"
    fi 
    FSTAR_INCLUDES="$FSTAR_INCLUDES$SEP$FSTAR_EXTRA_INCLUDES"
  '';
in
lib:
let
  fstar-bin-flags = fstar-bin-flags-of-lib lib;
  fstar-script = ''
    IFS=':' read -ra includes <<< "$FSTAR_INCLUDES"
    if [ -z "$FPM_DEBUG_WRAPPER" ]; then
       set -x
    fi
    ${fstar-bin-flags.bin}/bin/fstar.exe ${fstar-bin-flags.flags} \
          $(for i in "''${includes[@]}"; do printf -- "--include %s " "$i"; done) \
          $(test -z "$FPM_LIB_PATH" || (cat "$FPM_LIB_PATH/plugin-modules" | xargs -IX -- echo "--load_cmxs X" | paste -sd " " -)) \
          $([ -z "$FPM_LIB_CHECKED_FILES" ] || {
              if [[ $* == *--cache_dir* ]]; then
                : # If a cache_dir is specified, it overrides our setting
              else
                CHECKED_CACHE_PATH="$FPM_LIB_CHECKED_FILES"
                if [[ $* == *--cache_checked_modules* ]]; then
                   CHECKED_CACHE_PATH="./.cache-checked/"
                   mkdir -p "$CHECKED_CACHE_PATH"
                   find "$FPM_LIB_CHECKED_FILES/" \( -type f -or -type l \) -exec cp -f --no-preserve=mode '{}' "$CHECKED_CACHE_PATH" \;
                fi   
                echo "--cache_dir $CHECKED_CACHE_PATH"
              fi
          }
          ) \
          "$@"
  '';
empty-lib = {
  name = "${lib.name}-dependencies";
      modules = [];
      inherit (lib) dependencies;
      plugin-entrypoints = [];
  };
in
mkShell rec {
  name = "${lib.name}-dev-env";
  FPM_NAME = lib.name;
  FPM_LOCAL_MODULES = nixlib.concatStringsSep ":" (map toString lib.modules);
  FPM_LIB_PATH = library-derivation empty-lib;
  FPM_LIB_CHECKED_FILES = checked empty-lib;
  FSTAR_INCLUDES = nixlib.makeSearchPath "" ["${FPM_LIB_PATH}/plugins" "${FPM_LIB_PATH}/modules"];
  nativeBuildInputs = [
    (writeShellScriptBin "fstar.exe" fstar-script)
    (writeShellScriptBin "fstar-env-var" fstar-script)
    z3-bin
  ];
  shellHook = ''
    ${FPM_LOCAL_MODULES-script}
  '';
}
