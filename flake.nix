{
  description = "FPM (the F* Package Manager)";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    fstar-flake.url = "github:W95Psp/nix-flake-fstar";
    fpm.url = "github:W95Psp/nix-flake-fstar";
  };
  
  outputs = { self, nixpkgs, flake-utils, fstar-flake, fpm }:
    let
      nixlib = nixpkgs.lib;
      fn = import ./functions.nix nixlib;
      validatior = import ./validator.nix nixlib;
    in
      rec {
        library-derivation = lib:
          # let llib = parse.preprocess lib; in
          { inherit lib;
          } // flake-utils.lib.eachSystem
            [ "x86_64-darwin" "x86_64-linux" "aarch64-linux"]
            (system:
              let
                pkgs = nixpkgs.legacyPackages.${system};
                pkgs-fstar = fstar-flake.packages.${system};
                z3 = pkgs-fstar.z3;
                opt = {
                  inherit nixlib;
                  mkDerivation = pkgs.stdenv.mkDerivation;
                  findutils = pkgs.findutils;
                  fstar-dependencies =
                    [pkgs-fstar.z3 pkgs-fstar.fstar] ++
                    (with pkgs.ocamlPackages;
                      [ ocaml
                        ocamlbuild findlib batteries stdint zarith yojson fileutils pprint
                        menhir ppx_deriving ppx_deriving_yojson process ocaml-migrate-parsetree
                        sedlex_2
                      ]);
                };
                der = import ./library-derivation.nix opt lib;
                dev = import ./library-dev-env.nix (opt // {
                  fstar-bin = pkgs-fstar.fstar;
                  z3-bin = pkgs-fstar.z3;
                  mkShell = pkgs.mkShell;
                  writeShellScriptBin = pkgs.writeShellScriptBin;
                  writeShellScript = pkgs.writeShellScript;
                }) lib;
              in
                validatior lib
                (rec {
                  inherit der;
                  devShell = dev;
                }));
    };
}

