#!/bin/sh
# Rewrite the generated geometry block of a proposal mockup from the
# addon's live tables (layout_json.lua, run in the WoW mock).
#
#   .claude/skills/plates/tools/layout.sh [mockup.html ...]
#
# With no file it refreshes the template itself
# (.claude/skills/plates/tools/proposal-template.html). In each file the
# text between /* @@LAYOUT-BEGIN@@ */ and /* @@LAYOUT-END@@ */ is replaced;
# nothing else is touched. As plates.sh, it builds a symlink farm next to
# the real harness (in a temp dir), so nothing is written in the addon.
set -e
here=$(cd "$(dirname "$0")" && pwd)
addon=$(cd "$here/../../../.." && pwd)
[ $# -eq 0 ] && set -- "$here/proposal-template.html"
work=$(mktemp -d "${TMPDIR:-/tmp}/sd-layout.XXXXXX")
trap 'rm -rf "$work"' EXIT
farm="$work/farm"
mkdir -p "$farm/tests"
for f in "$addon"/*; do
    [ "$(basename "$f")" = tests ] || ln -s "$f" "$farm/$(basename "$f")"
done
for f in harness.lua wowmock.lua fixtures.lua; do ln -s "$addon/tests/$f" "$farm/tests/$f"; done
cp "$here/layout_json.lua" "$farm/tests/layout_json.lua"
js="$work/layout.js"
(cd "$farm" && SD_LAYOUT_OUT="$js" luajit -e 'dofile("tests/harness.lua").Run("tests", { "layout_json" }, {})' \
    | grep -v '^  ok ' || true)
[ -s "$js" ] || { echo "layout.sh: no geometry written" >&2; exit 1; }
for html in "$@"; do
    luajit - "$html" "$js" <<'LUA'
local html, js = arg[1], arg[2]
local f = assert(io.open(html, "rb")); local text = f:read("*a"); f:close()
f = assert(io.open(js, "rb")); local gen = f:read("*a"); f:close()
local B, E = "/* @@LAYOUT-BEGIN@@ */", "/* @@LAYOUT-END@@ */"
local a, b = text:find(B, 1, true)
local c = a and text:find(E, b + 1, true)
if not (a and c) then io.stderr:write("layout.sh: no markers in " .. html .. "\n"); os.exit(1) end
local out = text:sub(1, b) .. "\n" .. gen .. text:sub(c)
f = assert(io.open(html, "wb")); f:write(out); f:close()
print("layout.sh: geometry written into " .. html)
LUA
done
