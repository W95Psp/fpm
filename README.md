[**F***](https://www.fstar-lang.org/) **P**ackage **M**anager (FPM) is a package manager for F*, on top of the [Nix package manager](https://nixos.org/).

Given a list of F* modules and of (git-based) F* dependencies, FPM automatically provides:
 - ready-to-use development environment (with a fully configured F* binary in path);
 - automatic OCaml compilation (if needed);
 - automatic JavaScript compilation (if needed).
 
# Example
## OCaml Hello World
The example [hello-ocaml-world](examples/hello-ocaml-world) consist in one module with no dependencies, that just prints an `"Hello World"` after extraction to OCaml and after compilation.

The module is very simple:
```
module Main
let main () = 
  FStar.IO.print_string "Hello world!"
```

The file `flake.nix` contains the library and program declaration:
```
{
  description = "hello-word-fstar";
  
  inputs = {
    fpm.url = github:W95Psp/fpm; # fetches FPM
    # here, we would declare F* libraries, for this example there's nothing
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
```

Running `nix run` produces `Hello World!` in the console! It automatically:
 1. fetches an F* binary;
 2. pulls and sets up every F* depenedncies (here, none);
 3. compile declared plugins entrypoints (here, none, again) into native ones;
 4. extracts the module `Main.fst` into `Main.ml`;
 5. compile `Main.ml` with the correct OCaml libraries;
 6. runs the resulting program.

# Bigger example
TODO

# Details
## Types
### `library`
A set with the following attributes:
 - `name: string`;
 - `modules: list path`: a list of files (F* modules, OCaml modules, C header, C implementation, JS file);
 - `plugin-entrypoints?: list path`: subset of `module`, F* or OCaml modules (default `[]`);
 - `dependencies: list library`: a list of dependencies;
 - `fstar-options?: fstar-options`: F* options (default `{}`).

### `ocaml-program`
A set with the following attributes:
 - `name: string`;
 - `modules: list path`: a list of files (F* modules, OCaml modules, C header, C implementation, JS file);
 - `dependencies: list library`: a list of dependencies;
 - `entrypoint: path`: the entrypoint module (has to be a subset of `modules`);
 - `driver?: path`: OCaml driver (default driver simply calls the function `main` from module `entrypoint`);
 - `assets?: path`: path of a directory containing non-F* assets (default: empty directory);
 - `lflags?: string`: list of `lflags` for ocaml (default `""`);
 - `ocaml-packages?: list {name: string; package: derivations}`: list of (supplementary to `fstarlib`) OCaml packages with their (opam) name (default `[]`);
 - `target?: "native"|"byte"`: build either an ocaml bytecode or a native binary (default `"native"`);
 - `fstar-options?: fstar-options`: F* options (default `{}`).

### `fstar-options`
A set:
 - `patches?: list path`: list of patches to apply on F*'s own sources (default `[]`);
 - `source?: source object` (defaul `null`);
 - `unsafe_tactic_exec?: bool` (defaults `false`).

## Nix Files
### `validator.nix`
Type: `library -> next:'a -> 'a`
Validate the sturcture of a library, and continue with `next`.

### `library-derivation.nix`
Type: `lib:library -> derivation`
Builds a derivation for library `lib`, with the following structure:
 - `./modules`: flat listings of all the direct or indirect (via dependencies) modules of `lib`;
 - `./plugins`: one `cmxs` file for every module listed in `plugin-entrypoints`.
 
### `dev-shell.nix`
Type: `lib:library -> derivation`


