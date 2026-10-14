-- The kinds of People row (ns.db.interactions[guid][i].type), each told
-- once, here or by the feature that writes it, rather than in a list in
-- every file that treats one kind apart.
--
-- Rows.Register(type, spec) declares a kind or adds to one: the core says
-- how a row of it counts, the ledger (UI/TimelineText.lua) how it reads,
-- each in its own call, so a feature's folder can do both. Every field is
-- optional, and a kind nobody declared is still stored and shown, as the
-- fallbacks below say.
--
--   chat        it carries chat text: its excerpt is kept only while chat
--               storage is on, and trimmed to the chat lines setting
--               (Core/Interactions.lua)
--   observed    something the user saw of them, not an exchange: it does not
--               count as an interaction on record, nor make them someone
--               just dealt with (Interactions.Count, Since; the picker)
--   proximity   they were within earshot or arm's reach, so a live row is
--               also "last seen" (Characters.Seen)
--   opens       a live row with a diary entry opens a "nearby" together
--               session (Sessions.Note); any other kind only joins an open one
--   structural  the bones of a session, not a highlight of it
--               (Sessions.Highlights)
--   meeting     a row outside any session that counts as meeting them
--               (People: times met, last met, the zones)
--   dealt       the mark it leaves on Recently nearby's day ("together",
--               "trade" or "talk"; Sightings, DEALT_RANK)
--   matters     the first one makes a person matter, so their first
--               sighting shows in hindsight (Core/JourneyRecap.lua, JRN-23)
--   activity    the timeline's activity ("chat", "group", "trade", ...,
--               Timeline's RANK); none, and it cannot make an exchange alone
--   moment      function(row): true when it is a line of its own on the
--               timeline
--   hidden      never shown on the timeline
--   reason      why the picker offers someone whose latest row it is ("they
--               saved you"); without one, "recent <type>"
--   text        function(row, guid): its line on the timeline; without one,
--               the type itself
--   icon        its Style.ART key on the timeline; without one, no icon
--
-- Unknown kinds: activity "other" (chatter, "N other interactions"), not a
-- moment, no excerpt, nothing else.

local addonName, ns = ...

local Rows = {}
ns.Rows = Rows

local KINDS = {}
local NONE = {}

-- Declares `kind`, or adds `spec`'s fields to it. Returns the kind's table.
function Rows.Register(kind, spec)
    assert(type(kind) == "string", "a row kind is a string")
    local k = KINDS[kind]
    if not k then
        k = { type = kind }
        KINDS[kind] = k
    end
    for key, value in pairs(spec or {}) do k[key] = value end
    return k
end

-- The kind's table, or an empty one for a kind nobody declared.
function Rows.Get(kind)
    return KINDS[kind] or NONE
end

-- Whether `kind` was declared at all.
function Rows.Known(kind)
    return KINDS[kind] ~= nil
end

-- Every declared kind's name, sorted (for the tests and /sd debug).
function Rows.All()
    local list = {}
    for kind in pairs(KINDS) do list[#list + 1] = kind end
    table.sort(list)
    return list
end

--------------------------------------------------------------------------
-- The kinds the diary has always had
--------------------------------------------------------------------------
--
-- Their words and icons are UI/TimelineText.lua's; the features that came
-- later (World PvP, witnesses) declare theirs here for now too, until they
-- move to their folders. A feature in Features/<Name>/ declares its kind
-- whole there, words and icon included (its Kind.lua;
-- .claude/registry-refactor.md, "A feature's folder").

local function Always() return true end

Rows.Register("group_join", { structural = true, meeting = true, dealt = "together", matters = true,
    activity = "group" })
-- Implied by the session's end, so never a line.
Rows.Register("group_leave", { structural = true, hidden = true })
-- A trade is a moment of its own when something of note changed hands.
Rows.Register("trade", { proximity = true, opens = true, meeting = true, dealt = "trade", matters = true,
    activity = "trade",
    moment = function(row) return ns.Timeline.TradeQuality(row) >= ns.Timeline.UNCOMMON end })
-- Always a line, and names nothing in a headline: the details line already
-- says "they went from 18 to 21".
Rows.Register("level_up", { observed = true, moment = Always })
-- World PvP (Core/Fights.lua): always a line, never an activity, as TLN-2
-- has it for PvP kills.
Rows.Register("pvp_kill", { moment = Always, reason = "you killed them" })
Rows.Register("pvp_death", { moment = Always, reason = "they killed you" })
-- Witnesses to the user's fights (Capture/Witnesses.lua): always a line.
Rows.Register("watched_death", { moment = Always, reason = "they watched you die" })
Rows.Register("tried_to_help", { moment = Always, reason = "they tried to save you" })
Rows.Register("saved_you", { moment = Always, reason = "they saved you" })
