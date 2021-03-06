{
  description = "LibA";

  inputs = {
    # fpm.url = git+ssh://git@github.com/W95Psp/fpm;
    fpm.url = path:/home/lucas/Bureau/fpm;
    # fpm.url = path:../../.;
  };

  outputs = { nixpkgs, fpm, ... }:
    fpm rec {
      lib = {
        name = "LibC";
        dependencies = [
          (import ../LibB/package.nix)
          fpm.js-lib
        ];
        modules = [
          ./LibC.ModX.fst
          ./LibC.ModY.fst
          ./LibC.ModZ.fst
          ./HelloJS.fst
          ./JS.TypedObjects.fst
          ./JS.TypedObjects.fsti
          ./Js.TypedObjects.Utils.fst
          ./JS.Window.fst
          ./Main.fst
        ];
        plugin-entrypoints = [ ];
      };
      ocaml-programs = [{
        name = "HelloWorld";
        dependencies = [lib];
        entrypoint = ./Main.fst;
      }];
      js-programs = [{
        name = "HelloJavaScript";
        dependencies = [lib];
        entrypoint = ./HelloJS.fst;
      }];
    };
}
