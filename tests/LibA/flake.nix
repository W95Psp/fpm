{
  description = "LibA";

  inputs = {
    fpm.url = path:../../.;
  };

  outputs = { nixpkgs, fpm, ... }:
    let
      d = fpm.library-derivation (import ./package.nix);
      lib = nixpkgs.lib;
    in
      d;
}
