nixlib:
# - `patches?: list path`: list of patches to apply on F*'s own sources (default `[]`);
# - `override?: set` (defaul `null`);
# - `unsafe_tactic_exec?: bool` (defaults `false`).
let
  # Merge two attrsets of F* options together
  merge = a: b:
    let
      any-has = name: builtins.hasAttr name a || builtins.hasAttr name b;
    in
      {
        patches = nixlib.unique ((a.patches or []) ++ (b.patches or []));
      } // (
        if any-has "override" then
          { source =
              if builtins.hasAttr "override" a then
                if builtins.hasAttr "override" b then
                  if a.override == b.override then a.override
                  else throw "Cannot merge two `fstar-options` specifying two different overrides."
                else a.override
              else b.override; }
        else {}
      ) // (
        if any-has "unsafe_tactic_exec" then
          {
            unsafe_tactic_exec = (a.unsafe_tactic_exec or false) || (b.unsafe_tactic_exec or false);
          }
        else {}
      );
  # Compute the attrset of F* options for a library, merging every F* options from every dependencies
  # (a dependency might require a patch or a specific flag to operate)
  options-of-lib = lib:
    let
      options = nixlib.foldl
        merge
        (lib.fstar-options or {}) 
        (map options-of-lib lib.dependencies);
      debug = builtins.toJSON {
        fn = "options-of-lib";
        inherit lib options;
      };
    in
      options;
      # builtins.deepSeq debug (builtins.trace debug options);
  # Compute an F* binary and set of flags given an attrset of F* options
  mk-fstar = system: fstar-flake: options:
    let
      pkgs-fstar = fstar-flake.packages.${system};
      tools = fstar-flake.lib.${system};
      fstar-bin =
        let
          base' = pkgs-fstar.fstar;
        in
          if builtins.hasAttr "override" options || ( builtins.hasAttr "patches" options &&
                                                      nixlib.length options.patches > 0 )
          then
            let override = options.override or {}; in
            if builtins.hasAttr "patches" override
            then throw "The `override` property of an `fstar-options` should not specify patches."
            else base'.override (override // {
              patches = nixlib.unique (map (x: "${x}") options.patches);
            })
          else base';
          # if builtins.hasAttr "patches" options
          #    && nixlib.length options.patches > 0
          # then 
          #   tools.perform-fstar-to-ocaml base.fstar
          #     (pkgs-fstar.fstar.overrideAttrs 
          #       (o: {patches = o.patches ++ options.patches;}))
          # else base;
    in
      { bin = fstar-bin;
        flags = if builtins.hasAttr "unsafe_tactic_exec" options
                   && options.unsafe_tactic_exec
                then "--unsafe_tactic_exec"
                else "";
        inherit options;
      };
in
{ inherit merge options-of-lib mk-fstar; }

