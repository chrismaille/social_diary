-- The journal's art (Style, from UI/StyleTokens.lua): each key a list of
-- candidate files, the first the client has winning, and flat colour when
-- none does. Also the instance and character pictures, which fall back the
-- same way, and the gradients, shades and noise the book is drawn with.

local addonName, ns = ...

local Style = ns.Style

--------------------------------------------------------------------------
-- Art, with fallbacks
--------------------------------------------------------------------------

Style.ART = {
    -- Flat colour by default: in-client (6 Oct) every paper texture cost
    -- contrast, and the Spellbook pages are sprite sheets. PAPER_TRIALS below.
    paperLeft = {},
    paperRight = {},
    grain = { "Interface\\Stationery\\StationeryTest1" },
    -- Grime and wear on the cover and brass: a rough, high-contrast texture.
    grime = { "Interface\\FrameGeneral\\UI-Background-Rock", "Interface\\FrameGeneral\\UI-Background-Marble",
        "Interface\\Stationery\\StationeryTest1" },
    circle = { "Interface\\CharacterFrame\\TempPortraitAlphaMask" },
    classes = { "Interface\\TargetingFrame\\UI-Classes-Circles" },
    book = { "Interface\\Icons\\INV_Misc_Book_09" },
    map = { "Interface\\Icons\\INV_Misc_Map_01" },
    search = { "Interface\\Common\\UI-Searchbox-Icon" },
    together = { "Interface\\GossipFrame\\TabardGossipIcon" },
    talk = { "Interface\\GossipFrame\\GossipGossipIcon" },
    -- The same bubble, in the chat's whisper or party colour (ART_TINT).
    whisper = { "Interface\\GossipFrame\\GossipGossipIcon" },
    party = { "Interface\\GossipFrame\\GossipGossipIcon" },
    trade = { "Interface\\GossipFrame\\VendorGossipIcon" },
    -- An instance visit on the timeline (TLN-4).
    dungeon = { "Interface\\Icons\\INV_Misc_Key_03", "Interface\\Icons\\INV_Sword_04" },
    -- A rare killed together: a timeline moment (TLN-2).
    rare = { "Interface\\Icons\\INV_Misc_Head_Dragon_01", "Interface\\Icons\\INV_Sword_04" },
    -- A death in a session: a timeline moment.
    death = { "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", "Interface\\Icons\\Ability_Rogue_FeignDeath",
        "Interface\\Icons\\INV_Sword_04" },
    -- A diary entry's level-up: a timeline moment.
    levelup = { "Interface\\Icons\\Spell_Holy_SurgeOfLight", "Interface\\Icons\\Spell_Holy_Restoration",
        "Interface\\Icons\\INV_Sword_04" },
    -- The Recently nearby table: attackable when seen, and the sort direction.
    hostile = { "Interface\\Icons\\Ability_DualWield", "Interface\\Icons\\INV_Sword_04" },
    sortArrow = { "Interface\\Buttons\\UI-SortArrow" },
    -- SES-9's "seen around": something glimpsed, not done.
    around = { "Interface\\Icons\\INV_Misc_Spyglass_03", "Interface\\Icons\\Ability_Tracking" },
    -- A campfire sat by together (Capture/Campfire.lua): Basic Campfire's
    -- own spell icon.
    campfire = { "Interface\\Icons\\Spell_Fire_Fire", "Interface\\Icons\\INV_Sword_04" },
    -- An inventory icon, so it keeps its dark square (fine at 14 px).
    added = { "Interface\\Icons\\INV_Feather_05" },
    -- A note the user wrote (DIA-11), standing on its own on the timeline.
    note = { "Interface\\Icons\\INV_Misc_Note_01", "Interface\\Icons\\INV_Scroll_03" },
}

-- What `/sd art paper` steps through, as { left page, right page }.
Style.PAPER_TRIALS = {
    { "Interface\\Stationery\\StationeryTest1", "Interface\\Stationery\\StationeryTest1" },
    { "Interface\\QuestFrame\\QuestBG", "Interface\\QuestFrame\\QuestBG" },
    { "Interface\\Spellbook\\Spellbook-Page-1", "Interface\\Spellbook\\Spellbook-Page-2" },
}

-- `/sd art paper` steps through PAPER_TRIALS, for picking one in the client.
-- Not saved: a winner goes into ART instead.
local override = {}

local resolved = {}

local function Exists(path)
    if not GetFileIDFromPath then return true end  -- cannot tell; try it
    return GetFileIDFromPath(path) ~= nil
end

function Style.Art(key)
    if override[key] ~= nil then return override[key] or nil end
    if resolved[key] == nil then
        resolved[key] = false
        for _, path in ipairs(Style.ART[key] or {}) do
            if Exists(path) then
                resolved[key] = path
                break
            end
        end
    end
    return resolved[key] or nil
