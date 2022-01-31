#! /usr/bin/env bash

# If a flake file exists already, we don't touch it and exit
if [ -f flake.nix ]; then
    >&2 echo "Error: the file ./flake.nix exists already."
    exit 1
fi

# We ask for package name
ask_name (){
    default_name=$(basename "$PWD")
    printf "Package name: (%s) " "$default_name"
    read name
    name="${name:=$default_name}"
}
ask_name

# Setup direnv?
ask_direnv () {
    printf "Setup direnv? (y)"
    read setup_direnv
    setup_direnv="${setup_direnv:=y}"
    case "$setup_direnv" in
	y) echo "use flake" > .direnv;;
	n) ;;
	*) echo "Please anwser 'y' or 'n'." && ask_direnv;;
    esac
}
ask_direnv

# Let the user interactively give dependency
declare -gA deps
ask_dependency () {
    printf "Add dependency? (n)"
    read dep
    if [[ "$dep" == "n" ]]; then
       return;
    fi
    tab="    "
    if name=$(nix eval --raw "$dep"\#lib.name &2>/dev/null); then
	deps["$name"]="$dep"
	printf 'Added "%s".\n' "$name"
    else
	printf 'Error while fetching flake "%s".\n' "$dep"
    fi
    ask_dependency
}
printf "What are the dependency of your package?\n"
printf "A dependency is expected to be a flake URI (e.g. 'github:owner/repo', 'git+ssh://git@somewhere.tld/owner/repo'...).\n"
printf "Anwser 'n' (or nothing) when your are done.\n"
ask_dependency

# Mandatory dependency
deps["fpm"]="github:W95Psp/fpm";

{
  cat <<- FLAKE
	{
	  description = "F* package";
	  inputs = {
FLAKE
  # we display the dependencies the used added
  for x in "${!deps[@]}"; do
      printf "%s  \"%s\".url = %s;\n" "$tab" "$x" "${deps[$x]}"
  done
  cat <<- FLAKE
	  };
	  outputs = { nixpkgs, fpm, ... }@libs:
	    fpm rec {
	      lib = {
FLAKE
  tab="        "
  printf "%sname = \"%s\";\n" "$tab" "$name"

  printf "%sdependencies = [\n" "$tab"
  for x in "${!deps[@]}"; do
      printf "%s  libs.\"%s\"\n" "$tab" "$x"
  done
  printf "%s]\n" "$tab"
  
  printf "%smodules = [\n" "$tab"
  # we detect the local modules automatically
  fd '[.](fsti?|mli?|js)$' -x printf "%s  ./%s\n" "$tab" "{}"
  printf "%s]\n" "$tab"
  
  printf "%splugin-entrypoints = [\n" "$tab"
  # we extract modules containing entrypoints
  rg --type-add='fstar:*.fst *.fsti' --type fstar -lU0 '\[@@?[^]]*plugin[^]]*\]' | xargs -IX -0 printf "%s  ./%s\n" "$tab" 'X' | sort -u
  printf "%s]\n" "$tab"
} > flake.nix

{
  cat <<- FLAKE
	      };
	      ocaml-programs = [
	        # { name = "example";
	        #   dependencies = [lib];
	        #   entrypoint = ./Entrypoint.fst; }
	      ];
	    };
	}
FLAKE
} >> flake.nix

# let's ensure we're inside a git repo
if ! git rev-parse --is-inside-git-dir &>/dev/null; then
    git init
fi
# let's add flake.nix into that repo
git add flake.nix

# TODO: check that every module discovered is in the repo as well



