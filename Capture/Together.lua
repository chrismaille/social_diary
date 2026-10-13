-- The events that drive together sessions (SES-2 to SES-4).
--
-- Core/Sessions.lua holds the model and never touches a unit token; this file
-- is where the client's signals are read and handed to it: the lifecycle
-- (login, the tick, logout) and what happens during a session -- zones,
-- quests, rares and world bosses. Deaths have a file of their own
-- (Capture/Deaths.lua).

local addonName, ns = ...

local TICK_SECONDS = 30

--------------------------------------------------------------------------
-- Presence
--------------------------------------------------------------------------

local function Grouped(guid)
    return ns.Roster.Has(guid)
end

-- "Seen nearby": the unit tokens that can name a player, read live rather
-- than from the sightings store (M2). Built once per tick, and only when a
-- participant is actually out of the group. Drawn by the client, too: a
-- party frame's mouseover across the map is not "nearby" (Capture/Nearby.lua).
local POINTED = { "target", "focus", "mouseover" }

local VISIBLE = { visible = true }

local function VisibleSet()
    local set = {}
    local function Add(unit)
        local guid = ns.PlayerGUIDFromUnit(unit, VISIBLE)
        if guid then set[guid] = true end
    end
    ns.Units.Each(POINTED, Add)
    ns.Units.Each(ns.Units.Plates, Add)
    return set
end

local function NearbyTest()
    local visible
    return function(guid)
        visible = visible or VisibleSet()
        return visible[guid] == true
    end
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

local function Tick()
    if not ns.ownGUID then return end

    -- A diary entry can be in the group without a roster change announcing
    -- it: added to the diary mid-group, or resumed after a reload.
    ns.Sessions.Roster(ns.Roster.Members())
    ns.Sessions.Tick(Grouped, NearbyTest())
    ns.Roster.Touch()
end

ns._test.TogetherTick = Tick

ns.On("PLAYER_LOGIN", function()
    ns.Sessions.Resume()
    ns.Every(TICK_SECONDS, Tick)
end)

ns.On("PLAYER_LOGOUT", function()
    ns.Sessions.Flush(Grouped)
    ns.Roster.Touch()
end)

--------------------------------------------------------------------------
-- During a session (SES-4)
--------------------------------------------------------------------------

ns.On("ZONE_CHANGED_NEW_AREA", function()
    ns.Sessions.Zone()
end)

-- Your Diary counts them too, on the route (JRN-6, JRN-7): one handler
-- for each event, calling both.
ns.On("QUEST_TURNED_IN", function(_, questID)
    local n = ns.Sessions.Quest(questID, Grouped)
    if n > 0 then ns.Debug("quest %s counted for %d participant(s)", tostring(questID), n) end
    ns.JourneyCapture.QuestTurnedIn(questID)
end)

ns.On("PLAYER_LEVEL_UP", function(_, level)
    ns.Sessions.MyLevel(level)
    ns.JourneyCapture.LevelUp(level)
end)

-- Rares and world bosses. PARTY_KILL gives plain attacker and victim GUIDs
-- (Session 1, even under combat lockdown), but no classification: that has
-- to come off a unit token still pointing at the corpse.
local RARE_KINDS = { rare = true, rareelite = true, worldboss = true }

-- The plates come last, after every token the user points at on purpose.
local VICTIM_UNITS = { "target", "focus", "mouseover" }
for i = 1, 5 do VICTIM_UNITS[#VICTIM_UNITS + 1] = "boss" .. i end

local function FindUnit(guid)
    local function On(unit)
        if UnitExists(unit) and ns.Plain(UnitGUID(unit)) == guid then return unit end
    end
    return ns.Units.Each(VICTIM_UNITS, On) or ns.Units.Each(ns.Units.Plates, On)
end

ns.On("PARTY_KILL", function(_, attacker, victim)
    if not ns.Sessions.Current() then return end

    attacker = ns.SafeGUID(attacker)
    if not attacker or not (attacker == ns.ownGUID or ns.Roster.Has(attacker)) then return end

    victim = ns.Plain(victim)
    if type(victim) ~= "string" or ns.SafeGUID(victim) then return end

    local unit = FindUnit(victim)
    local kind = unit and UnitClassification and ns.Plain(UnitClassification(unit))
    if not kind or not RARE_KINDS[kind] then return end

    local name = ns.Plain((UnitName(unit)))
    local n = ns.Sessions.Rare({ name = name, npcID = ns.NpcID(victim), kind = kind }, Grouped)
    if n > 0 then ns.Debug("%s %s counted for %d participant(s)", kind, tostring(name), n) end
end)
