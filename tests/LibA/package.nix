{ name = "LibA";
  dependencies = [];
  modules = [
    ./LibA.ModX.fst
    ./LibA.ModY.fst
    ./LibA.Native.fst
    ./LibA.ModZ.fst
  ];
  plugin-entrypoints = [ ./LibA.Native.fst ];
}
