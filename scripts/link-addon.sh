#!/bin/sh
# Link this clone into the game's Interface/AddOns as `social_diary`, the
# name the TOC and .pkgmeta use: the client loads a folder's
# social_diary.toc only when the folder is named the same, so the clone may
# live anywhere and the folder down there is the link.
#
#   sh scripts/link-addon.sh [<path>]
#
# <path> may be the game root, its `_retail_` folder or Interface/AddOns;
# the WOW_ADDONS environment variable does the same. The resolved AddOns
# folder is remembered in the gitignored .wow-addons, so later runs (and
# `make install`) need no path. On Windows run this from Git Bash: the link
# becomes a junction, which needs no administrator. On Linux and macOS it
# is a symlink; Wine follows it.

set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
addon=social_diary
remember_file="$repo/.wow-addons"

die() {
    echo "link-addon: $*" >&2
    exit 1
}

# The game root, `_retail_`, `Interface` and Interface/AddOns are all
# accepted; hand back the AddOns folder.
resolve_addons() {
    if [ -d "$1/Interface/AddOns" ]; then
        printf '%s/Interface/AddOns\n' "$1"
    elif [ -d "$1/_retail_/Interface/AddOns" ]; then
        printf '%s/_retail_/Interface/AddOns\n' "$1"
    elif [ -d "$1/AddOns" ]; then
        printf '%s/AddOns\n' "$1"
    else
        printf '%s\n' "$1"
    fi
}

path=${WOW_ADDONS:-}
if [ -z "$path" ] && [ "$#" -ge 1 ] && [ -n "$1" ]; then
    path=$1
fi
if [ -z "$path" ] && [ -f "$remember_file" ]; then
    path=$(cat "$remember_file")
fi
if [ -z "$path" ]; then
    for guess in \
        "$HOME/.local/share/Steam/steamapps/common/World of Warcraft" \
        "$HOME/.steam/steam/steamapps/common/World of Warcraft" \
        "$HOME/Applications/World of Warcraft" \
        "/Applications/World of Warcraft" \
        "/c/Program Files (x86)/World of Warcraft" \
        "/mnt/c/Program Files (x86)/World of Warcraft"
    do
        if [ -d "$guess/_retail_/Interface/AddOns" ]; then
            path=$guess
            break
        fi
    done
fi
[ -n "$path" ] || die "which World of Warcraft? pass the game folder (or _retail_ or Interface/AddOns), set WOW_ADDONS, or first run: make install ADDONS=<path>"

addons=$(resolve_addons "$path")
case $addons in
    */AddOns) ;;
    *) die "$addons is not an AddOns folder; pass the game root, _retail_ or Interface/AddOns" ;;
esac
[ -d "$addons" ] || die "no such folder: $addons"

link=$addons/$addon
if [ -L "$link" ]; then
    rm "$link"
elif [ -e "$link" ]; then
    die "$link already exists and is not a link; remove it first (a copy from a release?)"
fi

case $(uname -s) in
    MINGW*|MSYS*|CYGWIN*)
        cmd //c mklink //J "$(cygpath -w "$link")" "$(cygpath -w "$repo")" >/dev/null ||
            die "mklink failed; create the junction by hand with: cmd /c mklink /J <link> <repo>"
        ;;
    *)
        ln -s "$repo" "$link"
        ;;
esac

printf '%s\n' "$addons" > "$remember_file"
echo "linked $link -> $repo"
