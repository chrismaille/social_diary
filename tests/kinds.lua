-- Every feature registered whole, and core naming none of them.
--
-- A detection lives in Features/<Name>/ and plugs into the registries
-- (Core/Rows.lua, Journey.RegisterList, Recap.RegisterMoment,
-- Plate.RegisterMark and RegisterPass, JourneyMargin.Register,
-- Text.RegisterCaption and RegisterLines). A registration left half done
-- still loads, and the page quietly does without it: a People row reads
-- as its raw type, a moment opens a plate with no mark on it, two kinds
-- share a place in the margin. These checks catch that before the client
-- does, and catch core reaching into a feature by name again.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local function Sorted(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

--------------------------------------------------------------------------
Section("every People row kind reads and shows")

for _, kind in ipairs(ns.Rows.All()) do
    local k = ns.Rows.Get(kind)
    if not k.hidden then
        Check(type(k.text) == "function", kind .. " has no words on the timeline")
        Check(type(k.icon) == "string", kind .. " has no icon")
        Check(#(ns.Style.ART[k.icon] or {}) > 0, kind .. "'s icon " .. tostring(k.icon) .. " has no art")
        Check(k.activity ~= nil or k.moment ~= nil, kind .. " is neither an activity nor a moment")
        Check(k.observed or k.reason or k.activity, kind .. " has no reason for the picker")
    end
end

--------------------------------------------------------------------------
Section("every recap moment is ranked, gathered and marked")

local Recap, Plate = ns.JourneyRecap, ns.UI.JourneyPlate
local orders = {}
for _, kind in ipairs(Sorted(Recap.MOMENTS)) do
    local spec = Recap.MOMENTS[kind]
    Check(type(Recap.RANK[kind]) == "number", kind .. " has no rank")
    Check(spec.entry ~= nil, kind .. " gathers into no entry field")
    Check(spec.gather ~= nil or (spec.list ~= nil and ns.Journey.LISTS[spec.list] ~= nil),
        kind .. " gathers from a list nobody registered")
    Check(spec.moment ~= nil or spec.field ~= nil, kind .. " puts its record in no field of the moment")
    Check(Plate.MARKS[kind] ~= nil, kind .. " has no mark on the plates")
    Check(not orders[spec.order], kind .. " shares its order with " .. tostring(orders[spec.order]))
    orders[spec.order or 0] = kind
end

--------------------------------------------------------------------------
Section("every mark draws in its own place")

local marks = {}
local markName = {}
for name, spec in pairs(Plate.MARKS) do markName[spec] = name end
for _, spec in ipairs(Plate.MARK_ORDER) do
    local kind = markName[spec] or "?"
    Check(type(spec.draw) == "function", kind .. "'s mark draws nothing")
    Check(type(spec.cap) == "number" and spec.count ~= nil, kind .. "'s mark has no cap or count")
    Eq(Plate.CAP[spec.count], spec.cap, kind .. "'s cap is not in CAP")
    Check(spec.order ~= Plate.ROAD_DEATHS, kind .. " is drawn on the road deaths' turn")
    Check(not marks[spec.order], kind .. " shares its order with " .. tostring(marks[spec.order]))
    marks[spec.order] = kind
end

--------------------------------------------------------------------------
Section("every margin note has its pool, words and leader, in its own place")

local Margin = ns.UI.JourneyMargin
local margin = {}
for name, at in pairs(Margin.PEOPLE) do margin[at] = "people (" .. name .. ")" end
for _, kind in ipairs(Sorted(Margin.KINDS)) do
    local spec = Margin.KINDS[kind]
    Check(type(spec.pool) == "string", kind .. "'s note has no pool")
    Check(type(spec.new) == "function" and type(spec.write) == "function", kind .. "'s note is never made or written")
    Check(type(spec.mark) == "function", kind .. "'s note has no leader to its mark")
    Check(spec.item ~= nil or spec.items ~= nil, kind .. "'s note takes nothing from the plate")
    Check(not margin[spec.order], kind .. " shares its margin place with " .. tostring(margin[spec.order]))
    margin[spec.order] = kind
end

--------------------------------------------------------------------------
Section("every caption's words have their own places")

local Text = ns.UI.JourneyText
local leads, tails = {}, {}
for _, key in ipairs(Sorted(Text.CAPTIONS)) do
    local spec = Text.CAPTIONS[key]
    Check(spec.moment == nil or Recap.MOMENTS[spec.moment] ~= nil or spec.moment == "death",
        key .. "'s caption gathers a moment kind nobody registered")
    if spec.lead then
        Check(not leads[spec.lead.at], key .. " leads at " .. spec.lead.at .. " with " .. tostring(leads[spec.lead.at]))
        leads[spec.lead.at] = key
    end
    if spec.tail then
        Check(not tails[spec.tail.at], key .. " tails at " .. spec.tail.at .. " with " .. tostring(tails[spec.tail.at]))
        tails[spec.tail.at] = key
    end
end
local paragraphs = {}
for _, p in ipairs(Text.Paragraphs()) do
    local at = tostring(p.at) .. ":" .. tostring(p.run or p.key)
    Check(not paragraphs[at], tostring(p.key) .. " shares its paragraph place with " .. tostring(paragraphs[at]))
    paragraphs[at] = p.key
end

--------------------------------------------------------------------------
Section("every feature's files load, and core names no feature")

local function Read(path)
    local f = assert(io.open(path, "r"), "cannot read " .. path)
    local s = f:read("*a")
    f:close()
    return s
end
local function Ls(cmd)
    local list, p = {}, assert(io.popen(cmd))
    for line in p:lines() do list[#list + 1] = line end
    p:close()
    return list
end

local toc = Read("social_diary.toc")
local packaged = toc:match("^(.-)#@do%-not%-package@") or toc
local features = Ls("ls -1 Features")
Check(#features > 0, "no Features/ folder")
for _, name in ipairs(features) do
    for _, file in ipairs(Ls("ls -1 Features/" .. name)) do
        local path = "Features/" .. name .. "/" .. file
        Check(toc:find(path, 1, true) ~= nil, path .. " is not in the TOC")
        if file == "Dev.lua" then
            Check(packaged:find(path, 1, true) == nil, path .. " would be packaged")
        end
    end
    Check(ns[name] ~= nil, "Features/" .. name .. " makes no ns." .. name)
end
Check(Read(".pkgmeta"):find("Features/*/Dev.lua", 1, true) ~= nil, ".pkgmeta does not leave the features' Dev.lua out")

for _, dir in ipairs({ "Core", "Core/Bridges", "UI", "Capture", "Dev" }) do
    for _, file in ipairs(Ls("ls -1 " .. dir .. "/*.lua 2>/dev/null")) do
        local code = Read(file)
        for _, name in ipairs(features) do
            Check(not code:find("ns%." .. name .. "[^%w_]"), file .. " names the feature ns." .. name)
        end
    end
end
