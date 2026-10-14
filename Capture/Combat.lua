-- Your Diary's fights in more depth (JRN-25, JRN-26): the close calls,
-- and how many kills a quest's drops took. Both go on the logged-in
-- character's route (Core/Journey.lua), while it is being kept.
--
-- Close calls. The player's health is secret always (probes, 11 Oct), so
-- a fight is judged by the damage it did, less the healing that came in:
-- the client's damage meter, read once combat is over, when its numbers
-- are plain, against the maximum health. Healing received is no meter
-- type; it is each healer's spells by the unit healed, as
-- PrephDamageMeter's "Targets healed" reads them. What was fought comes off the target while it lasts: every
-- creature the user targets that can attack them, counted by kind.
--
-- Hunts. The quest log says what a quest wants and how many are had;
-- PARTY_KILL says what the user or their group killed (plain under
-- combat lockdown, Session 1); the loot window says what each item came
-- off (GetLootSourceInfo, probe 11 Oct). A quest wanting items is counted
-- from when it is seen with none of them until it has them all. Where the
-- user runs QuestieDB, it names the item and every kind that drops it, and
-- Questie's drop rates say how many kills it should have taken (EXT-2).

local addonName, ns = ...

local Journey = ns.Journey

local Combat = {}
ns.CombatCapture = Combat

local RANKS = { elite = true, rare = true, rareelite = true, worldboss = true }

-- Seconds: how long after combat the damage meter is read, and read again
-- while it does not read yet (`tries` times in all); how long the quest
-- log's updates are gathered into one reading; how long a quest gone from
-- the log waits for its turn-in.
local WAIT = { meter = 1, tries = 5, scan = 0.2, removed = 1 }

local function Live()
    if not (ns.JourneyCapture and ns.JourneyCapture.On()) or not ns.ownGUID then return nil end
    local j = Journey.Mine()
    if not j or j.test then return nil end
    return j
end

local function Level()
    local level = ns.Plain(UnitLevel("player"))
    return type(level) == "number" and level or nil
end

local function Name(unit)
    local name = ns.Plain((UnitName(unit)))
    return type(name) == "string" and name ~= "" and name or nil
end

-- The unit token on `guid`, if one still is: what the user points at,
-- then the nameplates.
local UNITS = { "target", "mouseover", "focus" }

local function UnitOn(guid)
    local function On(unit)
        if ns.Plain(UnitExists(unit)) and ns.Plain(UnitGUID(unit)) == guid then return unit end
    end
    return ns.Units.Each(UNITS, On) or ns.Units.Each(ns.Units.Plates, On)
end

--------------------------------------------------------------------------
-- Close calls
--------------------------------------------------------------------------

-- The fight under way: { started, seen = { [guid] = true }, foes, kinds =
-- { [npcID] = { n, name, rank } } }.
local fight

local function Foe(unit)
    if not fight or not ns.Plain(UnitExists(unit)) or not ns.Plain(UnitCanAttack("player", unit)) then return end
    local guid = ns.Plain(UnitGUID(unit))
    local npcID = ns.NpcID(guid)
    if not npcID or fight.seen[guid] then return end
    fight.seen[guid] = true
    fight.foes = fight.foes + 1
    local kind = fight.kinds[npcID]
    if not kind then
        kind = { n = 0 }
        fight.kinds[npcID] = kind
    end
    kind.n = kind.n + 1
    kind.name = kind.name or Name(unit)
    -- Kept a while, to put right a recap that gives it a surname.
    if kind.name then Journey.NoteName(npcID, kind.name) end
    -- Its level as it showed: -1 is the skull, a level not told.
    local level = ns.Plain(UnitLevel(unit))
    if type(level) == "number" and level ~= 0 then kind.level = level end
    local rank = UnitClassification and ns.Plain(UnitClassification(unit))
    if RANKS[rank] then kind.rank = rank end
end

-- The kind fought most: the most targeted, ties to the lower id.
local function Main(kinds)
    local best, npcID
    for id, kind in pairs(kinds) do
        if not best or kind.n > best.n or (kind.n == best.n and id < npcID) then best, npcID = kind, id end
    end
    return npcID, best
end

local function Table(value)
    value = ns.Plain(value)
    return type(value) == "table" and value or nil
end

