{ name = "LibC";
  dependencies = [
    (import ../LibB/package.nix)
  ];
  modules = [
    ./LibC.ModX.fst
    ./LibC.ModY.fst
    ./LibC.ModZ.fst
    ./Main.fst
  ];
  plugin-entrypoints = [ ];
}
