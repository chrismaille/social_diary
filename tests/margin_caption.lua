-- The plates' margin and caption registries (.claude/registry-refactor.md,
-- phase 4): a kind registered from a later file (as Features/<Name>/ will)
-- puts its note in every plate's margin at its `order`, from its own pool,
-- with a leader to its mark, counted on the page, and tells the caption
-- what it showed; its caption words go in their lead, tail and coda places
-- among today's. Taken out again, the plates are as they were.
--
-- The kind here is made up ("scrap"); nothing of it is ever shown in the
-- client.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Text = ns.UI.JourneyText
local Margin = ns.UI.JourneyMargin

SELF.level = 12
mock.SetUnit("player", SELF)

--------------------------------------------------------------------------
Section("today's kinds, in their places")

local function Orders()
    local list = {}
    for _, spec in ipairs(Margin.ORDER) do list[#list + 1] = spec.kind .. " " .. spec.order end
    return table.concat(list, ", ")
end
Eq(Orders(), "find 20, witness 30, killer 40, foe 50, lucky 60, hunt 70, campfire 90", "the margin's kinds")
Eq(Margin.PEOPLE.close, 10, "the people who did something with you")
Eq(Margin.PEOPLE.seen, 80, "the people only seen")
for _, key in ipairs({ "find", "finale", "skill", "death", "close", "luck", "fortune", "witness", "campfire" }) do
    Check(Text.CAPTIONS[key] ~= nil, "no caption words for " .. key)
end

--------------------------------------------------------------------------
Section("caption words registered by a later file")

-- A scrap leads between the deaths (50) and a close call (60), is told in
-- the tail between them too (death 40, close 50), and adds a sentence
-- after a witness's (10). `said.scrap` is what its margin note showed.
Text.RegisterCaption("scrap", {
    moment = "scrap",
    take = function(m, said) if not said.hidden then return m end end,
    lead = { at = 55, say = function(list) return #list == 1 and "A scrap" or (#list .. " scraps") end },
    tail = { at = 45, say = function(list) return #list == 1 and "a scrap" or (#list .. " scraps") end },
    coda = { at = 20, say = function(c)
        local n = c.said.scrap
        return n and ("Scraps beside it: " .. n .. ".") or nil
    end },
})
local SCRAP, DEATH = { kind = "scrap" }, { kind = "death" }
local CALL = { kind = "close", call = { pct = 6, name = "Plainstrider" } }
local function Caption(moments, said) return Text.PlateCaption({ mapID = 1412, moments = moments }, nil, said) end
Eq(Caption({ SCRAP }), "A scrap.", "a scrap alone leads")
Eq(Caption({ SCRAP, SCRAP }), "2 scraps.", "two scraps")
Eq(Caption({ DEATH, SCRAP }), "A death, and a scrap.", "the deaths lead before a scrap")
Eq(Caption({ SCRAP, CALL }), "A scrap, and a close call with a Plainstrider.", "a scrap leads before a close call")
Eq(Caption({ CALL, DEATH, SCRAP }), "A death, a scrap, and a close call with a Plainstrider.",
    "a scrap's place in the tail")
Eq(Caption({ SCRAP, { kind = "level", level = 9 } }), "A scrap.", "a scrap leads before the level")
Eq(Caption({ SCRAP, { kind = "level", level = 9 } }, { hidden = true }), "Level 9.", "what it gathers, by `said`")
Eq(Caption({ DEATH }, { scrap = 2 }), "A death. Scraps beside it: 2.", "its coda after the words")
Eq(Caption({ DEATH, SCRAP }, { death = "a Plainstrider", scrap = 1 }),
    "A death, to a Plainstrider, and a scrap. Scraps beside it: 1.", "its words with the margin's")

--------------------------------------------------------------------------
Section("a margin kind registered by a later file")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

local function Open(i)
    page.open = i
    page.mode = "plates"
    ns.UI.RedrawJourneyPage()
end
-- Every entry's plates as they are: each plate's margin kinds and words.
local function Pages()
    local out = {}
    for i in ipairs(page.recap.entries) do
        Open(i)
        local lines = {}
        for k, plate in ipairs(page.plates) do
            if plate:IsShown() then
                local kinds = {}
                for _, it in ipairs(plate.margin or {}) do kinds[#kinds + 1] = it.kind end
                lines[#lines + 1] = k .. ":" .. table.concat(kinds, ",") .. "|" .. (page.captionPool[k] and
                    page.captionPool[k].text or "")
            end
        end
        out[i] = tostring(page.pattern) .. " " .. table.concat(lines, " ")
    end
    return out
end
local before = Pages()

-- A note at order 45: after a killer's card (40), before a close call's
-- (50). Each plate gets one, at the plate's top left corner.
local written = {}
Margin.Register("scrap", {
    order = 45, pool = "scrapPool", count = "scrapsWritten",
    new = function(parent)
        local note = CreateFrame("Frame", nil, parent)
        function note:Layout(x, y, w) self.box = { x, y, w, 20 }; return w, 20 end
        function note:Nearest() return self.box[1], self.box[2] end
        return note
    end,
    item = function(plate)
        local s = plate.slot
        return { scrap = plate, top = s.y + s.pad, x = s.x + s.pad }
    end,
    write = function(note, it, c)
        note.seed = c.Seed("scrap")
        written[#written + 1] = note
    end,
    mark = function(it) local s = it.scrap.slot; return { s.x + s.w / 2, s.y + s.h / 2 } end,
    say = function(said, shown) if shown[1] then said.scrap = #shown end end,
})
Check(page.scrapPool ~= nil, "a kind registered after the page was built has no pool")
local order = {}
for _, spec in ipairs(Margin.ORDER) do order[#order + 1] = spec.kind end
Eq(table.concat(order, ","), "find,witness,killer,scrap,foe,lucky,hunt,campfire", "the kind in its order")

-- On every page, wherever a scrap shows: after the people who did
-- something with you and the cards ordered before it, before the rest;
-- its leader drawn; counted; and the caption told.
local TIER = { session = 1, fight = 1, note = 1, added = 1, find = 1, first = 2, crossed = 3 }
local POS = {}
for _, spec in ipairs(Margin.ORDER) do POS[spec.kind] = spec.order end
local shownScraps = 0
for i in ipairs(page.recap.entries) do
    Open(i)
    local onPage = 0
    for _, plate in ipairs(page.plates) do
        if plate:IsShown() then
            local last, scrap = 0, nil
            for _, it in ipairs(plate.margin or {}) do
                local at = POS[it.kind]
                if it.kind == "person" then
                    -- Its tier (UI/JournalJourney.lua's TIER): something
                    -- done together, or only seen.
                    local tier = 3
                    for _, m in ipairs(it.g.moments) do tier = math.min(tier, TIER[m.kind] or 2) end
                    at = tier == 1 and Margin.PEOPLE.close or Margin.PEOPLE.seen
                end
                Check(at ~= nil, "a margin item of no kind: " .. tostring(it.kind))
                if it.kind ~= "person" then Check(at >= last, "the margin out of its order on entry " .. i) end
                last = math.max(last, at)
                if it.kind == "scrap" then scrap = it end
            end
            if scrap then
                onPage = onPage + 1
                Check(scrap.note ~= nil and scrap.note.seed:match("^scrap:"), "a scrap's note not written")
                local led = false
                for _, link in ipairs(page.links) do
                    if link.strip == scrap.note then led = true end
                end
                Check(led, "a scrap has no leader")
            end
        end
    end
    Eq(page.scrapsWritten, onPage, "the scraps counted on entry " .. i)
    shownScraps = shownScraps + onPage
end
Check(shownScraps > 0, "no scrap was shown anywhere")
Check(#written > 0, "no scrap note was written")

-- The words beside a plate whose scrap showed say so (its `say` into the
-- caption's `said`, the coda above).
local told = false
for i in ipairs(page.recap.entries) do
    Open(i)
    for k = 1, page.captionPool.used do
        local text = page.captionPool[k].text or ""
        if text:find("Scraps beside it: 1.", 1, true) then told = true end
    end
end
Check(told, "no caption was told of its plate's scrap")

--------------------------------------------------------------------------
Section("taken out again")

Margin.Remove("scrap")
Text.RemoveCaption("scrap")
Check(Margin.KINDS.scrap == nil and Text.CAPTIONS.scrap == nil, "the kind is still registered")
local after = Pages()
for i = 1, #before do Eq(after[i], before[i], "entry " .. i .. " as it was") end
Eq(Caption({ SCRAP, DEATH }), "A death.", "a scrap's words gone")
