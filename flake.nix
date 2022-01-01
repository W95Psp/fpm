{
  description = "FPM (the F* Package Manager)";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    fstar-flake.url = "github:W95Psp/nix-flake-fstar";
    zarith_stubs_js = {
      url = "github:janestreet/zarith_stubs_js";
      flake = false;
    };
  };
  
  outputs = { self, nixpkgs, flake-utils, zarith_stubs_js, fstar-flake }:
    let
      nixlib = nixpkgs.lib;
      fn = import ./functions.nix nixlib;
      validatior = import ./validator.nix nixlib;
      functions = system: fstar-options:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs-fstar = fstar-flake.packages.${system};
          tools = fstar-flake.lib.${system};
          fstar-bin-tools = import ./fstar-options.nix nixlib;
          fstar-bin-flags-of-lib = lib: fstar-bin-tools.mk-fstar system fstar-flake (fstar-bin-tools.options-of-lib lib);
          opt = {
            inherit nixlib fstar-bin-flags-of-lib;
            inherit (pkgs) writeShellScriptBin writeShellScript mkShell findutils;
            fstar-dependencies =
              [pkgs-fstar.z3] ++
              (with pkgs.ocamlPackages;
                [ ocaml
                  ocamlbuild findlib batteries stdint zarith yojson fileutils pprint
                  menhir ppx_deriving ppx_deriving_yojson process ocaml-migrate-parsetree
                  sedlex_2
                ]);
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
    in
      {
        __functor =
          _: {
            lib ? null,
            fstar-options ? {},
            ocaml-programs ? [],
            js-programs ? []
          }:
          {
            inherit lib;
          } //
          flake-utils.lib.eachSystem [ "x86_64-darwin" "x86_64-linux" "aarch64-linux"]
            (system:
              let
                f = functions system fstar-options;
                s = {
                  fstar-lib = lib;
                  packages = nixlib.listToAttrs (
                    (map (prog: {name = prog.name; value = f.ocaml-program prog;}) ocaml-programs)
                    ++
                    (map (prog: {name = prog.name; value = f.js-program prog;}) js-programs)
                  );
                  devShells = nixlib.listToAttrs (
                    let h = prog: {
                          name = prog.name;
                          value = lib // {
                            name = lib.name + "-" + prog.name;
                            dependencies = lib.dependencies ++ prog.dependencies;
                          };
                        };
                    in (map h ocaml-programs) ++ (map h js-programs)
                  );
                  devShell = f.library-dev-env lib;
                };
                package-names = builtins.attrNames s.packages;
              in
                s // (if nixlib.length package-names == 1 then {
                  defaultPackage = s.packages.${nixlib.head package-names};
                } else {})
            );
      };
}

