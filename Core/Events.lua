-- Central event dispatcher.
--
-- One frame for the whole addon. Registration is tracked per event so that
-- dropping the last handler genuinely unregisters the event rather than
-- leaving it firing into a no-op -- SIG-5 requires sighting handlers to be
-- unregistered in cities, not merely ignored.
--
-- The same On/Off also carry the addon's own messages, named SD_*, which
-- ns.Fire dispatches straight away (no frame, no client event). They let
-- Core and Capture say what happened without knowing which window cares,
-- and let one UI file follow another without a callback slot to assign:
--
--   SD_REUNION (guid, reason)  a diary entry joined the group ("group") or
--                              came into view ("nearby"). Fired by
--                              Core/Roster.lua, before Sessions sees the
--                              join, and Capture/Nearby.lua; UI/Reunion.lua
--                              toasts it (REU-1, REU-5).
--   SD_DIARY_CHANGED ()        the user edited or removed diary data: the
--                              entry form, the settings page's deletes,
--                              /sd testdata. UI/Journal.lua refreshes the
--                              journal and the loose entry sheet.
--   SD_PAPER_CHANGED ()        the paper or its grain changed (/sd art).
--                              Fired by UI/StyleArt.lua and UI/StyleBook.lua;
--                              the journal's book repaints.
--   SD_WORLD_SETTLED ()        a few seconds after entering the world (a
--                              login, a /reload, a loading screen), when the
--                              client has loaded what the character holds
--                              (its bags, its skills). Fired by Capture/
--                              Journey.lua, from a timer of its own its
--                              PLAYER_ENTERING_WORLD handler queues. A
--                              feature's capture that holds what the
--                              character has against its last reading
--                              takes its first one here, which only sets
--                              the mark: what is had then was had out of
--                              sight. Whether the route is kept is the
--                              feature's to ask (ns.Journey.Kept).
--   SD_QUEST_ACCEPTED (questID)   a quest taken, its id a plain number.
--   SD_QUEST_TURNED_IN (questID)  a quest turned in, likewise. Both fired
--                              by Capture/Journey.lua straight after the
--                              route has counted the quest (Journey.Act),
--                              whether or not the route is kept: a
--                              feature asks that itself (ns.Journey.Kept).
--                              The turn-in comes through Capture/
--                              Together.lua's QUEST_TURNED_IN handler,
--                              after the session's count.
--   SD_LEVEL_ROSE (guid, from, level)  a character was read at a higher
--                              level than their record held (`from`, a
--                              number; `level`, the new one, already on
--                              the record). Fired by Characters.Observe
--                              (Core/Characters.lua) on a live reading
--                              only (no `info.time`: a backfilled one
--                              describes the past), never on a first
--                              reading, for anyone, the user's own
--                              characters included (record.isSelf,
--                              ns.ownGUID: the listener's to skip). Any
--                              reading counts: a unit token, a roster's
--                              UNIT_LEVEL, a nameplate.
--   SD_YOU_DIED (death)        the user died (PLAYER_DEAD). `death` is
--                              { guess, time, where }: the killer guessed
--                              at the moment (the deaths' capture's
--                              shape: { player, guid } for a player,
--                              { npcID, name, ... } for a creature, or
--                              nil), when, and ns.Where() then. Fired by
--                              the feature that watches the user's deaths,
--                              inside its PLAYER_DEAD handler, before it
--                              keeps the death on the route, in a session
--                              or not.
--   SD_DEATH_RECAP (death, killer)  the death recap named who killed the
--                              user: `death` the same table SD_YOU_DIED
--                              carried (a listener may key what it wrote
--                              by it), `killer` the recap's ({ player,
--                              guid, spell } or a creature's { npcID,
--                              name, spell, ... } or the world's
--                              { environment }). Fired by the same
--                              feature once combat is over, before the
--                              death it keeps takes its killer; never
--                              when no recap came.
--   SD_TRADE_COMPLETED (guid, received)  a trade the client said was
--                              completed, with `guid` (who it was with),
--                              `received` what came the user's way: the
--                              trade row's context.received ({ { link,
--                              count }, ... }, or nil for none). Fired by
--                              the feature that captures trades as it
--                              stores the row, now (ns.Now() is its time).
--   SD_FIGHT_SURVIVED (started, ended, taken, max, foe)  a fight the user
--                              came out of alive, as the feature that
--                              judges close calls reads it once the damage
--                              meter does (a moment after combat ends):
--                              from `started` to `ended` (ns.Now() times),
--                              `taken` the damage taken less the healing
--                              the meter lists, `max` the user's maximum
--                              health, `foe` the creature fought most
--                              ({ npcID, name, rank }) or nil. Every
--                              fight judged, close or not (the listener
--                              says what is close enough for it), fired
--                              before the close call is kept; never for a
--                              fight the meter never read, nor while dead,
--                              nor while the route is not kept (the
--                              judge's own gate, ns.Journey.Kept).
--
-- Dispatch is synchronous: SD_REUNION's toast has read "last met" before
-- ns.Fire returns, which is what lets Group fire it ahead of Sessions.

local addonName, ns = ...

local frame = CreateFrame("Frame", "SocialDiaryEventFrame")
local handlers = {}

-- The addon's own messages never reach RegisterEvent: the client would
-- reject a name it does not know, and they are dispatched by ns.Fire anyway.
local function IsMessage(event)
    return type(event) == "string" and event:sub(1, 3) == "SD_"
end

function ns.On(event, handler)
    local list = handlers[event]
    if not list then
        list = { live = 0 }
        handlers[event] = list
        if not IsMessage(event) then frame:RegisterEvent(event) end
    end

    -- Sightings switch on and off at every city gate, so a tombstone is
    -- reused rather than letting the list grow with each trip.
    local slot = #list + 1
    for i = 1, #list do
        if list[i] == false then
            slot = i
            break
        end
    end

    list[slot] = handler
    list.live = list.live + 1
end

-- Removal leaves a `false` tombstone rather than compacting, so a handler may
-- call Off on its own event from inside dispatch without disturbing the loop.
-- Tombstones are bounded by the number of registrations and the whole list is
-- dropped once the last live handler goes.
function ns.Off(event, handler)
    local list = handlers[event]
    if not list then return end

    for i = 1, #list do
        if list[i] == handler then
            list[i] = false
            list.live = list.live - 1
        end
    end

    if list.live <= 0 then
        handlers[event] = nil
        if not IsMessage(event) then frame:UnregisterEvent(event) end
    end
end

function ns.IsRegistered(event)
    return handlers[event] ~= nil
end

-- The CHAT_MSG_* payload, whose positions are easy to get wrong and silent
-- when you do: 1 text, 2 sender, 3..10 language/channel/flags, 11 lineID,
-- 12 guid. Unpacked once here so no handler has to count underscores.
--
-- fn(text, sender, guid, lineID, event). `guid` has been through SafeGUID
-- already: nil under chat lockdown, where text, sender and guid all come
-- back secret (INT-4), and for a sender who is not a player. The rest is as
-- the client sent it, so still to be scrubbed.
function ns.ChatHandler(fn)
    return function(event, text, sender, _, _, _, _, _, _, _, _, lineID, guid)
        fn(text, sender, ns.SafeGUID(guid), lineID, event)
    end
end

-- Returns the handler, for an ns.Off later.
function ns.OnChat(event, fn)
    local handler = ns.ChatHandler(fn)
    ns.On(event, handler)
    return handler
end

--------------------------------------------------------------------------
-- Timers
--------------------------------------------------------------------------

-- Once, after `seconds`. A client without C_Timer runs `fn` straight away:
-- every delay here is a grace period (a roster settling, a trade result
-- arriving), and skipping it is better than never running at all.
function ns.After(seconds, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, fn)
    else
        fn()
    end
end

-- Every `seconds`, on one shared ticker per interval: the together tick, the
-- group scan and the sighting sweep all run every 30 seconds, and three
-- tickers on the same period are three wake-ups for the work of one.
--
-- Returns a handle whose Cancel stops `fn`, or nil when the client has no
-- tickers (and `fn` never repeats). A job added later runs on the ticker's
-- existing beat, so its first run can come sooner than `seconds`.
local every = {}  -- [seconds] = { job, ... }; false where one was cancelled

function ns.Every(seconds, fn)
    if not (C_Timer and C_Timer.NewTicker) then return nil end

    local jobs = every[seconds]
    if not jobs then
        jobs = {}
        every[seconds] = jobs
        C_Timer.NewTicker(seconds, function()
            for i = 1, #jobs do
                local job = jobs[i]
                if job then job.fn() end
            end
        end)
    end

    -- A cancelled slot is reused, as ns.On reuses its tombstones: the sweep
    -- starts and stops at every city gate.
    local slot = #jobs + 1
    for i = 1, #jobs do
        if jobs[i] == false then
            slot = i
            break
        end
    end

    local job = { fn = fn }
    function job.Cancel()
        if jobs[slot] == job then jobs[slot] = false end
    end
    jobs[slot] = job
    return job
end

-- One handler, protected: an error in it goes to the client's error
-- handler (the usual Lua error frame) and the next handler for the same
-- event still runs, so a fault in one module -- Your Diary's capture, say
-- -- cannot silence another's. Without an error handler (the tests' mock)
-- the error is raised as it always was, so nothing fails quietly there.
local function Call(handler, event, ...)
    local handle = geterrorhandler and geterrorhandler()
    if not handle then return handler(event, ...) end
    local ok, err = pcall(handler, event, ...)
    if not ok then handle(err) end
