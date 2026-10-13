-- World PvP kills: a player killed by the user or by their group
-- (Core/Fights.lua). The other half, the user killed by a player, is
-- Capture/Deaths.lua's.
--
-- PARTY_KILL gives plain attacker and victim GUIDs, even under combat
-- lockdown (prd.md, Session 1). It fires for kills by the user and by their
-- group, so a kill by a group member counts too: the number is "kills", and
-- the timeline says who landed the blow.
--
-- Open world only. A battleground or arena kill is not a meeting with
-- anyone, and forty of them a match would bury the buffer; their GUIDs come
-- back secret there anyway, which SafeGUID drops.

local addonName, ns = ...

local PVP_INSTANCES = { pvp = true, arena = true }

-- Unit tokens that may still point at the victim, to read what the GUID
-- alone cannot (level, faction). The plates last.
local UNITS = { "target", "focus", "mouseover" }

local function Observe(guid)
    local function On(unit)
        if UnitExists(unit) and ns.Plain(UnitGUID(unit)) == guid then return unit end
    end
    local unit = ns.Units.Each(UNITS, On) or ns.Units.Each(ns.Units.Plates, On)
    if unit then
        ns.Characters.ObserveUnit(unit)
    else
        ns.Characters.ObserveGUID(guid)
    end
end

ns.On("PARTY_KILL", function(_, attacker, victim)
    attacker, victim = ns.SafeGUID(attacker), ns.SafeGUID(victim)
    if not attacker or not victim or victim == ns.ownGUID then return end

    local mine = attacker == ns.ownGUID
    if not mine and not ns.Roster.Has(attacker) then return end
    -- One of your own group, mind-controlled or otherwise: not a fight.
    if ns.Roster.Has(victim) then return end

    local _, kind = IsInInstance()
    if PVP_INSTANCES[ns.Plain(kind)] then return end

    Observe(victim)
    ns.Fights.Kill(victim, not mine and attacker or nil)
    ns.Debug("pvp: %s killed %s", mine and "you" or attacker, victim)
end)
