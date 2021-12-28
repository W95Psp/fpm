

# Types
## `library`
A set with the following attributes:
 - `name: string`;
 - `modules: list path`: a list of files (F* modules, OCaml modules, C header, C implementation, JS file);
 - `plugin-entrypoints?: list path`: subset of `module`, F* or OCaml modules (default `[]`);
 - `dependencies: list library`: a list of dependencies;
 - `fstar-options?: fstar-options`: F* options (default `{}`).

## `ocaml-program`
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

## `fstar-options`
A set:
 - `patches?: list path`: list of patches to apply on F*'s own sources (default `[]`);
 - `source?: source object` (defaul `null`);
 - `unsafe_tactic_exec?: bool` (defaults `false`).

# Nix Files
## `validator.nix`
Type: `library -> next:'a -> 'a`
Validate the sturcture of a library, and continue with `next`.

## `library-derivation.nix`
Type: `lib:library -> derivation`
Builds a derivation for library `lib`, with the following structure:
 - `./modules`: flat listings of all the direct or indirect (via dependencies) modules of `lib`;
 - `./plugins`: one `cmxs` file for every module listed in `plugin-entrypoints`.
 
## `dev-shell.nix`
Type: `lib:library -> derivation`