end

-- Client events and the addon's messages run through the same loop.
local function Dispatch(event, ...)
    local list = handlers[event]
    if not list then return end

    for i = 1, #list do
        local handler = list[i]
        if handler then
            Call(handler, event, ...)
        end
    end
end

frame:SetScript("OnEvent", function(_, event, ...) Dispatch(event, ...) end)

-- One of the SD_* messages above, to every handler On registered for it, in
-- registration order. A client event's name is refused: firing one by hand
-- would run its handlers on a payload the client never sent.
function ns.Fire(msg, ...)
    if not IsMessage(msg) then
        error(("ns.Fire: %s is not an SD_ message"):format(tostring(msg)), 2)
    end
    Dispatch(msg, ...)
end

ns.On("ADDON_LOADED", function(_, loaded)
    if loaded ~= addonName then return end
    ns.InitDB()
end)

ns.On("PLAYER_ENTERING_WORLD", function() ns.FillBegunZone() end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.FillBegunZone() end)

ns.On("PLAYER_LOGIN", function()
    ns.TouchOwnCharacter()
    ns.Interactions.Prune()
    ns.Diary.FillSeen()
    ns.Sightings.Rollup()
    -- After both: a record goes once the rows that held on to it have.
    ns.Characters.Prune()
    ns.Reunions.Prune()
    ns.Debug("v%s loaded. /sd opens the journal, /sd help lists commands.", ns.version)

    -- NFR-6 says no data loss on /reload. An empty database looks exactly
    -- like a first run, so with debug on, say which one it was (see
    -- ns.InitDB).
    if not ns.dbRestored then
        ns.Debug("no saved data came back this load -- a first run, or the client dropped it.")
    end
end)
