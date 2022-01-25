# This file provides a function that cooks a dev environement given a library.

# It basically generate a library derivation, generate checked files
# for dependencies and sets up a few FPM_* environment variables.

# It also prepare a special `fstar.exe` sensible to those FPM_*
# environement variables (via a shellHook). See
# ./scripts/fstar-wrapper.sh and ./scripts/prepare-dev-env.sh for more
# details.

{ nixlib, writeShellScriptBin, fstar-bin-flags-of-lib, z3-bin, mkShell, ... }@deps:
lib:
let bin-flags = fstar-bin-flags-of-lib lib;
    empty-lib = { name = "${lib.name}-dependencies";
                  modules = [];
                  inherit (lib) dependencies;
                  plugin-entrypoints = []; }; in
mkShell rec {
  name = "${lib.name}-dev-env";
  
  FPM_LIB_NAME = lib.name;
  FPM_LOCAL_MODULES = nixlib.concatStringsSep ":" (map toString lib.modules);
  FPM_LIB_PATH          = import ./library-derivation.nix deps empty-lib;
  FPM_LIB_CHECKED_FILES = import ./checked.nix            deps empty-lib;
  
  FSTAR_BINARY = "${bin-flags.bin}/bin/fstar.exe";

  nativeBuildInputs = [ (writeShellScriptBin "fstar.exe" (builtins.readFile ./scripts/fstar-wrapper.sh))
                        z3-bin ];
  shellHook = "source ${./scripts/prepare-dev-env.sh}";
}
