{
  description = "FPM (the F* Package Manager)";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    
    # FStar binaries
    fstar-flake.url = "github:W95Psp/nix-flake-fstar";
    
    # Missing chunks for JS extraction
    zarith_stubs_js = {
      url = "github:janestreet/zarith_stubs_js";
      flake = false;
    };
  };
  
  outputs = { self, nixpkgs, flake-utils, zarith_stubs_js, fstar-flake }:
    let
      nixlib = nixpkgs.lib;
      functions = system: fstar-options:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs-fstar = fstar-flake.packages.${system};
          tools = fstar-flake.lib.${system};
          fstar-bin-tools = import ./fstar-options.nix nixlib;
          fstar-bin-flags-of-lib = lib: fstar-bin-tools.mk-fstar system fstar-flake (fstar-bin-tools.options-of-lib lib);
          opt = {
            inherit nixlib fstar-bin-flags-of-lib;
            inherit (pkgs) writeShellScriptBin writeText mkShell findutils;
            fstar-dependencies = pkgs-fstar.fstar.buildInputs;
            fstar-bin = pkgs-fstar.fstar;
            z3-bin = pkgs-fstar.z3;
            mkDerivation = pkgs.stdenv.mkDerivation;
          };
        in
          {
            library-derivation = import ./library-derivation.nix opt;
            library-dev-env = import ./library-dev-env.nix opt;
            ocaml-program = import ./ocaml-program.nix opt;
            js-program = import ./js/js-program.nix (opt // {
              inherit (pkgs.ocamlPackages) js_of_ocaml js_of_ocaml-ppx;
              inherit zarith_stubs_js;
            });
          };
      # Given a library `lib`, and a set of binary targets (`(ocaml|js)-programs`)
      # `mkFlake` produces a flake output
      mkFlake = { lib ? null,
                  fstar-options ? {},
                  ocaml-programs ? [],
                  js-programs ? []}:
        # Ensure `lib` is validated as a correct library declaration
        import ./validator.nix nixlib lib (
          { inherit lib; /* the flake has an attribute containing the library declaration itself */ } //
          # For every supported system
          flake-utils.lib.eachSystem [ "x86_64-darwin" "x86_64-linux" "aarch64-linux"]
            (system:
              let
                f = functions system fstar-options;
                s = {
                  fstar-lib = lib;
                  # For each JS or OCaml program, we generate a derivation
                  apps = builtins.mapAttrs (_: bin: {
                    type = "app";
                    program = "${bin}";
                  }) s.packages;
                  # apps = nixlib.listToAttrs (
                  #   (map (prog: {name = prog.name; value = s.${name};}) ocaml-programs);
                  packages = nixlib.listToAttrs (
                    (map (prog: {name = prog.name; value = f.ocaml-program prog;}) ocaml-programs) ++
                    (map (prog: {name = prog.name; value = f.js-program prog;}) js-programs));
                  # For each JS or OCaml program, we generate a specific devShell 
                  devShells = nixlib.listToAttrs (
                    let h = more: prog: {
                          name = prog.name;
                          value = f.library-dev-env (lib // {
                            name = lib.name + "-" + prog.name;
                            dependencies = nixlib.unique (lib.dependencies ++ prog.dependencies ++ more);
                          });
                        };
                    in (map (h []) ocaml-programs) ++ (map (h [(import ./js/JS-Lib)]) js-programs)
                  );
                  # We also want a generic lib-related devShell
                  devShell = f.library-dev-env lib;
                };
                package-names = builtins.attrNames s.packages;
                app-names = builtins.attrNames s.apps;
              in
                s // (if nixlib.length package-names == 1 then {
                  defaultPackage = s.packages.${nixlib.head package-names};
                } else {}) // (if nixlib.length app-names == 1 then {
                  defaultApp = s.apps.${nixlib.head app-names};
                } else {})
            )
        );
    in
      # This flake is parametrized by a library declaration
      # Whence `__functor`: the following set behaves as a function
      {
        __functor = self: mkFlake;
        # This flake also declares a few library-independent defintions:
        js-lib = import ./js/JS-Lib;
      } // flake-utils.lib.eachSystem [ "x86_64-darwin" "x86_64-linux" "aarch64-linux"] (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
          {
            apps.create = {
              type = "app";
              program = "${pkgs.writeShellScript "create-fpm-package" ''
                 export PATH=${with pkgs; lib.makeBinPath [ fd ripgrep git coreutils findutils nixUnstable ]}
                 ${pkgs.bash}/bin/bash ${./create-package.sh}
              ''}";
            };
          }
      );
}

