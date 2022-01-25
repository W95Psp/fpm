#!/usr/bin/env bash

# This script transforms the environment variables
# FPM_LOCAL_MODULES, FPM_LIB_PATH and FPM_LIB_CHECKED_FILES
# into FSTAR_INCLUDES, FSTAR_PLUGINS, FSTAR_CHECKED_PATH.
# (so that ./fstar-wrapper.sh can grap them)

# First, we set FPM_LIB_ROOT the local root of our library (basically
# the place where flake.nix lives)
export FPM_LIB_ROOT="$PWD"

remap_as_local_include_path () {
    local components module="$1"
    
    # FPM being nix-based, in some situation, FPM_LOCAL_MODULES looks
    # like `/nix/store/some/path/to/foo/Bar.fst:...`. It means that
    # FPM_LOCAL_MODULES actually references modules living in the nix
    # store: the source `./.` was dumped to nix store.

    # Since we are setting up a dev environment, we are not interested
    # in those readonly modules, but rather in their live counterpart
    # living somewhere below the current directory.

    # This function takes such a path and tries to find the remap such
    # a /nix/store path into the current file hierachy.

    # First, we split the path `module` to retrive its components
    IFS='/' read -ra components <<< "$module"
    # Then, we try to find the longest suffix of `components` so that the path exists under `FPM_LIB_ROOT`
    for i in $(seq 1 "${#components[@]}"); do
	# `p` is the path we reconstruct
        p="$FPM_LIB_ROOT/$(IFS=/ ; echo "${chunks[*]:$i}")"
        test -f "$p" && {
	    # if `p` is a valid path, then we return its parent
	    # directory (we just need the directory)
            dirname "$p"
            break
        }
    done
}

export FSTAR_INCLUDES=$(
    {
	# Include the parent directory of every module declared in the library
	IFS=':' read -ra modules <<< "$FPM_LOCAL_MODULES"
	for module in "${modules[@]}"; do
            remap_as_local_include_path "$module"
	done
	
	# Include the directory containing the modules of every dependencies to the library
	echo "$FPM_LIB_PATH/modules"
	# Same, but for plugins (F* will look for CMXS files in its include paths)
	echo "$FPM_LIB_PATH/plugins"

	# In case FSTAR_INCLUDES is not empty (TODO: useful? or dangerous?)
	echo "$FSTAR_INCLUDES" | tr -s ':' '\n'
    } | sed '/^$/d' | sort -u | paste -sd ":" - # we make sure there's not duplicate (even though F* doesn't care), or empty entries (hence sed)
)

export FSTAR_PLUGINS=$(cat "$FPM_LIB_PATH/plugin-modules" | paste -sd ":")
export FSTAR_CHECKED_PATH="$FPM_LIB_CHECKED_FILES"

