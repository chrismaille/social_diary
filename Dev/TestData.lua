-- /sd testdata: a made-up diary entry, Tester Testerson, with a week of
-- history -- questing sessions, two dungeon visits, rares, trades, chat, a
-- seen-around stretch, notes the user wrote -- so the profile timeline
-- (TLN-1 to TLN-10) can be looked at in the client without playing it all
-- first; and a made-up route under it for Your Diary (8.11).
--
-- Everything is written through the modules capture writes through, timed
-- relative to now. The GUID is not a real character's (realm 0000), and every
-- session and visit is marked `test`, so /sd testdata remove takes it all
-- out again. Writing again replaces the last copy.
--
-- Development tooling, but the in-client test runbooks use it: it stays in
-- the TOC's Dev/ block until a release drops that.

local addonName, ns = ...

local TestData = {}
ns.TestData = TestData

local GUID = "Player-0000-7E57E570"
TestData.GUID = GUID

local MIN, HOUR, DAY = 60, 60 * 60, 24 * 60 * 60

local function Link(quality, id, name)
    return ("|cnIQ%d:|Hitem:%d::::::::::::|h[%s]|h|r"):format(quality, id, name)
end

local LINEN = Link(1, 2589, "Linen Cloth")
local JERKY = Link(1, 117, "Tough Jerky")
local STAFF = Link(2, 6505, "Crescent Staff")
-- Your Diary's firsts (JRN-24): the made-up route's first bag, green,
-- shoulders, blue (Tester's gift) and epic.
local POUCH = Link(1, 4496, "Small Brown Pouch")
local BRACERS = Link(2, 6070, "Wolfskin Bracers")
local SHOULDERS = Link(1, 1806, "Rawhide Shoulderpads")
local CLOAK = Link(3, 6449, "Glowing Lizardscale Cloak")
local GUTWRENCHER = Link(4, 5616, "Gutwrencher")
-- When Tester gave the blue: in the trade of today's last session.
local GIFT_AGO = 82 * MIN

-- Other group members of the visits: only names, they are not diary entries.
local KAELITH = { guid = "Player-0000-7E57E571", first = "Kaelith", surname = "Dawnsong", class = "DRUID", role = "HEALER" }
local BROM = { guid = "Player-0000-7E57E572", first = "Brom", surname = "Ironhide", class = "WARRIOR", role = "TANK" }
local ZURI = { guid = "Player-0000-7E57E573", first = "Zuri", surname = "Nightfang", class = "PRIEST", role = "DAMAGER" }

local function Me()
    return { guid = ns.ownGUID, first = "You", role = "DAMAGER" }
end

local function Tester()
    return { guid = GUID, first = "Tester", surname = "Testerson", class = "SHAMAN", role = "DAMAGER" }
end

-- Closed, so it never becomes the open session.
local function Session(start, seconds, zones, p, extra)
    p.since, p.last, p.seconds = start, start + seconds, seconds
    local opts = {
        source = "group", test = true, startedAt = start, endedAt = start + seconds,
        participants = { [GUID] = p }, zones = zones,
    }
    for k, v in pairs(extra or {}) do opts[k] = v end
    return ns.Sessions.New(opts)
end

local function Visit(visit)
    visit.test = true
    return ns.Instances.New(visit)
end

-- The zone alone, as written: where the user stands now would be wrong. The
-- session is the one given or none, never whatever happens to be open.
local function Row(kind, time, zone, data, session)
    data = data or {}
    data.time = time
    data.where = { zone = zone }
    data.session = session and session.id or false
    return ns.Interactions.Add(GUID, kind, data)
end

local function Chat(start, zone, session, lines)
    for i, line in ipairs(lines) do
        Row(line[1] == ">" and "whisper_out" or "whisper_in", start + i * 20, zone,
            { excerpt = line[2] }, session)
    end
end

-- A level-up as UNIT_LEVEL would have stored it (Characters.Observe).
local function LevelUp(time, zone, level, session)
    Row("level_up", time, zone, { context = { from = level - 1, level = level } }, session)
end

local function Quests(n, from)
    local list = {}
    for i = 1, n do list[i] = from + i end
    return list
end

--------------------------------------------------------------------------
-- Your Diary (8.11): a made-up route for the logged-in character
--------------------------------------------------------------------------
--
-- Levels 10 to 16 over six evenings, several zones a level: a grinding
-- stop, roads, the hearthstone (no line drawn across), a city, a flight, a
-- dungeon pinned at its door, then two weeks at a pretend cap of 16 (the
-- client's own is far above), timed to lie under Tester's sessions, notes
-- and a fight, so the map plates have meetings on them. The real route is
-- parked while it is here and comes back with /sd testdata remove; capture
-- leaves a test route alone.

local DUROTAR, BARRENS, ORGRIMMAR, STONETALON = 1411, 1413, 1454, 1442
local JOURNEY_CAP = 16

function TestData.RemoveJourney()
    local guid = ns.ownGUID
    local j = guid and ns.db.journey[guid]
    if not (j and j.test) then return false end
    local parked = ns.db.journeyParked
    ns.db.journey[guid] = parked and parked[guid] or nil
    if parked then
        parked[guid] = nil
        if next(parked) == nil then ns.db.journeyParked = nil end
    end
    ns.Journey.Touch()
    return true
end

function TestData.WriteJourney(now)
    TestData.RemoveJourney()
    local guid = ns.ownGUID
    if not guid then return nil end
    local J = ns.Journey
    if ns.db.journey[guid] then
        ns.db.journeyParked = ns.db.journeyParked or {}
        ns.db.journeyParked[guid] = ns.db.journey[guid]
    end

    local start = ns.DayStart(now - 20 * DAY) + 18 * HOUR
    local j = { startedAt = start, startLevel = 10, startMapID = DUROTAR, levels = {}, segments = {}, marks = {},
        test = { maxLevel = JOURNEY_CAP, level = JOURNEY_CAP } }
    ns.db.journey[guid] = j

    local level, t = 10, start
    local function Push(seg)
        seg.levelFrom, seg.levelTo = level, level
        j.segments[#j.segments + 1] = J.Pack(seg)
    end
    local function Road(seconds, map, pts)
        Push({ kind = "road", from = t, to = t + seconds, mapID = map, pts = J.PackPoints(pts) })
        t = t + seconds
    end
    local function Stop(seconds, map, x, y, r, act, sub)
        Push({ kind = "stop", from = t, to = t + seconds, mapID = map, x = x, y = y, r = r, seconds = seconds,
            act = act, subZone = sub })
        t = t + seconds
    end
    local function Flight(seconds, map1, x1, y1, map2, x2, y2)
        Push({ kind = "flight", from = t, to = t + seconds, mapID = map1, mapID1 = map1, x1 = x1, y1 = y1,
            mapID2 = map2, x2 = x2, y2 = y2 })
        t = t + seconds
    end
    local function Dungeon(seconds, map, x, y, id, name)
        Push({ kind = "dungeon", from = t, to = t + seconds, mapID = map, x = x, y = y, instanceID = id,
            instanceType = "party", name = name, seconds = seconds })
        t = t + seconds
    end
    local function Ding(map, x, y, sub)
        level = level + 1
        j.levels[level] = { at = t, mapID = map, x = x, y = y, subZone = sub }
    end
    -- A first found at `at`, at the level then, as capture keeps it
    -- (Journey.Firsts).
    j.firsts = {}
    local function Find(kind, at, map, x, y, link, from, giver)
        j.firsts[kind] = { t = at, mapID = map, x = x, y = y, level = level, link = link, from = from,
            guid = giver }
    end
    -- Close calls (JRN-25) and quest drops counted (JRN-26), as capture
    -- keeps them (Journey.CloseCall, Journey.HuntDone), at the level then.
    -- Five hunts, so the character's usual is known (Journey.UsualLuck):
    -- four usual ones, which never show, and one that was bad luck. Item IDs
    -- as QuestieDB has them (the hunt card's icon); the harpies' talons and the
    -- Kolkar key keep none, as an old record.
    j.closeCalls, j.hunts = {}, {}
    local function Close(at, map, x, y, pct, seconds, foe)
        local call = { t = at, mapID = map, x = x, y = y, level = level, pct = pct, seconds = seconds }
        for key, value in pairs(foe or {}) do call[key] = value end
        j.closeCalls[#j.closeCalls + 1] = call
    end
    local function Hunt(at, map, x, y, quest, need, kills, npcID, name, extra)
        local hunt = { t = at, mapID = map, x = x, y = y, level = level, questID = quest[1],
            title = quest[2], item = quest[3], need = need, kills = kills, npcID = npcID, name = name }
        for key, value in pairs(extra or {}) do hunt[key] = value end
        j.hunts[#j.hunts + 1] = hunt
    end
    -- Chain finales (JRN-28), as capture keeps them (Journey.Finale): the
    -- quest turned in, how many of the chain were done, and where it began
    -- when the diary saw its first quest taken.
    j.finales, j.chainStarts = {}, {}
    local function Finale(at, map, x, y, questID, title, n, started)
        j.finales[#j.finales + 1] = { t = at, mapID = map, x = x, y = y, level = level, questID = questID,
            title = title, n = n, started = started }
    end
    -- Profession caps (JRN-29), as capture keeps them (Journey.SkillCap).
    j.skillCaps = {}
    local function SkillCap(at, map, x, y, skillLine, name, rank)
        j.skillCaps[#j.skillCaps + 1] = { t = at, mapID = map, x = x, y = y, level = level, skillLine = skillLine,
            name = name, rank = rank }
    end

    -- Level 10: Durotar, grinding by Razor Hill, Sen'jin, then west into
    -- The Barrens (the border splits the road).
    Road(600, DUROTAR, { 0.52, 0.44, 0.50, 0.48, 0.47, 0.52, 0.45, 0.55 })
    Stop(1500, DUROTAR, 0.45, 0.56, 55, { combat = 900, deaths = 1 }, "Razor Hill")
    Find("bag", t - 400, DUROTAR, 0.47, 0.54, POUCH, "loot")
    Hunt(t - 300, DUROTAR, 0.46, 0.55, { 817, "Practical Prey", "Durotar Tiger Fur" }, 4, 7, 3121, "Durotar Tiger",
        { itemID = 4892 })
    -- A finale whose chain began before the diary: "a chain of seven", no
    -- more.
    Finale(t - 200, DUROTAR, 0.45, 0.57, 924, "The Demon Seed", 7)
    Road(480, DUROTAR, { 0.45, 0.56, 0.40, 0.60, 0.36, 0.62, 0.34, 0.66 })
    Stop(420, DUROTAR, 0.34, 0.66, 25, { questsOut = 3, questsIn = 2 }, "Sen'jin Village")
    Road(540, DUROTAR, { 0.34, 0.66, 0.25, 0.60, 0.12, 0.55, 0.03, 0.52 })
    Road(720, BARRENS, { 0.97, 0.32, 0.85, 0.30, 0.70, 0.31, 0.58, 0.30, 0.53, 0.29 })
    Stop(1200, BARRENS, 0.52, 0.30, 40, { questsOut = 4, resting = 600 }, "The Crossroads")
    Ding(BARRENS, 0.52, 0.30, "The Crossroads")

    -- Level 11: the Forgotten Pools, the hearthstone to Orgrimmar, and a
    -- flight back down.
    t = start + DAY
    Road(600, BARRENS, { 0.52, 0.30, 0.48, 0.36, 0.46, 0.40, 0.45, 0.44 })
    Stop(1800, BARRENS, 0.45, 0.45, 70, { combat = 1200 }, "The Forgotten Pools")
    J.Fight(j, "lost", nil, t - 600, { mapID = BARRENS, x = 0.45, y = 0.46 })
    -- A close call with no creature targeted: its cross, and no card.
    Close(t - 1500, BARRENS, 0.44, 0.44, 9, 70)
    Hunt(t - 200, BARRENS, 0.46, 0.45, { 845, "The Zhevra", "Zhevra Hooves" }, 4, 6, 3242, "Zhevra Runner",
        { itemID = 5086 })
    -- Good luck on a full plate with a caption column (UI/LuckyCard.lua's
    -- L): four beaks off the first four, where forty were expected.
    Hunt(t - 100, BARRENS, 0.44, 0.46, { 844, "Plainstrider Menace", "Plainstrider Beak" }, 4, 4, 3244,
        "Greater Plainstrider", { expected = 40, itemID = 5087 })
    Road(420, BARRENS, { 0.45, 0.45, 0.50, 0.48, 0.56, 0.50, 0.60, 0.52 })
    t = t + 30
    Stop(900, ORGRIMMAR, 0.54, 0.68, 150, { resting = 900 }, "Valley of Strength")
    -- First Aid at its first cap, bandaging in the city.
    SkillCap(t - 300, ORGRIMMAR, 0.55, 0.67, 129, "First Aid", 75)
    Flight(240, ORGRIMMAR, 0.45, 0.64, BARRENS, 0.51, 0.30)
    Road(500, BARRENS, { 0.51, 0.30, 0.55, 0.25, 0.58, 0.20, 0.60, 0.16 })
    Stop(1500, BARRENS, 0.60, 0.15, 50, { combat = 800, questsOut = 2 }, "The Sludge Fen")
    Find("uncommon", t - 200, BARRENS, 0.61, 0.14, BRACERS, "quest")
    -- Where the Samophlange chain began, for its finale at level 13.
    local samophlange = { t = t - 900, mapID = BARRENS, x = 0.60, y = 0.16, level = level }
    j.chainStarts[894] = samophlange
    Ding(BARRENS, 0.60, 0.15, "The Sludge Fen")

    -- Level 12: west across The Barrens into Stonetalon.
    t = start + 2 * DAY
    Road(700, BARRENS, { 0.60, 0.15, 0.52, 0.20, 0.42, 0.24, 0.35, 0.27, 0.30, 0.28 })
    Stop(1200, BARRENS, 0.30, 0.28, 45, { combat = 600 })
    -- An elite of level 29 and two more, with no display kept: no picture,
    -- the chart and its tag (on a plate of three, where the margin is
    -- tight).
    Close(t - 500, BARRENS, 0.31, 0.29, 4, 95, { npcID = 4442, name = "Razormane Battleguard", rank = "elite",
        foeLevel = 29, foes = 3 })
    Road(600, BARRENS, { 0.30, 0.28, 0.22, 0.25, 0.14, 0.22, 0.05, 0.20 })
    Road(900, STONETALON, { 0.90, 0.80, 0.82, 0.74, 0.76, 0.66, 0.73, 0.60 })
    Stop(1500, STONETALON, 0.72, 0.60, 55, { combat = 900, questsOut = 1 }, "Windshear Crag")
    Hunt(t - 300, STONETALON, 0.71, 0.61, { 6284, "Harpies Threaten", "Witchwing Talon" }, 6, 11, 4022,
        "Bloodfury Harpy", { itemID = 5064 })
    -- Good luck in a narrow column (the lucky card's M, two lines on its
    -- tag): the remains off the first, where nine were expected.
    Hunt(t - 250, STONETALON, 0.72, 0.62, { 6283, "Bloodfury Bloodline", "Bloodfury Ripper's Remains" }, 1, 1,
        4024, "Bloodfury Ripper", { expected = 9 })
    -- Mining at its second cap, off the crag's veins.
    SkillCap(t - 700, STONETALON, 0.73, 0.59, 186, "Mining", 150)
    Ding(STONETALON, 0.72, 0.60, "Windshear Crag")

    -- Level 13: back to The Barrens and into the Wailing Caverns.
    t = start + 3 * DAY
    Road(800, STONETALON, { 0.72, 0.60, 0.78, 0.70, 0.85, 0.78, 0.95, 0.86 })
    Road(700, BARRENS, { 0.06, 0.22, 0.20, 0.28, 0.32, 0.33, 0.42, 0.36, 0.46, 0.36 })
    Dungeon(3000, BARRENS, 0.46, 0.36, 43, "Wailing Caverns")
    Road(400, BARRENS, { 0.46, 0.36, 0.49, 0.33, 0.52, 0.30 })
    Stop(600, BARRENS, 0.52, 0.30, 30, { questsOut = 3, resting = 500 }, "The Crossroads")
    Find("shoulder", t - 250, BARRENS, 0.53, 0.31, SHOULDERS, "vendor")
    Hunt(t - 2000, BARRENS, 0.50, 0.40, { 867, "Harpy Raiders", "Harpy Talon" }, 8, 13, 3276, "Witchwing Harpy")
    -- A chain of eight brought to its end, begun at the Sludge Fen.
    Finale(t - 150, BARRENS, 0.52, 0.31, 3924, "Samophlange Manual", 8, samophlange)
    -- Then good luck out west, an hour the route did not keep: a light
    -- plate after the full one. Its print would be tucked into the full
    -- plate's row (F+L), but the lucky card's S will not go on the smaller
    -- print, so the page is FL and S lies on the snapshot, its corner come
    -- unstuck (UI/LuckyCard.lua). The blood off four lizards, where 33
    -- were expected.
    t = t + 3600
    Hunt(t - 1800, BARRENS, 0.16, 0.25, { 907, "Enraged Thunder Lizards", "Thunder Lizard Blood" }, 3, 4, 3239,
        "Thunder Lizard", { expected = 33 })
    Ding(BARRENS, 0.52, 0.30, "The Crossroads")

    -- Level 14: one long evening at Camp Taurajo.
    t = start + 4 * DAY
    Road(900, BARRENS, { 0.52, 0.30, 0.50, 0.40, 0.48, 0.50, 0.47, 0.58 })
    Stop(2400, BARRENS, 0.47, 0.58, 60, { combat = 1600, deaths = 2 }, "Camp Taurajo")
    -- One common creature of level 13, with its display: its card cut in
    -- ink over the chart, "Lv 13" on its tag, no deed.
    -- The Murloc Streamrunner (735) and its display (527) are the pair seen
    -- in the client (10 Oct), out of its own zone.
    Close(t - 1200, BARRENS, 0.48, 0.57, 6, 48, { npcID = 735, name = "Murloc Streamrunner", display = 527,
        foeLevel = 13 })
    -- Good luck (EXT-3): the one item off the first kill, where ten were
    -- expected; and seven off four, where 58 were.
    Hunt(t - 900, BARRENS, 0.46, 0.59, { 852, "Hezrul's Head", "Hezrul's Head" }, 1, 1, 3396, "Hezrul Bloodmark",
        { expected = 10, itemID = 5025 })
    Hunt(t - 300, BARRENS, 0.48, 0.60, { 4021, "Counterattack!", "Kolkar Booty Key" }, 7, 4, 3275,
        "Kolkar Marauder", { expected = 58.3 })
    Ding(BARRENS, 0.47, 0.58, "Camp Taurajo")

    -- Level 15: the Raptor Grounds; level 16 is the pretend cap.
    t = start + 5 * DAY
    Road(800, BARRENS, { 0.47, 0.58, 0.44, 0.66, 0.42, 0.74, 0.44, 0.82 })
    Stop(2100, BARRENS, 0.44, 0.82, 50, { combat = 1400 }, "Raptor Grounds")
    Find("epic", t - 700, BARRENS, 0.45, 0.80, GUTWRENCHER, "loot")
    -- An old record, kept before levels were: a common creature and one
    -- more, no tag.
    Close(t - 1500, BARRENS, 0.45, 0.81, 7, 30, { npcID = 3256, name = "Sunscale Scytheclaw", foes = 2 })
    -- The bad luck: five horns took 26 raptors of two kinds, where twelve
    -- were expected (EXT-2).
    Hunt(t - 400, BARRENS, 0.43, 0.83, { 865, "Raptor Horns", "Intact Raptor Horn" }, 5, 26, 3256,
        "Sunscale Scytheclaw", { expected = 12, itemID = 5055,
            byKind = { [3256] = { n = 17, name = "Sunscale Scytheclaw" },
                [3254] = { n = 9, name = "Sunscale Lashtail" } } })
    Road(600, BARRENS, { 0.44, 0.82, 0.48, 0.74, 0.50, 0.64 })
    Stop(900, BARRENS, 0.50, 0.63, 35, { questsOut = 2 })
    Ding(BARRENS, 0.50, 0.63)

    -- Two weeks at the cap, under Tester's sessions (TestData.Write).
    t = now - 12 * DAY
    Road(600, BARRENS, { 0.50, 0.63, 0.53, 0.52, 0.56, 0.44 })
    Stop(1800, BARRENS, 0.56, 0.42, 45, { combat = 1000 }, "Lushwater Oasis")
    -- A rare of level 23 and another with it, out at 1%: the barest bar.
    Close(t - 900, BARRENS, 0.57, 0.41, 1, 38, { npcID = 5828, name = "Humar the Pridelord", rank = "rare",
        foeLevel = 23, foes = 2 })
    t = now - 9 * DAY
    Flight(260, BARRENS, 0.51, 0.30, ORGRIMMAR, 0.45, 0.64)
    Stop(1200, ORGRIMMAR, 0.50, 0.70, 150, { resting = 1200 }, "Valley of Strength")
    t = now - 6 * DAY + 200
    Road(100, BARRENS, { 0.52, 0.36, 0.55, 0.41 })
    Stop(2700, BARRENS, 0.55, 0.42, 50, { combat = 1500, questsOut = 5 }, "Lushwater Oasis")
    J.Fight(j, "won", GUID, now - 6 * DAY + 1500, { mapID = BARRENS, x = 0.57, y = 0.44 })
    t = now - DAY - 5 * HOUR
    Stop(3600, BARRENS, 0.50, 0.35, 60, { combat = 2000 }, "Razormane Grounds")
    Dungeon(52 * MIN, BARRENS, 0.46, 0.36, 43, "Wailing Caverns")
    Road(600, BARRENS, { 0.46, 0.36, 0.35, 0.30, 0.22, 0.25, 0.05, 0.20 })
    Road(600, STONETALON, { 0.90, 0.80, 0.80, 0.72, 0.72, 0.62 })
    Stop(2700, STONETALON, 0.71, 0.61, 55, { combat = 1200, questsOut = 4 }, "Windshear Crag")
    -- A boss with a skull for its level, made up for the tag: "Lv ?? (Boss)".
    Close(t - 800, STONETALON, 0.70, 0.60, 3, 120, { npcID = 12397, name = "Lord Kazzak", rank = "worldboss",
        foeLevel = -1 })
    t = now - 4 * HOUR
    Road(180, BARRENS, { 0.44, 0.82, 0.43, 0.88, 0.43, 0.90 })
    Dungeon(35 * MIN, BARRENS, 0.43, 0.90, 47, "Razorfen Kraul")
    t = now - 90 * MIN
    Stop(1200, BARRENS, 0.52, 0.30, 40, { questsOut = 2, resting = 300 }, "The Crossroads")
    -- Tester's gift, in the trade of that session (TestData.Write).
    Find("rare", now - GIFT_AGO, BARRENS, 0.535, 0.31, CLOAK, "trade", GUID)

    J.Touch()
    return j
end

function TestData.Remove()
    TestData.RemoveJourney()
    local had = ns.db.characters[GUID] ~= nil
    -- Every test session has Tester as its only participant, so forgetting
    -- them drops those sessions. A visit outlives one member, though, so the
    -- made-up ones go by their mark.
    ns.Characters.Forget(GUID)
    for _, visit in ipairs(ns.Instances.All()) do
        if visit.test then ns.Instances.Remove(visit.id) end
    end
    return had
end

function TestData.Write(now)
    TestData.Remove()
    now = now or ns.Now()

    ns.Characters.Observe(GUID, {
        first = "Tester", surname = "Testerson", class = "SHAMAN", race = "Orc",
        faction = "Horde", level = 22, sex = 2, time = now - 6 * DAY - HOUR,
    })

    -- Six days ago: chat and a trade with a stranger, then the add, then a
    -- first questing session (TLN-8: the add sits above the exchange).
    local t1 = now - 6 * DAY
    Chat(t1, "The Barrens", nil, {
        { "<", "hey, you doing the Kolkar quests too?" },
        { ">", "yeah, want to group?" },
        { "<", "sure, but got any spare linen first?" },
    })
    Row("trade", t1 + 90, "The Barrens", { context = { given = { { link = LINEN, count = 10 } } } })
    Row("whisper_in", t1 + 110, "The Barrens", { excerpt = "ty! inviting" })

    local entry = ns.Diary.Add(GUID, { source = "test" })
    if not entry then
        ns.Print("could not write the test character.")
        return nil
    end
    entry.addedAt = t1 + 100
    entry.addedContext.zone = "The Barrens"
    entry.note = "Test data from /sd testdata. Remove it with /sd testdata remove."
    entry.tags = { "test" }
    entry.relationship = "questing buddy"

    local s1 = Session(t1 + 300, 45 * MIN, { "The Barrens" },
        { quests = Quests(5, 800), levelStart = 17, levelEnd = 18 },
        { deaths = { [ns.ownGUID] = 1 }, deathLog = {
            { guid = ns.ownGUID, time = t1 + 300 + 20 * MIN, zone = "The Barrens", subZone = "Lushwater Oasis",
                killer = { source = "recap", name = "Kolkar Pack Runner", npcID = 3274, attackers = 2 } },
        } })
    LevelUp(t1 + 300 + 32 * MIN, "The Barrens", 18, s1)
    Chat(t1 + 600, "The Barrens", s1, {
        { "<", "centaur over there" }, { ">", "got it" }, { "<", "nice pull" },
        { ">", "need water?" }, { "<", "all good" }, { ">", "next camp" },
    })

    -- Yesterday: three hours of questing with a dungeon in the middle, a rare
    -- and a green trade (TLN-3: three activities named; TLN-4: the dungeon
    -- in a block of its own).
    local t2 = now - DAY - 5 * HOUR
    local s2 = Session(t2, 3 * HOUR + 5 * MIN, { "The Barrens", "Stonetalon Mountains" },
        { quests = Quests(14, 900), levelStart = 18, levelEnd = 21,
            rares = { { name = "Humar the Pridelord", npcID = 5828, kind = "rare", time = t2 + 40 * MIN } } },
        -- One of the user's deaths has no record: older sessions only counted.
        { deaths = { [ns.ownGUID] = 2, [GUID] = 1 }, others = 3, deathLog = {
            { guid = ns.ownGUID, time = t2 + 25 * MIN, zone = "The Barrens", subZone = "Razormane Grounds",
                killer = { source = "recap", name = "Razormane Geomancer", npcID = 3269, spell = "Fireball",
                    attackers = 3 } },
            { guid = GUID, time = t2 + 2 * HOUR + 50 * MIN, zone = "Stonetalon Mountains",
                killer = { source = "target", name = "Venture Co. Logger", npcID = 3989 } },
        } })
    Chat(t2 + 5 * MIN, "The Barrens", s2, {
        { ">", "WC after these?" }, { "<", "yes! finding a tank" }, { "<", "Brom is in" },
        { ">", "omw" }, { "<", "summoning stone is south" },
    })
    Visit({
        instanceID = 43, name = "Wailing Caverns", instanceType = "party", difficulty = "Normal",
        startedAt = t2 + 60 * MIN, endedAt = t2 + 112 * MIN,
        members = { Tester(), Me(), KAELITH, BROM, ZURI },
        bossesKilled = { "Lady Anacondra", "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum" },
        bossTotal = 8, deaths = 4, wipes = 1, sessionIds = { s2.id },
    })
    LevelUp(t2 + 30 * MIN, "The Barrens", 19, s2)
    LevelUp(t2 + 95 * MIN, "Wailing Caverns", 20, s2)
    LevelUp(t2 + 140 * MIN, "Stonetalon Mountains", 21, s2)
    Row("trade", t2 + 150 * MIN, "Stonetalon Mountains",
        { context = { given = { { link = STAFF, count = 1 } } } }, s2)
    Chat(t2 + 160 * MIN, "Stonetalon Mountains", s2, {
        { "<", "omg thank you" }, { ">", "it's an upgrade for you" }, { "<", "gn!" },
    })

    -- Today: a session that was only a dungeon run (it gives way to the
    -- visit), then a short questing session with a rare and a trade (jerky,
    -- and a blue).
    local t3 = now - 4 * HOUR
    local s3 = Session(t3, 40 * MIN, { "Razorfen Kraul" },
        { levelStart = 21, levelEnd = 22 }, { others = 3 })
    Visit({
        instanceID = 47, name = "Razorfen Kraul", instanceType = "party", difficulty = "Normal",
        startedAt = t3 + 3 * MIN, endedAt = t3 + 38 * MIN,
        members = { Tester(), Me(), BROM, KAELITH, ZURI },
        bossesKilled = { "Roogug", "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk" },
        bossTotal = 6, deaths = 2, sessionIds = { s3.id },
    })
    LevelUp(t3 + 25 * MIN, "Razorfen Kraul", 22, s3)
    Chat(t3 + 10 * MIN, "Razorfen Kraul", s3, {
        { "<", "careful, patrol" }, { ">", "oom" }, { "<", "drinking" },
    })

    local t4 = now - 90 * MIN
    local s4 = Session(t4, 15 * MIN, { "The Barrens" },
        { quests = Quests(2, 950), levelStart = 22, levelEnd = 22,
            rares = { { name = "Rocklance", npcID = 3270, kind = "rare", time = t4 + 5 * MIN } } })
    -- With a blue in it: the made-up route's first blue (Your Diary, JRN-24).
    Row("trade", now - GIFT_AGO, "The Barrens",
        { context = { received = { { link = JERKY, count = 5 }, { link = CLOAK, count = 1 } } } }, s4)

    -- Notes (DIA-11, TLN-10): one in a session, one in the dungeon inside
    -- yesterday's session, and one written when nothing was going on.
    local function Note(time, zone, text)
        ns.Notes.Add(GUID, text, { time = time, where = { zone = zone } })
    end
    Note(t1 + 300 + 40 * MIN, "The Barrens", "Tester knows every Kolkar camp by heart.")
    Note(t2 + 100 * MIN, "Wailing Caverns", "Skum took three tries. Tester never gave up.")
    Note(now - 60 * MIN, "Orgrimmar", "Promised to help with Sludge Fen tomorrow.")

    -- Seen around since, six pulses five minutes apart, and a whisper just
    -- now. Every row above is written oldest first, the order capture keeps.
    for i = 0, 5 do
        ns.Sessions.Around(GUID, now - 40 * MIN + i * 5 * MIN, "Durotar")
    end
    Row("whisper_in", now - 5 * MIN, "Durotar", { excerpt = "same time tomorrow?" })

    -- Your Diary's made-up route, under all of the above.
    TestData.WriteJourney(now)

    -- The entry's fields above were written by hand, past Diary's setters.
    ns.Touch()
    return entry
end

ns.Slash.Register("testdata", function(rest)
    if rest == "remove" then
        if TestData.Remove() then
            ns.Print("removed the test data.")
        else
            ns.Print("there was no test data.")
        end
        ns.Fire("SD_DIARY_CHANGED")
    elseif TestData.Write() then
        ns.Print("wrote |cffffffffTester Testerson|r: a week of sessions, two dungeon runs, rares,"
            .. " trades and chat; and a made-up route for this character in Your Diary (yours is put"
            .. " aside meanwhile). |cffffd100/sd testdata remove|r takes it out again.")
        ns.UI.ShowJournal(GUID)
        ns.Fire("SD_DIARY_CHANGED")
    end
end, "write a made-up diary entry, Tester Testerson, with a week of history, and a made-up route"
    .. " in Your Diary; |cffffd100/sd testdata remove|r removes both", { dev = true })