-- The damage meter's latest session of meter type `kind` ("DamageTaken",
-- "HealingDone"), and its id; nil while it does not read.
local function Session(kind)
    local meter, types = C_DamageMeter, Enum and Enum.DamageMeterType
    local which = types and types[kind]
    if not (meter and which) then return nil end
    local id, ok, session
    if meter.GetAvailableCombatSessions and meter.GetCombatSessionFromID then
        local okL, sessions = pcall(meter.GetAvailableCombatSessions)
        for _, entry in ipairs(okL and Table(sessions) or {}) do
            local sid = ns.Plain(Table(entry) and entry.sessionID)
            if type(sid) == "number" and (not id or sid > id) then id = sid end
        end
        if id then ok, session = pcall(meter.GetCombatSessionFromID, id, which) end
    end
    if not id and meter.GetCombatSessionFromType and Enum.DamageMeterSessionType then
        id = "current"
        ok, session = pcall(meter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Current, which)
    end
    session = ok and Table(session)
    local sources = session and Table(session.combatSources)
    if not sources then return nil end
    return sources, id, which
end

-- The damage the user took in the latest session, and its id; nil while
-- it does not read. No row for the user is none taken.
local function Taken()
    local sources, id = Session("DamageTaken")
    if not sources then return nil end
    for _, src in ipairs(sources) do
        src = Table(src)
        if src and ns.Plain(src.isLocalPlayer) == true then
            local amount = ns.Plain(src.totalAmount)
            if type(amount) ~= "number" then return nil end
            return amount, id
        end
    end
    return 0, id
end

