

# Types
## `library`
A set with the following attributes:
 - `modules: list path`: a list of files (F* modules, OCaml modules, C header, C implementation, JS file)
 - `plugin-entrypoints: list path`: subset of `module` (F* or OCaml modules)
 - `dependency: list library`: a li

# `validator.nix`
Type: `library -> next:'a -> 'a`
Validate the sturcture of a library, and continue with `next`.

# `library-derivation.nix`
Type: `lib:library -> derivation`
Builds a derivation for library `lib`, with the following structure:
 - `./modules`: flat listings of all the direct or indirect (via dependencies) modules of `lib`;
 - `./plugins`: one `cmxs` file for every module listed in `plugin-entrypoints`.
 
# `dev-shell.nix`
Type: `lib:library -> derivation`


