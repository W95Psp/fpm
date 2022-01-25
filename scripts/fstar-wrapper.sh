#!/usr/bin/env bash
# Wrapper for F* binary, to pass flags as environement variables.
# It is sensible to the following variables:
# - FSTAR_INCLUDES, a list of paths to be included (exemple: `/some/path/:/some/other/path:~/another/path`);
# - FSTAR_PLUGINS, a list of plugins name to be loaded (example: to load "/path/a/Foo.cmxs" and "/path/b/Bar.cmxs", you should include --via FSTAR_INCLUDES for instance-- the paths `/path/a` and `/path/b` *and* set FSTAR_PLUGINS to `Foo:Bar`);
# - FSTAR_CHECKED_PATH, a (possibly readonly, see `handle_checked` below) path to `*.checked` F* files.

if [[ -z "$FSTAR_BINARY" ]]; then
    echo "FSTAR_BINARY missing"
    exit 1
fi

list_to_flags () {
    local values flag_name="$1"
    IFS=':' read -ra values <<< "$2"
    for v in "${values[@]}"; do
	printf -- ' --%s %s ' "$flag_name" "$v"
    done
}

handle_checked () {
    # If `FSTAR_CHECKED_PATH` is empty or an flag `cache_dir` was
    # supplied, we do nothing (setting the flag `--cache_dir` manually
    # overrides the env variable)
    if [[ ( -z "$FSTAR_CHECKED_PATH" ) || ( $* == *--cache_dir* ) ]]; then
	return
    fi
    if [[ ! -d "$FSTAR_CHECKED_PATH" ]]; then
	>&2 echo "[fstar-wrapper] Error: Variable FSTAR_CHECKED_PATH is set to '$FSTAR_CHECKED_PATH', which seems not to be a valid directory."
	exit 2
    fi
    # If the flag `cache_checked_modules` is enabled, F* will try to
    # write in the cache directory FSTAR_CHECKED_PATH. Thus, if
    # `cache_checked_modules` is enabled AND that FSTAR_CHECKED_PATH
    # is readonly, we need a workaround.
    if [[ ( $* == *--cache_checked_modules* ) && ( ! -w "$FSTAR_CHECKED_PATH" ) ]]; then
	# We create a directory FSTAR_CHECKED_PATH_LOCAL in which we
	# copy every checked file from the readonly path FSTAR_CHECKED_PATH
	FSTAR_CHECKED_PATH_LOCAL="./.cache-checked/"
	mkdir -p "$FSTAR_CHECKED_PATH_LOCAL"
	# The flag -f to `cp` forces override of checked files
	find "$FSTAR_CHECKED_PATH/" \( -type f -or -type l \) -exec cp -f --no-preserve=mode '{}' "$FSTAR_CHECKED_PATH_LOCAL" \;
	echo "--cache_dir $FSTAR_CHECKED_PATH_LOCAL"
    else
	echo "--cache_dir $FSTAR_CHECKED_PATH"
    fi
}

set -x

# if no argument, then we display F*'s help message
# (otherwise calling F* without modules but with includes flags result in the error 5 ('No file provided'))
if [[ -z "$@" ]]; then
    $FSTAR_BINARY --help
else
    $FSTAR_BINARY                                     \
	$FSTAR_FLAGS                                  \
	$(list_to_flags 'include' "$FSTAR_INCLUDES")  \
	$(list_to_flags 'load_cmxs' "$FSTAR_PLUGINS") \
	$(handle_checked) "$@"
fi