end

-- Cycles both pages through the trials, then flat colour, then around.
local trial = 0

function Style.NextPaper()
    local list = Style.PAPER_TRIALS
    trial = trial % (#list + 1) + 1
    if trial > #list then
        override.paperLeft, override.paperRight = false, false
        ns.Print("paper: flat colour")
    else
        override.paperLeft, override.paperRight = list[trial][1], list[trial][2]
        ns.Print("paper %d of %d: %s", trial, #list, list[trial][1])
    end
    ns.Fire("SD_PAPER_CHANGED")
end

-- Inventory icons have a baked-in dark square and a frame at the edge.
-- ICON_CROP, as texture coordinates, cuts the frame off.
Style.ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }

function Style.IsInventoryIcon(key)
    local path = Style.Art(key)
    return path ~= nil and path:find("^Interface\\Icons\\") ~= nil
end

-- Art drawn in a colour: each a function returning r, g, b. Whispers and
-- party lines take the chat's own colour for them, so a player who changed
-- it sees theirs; the fallback is the client's default.
local function ChatColour(chatType, r, g, b)
    return function()
        local info = ChatTypeInfo and ChatTypeInfo[chatType]
        if info and info.r then return info.r, info.g, info.b end
        return r, g, b
    end
end

local ART_TINT = {
    whisper = ChatColour("WHISPER", 1, 0.5, 1),
    party = ChatColour("PARTY", 0.667, 0.667, 1),
}

-- The colour to draw art `key` in: white (as drawn) unless it is tinted.
function Style.ArtTint(key)
    local tint = ART_TINT[key]
    if tint then return tint() end
    return 1, 1, 1
end

-- Sounds, by key, as art is: each a list of SOUNDKIT names, the first the
-- client knows winning, and silence where it knows none. Played on the
-- sound effects channel, so the player's effects volume and switch govern
-- them. Only the book's own moments make a sound; choosing a person in the
-- list does not.
--   sheetOpen, sheetClose  a loose sheet laid on the book or taken off it:
--                          paper, the quest log's, which the world map shares
--   pageTurn               a ribbon turning the book to another page
--   write                  something new written into the diary: a person
--                          added, a new note saved. The quill of a quest
--                          written into the log
--   tear                   the parcel at login torn open: a bag opened
--   foeAlert               a foe in view (Core/Reunions.lua): the raid
--                          warning, on the master channel, so it is heard
--                          with sound effects turned down
Style.SOUNDS = {
    sheetOpen = { "IG_QUEST_LOG_OPEN", "IG_SPELLBOOK_OPEN" },
    sheetClose = { "IG_QUEST_LOG_CLOSE", "IG_SPELLBOOK_CLOSE" },
    pageTurn = { "IG_ABILITY_PAGE_TURN", "IG_SPELLBOOK_OPEN" },
    write = { "IG_WRITE_QUEST", "IG_QUEST_LIST_SELECT" },
    foeAlert = { "RAID_WARNING", "READY_CHECK" },
    -- The parcel at login torn open (UI/Intro.lua): a bag opened, the
    -- wrapping coming off (chosen in-client, 9 Oct; the quest abandon's rip
    -- did not fit), else a sheet laid down.
    tear = { "IG_BACKPACK_OPEN", "IG_QUEST_LOG_OPEN" },
}

-- `channel` is "SFX" unless given.
function Style.PlaySound(key, channel)
    if not (PlaySound and SOUNDKIT) then return end
    for _, name in ipairs(Style.SOUNDS[key] or {}) do
        local id = SOUNDKIT[name]
        if id then
            PlaySound(id, channel or "SFX")
            return
        end
    end
end

function Style.SetTexture(texture, key, r, g, b, a)
    local path = Style.Art(key)
    if path then
        texture:SetTexture(path)
        return true
    end
    if r then texture:SetColorTexture(r, g, b, a or 1) end
    return false
end

-- A round spot of colour: the circle art tinted, else a flat square of the
-- same colour. Returns whether it came out round.
function Style.Disc(texture, r, g, b, a)
    local circle = Style.Art("circle")
    if circle then
        texture:SetTexture(circle)
        texture:SetVertexColor(r, g, b, a)
    else
        texture:SetColorTexture(r, g, b, a)
    end
    return circle ~= nil
end

-- A two-colour gradient, each colour { r, g, b, a }: `from` at the start of
-- `orientation` (left, or bottom for VERTICAL), `to` at the end. SetGradient
-- takes colour objects in current clients; where that fails, a flat wash at
-- the average is close enough.
function Style.Gradient(texture, orientation, from, to)
    texture:SetColorTexture(1, 1, 1, 1)
    local ok = CreateColor and pcall(texture.SetGradient, texture, orientation,
        CreateColor(from[1], from[2], from[3], from[4]), CreateColor(to[1], to[2], to[3], to[4]))
    if not ok then
        texture:SetColorTexture((from[1] + to[1]) / 2, (from[2] + to[2]) / 2, (from[3] + to[3]) / 2,
            (from[4] + to[4]) / 2)
    end
end

-- A soft edge in one colour: alpha `from` at the start, `to` at the end.
function Style.Shade(texture, orientation, r, g, b, from, to)
    Style.Gradient(texture, orientation, { r, g, b, from }, { r, g, b, to })
end

-- An ink hairline round `target` (the frame itself by default), drawn on
-- `frame` in `layer` and `sublevel`: top, bottom, left, right. `alpha` is
-- one alpha for all four, or { top, bottom, left, right }.
local SIDES = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
    { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }

function Style.Hairline(frame, layer, sublevel, alpha, target)
    local INK = Style.INK
    target = target or frame
    for i, side in ipairs(SIDES) do
        local line = frame:CreateTexture(nil, layer, nil, sublevel)
        line:SetPoint(side[1], target)
        line:SetPoint(side[2], target)
        if i <= 2 then line:SetHeight(1) else line:SetWidth(1) end
        line:SetColorTexture(INK[1], INK[2], INK[3], type(alpha) == "table" and alpha[i] or alpha)
    end
end

-- Noise in [0, 1) that is the same every time, so the book does not age
-- differently each time it opens.
local function Noise(n)
    local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
    return x - math.floor(x)
end
Style.Noise = Noise

-- The group finder's picture of each instance, by the instanceID
-- GetInstanceInfo gives (db.instances). Any id missing here, or any file the
-- client lacks, falls back to the name with its spaces and marks taken out,
-- then to a drop cap. In-client (7 Oct): WailingCaverns, RazorfenKraul and
-- Deadmines exist; the rest of the ids and names are unverified.
local INSTANCE_ART = {
    [389] = "RagefireChasm", [43] = "WailingCaverns", [36] = "Deadmines", [33] = "ShadowfangKeep",
    [48] = "BlackfathomDeeps", [34] = "StormwindStockades", [90] = "Gnomeregan",
    [47] = "RazorfenKraul", [189] = "ScarletMonastery", [129] = "RazorfenDowns", [70] = "Uldaman",
    [209] = "ZulFarak", [349] = "Maraudon", [109] = "SunkenTemple", [230] = "BlackrockDepths",
    [229] = "BlackrockSpire", [429] = "DireMaul", [289] = "Scholomance", [329] = "Stratholme",
    [409] = "MoltenCore", [249] = "OnyxiaEncounter", [469] = "BlackwingLair", [309] = "ZulGurub",
    [509] = "AQRuins", [531] = "AQTemple", [533] = "Naxxramas",
}
local INSTANCE_ART_PATH = "Interface\\LFGFrame\\LFGIcon-"

local instanceArt = {}

function Style.InstanceArt(visit)
    local key = visit.instanceID or visit.name or "?"
    if instanceArt[key] == nil then
        instanceArt[key] = false
        local bare = visit.name and visit.name:gsub("^The ", ""):gsub("[^%a]", "")
        for _, name in ipairs({ INSTANCE_ART[visit.instanceID] or false, bare or false }) do
            if name and Exists(INSTANCE_ART_PATH .. name) then
                instanceArt[key] = INSTANCE_ART_PATH .. name
                break
            end
        end
    end
    return instanceArt[key] or nil
end

--------------------------------------------------------------------------
-- Character art
--------------------------------------------------------------------------

local RACE_ATLAS = { Scourge = "undead", NightElf = "nightelf" }

-- The race portraits are atlases in current clients ("raceicon-tauren-male").
function Style.SetRaceIcon(texture, record)
    if not (record and type(record.race) == "string") then return false end
    if not (C_Texture and C_Texture.GetAtlasInfo and texture.SetAtlas) then return false end

    local race = RACE_ATLAS[record.race] or record.race:lower()
    local sex = record.sex == 3 and "female" or "male"
    local atlas = ("raceicon-%s-%s"):format(race, sex)
    if not C_Texture.GetAtlasInfo(atlas) then return false end

    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetAtlas(atlas)
    return true
end

function Style.SetClassIcon(texture, class)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    local path = coords and Style.Art("classes")
    if not path then return false end
    texture:SetTexture(path)
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    return true
end

-- The class icon, else a faint ink square the same size, so a row without
-- a class keeps its column. For the small icons beside a name.
function Style.ClassIconOrInk(texture, class)
    if Style.SetClassIcon(texture, class) then return end
    local INK = Style.INK
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetColorTexture(INK[1], INK[2], INK[3], 0.35)
end
