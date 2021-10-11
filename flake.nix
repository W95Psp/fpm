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
      functions = system:
        {
          fstar-patches ? [],
          fstar-override ? null
            # { name = "fstar-version-blabla";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "FStarLang";
            #     repo = "FStar";
            #     rev = "54ddadbdd8aa36b2bbb60b3c0a24fc4bfa3e90ce";
            #     sha256 = "sha256-mm4i5Ta/TMAXB6qlEO09BZZ9xHlbzzInXJrWX+Fp9uQ=";
            #   };
            # }
        }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs-fstar = fstar-flake.packages.${system};
          tools = fstar-flake.lib.${system};
          fstar-bin =
            let
              base' = pkgs-fstar.fstar;
              base  = if isNull fstar-override then base'
                      else base'.override fstar-override;
            in
              if nixlib.length fstar-patches == 0
              then base.fstar
              else 
                tools.perform-fstar-to-ocaml base.fstar
                  (pkgs-fstar.fstar.overrideAttrs 
                    (o: {patches = o.patches ++ fstar-patches;}));
          opt = {
            inherit nixlib;
            inherit (pkgs) writeShellScriptBin writeShellScript mkShell findutils;
            fstar-dependencies =
              [pkgs-fstar.fstar pkgs-fstar.z3] ++
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
          };
    in
      {
        __functor =
          _: {
            lib ? null,
            ocaml-programs ? [],
            fstar-patches  ? [],
            fstar-override ? []
          }:
          {
            inherit lib;
          } //
          flake-utils.lib.eachSystem [ "x86_64-darwin" "x86_64-linux" "aarch64-linux"]
            (system:
              let
                f = functions system {inherit fstar-patches;};
                s = {
                  fstar-lib = lib;
                  packages = nixlib.listToAttrs (
                    (map (prog: {name = prog.name; value = f.ocaml-program prog;}) ocaml-programs)
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

