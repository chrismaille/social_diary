#!/bin/sh
# Render Your Diary's right page for every /sd testdata entry (and each
# weighted page forced onto one) from the WoW mock, without the client.
#
#   .claude/skills/plates/tools/plates.sh [out-dir] [label-or-pattern ...]
#
# out-dir defaults to /tmp/sd-plates. Prints a SUMMARY line per entry
# (pattern, plate weights and moment kinds, what made each margin), then the
# render's checks; PNGs land in out-dir (look at them with Read).
# SD_PLATES_FORCE=0 skips the forced pages.
#
# The harness loads the addon from tests/.. , so this builds a farm in
# out-dir/farm: symlinks to the addon's files, plus the dump script beside
# the real harness, wowmock and fixtures. Nothing is written in the addon.
set -e
here=$(cd "$(dirname "$0")" && pwd)
addon=$(cd "$here/../../../.." && pwd)
out=${1:-/tmp/sd-plates}
[ $# -gt 0 ] && shift
farm="$out/farm"
rm -rf "$farm"
mkdir -p "$farm/tests"
for f in "$addon"/*; do
    [ "$(basename "$f")" = tests ] || ln -s "$f" "$farm/$(basename "$f")"
done
for f in harness.lua wowmock.lua fixtures.lua; do ln -s "$addon/tests/$f" "$farm/tests/$f"; done
cp "$here/plate_dump.lua" "$farm/tests/plate_dump.lua"
rm -f "$out"/*.png
cd "$farm"
SD_PLATES_OUT="$out" luajit -e 'dofile("tests/harness.lua").Run("tests", { "plate_dump" }, {})' \
    | grep -v '^  ok '
python3 -I -B "$here/plate_render.py" "$out" "$@"
