-- Your Diary's right-page geometry as JSON, for the proposal template
-- (proposal-template.html). Run through layout.sh (it builds the harness
-- farm this needs, as plates.sh does for plate_dump.lua); not a test.
--
-- Reads the live tables after T.Boot(), so no number is ever retyped:
--   ns.UI.YourDiary: RIGHT_H, LAYOUT (every key, each a plain array of
--   slots; FL.tucked, the same table as LAYOUT["F+L"], goes in TUCKED as
--   the string "F+L"),
--   SNAPSHOT, CAPTION, OFF, LEADER, and ROW (UI/Journey/Margin.lua's
--   file-local ROW, exported at that file's foot as YourDiary.ROW);
--   ns.UI.JourneyMargin: PEOPLE and ORDER (each registered kind's order,
--   filler, pool, and which optional hooks it has).
-- Writes `const GEO = {...};` to $SD_LAYOUT_OUT (default
-- /tmp/sd-layout.js); layout.sh splices it into the template between
-- /* @@LAYOUT-BEGIN@@ */ and /* @@LAYOUT-END@@ */.
local T = ...
local ns = T.Boot()
local YD = ns.UI.YourDiary
local Margin = ns.UI.JourneyMargin

local function Key(k)
    return ('"%s"'):format(tostring(k))
end

-- Plain JSON of a Lua value: arrays where the keys run 1..n, objects
-- otherwise (keys sorted, numbers first), functions and frames left out.
-- `seen` keeps a table met twice (FL.tucked) to a name.
local function Json(v, alias)
    local kind = type(v)
    if kind == "number" then
        if v == math.huge then return "1e9" end
        if v == math.floor(v) then return ("%d"):format(v) end
        return (("%.4f"):format(v):gsub("0+$", ""):gsub("%.$", ""))
    elseif kind == "string" then
        return '"' .. v:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
    elseif kind == "boolean" then
        return tostring(v)
    elseif kind ~= "table" then
        return nil
    end
    if alias and alias[v] then return Json(alias[v]) end
    local n = #v
    local keys = {}
    for k, x in pairs(v) do
        if Json(x, alias) ~= nil and not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
            keys[#keys + 1] = k
        end
    end
    if #keys == 0 and n > 0 then
        local parts = {}
        for i = 1, n do parts[i] = Json(v[i], alias) or "null" end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for i = 1, n do keys[#keys + 1] = i end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) == "number" end
        return a < b
    end)
    if #keys == 0 then return (n == 0 and next(v) == nil) and "[]" or "{}" end
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = Key(k) .. ":" .. Json(v[k], alias) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local LAYOUT = YD.LAYOUT
-- LAYOUT.FL.tucked is LAYOUT["F+L"] itself: written as its key.
local alias = { [LAYOUT["F+L"]] = "F+L" }

local layout = {}
for _, k in ipairs({ 1, 2, 3 }) do layout[#layout + 1] = Key(k) .. ":" .. Json(LAYOUT[k], alias) end
local named = {}
for k in pairs(LAYOUT) do
    if type(k) == "string" then named[#named + 1] = k end
end
table.sort(named)
-- A layout's variants under a string key (FL.tucked) are written apart,
-- in TUCKED, so every layout stays a plain array of slots.
local tucked = {}
for _, k in ipairs(named) do
    local own = {}
    for kk, vv in pairs(LAYOUT[k]) do
        if type(kk) == "number" then own[kk] = vv else tucked[#tucked + 1] = Key(k) .. ":" .. Json(vv, alias) end
    end
    layout[#layout + 1] = Key(k) .. ":" .. Json(own)
end

local kinds = {}
for _, spec in ipairs(Margin.ORDER) do
    kinds[#kinds + 1] = {
        kind = spec.kind, order = spec.order, pool = spec.pool, filler = spec.filler or false,
        wants = spec.wants ~= nil, fits = spec.fits ~= nil, after = spec.after ~= nil,
    }
end

local lines = {
    "const GEO = {",
    "  RIGHT_H: " .. Json(YD.RIGHT_H) .. ",",
    "  LAYOUT: {",
}
for i, l in ipairs(layout) do lines[#lines + 1] = "    " .. l .. (i < #layout and "," or "") end
lines[#lines + 1] = "  },"
lines[#lines + 1] = "  TUCKED: {" .. table.concat(tucked, ",") .. "},"
for _, pair in ipairs({ { "SNAPSHOT", YD.SNAPSHOT }, { "CAPTION", YD.CAPTION }, { "OFF", YD.OFF },
    { "ROW", YD.ROW }, { "LEADER", YD.LEADER }, { "PEOPLE", Margin.PEOPLE }, { "KINDS", kinds } }) do
    lines[#lines + 1] = "  " .. pair[1] .. ": " .. assert(Json(pair[2]), pair[1]) .. ","
end
lines[#lines + 1] = "};"

local path = os.getenv("SD_LAYOUT_OUT") or "/tmp/sd-layout.js"
local out = assert(io.open(path, "w"))
out:write(table.concat(lines, "\n"), "\n")
out:close()
print("layout_json: wrote " .. path)