-- Whether the meter's unit name is the user's: by the first name, the
-- realm and any surname aside (the meter's own spelling is untested).
local function Mine(name)
    name = ns.Plain(name)
    local me = ns.Plain((UnitName("player")))
    if type(name) ~= "string" or type(me) ~= "string" then return false end
    local first = me:match("^[^%s%-]+")
    return first ~= nil and name:match("^[^%s%-]+") == first
end

-- A spell row's targets: combatSpellDetails is one or a list of them
-- (as PrephDamageMeter reads it). With one, the row is all theirs, and its
-- total is the sounder number.
local function Targets(spell)
    local d = Table(spell.combatSpellDetails)
    if not d then return {} end
    if d.unitName ~= nil or d.amount ~= nil then d = { d } end
    return d
end

local function Amount(spell, d, alone)
    local first, second = ns.Plain(d.amount), ns.Plain(spell.totalAmount)
    if alone then first, second = second, first end
    if type(first) == "number" and first ~= 0 then return first end
    return type(second) == "number" and second or first
end

-- The healing the user received in the latest session, from every healer
-- the meter lists (the user, their group): each healer's spells, broken
-- down by the unit healed. Nil while any of it does not read.
local function Received()
    local meter = C_DamageMeter
    local sources, id, which = Session("HealingDone")
    if not (sources and meter.GetCombatSessionSourceFromID) then return nil end
    local total = 0
    for _, src in ipairs(sources) do
        src = Table(src)
        if not src then return nil end
        local guid, creature = ns.Plain(src.sourceGUID), ns.Plain(src.sourceCreatureID)
        local ok, data
        if id == "current" then
            ok, data = pcall(meter.GetCombatSessionSourceFromType, Enum.DamageMeterSessionType.Current, which,
                guid, creature)
        else
            ok, data = pcall(meter.GetCombatSessionSourceFromID, id, which, guid, creature)
        end
        local spells = ok and Table(data) and Table(data.combatSpells)
        if not spells then return nil end
        for _, spell in ipairs(spells) do
            spell = Table(spell)
            if not spell then return nil end
            local targets = Targets(spell)
            for _, d in ipairs(targets) do
                d = Table(d)
                if not d then return nil end
                if ns.IsSecret(d.unitName) then return nil end
                if Mine(d.unitName) then
                    local amount = Amount(spell, d, #targets == 1)
                    if type(amount) ~= "number" then return nil end
                    total = total + amount
                end
            end
        end
    end
    return total, id
end

-- What the meter added since it was last read: a session that carries on
-- across fights counts from where it was (j.meter, saved, so a /reload
-- does not count it again); a new one, or one that started over, whole.
local function Since(j, kind, amount, id)
    j.meter = j.meter or {}
    local last = j.meter[kind]
    j.meter[kind] = { id = id, amount = amount }
    if last and last.id == id and amount >= last.amount then return amount - last.amount end
    return amount
end

local function Judge(f, now, tries)
    tries = (tries or 0) + 1
    local j = Live()
    if not j or ns.Plain(UnitIsDeadOrGhost("player")) == true then return end
    local max = ns.Plain(UnitHealthMax("player"))
    local taken, id = Taken()
    local healed, hid = Received()
    if type(max) ~= "number" or not taken or not healed then
        ns.Debug("close call: the damage meter does not read yet%s", tries < WAIT.tries and ", trying again" or ", given up")
        if tries < WAIT.tries then ns.After(WAIT.meter, function() Judge(f, now, tries) end) end
        return
    end
    -- The healing that kept the user up, theirs and their group's, is
    -- taken off: what is left is how far the fight brought them down.
    taken = Since(j, "taken", taken, id)
    healed = Since(j, "received", healed, hid)
    ns.Debug("close call: %d damage taken, %d healing received", taken, healed)
    taken = math.max(0, taken - healed)
    local npcID, kind = Main(f.kinds)
    -- Who pulled them through it, if anyone did (Capture/Witnesses.lua).
    if ns.Witnesses then
        ns.Witnesses.Survived(f.started, now, taken, max,
            npcID and { npcID = npcID, name = kind.name, rank = kind.rank })
    end
    ns.Debug("close call: fight over, took %d of %d health, %d foe(s), most %s", taken, max, f.foes,
        tostring(kind and kind.name))
    local call = Journey.CloseCall({ t = now, level = Level(), taken = taken, max = max,
        seconds = math.max(0, now - f.started), npcID = npcID, name = kind and kind.name,
        rank = kind and kind.rank, foeLevel = kind and kind.level, foes = f.foes })
    if call and call.npcID and ns.Deaths then ns.Deaths.LookUp(call) end
end

ns.On("PLAYER_REGEN_DISABLED", function()
    if not Live() then return end
    fight = { started = ns.Now(), seen = {}, foes = 0, kinds = {} }
    Foe("target")
end)

ns.On("PLAYER_TARGET_CHANGED", function()
    Foe("target")
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    local f = fight
    fight = nil
    if f and Live() then
        local now = ns.Now()
        -- The meter takes the last blows in a moment after.
        ns.After(WAIT.meter, function() Judge(f, now) end)
    end
end)

--------------------------------------------------------------------------
-- Hunts
--------------------------------------------------------------------------

-- The quests in the log, each { questID, title, index }: the current API
-- where the client has it, else the old one's.
local function Quests()
    local list = {}
    local Q = C_QuestLog
    if Q and Q.GetNumQuestLogEntries and Q.GetInfo then
        for i = 1, ns.Plain(Q.GetNumQuestLogEntries()) or 0 do
            local info = Q.GetInfo(i)
            if info and not info.isHeader and type(ns.Plain(info.questID)) == "number" then
                list[#list + 1] = { questID = info.questID, title = ns.Plain(info.title), index = i }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, ns.Plain(GetNumQuestLogEntries()) or 0 do
            local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
            if not isHeader and type(ns.Plain(questID)) == "number" then
                list[#list + 1] = { questID = questID, title = ns.Plain(title), index = i }
            end
        end
    end
    return list
end

-- "Plainstrider Meat: 3/7" (or "3/7 Plainstrider Meat"): the item, how
-- many are had and how many wanted.
local function Parse(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return nil end
    local have, need = text:match("(%d+)%s*/%s*(%d+)")
    local item = text:gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", ""):gsub("^%s*%d+%s*/%s*%d+%s*", "")
    item = item:match("^%s*(.-)%s*$")
    return item, tonumber(have), tonumber(need)
end
Combat.Parse = Parse

-- A quest's objectives that want items, each { index, item, have, need,
-- finished }.
local function Wants(quest)
    local list = {}
    local Q = C_QuestLog
    if Q and Q.GetQuestObjectives then
        for i, o in ipairs(Q.GetQuestObjectives(quest.questID) or {}) do
            if ns.Plain(o.type) == "item" then
                local item, have, need = Parse(o.text)
                have, need = ns.Plain(o.numFulfilled) or have, ns.Plain(o.numRequired) or need
                list[#list + 1] = { index = i, item = item, have = have, need = need,
                    finished = ns.Plain(o.finished) == true }
            end
        end
    elseif GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        for i = 1, ns.Plain(GetNumQuestLeaderBoards(quest.index)) or 0 do
            local text, kind, finished = GetQuestLogLeaderBoard(i, quest.index)
            if ns.Plain(kind) == "item" then
                local item, have, need = Parse(text)
                list[#list + 1] = { index = i, item = item, have = have, need = need,
                    finished = ns.Plain(finished) == true }
            end
        end
    end
    return list
end

-- The drop rates, where the user runs Questie or its database (EXT-2).
local function Rate(itemID, npcID)
    return ns.QuestieBridge and ns.QuestieBridge.DropRate(itemID, npcID)
end

-- Wowhead's, where the first cannot be believed (Journey.Believable).
local function Wowhead(itemID, npcID)
    return ns.QuestieBridge and ns.QuestieBridge.WowheadRate(itemID, npcID)
end

local function Done(j, questID, index)
    local rec = Journey.HuntDone(j, questID, index, { t = ns.Now(), level = Level(), Rates = { Rate, Wowhead } })
    if rec and rec.npcID and ns.Deaths then ns.Deaths.LookUp(rec) end
    if rec then ns.Debug("hunt done: %s, %d kills for %d", tostring(rec.item), rec.kills, rec.need) end
    return rec
end

-- One reading of the log: a want with none had yet begins a hunt, a hunt
-- whose want is met ends.
function Combat.Scan()
    local j = Live()
    if not j then return end
    for _, quest in ipairs(Quests()) do
        for _, want in ipairs(Wants(quest)) do
            local met = want.finished or (want.have and want.need and want.have >= want.need)
            if Journey.Hunting(j, quest.questID, want.index) then
                if met then Done(j, quest.questID, want.index) end
            elseif not met and want.have == 0 then
                -- What it is, and every kind that drops it, where QuestieDB
                -- says (EXT-2).
                local Q = ns.QuestieBridge
                local itemID = Q and Q.ItemFor(quest.questID, want.item)
                Journey.Hunt(j, { questID = quest.questID, index = want.index, title = quest.title,
                    item = want.item, need = want.need, t = ns.Now(), itemID = itemID,
                    droppers = itemID and Q.Droppers(itemID) })
            end
        end
    end
end

local queued = false

local function Queue()
    if queued then return end
    queued = true
    ns.After(WAIT.scan, function()
        queued = false
        Combat.Scan()
    end)
end

ns.On("QUEST_LOG_UPDATE", Queue)
ns.On("QUEST_ACCEPTED", Queue)
ns.On("PLAYER_ENTERING_WORLD", Queue)

-- Handed in: whatever was still being counted for it was met.
ns.On("QUEST_TURNED_IN", function(_, questID)
    local j = Live()
    questID = ns.Plain(questID)
    if not (j and j.hunting and type(questID) == "number") then return end
    local done = {}
    for _, hunt in pairs(j.hunting) do
        if hunt.questID == questID then done[#done + 1] = hunt.index end
    end
    for _, index in ipairs(done) do Done(j, questID, index) end
end)

-- Abandoned, or handed in: the turn-in has a moment to come first.
ns.On("QUEST_REMOVED", function(_, questID)
    questID = ns.Plain(questID)
    if type(questID) ~= "number" then return end
    ns.After(WAIT.removed, function() Journey.HuntGone(Live(), questID) end)
end)

local function Hunting(j)
    return j and j.hunting and next(j.hunting) ~= nil
end

ns.On("PARTY_KILL", function(_, attacker, victim)
    local j = Live()
    if not Hunting(j) then return end
    attacker = ns.SafeGUID(attacker)
    if not attacker or not (attacker == ns.ownGUID or ns.Roster.Has(attacker)) then return end
    victim = ns.Plain(victim)
    local npcID = ns.NpcID(victim)
    if not npcID then return end
    local unit = UnitOn(victim)
    Journey.HuntKill(j, npcID, unit and Name(unit))
end)

-- What the loot window holds, and what each item came off.
ns.On("LOOT_OPENED", function()
    local j = Live()
    if not Hunting(j) or not (GetNumLootItems and GetLootSourceInfo) then return end
    for slot = 1, ns.Plain(GetNumLootItems()) or 0 do
        local link = ns.Plain(GetLootSlotLink(slot))
        local item = type(link) == "string" and link:match("%[(.-)%]")
        if item then
            local sources = { GetLootSourceInfo(slot) }
            for i = 1, #sources, 2 do
                local guid = ns.Plain(sources[i])
                local npcID = ns.NpcID(guid)
                if npcID then
                    local unit = UnitOn(guid)
                    Journey.HuntDrop(j, item, npcID, unit and Name(unit), tonumber(link:match("item:(%d+)")))
                end
            end
        end
    end
end)

-- A group member's loot (the party's loot message, plain, probe 12 Oct):
-- a hunted item they took is one the group's kills gave and the user could
-- not have (Journey.HuntShared). The looter by their GUID, so the message's
-- words in any language do not matter; "x3" after the link is three.
ns.OnChat("CHAT_MSG_LOOT", function(text, _, guid)
    local j = Live()
    if not Hunting(j) or not guid or guid == ns.ownGUID or not ns.Roster.Has(guid) then return end
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local item = text:match("|h%[(.-)%]|h")
    if not item then return end
    local itemID = tonumber(text:match("|Hitem:(%d+)"))
    local n = tonumber(text:match("|h|r?x(%d+)")) or 1
    if Journey.HuntShared(j, item, itemID, n) then
        ns.Debug("hunt shared: %s took %d %s", tostring(guid), n, item)
    end
end)
