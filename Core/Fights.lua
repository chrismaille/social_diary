-- World PvP: who you killed, and who killed you (prd.md, "Killed them, or
-- killed by them").
--
-- Each fight is an interaction row on the other player, so a stranger's
-- fights live in the buffer under its usual retention and come along when
-- they are added (flow 5, the ganker), like any other row:
--
--   pvp_kill    they died to you or your group. context.by is the group
--               member who landed the killing blow; nil when it was you.
--               Both count as a kill; the timeline tells them apart.
--   pvp_death   they killed you. context.probable while it rests on the
--               guess at the moment of death (your target); the death recap
--               confirms it, moves it to the real killer, or takes it back
--               when no player killed you. context.spell, from the recap.
--
-- Capture/PvP.lua and Capture/Deaths.lua say what happened; this file
-- writes it down and adds it up.

local addonName, ns = ...

local Fights = {}
ns.Fights = Fights

local KILL, DEATH = "pvp_kill", "pvp_death"
Fights.KILL, Fights.DEATH = KILL, DEATH

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

-- `victim` died to the user, or to group member `by`.
-- Each fight is also a mark on the user's own route (JRN-10), which keeps
-- the outcome after a stranger's row has gone.
function Fights.Kill(victim, by)
    local row = ns.Interactions.Add(victim, KILL, { hostile = true, context = { by = ns.SafeGUID(by) } })
    if row then ns.Journey.Fought("won", victim, row.time) end
    return row
end

-- The user died. `killer` is the guess Capture/Deaths.lua made at that
-- moment; only a player is a fight. Returns what Resolve needs to correct
-- it later, or nil.
function Fights.Died(killer, time, where)
    if not (killer and killer.player and killer.guid) then return nil end
    local row = ns.Interactions.Add(killer.guid, DEATH,
        { hostile = true, time = time, where = where, session = false, context = { probable = true } })
    if not row then return nil end
    return { guid = killer.guid, row = row, mark = ns.Journey.Fought("lost", killer.guid, row.time, where) }
end

-- The death recap came: `killer` is who it says, `fight` what Died wrote
-- (or nil). The row is confirmed, moved to the player the recap names, or
-- taken back when the recap names a creature or nothing.
function Fights.Resolve(fight, killer, time, where)
    local guid = killer and killer.player and killer.guid

    if fight and fight.guid == guid then
        fight.row.context = fight.row.context or {}
        fight.row.context.probable = nil
        fight.row.context.spell = killer.spell
        ns.Touch()
        return fight
    end

    if fight then ns.Interactions.Remove(fight.guid, fight.row) end
    local mark = fight and fight.mark
    if not guid then
        if mark then ns.Journey.Refight(ns.Journey.Mine(), mark, false) end
        return nil
    end

    ns.Characters.ObserveGUID(guid)
    local row = ns.Interactions.Add(guid, DEATH,
        { hostile = true, time = time, where = where, session = false, context = { spell = killer.spell } })
    if not row then return nil end
    -- The mark moves with the row: same fight, the player the recap names.
    if mark then
        mark.t = row.time
        ns.Journey.Refight(ns.Journey.Mine(), mark, guid)
    else
        mark = ns.Journey.Fought("lost", guid, row.time, where)
    end
    return { guid = guid, row = row, mark = mark }
end

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

-- The fights with `guid`: { kills, yours, deaths, last, zone } -- every
-- kill, the ones you landed yourself, your deaths to them, and when and
-- where the latest fight was. nil when there has been none.
function Fights.With(guid)
    local rows = ns.Interactions.For(guid)
    if not rows then return nil end

    local t = { kills = 0, yours = 0, deaths = 0 }
    for i = 1, #rows do
        local row = rows[i]
        if row.type == KILL or row.type == DEATH then
            if row.type == KILL then
                t.kills = t.kills + 1
                if not (row.context and row.context.by) then t.yours = t.yours + 1 end
            else
                t.deaths = t.deaths + 1
            end
            if not t.last or row.time >= t.last then t.last, t.zone = row.time, row.zone end
        end
    end
    if not t.last then return nil end
    return t
end
