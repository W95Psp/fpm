{ name = "LibB";
  dependencies = [
    (import ../LibA/package.nix)
  ];
  modules = [
    ./LibB.ModX.fst
    ./LibB.ModY.fst
    ./LibB.ModZ.fst
  ];
  plugin-entrypoints = [ ];
}

  
