{
  description = "hello-word-fstar";
  
  inputs = {
    fpm.url = github:W95Psp/fpm; # fetches FPM
    # here, we would declare F* libraries
  };
  
  outputs = { nixpkgs, fpm, ... }@libs:
    fpm rec {
      # we declare a library, basically an empty shell in this case
      lib = {
        name = "hello-world";
        dependencies = []; # no dependencies
        modules = [ ./Main.fst ]; # just one module
        plugin-entrypoints = [ ]; # no F* plugin
      };
      # and one ocaml program
      ocaml-programs = [{
        name = "hello-world";
        dependencies = [lib];
        entrypoint = ./Main.fst;
      }];
    };
}
