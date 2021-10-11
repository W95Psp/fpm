{
  lists, strings, attrsets, ...
}:
let
  extra = import ./functions.nix {inherit lists strings;};
  lib-examples = import ./lib-examples.nix;
  helpers = rec {
    # Given a library `lib`, this functions returns a list of cycles in dependencies
    # This function might throw error message if the library is malformed
    find-cyclic-dependencies = lib:
      let helper = parent-names: lib:
            let err = "At root>${strings.concatStringsSep ">" parent-names}, a dependency"; in
            builtins.deepSeq
              ( (   builtins.typeOf  lib                       != "set"    && throw "${err} is not a set"                                )
                || (builtins.typeOf (lib.name         or null) != "string" && throw "${err} have a bad field 'name' (not a string)"      )
                || (builtins.typeOf (lib.dependencies or null) != "list"   && throw "${err} have a bad field 'dependencies' (not a list)")
              )
              ( if lists.elem lib.name parent-names
                then
                  let f = n: lib.name == n; in
                  [ { path = extra.keep-while f parent-names; cycle = extra.drop-while f parent-names; } ]
                else lists.concatLists (map (helper ([lib.name] ++ parent-names)) lib.dependencies)
              );
      in helper [] lib;
    # Given a library `lib` without cyclic dependencies, resolves all dependencies into an array `{path: [library], lib: library}`
    linearize-dependencies = lib:
        let
          remove-exact-dups = ldeps:
            lists.foldl (acc: {path, lib}:
              ( if lists.elem lib (map ({lib,...}: lib) acc)
                then [] else [{inherit path lib;}]
              ) ++ acc
            ) [] ldeps;
          linearize = path: lib:
            [{inherit path lib;}]
            ++ (lists.concatLists (map (linearize (path ++ [lib])) lib.dependencies));
        in remove-exact-dups (linearize [] lib);
    # Given linear dependencies `ldeps`, returns duplicate libraries
    # under the form of a list of type `{x, y}` with `x` and `y`
    # libraries (i.e. libraries with same name but different
    # parameters or versions)
    find-library-mismatch = ldeps:
      lists.filter ({x, y}: x.lib.name == y.lib.name) (extra.pairwise-uniq ldeps);
    # Given linear dependencies `ldeps`, returns a list of objects
    # `{dups, x, y}`, where `x` and `y` are libraries, and `dups` a
    # non-empty list of module with same names
    find-duplicate-modules = ldeps:
      lists.filter ({dups,...}: lists.length dups > 0) (
        map ({x, y}: {
          inherit x y;
          dups = lists.intersectLists
            (map extra.filename-of x.lib.modules)
            (map extra.filename-of y.lib.modules);
        }) (extra.pairwise-uniq ldeps)
      );
    find-malformed-plugins =
      let wellformed = lib:
            let entrypoints = lib.plugin-entrypoints or []; in
            builtins.typeOf entrypoints == "list" &&
            lists.intersectLists lib.modules entrypoints == entrypoints;
      in
        lists.filter ({lib,...}: !(wellformed lib));
  };
  issues = rec {
    mk-report = lib:
      let
        cyclic-dependencies = helpers.find-cyclic-dependencies lib;
        ldeps = helpers.linearize-dependencies lib;
      in
        { inherit cyclic-dependencies;
          duplicate-modules = [];
          library-mismatch = [];
          find-malformed-plugins = [];
        }
        // (if lists.length cyclic-dependencies > 0 then {} else {
          inherit ldeps;
          duplicate-modules = helpers.find-duplicate-modules ldeps;
          library-mismatch = helpers.find-library-mismatch ldeps;
          find-malformed-plugins = helpers.find-malformed-plugins ldeps;
        });
    printers = rec {
      showPath = x: strings.concatMapStringsSep ">" (o: o.name) x.path;
      header = {
        cyclic-dependencies = "The following cycles have been detected:";
        duplicate-modules = "The following name clashes for modules have been detected:";
        library-mismatch = "The following version conflicts in dependencies have been detected:";
        find-malformed-plugins = "The following libraries contains malfored plugin entrypoints:";
      };
      each = {
        cyclic-dependencies = {path, cycle}:
          "${strings.concatStringsSep " - " path} ( ${strings.concatStringsSep " - " cycle} )";
        duplicate-modules = {x, y, dups}:
          "libraries ${x.lib.name} (${showPath x}) " +
          "and ${y.lib.name} (${showPath y})" +
          "both defines the modules [${strings.concatStringsSep ", " dups}]";
        library-mismatch = {x, y}:
          "library ${x.lib.name} is required by "+
          "'${showPath x}' and by " +
          "'${showPath y}'";
        find-malformed-plugins = {lib,path}@x:
          "the 'plugin-entrypoints' field of library ${lib.name} (${showPath x}) " +
          ( if builtins.typeOf lib.plugin-entrypoints != "list"
            then "is of type ${builtins.typeOf lib.plugin-entrypoints}, a list was expected"
            else "is not a subset of field 'modules'"
          );
      };
    };
    validate-msg = report:
      let
        errors = attrsets.filterAttrs (k: v: lists.length v > 0 && attrsets.hasAttr k printers.header) report;
      in
        strings.concatStringsSep "\n" (attrsets.mapAttrsToList (k: v:
          printers.header.${k} + "\n" + strings.concatMapStringsSep "\n" (l: " - ${printers.each.${k} l}") v
        ) errors);
    validate = lib:
      let r         = mk-report lib;
          error-msg = validate-msg r;
      in
        if error-msg == ""
        then
          rec { inherit lib;
                ldeps = r.ldeps; 
                modules = lists.concatLists (map ({lib,...}: lib.modules) ldeps);
              }
        else throw error-msg
    ;
  };
  prepareJSON = {name, modules, dependencies}:
        { inherit name;
          modules = map toString modules;
          dependencies = map prepareJSON dependencies;
        };
in
{
  tests = builtins.mapAttrs (name: lib:
    let error = issues.validate-msg (issues.mk-report lib); in
    if error == "" then
      let o = issues.validate lib; in
      { lib = prepareJSON o.lib;
        modules = map toString o.modules; }
    else error
  ) lib-examples;
  preprocess = issues.validate;
  linearize-dependencies = helpers.linearize-dependencies;
  inherit prepareJSON;
}

