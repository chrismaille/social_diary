-- Your Diary's words (JRN-11 to JRN-14, JRN-21 to JRN-26): what each recap
-- entry says, the plates' captions and margin notes, the first sightings in
-- hindsight, the zone lines, and the plates' tooltips.
--
-- Pure functions over Core/JourneyRecap.lua's entries, no frames: the page
-- (UI/JournalJourney.lua) and the plates (UI/JourneyPlate.lua) lay them out.
-- The journal's voice, as the front matter and the timeline speak it: prose,
-- relative dates, quiet. It recaps where you went and who you were with; it
-- never counts quests or keeps a score.

local addonName, ns = ...

local Text = {}
ns.UI.JourneyText = Text

local List = ns.UI.List
-- Tooltips and single lines keep the plain formatter; what wraps (the
-- prose, captions, margin notes) holds its times together (SPACE, below).
local Plain = ns.UI.Duration

-- How a time is written in Your Diary's words: the number held to its
-- unit by a no-break space (UTF-8 `nbsp`), so "55 min" never breaks across
-- two lines as "55" and "min". `keep` is the one switch: off, plain
-- spaces again, should the client's fonts draw no glyph for it or its
-- wrapping not honour it (to check in the client).
local SPACE = { keep = true, nbsp = "\194\160" }

local function Glue(text)
    if not SPACE.keep then return text end
    return (text:gsub(" ", SPACE.nbsp))
end

local function Duration(seconds)
    return Glue(ns.UI.Duration(seconds))
end
Text.Duration, Text.SPACE = Duration, SPACE

-- A zone's time in the ledger under an entry, short as a column of
-- figures: "1 h 33", "2 h", "52 min".
function Text.LedgerTime(seconds)
    local minutes = math.floor((seconds or 0) / 60)
    if minutes < 60 then return Glue(minutes .. " min") end
    local h, m = math.floor(minutes / 60), minutes % 60
    if m == 0 then return Glue(h .. " h") end
    return Glue(("%d h %02d"):format(h, m))
end

-- A time as the diary says it in a sentence, rounded the way one speaks:
-- "a few minutes", "twenty minutes", "half an hour", "an hour and a half",
-- "three hours". The prose is not a ledger; the zone rows carry the
-- exact times.
local WORDS = { [2] = "two", [3] = "three", [4] = "four", [5] = "five", [6] = "six", [7] = "seven",
    [8] = "eight", [9] = "nine", [10] = "ten", [11] = "eleven", [12] = "twelve", [15] = "fifteen",
    [20] = "twenty", [25] = "twenty-five", [40] = "forty", [45] = "forty-five", [50] = "fifty",
    [55] = "fifty-five" }

local function Spoken(seconds)
    local m = (seconds or 0) / 60
    if m < 1 then return "a moment" end
    if m < 8 then return "a few minutes" end
    if m < 25 or (m >= 38 and m < 53) then
        local n = 5 * math.floor(m / 5 + 0.5)
        return WORDS[n] and (WORDS[n] .. " minutes") or Glue(n .. " minutes")
    end
    if m < 38 then return "half an hour" end
    if m < 75 then return "an hour" end
    if m < 105 then return "an hour and a half" end
    local halves = math.floor(m / 30 + 0.5)
    local whole = math.floor(halves / 2)
    local name = WORDS[whole] or Glue(tostring(whole))
    return halves % 2 == 1 and (name .. " and a half hours") or (name .. " hours")
end
Text.Spoken = Spoken

local function MapName(mapID)
    return mapID and ns.MapName(mapID) or nil
end

local function Who(guid)
    return guid and (ns.Characters.FullName(guid) or ns.Characters.Name(guid)) or nil
end

-- "6 October", with the year once it is not this one's.
local function Day(t, now)
    return ns.UI.DayMonth(t, now or ns.Now())
end

-- A place: "Lushwater Oasis, The Barrens", or the zone alone.
local function Place(mapID, subZone)
    local zone = MapName(mapID)
    if subZone and zone and subZone ~= zone then return subZone .. ", " .. zone end
    return subZone or zone
end
Text.Place = Place

--------------------------------------------------------------------------
-- The prologue (JRN-13)
--------------------------------------------------------------------------

-- "This diary began at level 30, in Ashenvale." Nothing before it is
-- made up.
function Text.Prologue(prologue)
    if not prologue then return nil end
    local zone = MapName(prologue.mapID)
    return ("This diary began at level %d%s, on %s."):format(prologue.level,
        zone and (", in " .. zone) or "", Day(prologue.at))
end

--------------------------------------------------------------------------
-- An entry (JRN-11, JRN-12)
--------------------------------------------------------------------------

-- "LEVEL 12", "WEEK OF 6 OCTOBER": the rubric over the entry.
function Text.Title(e, now)
    if e.kind == "week" then
        return ("WEEK OF %s"):format(Day(e.week, now):upper())
    end
    return ("LEVEL %d"):format(e.level)
end

-- How the entry opens: where and when it began.
local function Opening(e, now)
    if e.kind == "week" then
        local r = e.reached
        if r then
            local where = r.dungeon or Place(r.mapID, r.subZone)
            return ("Reached level %d%s, on %s. The road goes on."):format(
                e.level or 0, where and (" in " .. where) or "", Day(r.at, now))
        end
        return nil
    end
    if not e.known then
        return "This level went by while the diary was not keeping your road."
    end
    if e.first then
        local place = e.places[1] and (e.places[1].name or MapName(e.places[1].mapID))
        return ("Your road begins here, on %s%s."):format(Day(e.from, now), place and (", in " .. place) or "")
    end
    local r = e.reached
    if not r then return nil end
    local where = r.dungeon or Place(r.mapID, r.subZone)
    return ("Reached on %s%s."):format(Day(r.at, now), where and (" in " .. where) or "")
end

-- The zones and their times are not told here: the ledger under the entry
-- (the zone rows) carries them, a dungeon's row marked with its doorway.
-- The prose keeps what is a story: where the time went, who was there.

-- A stop's deed for its tooltip on the plates ("35 min, mostly fighting").
local ACTIVITY = { fighting = "mostly fighting", questing = "questing", resting = "resting" }

-- Where the longest stops' time went, as a diary puts it, in a sentence or
-- two that vary from entry to entry so a long road does not read as a log.
-- The stops come in the order made. `first`: the earliest, by what was done
-- there, two ways of saying it (`D` the time spoken and capitalised, `d` as
-- is, `W` the place). `later`: the stops after it, named, with their deed
-- only where it differs from the first's, after one of the `openers`.
local STOPS = {
    first = {
        fighting = { "%D of fighting at %W.", "%W kept you fighting for %d." },
        questing = { "%D of quests round %W.", "Quests kept you at %W for %d." },
        resting = { "%D resting at %W.", "You rested %d at %W." },
        none = { "%D at %W.", "You lingered at %W for %d." },
    },
    later = { fighting = "fighting near %W", questing = "quests at %W", resting = "a rest at %W" },
    openers = { "Later, ", "Then ", "After that, " },
}

local function Capital(text)
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- Which way an entry says it: the same every time for the same entry, and
-- different from its neighbours.
local function Seed(e)
    return (e.level or 0) + math.floor((e.week or 0) / ns.DAY)
end

local function Stops(e)
    local first = e.stops[1]
    if not first then return nil end
    local seed = Seed(e)
    local where = first.seg.subZone or MapName(first.seg.mapID)
    if not where then return nil end
    local ways = STOPS.first[first.main or "none"] or STOPS.first.none
    local d = Spoken(first.seconds)
    local text = ways[seed % #ways + 1]:gsub("%%(%a)", function(k)
        if k == "D" then return Capital(d) elseif k == "d" then return d elseif k == "W" then return where end
    end)

    local later, seen = {}, { [where] = true }
    for i = 2, #e.stops do
        local stop = e.stops[i]
        local name = stop.seg.subZone
        if name and not seen[name] then
            seen[name] = true
            local deed = stop.main ~= first.main and stop.main and STOPS.later[stop.main]
            later[#later + 1] = deed and deed:gsub("%%W", function() return name end) or name
        end
    end
    if #later > 0 then
        text = text .. " " .. STOPS.openers[seed % #STOPS.openers + 1] .. List(later) .. "."
    end
    return text
end

-- "Flew to Orgrimmar." The places, not how many.
local function Flights(e)
    local names, seen = {}, {}
    for _, seg in ipairs(e.flights) do
        local name = MapName(seg.mapID2)
        if name and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    local list = List(names, { max = 3, shown = 2 })
    return list and ("Flew to " .. list .. ".") or nil
end

-- "With Tester Testerson for four hours and Kaelith Dawnsong briefly."
local PEOPLE = { max = 4, shown = 3, more = "others" }

local function People(e)
    local parts = {}
    for _, person in ipairs(e.people) do
        local name = Who(person.guid)
        if name then
            parts[#parts + 1] = name .. (person.seconds >= 300 and (" for " .. Spoken(person.seconds)) or " briefly")
        end
    end
    local list = List(parts, PEOPLE)
    return list and ("With " .. list .. ".") or nil
end

-- A fight in a few words. A stranger the buffer has let go is "a fight",
-- and how it ended (JRN-10).
function Text.Fight(mark, index)
    local guid = ns.Journey.FightWho(mark, index)
    local name = guid and Who(guid)
    if mark.outcome == "won" then
        return name and ("beat " .. name) or "won a fight"
    end
    return name and ("lost to " .. name) or "lost a fight"
end

local function Fights(e, index)
    local parts = {}
    for _, mark in ipairs(e.fights) do parts[#parts + 1] = Text.Fight(mark, index) end
    local list = List(parts, { max = 4, shown = 3, more = "more" })
    if not list then return nil end
    return Capital(list) .. "."
end

-- Two sentences as one paragraph, either may be missing.
local function Join(a, b)
    if a and b then return a .. " " .. b end
    return a or b
end

-- A quiet stretch still says something, briefly.
local function Quiet(e)
    if e.kind == "week" then return nil end
    if e.seconds <= 0 then return "Nothing on the road at this level." end
    return nil
end

-- The entry's paragraphs in the diary's voice (Text.Lines), in order: the
-- opening (where and when it began), where the time went (the stops, the
-- flights), who was there (people, fights), then each kind's paragraph in
-- its place, and a word for a quiet stretch where there is no more than
-- the opening. The player's own note is not among them: Text.Note gives
-- it, to be set in their hand. `index` is Journey.FightIndex's, built
-- once per page.
--
-- What is the diary's own is written here (PARAGRAPHS, numbered by hand).
-- Every other kind with a paragraph of its own registers it
-- (Text.RegisterLines), so a feature's file (Features/<Name>/, loaded
-- after UI/) adds to every entry's prose without this file knowing of it
-- (.claude/registry-refactor.md, "A feature's folder"). Today's: the
-- diary's opening 10, time 20, people 30; a kind registered from
-- Features/<Name>/ says its number there. Leave gaps. At
-- equal numbers the diary's paragraph goes first, then the kinds in the
-- order they registered.
--
-- `spec` (Text.RegisterLines(key, spec)), `key` the kind's name, never one
-- of PARAGRAPHS' keys; registering a key again replaces it:
--   at      its place among the paragraphs
--   lines   function(e, now, index) → its paragraph (its sentences joined
--           by a space), or nil where it has nothing to say: e the entry
--           (its gathered lists, by the recap moment's `entry`), now and
--           index as Text.Lines has them
--   run     optional: the name of a paragraph several kinds write
--           together ("combat": the fights' paragraph, which more than
--           one feature writes). The first of them with something to
--           say starts it, in its place; each after it with something to
--           say runs on in it, after a space, rather than starting one
--           of its own. So kinds told as one paragraph can live apart.
local PARAGRAPHS = {
    { at = 10, key = "opening", lines = function(e, now) return Opening(e, now) end },
    { at = 20, key = "time", lines = function(e) return Join(Stops(e), Flights(e)) end },
    { at = 30, key = "people", lines = function(e, now, index) return Join(People(e), Fights(e, index)) end },
}
local LINES, linesSeq = {}, 0
-- The paragraphs sorted into their places, built when first asked after a
-- kind registered or left.
local paragraphs

function Text.RegisterLines(key, spec)
    assert(type(key) == "string" and type(spec) == "table" and type(spec.at) == "number"
        and type(spec.lines) == "function", "Text.RegisterLines(key, { at, lines = function(e, now, index) ... })")
    for _, p in ipairs(PARAGRAPHS) do assert(p.key ~= key, "Text.RegisterLines: a kind may not be called " .. key) end
    linesSeq = linesSeq + 1
    spec.key, spec.seq = key, linesSeq
    LINES[key] = spec
    paragraphs = nil
    return spec
end

-- Takes a kind's paragraph out of every entry's prose again (a test's own
-- kind).
function Text.RemoveLines(key)
    LINES[key] = nil
    paragraphs = nil
end

-- Every paragraph in its order, the diary's and the kinds': { at, key,
-- lines }. For the tests too.
function Text.Paragraphs()
    if paragraphs then return paragraphs end
    paragraphs = {}
    for i, p in ipairs(PARAGRAPHS) do
        paragraphs[#paragraphs + 1] = { at = p.at, seq = i - #PARAGRAPHS, key = p.key, lines = p.lines }
    end
    for _, spec in pairs(LINES) do paragraphs[#paragraphs + 1] = spec end
    table.sort(paragraphs, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.seq < b.seq
    end)
    return paragraphs
end

function Text.Lines(e, now, index)
    local lines, runs = {}, {}
    for _, p in ipairs(Text.Paragraphs()) do
        local text = p.lines(e, now, index)
        local at = text and p.run and runs[p.run]
        if at then
            lines[at] = lines[at] .. " " .. text
        elseif text then
            lines[#lines + 1] = text
            if p.run then runs[p.run] = #lines end
        end
    end
    if #lines <= 1 then
        local quiet = Quiet(e)
        if quiet then lines[#lines + 1] = quiet end
    end
    return lines
end

-- The player's words as a font string is to show them, and only them: the
-- client's escape codes taken out (a colour, a texture; a link keeps its
-- "[name]"), any other bar shown as a bar, so nothing typed into a note
-- turns into a link or a colour on the page; line breaks and runs of
-- spaces folded into one space.
local function Written(text)
    text = tostring(text or ""):gsub("||", "\1")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "")
    text = text:gsub("|n", " "):gsub("|", "\1"):gsub("\1", "||")
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
Text.Written = Written

-- Written words cut to `most` bytes at the end of a word (at a whole
-- character where one word is longer than that), with an ellipsis; as
-- they are where they fit. Whether they were cut, too.
local ELLIPSIS = "\226\128\166"

local function Cut(text, most)
    if #text <= most then return text, false end
    local short = text:sub(1, most + 1):match("^(.*%S)%s")
        or text:sub(1, most):gsub("[\192-\255][\128-\191]*$", "")
    -- Never half of a shown bar ("||"), nor a comma before the ellipsis.
    short = short:gsub("|+$", function(bars) return bars:sub(1, #bars - #bars % 2) end)
    return short:gsub("[%s,;:]+$", "") .. ELLIPSIS, true
end

-- The player's own words at this level: their first note, quoted as they
-- wrote it (`most` bytes, cut at a whole character), and how many more
-- there are ("And one more note."), or nil without one. The quote is
-- theirs, set in the handwriting; the count is the diary's.
local NOTE = { most = 140 }

function Text.Note(e)
    local note = e.notes and e.notes[1]
    if not note or not note.text then return nil end
    local text = Written(note.text)
    if #text > NOTE.most then
        text = text:sub(1, NOTE.most - 2):gsub("[\192-\255][\128-\191]*$", ""):gsub("%s+$", "") .. "\226\128\166"
    end
    local more = #e.notes > 1 and (#e.notes == 2 and "And one more note." or ("And %d more notes."):format(#e.notes - 1))
        or nil
    return "\226\128\156" .. text .. "\226\128\157", more
end

-- "so far" under the level being played now.
function Text.Current(e)
    return e.current and "so far" or nil
end

--------------------------------------------------------------------------
-- The zone index (JRN-15)
--------------------------------------------------------------------------

-- "The Barrens", "levels 10 to 14 · 3 h 20 min".
function Text.ZoneName(z)
    return MapName(z.mapID) or ("Map " .. z.mapID)
end

function Text.ZoneLine(z)
    local levels
    if z.levelMin and z.levelMax and z.levelMin ~= z.levelMax then
        levels = ("levels %d to %d"):format(z.levelMin, z.levelMax)
    elseif z.levelMin then
        levels = "level " .. z.levelMin
    end
    local parts = {}
    if levels then parts[#parts + 1] = levels end
    if z.seconds and z.seconds >= 60 then parts[#parts + 1] = Plain(z.seconds) end
    return table.concat(parts, "  \194\183  ")
end

--------------------------------------------------------------------------
-- The sheet's tooltips (JRN-14)
--------------------------------------------------------------------------

local function When(t, level, now)
    local text = ns.UI.At(t, now)
    text = text:sub(1, 1):upper() .. text:sub(2)
    if level then text = text .. ", at level " .. level end
    return text
end

-- A meeting mark's tooltip: a title and lines. Who, when, at what level.
function Text.Meeting(m, now, index)
    if m.kind == "session" then
        local names = {}
        for guid in pairs(m.session.participants or {}) do names[#names + 1] = Who(guid) or "someone" end
        table.sort(names)
        local s = m.session
        local seconds = ns.Sessions.Duration(s)
        return "With " .. (List(names, PEOPLE) or "someone"), {
            "Together for " .. Plain(seconds),
            When(s.startedAt, m.level, now),
        }
    elseif m.kind == "fight" then
        local text = Text.Fight(m.mark, index)
        return text:sub(1, 1):upper() .. text:sub(2), { When(m.t, m.level, now) }
    elseif m.kind == "note" then
        local about = {}
        for guid in pairs(m.note.about or {}) do about[#about + 1] = Who(guid) or "someone" end
        table.sort(about)
        local lines = { Written(m.note.text) }
        if #about > 0 then lines[#lines + 1] = "About " .. List(about) end
        lines[#lines + 1] = When(m.t, m.level, now)
        return "Your note", lines
    end
    return "", {}
end

-- What kind of place a stop was, for the sheet's activity areas:
-- "fighting", "questing", "resting", or nil for a place you only stayed.
-- The recap's main activity, and a quest taken or handed in on a short
-- stop (a quest giver passed on the way) counts as questing too.
function Text.StopKind(seg)
    local main = ns.JourneyRecap.MainActivity(seg)
    if main then return main end
    local act = seg.act
    if act and (act.questsIn or 0) + (act.questsOut or 0) > 0 then return "questing" end
    return nil
end

local SHORT = { fighting = "fighting", questing = "questing", resting = "resting" }

-- How long a stop lasted, in words: a quest giver passed on the way is
-- "under a minute", not "0 min".
local function StopTime(seconds)
    return seconds >= 60 and Plain(seconds) or nil
end

-- A stop's label on the sheet: "Red Cloud Mesa · 6 min", or what was done
-- there where the place has no name ("fighting · 2 min"), the time left
-- off under a minute; nil with neither name nor deed.
function Text.StopLabel(seg, seconds)
    local kind = Text.StopKind(seg)
    local name = seg.subZone or (kind and SHORT[kind])
    if not name then return nil end
    local time = StopTime(seconds or seg.seconds or (seg.to - seg.from))
    return time and (name .. " \194\183 " .. time) or name
end

local function Times(n, one, many)
    if n == 1 then return one end
    if n == 2 then return many:format("twice") end
    return many:format(n .. " times")
end

-- A stop's tooltip: where, how long and what was done there, in plain
-- words, then when and at what level. `more` is how many short stays
-- close by the sheet drew as this one.
function Text.Stop(seg, now, more)
    local kind = Text.StopKind(seg)
    local lines = { (StopTime(seg.seconds or (seg.to - seg.from)) or "Under a minute")
        .. (kind and (", " .. ACTIVITY[kind]) or "") }
    local act = seg.act or {}
    local combat = act.combat or 0
    if combat >= 60 then
        lines[#lines + 1] = "Fought here for " .. Plain(combat)
    elseif combat > 0 then
        lines[#lines + 1] = "Fought here"
    end
    local took, gave = act.questsIn or 0, act.questsOut or 0
    if took > 0 then lines[#lines + 1] = took == 1 and "Took a quest" or ("Took %d quests"):format(took) end
    if gave > 0 then
        lines[#lines + 1] = gave == 1 and "Handed in a quest" or ("Handed in %d quests"):format(gave)
    end
    local deaths = act.deaths or 0
    if deaths > 0 then lines[#lines + 1] = Times(deaths, "Died here", "Died here %s") end
    local levels = seg.levelFrom ~= seg.levelTo and ("Levels %d to %d"):format(seg.levelFrom or 0, seg.levelTo or 0)
        or (seg.levelFrom and ("Level " .. seg.levelFrom))
    lines[#lines + 1] = When(seg.from, nil, now) .. (levels and (" \194\183 " .. levels) or "")
    if more and more > 0 then
        lines[#lines + 1] = more == 1 and "And one more short stay close by"
            or ("And %d more short stays close by"):format(more)
    end
    return seg.subZone or MapName(seg.mapID) or "A stop", lines
end

function Text.Pin(pin, now)
    return ("Level %d"):format(pin.level), { "Reached " .. ns.UI.At(pin.at, now) }
end

function Text.Dungeon(seg, now)
    return seg.name or "An instance", {
        Plain(seg.seconds or 0) .. " inside",
        When(seg.from, seg.levelFrom, now),
    }
end

function Text.Flight(seg, mapID, now)
    local other = seg.mapID1 == mapID and seg.mapID2 or seg.mapID1
    local toward = seg.mapID1 == mapID and "Flew to " or "Flew in from "
    local name = MapName(other)
    if seg.mapID1 == seg.mapID2 then toward, name = "A flight", nil end
    return toward .. (name or ""), { When(seg.from, seg.levelFrom, now) }
end

--------------------------------------------------------------------------
-- Plates, margin notes, first sightings (JRN-21 to JRN-23)
--------------------------------------------------------------------------

-- A person's short name for a margin note or a line: their first name.
local function Short(guid)
    local first = guid and ns.Characters.Name(guid)
    return first or Who(guid)
end
Text.Short = Short

-- "today", "yesterday", "Tuesday", or "4 October" past a week: the day a
-- plate's caption names, as it reads after a comma.
local function PlateDay(t, now)
    local label = ns.UI.DayLabel(t, now)
    if label == "Today" or label == "Yesterday" then return label:lower() end
    if now - t < 6 * ns.DAY then return date("%A", t) end
    return Day(t, now)
end

-- "Mulgore, yesterday": the plate's heading, written by hand beside it as
-- under a photograph in an album. Returns the zone and the day too, for a
-- column too narrow for both on one line. A plate the same day as the one
-- `before` it on the page counts on from it instead of saying the day
-- again: "Forty-five minutes later", and ", in The Barrens" when the zone
-- changed.
function Text.PlateHeading(plate, now, before)
    now = now or ns.Now()
    local zone = MapName(plate.mapID) or "Somewhere"
    if before and before.t and plate.t and plate.t >= before.t
        and ns.DayStart(plate.t) == ns.DayStart(before.t) then
        local later = Spoken(plate.t - before.t) .. " later"
        if plate.mapID == before.mapID then return Capital(later), Capital(later), nil end
        return Capital(later) .. ", in " .. zone, zone, later
    end
    local day = PlateDay(plate.t, now)
    return zone .. ", " .. day, zone, day
end

local NUMBER = { "a", "two", "three", "four", "five" }

-- A close call's health left (JRN-25), held together: "6% health".
local function Health(call)
    return Glue((call.pct or 0) .. "% health")
end

--------------------------------------------------------------------------
-- A plate's words (Text.PlateCaption) and the kinds that add to them
-- (Text.RegisterCaption)
--------------------------------------------------------------------------

-- A few words under a plate (JRN-21): what put it there, never a list.
-- The left page already tells the story; this only names the place.
-- They are three parts, in this order. The lead, the clause they open
-- with: "With Koko", "A first green: Wolfskin Bracers", "Into Mulgore for
-- the first time". The tail, what else happened there, after it and as
-- short as it: ", a first bag, and two deaths". And a coda, a sentence of
-- its own after the full stop: "Grisha mercilessly watched you die."
--
-- What is the diary's own is written here: the people you were with
-- (who no margin note names), fights with strangers, the first visit to a
-- zone, a dungeon's door, a long stay, the company a note names already,
-- the level reached, and "On the road" when there is nothing else (LEADS,
-- below). The level is said only when nothing else is ("Level 9."): the
-- rubric names it already, and the words are for what happened. Every
-- other kind of moment with words of its own registers them
-- (Text.RegisterCaption), so a feature's file (Features/<Name>/, loaded
-- after UI/) adds to every plate's words without this file knowing of it
-- (.claude/registry-refactor.md, phase 4).
--
-- The lead is the first in the order of `at` that has something to say;
-- the diary's leads are numbered by hand here and a kind's slot in
-- between by its number. The diary's: people 10, fights 45 (strangers),
-- arrive 100, dungeon 110, stay 120, company 130, level 150, and "On
-- the road" after all; a kind registered from Features/<Name>/ says its
-- number there. At equal numbers the diary's lead goes
-- first, then the kinds in the order they registered. A kind is asked
-- for its lead only when it gathered something.
-- The tail is every kind's words in the order of its tail's `at` (the
-- features' own), less the lead's own kind, which has said itself. A kind
-- ahead of the lead in the chain had nothing to say (or it would have
-- led), so nothing more is left out: a lead that passes has no tail words
-- either (a kind whose card shows it all). "X, and Y"; "X, Y, and Z".
--
-- `spec` (Text.RegisterCaption(key, spec)), `key` the kind's name, which
-- is also its key in `said` and in `c.lists`, and what `c.lead` is while
-- it leads; never one of the diary's own (LEADS' keys, "road"):
--   moment   the kind of plate.moments it gathers, in the plate's order,
--            for its lead and tail. None for a kind with a coda alone
--            (one the margin tells it of).
--   take     optional function(m, said) → what of the moment it keeps
--            (m.call, ...); nil to leave it out (what its card
--            tells). The moment itself where not given.
--   lead     optional { at, say = function(list, c) → text, rest }: its
--            opening clause, capitalised, no full stop; nil to let the
--            next lead have it. `rest` (optional, a list of words) goes in
--            its own place in the tail: a lead may say the first of its
--            list, its tail place the others.
--   tail     optional { at, say = function(list, c) → words }: a phrase
--            or a list of them, lower case, nil for none. Asked only when
--            it gathered something, and never when its own lead led.
--   coda     optional { at, say = function(c) → sentence }: a whole
--            sentence after the words' full stop; nil for none.
-- `c`, the words being written: plate, began, said, named (said.named or
-- {}), of (the first moment of each kind there), lists (each kind's
-- gathered list, by key) and, from the lead on, lead (the key of the one
-- that led: a kind's, or "people", "fights", "arrive", "dungeon", "stay",
-- "company", "level", "road").
--
-- `began` (optional) is when the road began, so the very first place
-- reads as where the diary began. `said` (optional) is what the margin
-- beside the plate tells already (UI/JournalJourney.lua, its kinds'
-- JourneyMargin `assume` and `say`), for the words not to tell it again:
-- `named` is who its notes name, [guid] = true for each, and `someone`,
-- how many strangers' notes there are ("With Tester." is not written
-- beside Tester's own note; "In good company." is). Every other key is a
-- kind's, by its key, and means what that kind says it does (the
-- features' own: their Text.lua says theirs).
local CAPTIONS, CAPTION_LIST, captionSeq = {}, {}, 0
-- The kinds sorted into their places, built when first asked after a kind
-- registered or left.
local chain

-- The diary's own leads, in their order (`at`), each say(c) → its clause
-- or nil. Kinds slot in between by number (Text.RegisterCaption).
local LEADS = {
    -- Who you were with that no note beside the plate names.
    { at = 10, key = "people", say = function(c)
        if #c.people == 0 then return nil end
        return "With " .. List(c.people, { max = 3, shown = 2, more = "others" })
    end },
    -- Fights with strangers no note tells: "A fight, won", "Two fights".
    { at = 45, key = "fights", say = function(c)
        local strangers = c.strangers
        if #strangers == 0 then return nil end
        if #strangers == 1 then return "A fight, " .. (strangers[1].outcome == "won" and "won" or "lost") end
        return Capital(NUMBER[#strangers] or tostring(#strangers)) .. " fights"
    end },
    { at = 100, key = "arrive", say = function(c)
        local arrive = c.of.arrive
        if not arrive then return nil end
        if c.began and arrive.t <= c.began then return "Where the diary began" end
        return "Into " .. (MapName(c.plate.mapID) or "a new zone") .. " for the first time"
    end },
    { at = 110, key = "dungeon", say = function(c)
        local dungeon = c.of.dungeon
        return dungeon and ("The way into " .. (dungeon.name or "a dungeon")) or nil
    end },
    { at = 120, key = "stay", say = function(c)
        local stay = c.of.stay
        if not stay then return nil end
        local seg = stay.seg
        local text = seg.subZone and seg.subZone ~= MapName(seg.mapID) and seg.subZone or "A long stay"
        return text .. ", " .. Duration(stay.seconds or seg.seconds or 0)
    end },
    -- Someone a note beside the plate names already: what you did together
    -- is said, never who.
    { at = 130, key = "company", say = function(c)
        if c.company == "fight" then return "Where the fighting was" end
        if c.company then return "In good company" end
        return nil
    end },
    { at = 150, key = "level", say = function(c)
        return c.of.level and ("Level " .. c.of.level.level) or nil
    end },
}
local ROAD = "On the road"

function Text.RegisterCaption(key, spec)
    assert(type(key) == "string" and type(spec) == "table" and (spec.lead or spec.tail or spec.coda),
        "Text.RegisterCaption(key, { moment, lead = { at, say }, tail = { at, say }, coda = { at, say } })")
    assert(key ~= "road", "Text.RegisterCaption: a kind may not be called " .. key)
    for _, lead in ipairs(LEADS) do assert(lead.key ~= key, "Text.RegisterCaption: a kind may not be called " .. key) end
    Text.RemoveCaption(key)
    captionSeq = captionSeq + 1
    spec.key, spec.seq = key, captionSeq
    CAPTIONS[key] = spec
    CAPTION_LIST[#CAPTION_LIST + 1] = spec
    chain = nil
    return spec
end

-- Takes a kind's words off every plate again (a feature switched off, a
-- test's own kind).
function Text.RemoveCaption(key)
    local old = CAPTIONS[key]
    if not old then return end
    CAPTIONS[key] = nil
    for i = #CAPTION_LIST, 1, -1 do
        if CAPTION_LIST[i] == old then table.remove(CAPTION_LIST, i) end
    end
    chain = nil
end
-- For the tests: the registered kinds.
Text.CAPTIONS = CAPTIONS

local function ByAt(a, b)
    if a.at ~= b.at then return a.at < b.at end
    return a.seq < b.seq
end

local function Chain()
    if chain then return chain end
    chain = { leads = {}, tails = {}, codas = {}, moments = {} }
    for i, lead in ipairs(LEADS) do
        chain.leads[#chain.leads + 1] = { at = lead.at, seq = i - #LEADS, key = lead.key, say = lead.say }
    end
    for _, spec in ipairs(CAPTION_LIST) do
        if spec.lead then
            chain.leads[#chain.leads + 1] = { at = spec.lead.at, seq = spec.seq, key = spec.key, spec = spec }
        end
        if spec.tail then chain.tails[#chain.tails + 1] = { at = spec.tail.at, seq = spec.seq, spec = spec } end
        if spec.coda then chain.codas[#chain.codas + 1] = { at = spec.coda.at, seq = spec.seq, spec = spec } end
        if spec.moment then
            local list = chain.moments[spec.moment] or {}
            chain.moments[spec.moment] = list
            list[#list + 1] = spec
        end
    end
    table.sort(chain.leads, ByAt)
    table.sort(chain.tails, ByAt)
    table.sort(chain.codas, ByAt)
    return chain
end

local NONE = {}

function Text.PlateCaption(plate, began, said)
    said = said or {}
    local named = said.named or {}
    local someone = named.someone or 0
    local C = Chain()
    local of, people, strangers, lists = {}, {}, {}, {}
    local c = { plate = plate, began = began, said = said, named = named, of = of, people = people,
        strangers = strangers, lists = lists }
    for _, spec in ipairs(CAPTION_LIST) do lists[spec.key] = {} end
    for _, m in ipairs(plate.moments) do
        for _, spec in ipairs(C.moments[m.kind] or NONE) do
            local kept = m
            if spec.take then kept = spec.take(m, said) end
            if kept then
                local list = lists[spec.key]
                list[#list + 1] = kept
            end
        end
        of[m.kind] = of[m.kind] or m
        if (m.kind == "session" or m.kind == "note" or m.kind == "first" or m.kind == "fight") then
            if m.guid and ns.Diary.IsDiary(m.guid) then
                local name = Short(m.guid)
                if named[m.guid] then
                    c.company = c.company or m.kind
                elseif name and not people[name] then
                    people[name] = true
                    people[#people + 1] = name
                end
            elseif m.kind == "fight" then
                if (m.guid and named[m.guid]) or (not m.guid and someone > 0) then
                    if not m.guid then someone = someone - 1 end
                    c.company = c.company or "fight"
                else
                    strangers[#strangers + 1] = m
                end
            end
        end
    end

    -- The lead: the first in the chain with something to say.
    local text, rest
    for _, lead in ipairs(C.leads) do
        local clause, more
        if lead.spec then
            local list = lists[lead.key]
            if #list > 0 then clause, more = lead.spec.lead.say(list, c) end
        else
            clause = lead.say(c)
        end
        if clause then
            text, rest, c.lead = clause, more, lead.key
            break
        end
    end
    if not text then text, c.lead = ROAD, "road" end

    -- What else happened there, each kind in its tail place.
    local tail = {}
    local function Put(words)
        if type(words) == "table" then
            for _, w in ipairs(words) do tail[#tail + 1] = w end
        elseif words then
            tail[#tail + 1] = words
        end
    end
    for _, t in ipairs(C.tails) do
        local spec = t.spec
        if spec.key == c.lead then
            Put(rest)
        else
            local list = lists[spec.key]
            if #list > 0 then Put(spec.tail.say(list, c)) end
        end
    end
    if #tail == 1 then
        text = text .. ", and " .. tail[1]
    elseif #tail > 1 then
        text = text .. ", " .. table.concat(tail, ", ", 1, #tail - 1) .. ", and " .. tail[#tail]
    end
    text = text .. "."
    for _, coda in ipairs(C.codas) do
        local sentence = coda.spec.coda.say(c)
        if sentence then text = text .. " " .. sentence end
    end
    return text
end

-- The player's own words on a person's margin note: their latest note
-- about them on the plate (a note moment's `note`, Core/JourneyRecap.lua),
-- as written (Written), for the strip to quote in their hand under the
-- name. Cut at a word past QUOTE.most bytes, for the strip to cut again to
-- its lines; and to QUOTE.tip for the strip's tooltip, where it was cut.
-- Returns the quote, whether it was cut, and the tooltip's words; nil
-- without a note that says anything.
local QUOTE = { most = 160, tip = 500 }

-- The note moment Text.MarginQuote quotes, or nil: the strip's leader
-- goes to its mark (12 Oct, in the client: a quote written in the south
-- under a leader to the north, where the time together was).
function Text.MarginQuoted(moments)
    local latest
    for _, m in ipairs(moments) do
        if m.kind == "note" and m.note and type(m.note.text) == "string"
            and (not latest or (m.t or 0) >= (latest.t or 0)) then
            latest = m
        end
    end
    local text = latest and Written(latest.note.text)
    if not text or text == "" then return nil end
    return latest, text
end

function Text.MarginQuote(moments)
    local _, text = Text.MarginQuoted(moments)
    if not text then return nil end
    local quote, cut = Cut(text, QUOTE.most)
    return quote, cut, (Cut(text, QUOTE.tip))
end
Text.QUOTE = QUOTE

-- What happened with one person on one plate, for their margin note:
-- "35 min together and a note", "killed you", "first seen · you'd meet
-- again at level 4". A stranger's note has only fights (JRN-22). The
-- short phrases are held together by no-break spaces as a time is ("a
-- note", "killed you"), so a strip's last line is never "note" alone
-- (10 Oct, in the client: "3 h 20 min together and a / note"); the strip
-- balances its lines as well (UI/PaperStrip.lua's STRIP.balance). Where
-- the strip quotes their note (Text.MarginQuote), the quote says it: no
-- "a note", only the others counted ("35 min together and one more note").
function Text.MarginWhat(moments, level)
    local parts, together, notes = {}, 0, 0
    for _, m in ipairs(moments) do
        if m.kind == "session" then together = together + (m.seconds or 0)
        elseif m.kind == "note" then notes = notes + 1 end
    end
    local quoted = notes > 0 and Text.MarginQuote(moments) ~= nil
    if quoted then notes = notes - 1 end
    -- A feature's moment that is this person's too (its `person`, Core/
    -- JourneyRecap.lua's RegisterMoment: say, something they gave you)
    -- first: a strip keeps STRIP.lines lines and cuts the rest, and that
    -- is what this person is remembered by here.
    for _, m in ipairs(moments) do
        if m.person and m.person.say then parts[#parts + 1] = m.person.say(m) end
    end
    if together > 0 then parts[#parts + 1] = (together >= 60 and Duration(together) or "a moment") .. " together" end
    if notes > 0 and quoted then
        parts[#parts + 1] = Glue(notes == 1 and "one more note" or (NUMBER[notes] or notes) .. " more notes")
    elseif notes > 0 then
        parts[#parts + 1] = Glue(notes == 1 and "a note" or (NUMBER[notes] or notes) .. " notes")
    end
    for _, m in ipairs(moments) do
        if m.kind == "fight" then
            if m.outcome == "lost" then
                parts[#parts + 1] = m.guid and Glue("killed you") or "a fight, lost"
            else
                parts[#parts + 1] = m.guid and "you won the fight" or "a fight, won"
            end
        end
    end
    for _, m in ipairs(moments) do
        if m.kind == "first" then
            local again = m.metLevel and level and m.metLevel > level
                and ("you'd meet again at level " .. m.metLevel) or "you'd meet again"
            parts[#parts + 1] = "first seen  \194\183  " .. again
        end
    end
    return table.concat(parts, " and ")
end

-- A killer's name in a sentence: "a Sunscale Lashtail", "an Ornery
-- Plainstrider"; a rare or a boss is most often one of a kind, named
-- ("Hogger", "The Rake"), so it goes bare, as does a name that brings its
-- own article.
function Text.KillerName(k)
    local name = k and k.name
    if not name or name == "" then return nil end
    if name:find("^[Tt]he ") or k.rank == "rare" or k.rank == "rareelite" or k.rank == "worldboss" then
        return name
    end
    return (name:find("^[AEIOUaeiou]") and "an " or "a ") .. name
end


--------------------------------------------------------------------------
-- Counts, plurals and items (shared helpers, exported below)
--------------------------------------------------------------------------

-- A number held to the word after it, as a time is ("31 Plainstriders"
-- never breaks after the 31); the rest of the words may wrap.
local function Count(n, words)
    return tostring(n) .. (SPACE.keep and SPACE.nbsp or " ") .. words
end

-- A creature's name for more than one: "Plainstriders", "Timber Wolves",
-- "Defias Highwaymen", "Harpies"; "Servants of Grol" when the name has an
-- "of". Only the last word changes. A few kinds are their own plural.
local SAME = { sheep = true, deer = true, fish = true, moose = true }
local IRREGULAR = { tooth = "teeth", foot = "feet", mouse = "mice", louse = "lice", ox = "oxen", child = "children",
    shaman = "shamans", human = "humans", talisman = "talismans", chief = "chiefs" }
local PLURAL = { { "ief$", "ieves" }, { "([lr])f$", "%1ves" }, { "fe$", "ves" }, { "man$", "men" },
    { "([^aeiouAEIOU])y$", "%1ies" }, { "([sxz])$", "%1es" }, { "([cs]h)$", "%1es" } }

local function Plural(name)
    local head, tail = name:match("^(.-)( of .+)$")
    if head then return Plural(head) .. tail end
    local word = name:match("(%a+)$") or ""
    local lower = word:lower()
    if SAME[lower] then return name end
    local odd = IRREGULAR[lower]
    if odd then
        if word:sub(1, 1) ~= lower:sub(1, 1) then odd = Capital(odd) end
        return name:sub(1, #name - #word) .. odd
    end
    for _, rule in ipairs(PLURAL) do
        local out, n = name:gsub(rule[1], rule[2])
        if n > 0 then return out end
    end
    return name .. "s"
end
Text.Plural = Plural

-- An item's name for more than one: "Intact Raptor Horns", but never
-- "Plainstrider Meats": what is not counted keeps its name (MASS, by its
-- last word, or a word it ends in), and so does a name already plural.
local MASS = { meat = true, flesh = true, blood = true, ichor = true, silk = true, cloth = true, leather = true,
    venom = true, dust = true, ore = true, wool = true, hair = true, fur = true, essence = true, oil = true,
    water = true, sand = true, ash = true, moss = true, slime = true, dirt = true, mud = true, powder = true,
    gunpowder = true, pollen = true, ink = true, fat = true, bark = true, bile = true, sap = true, silt = true,
    honey = true, grain = true, ectoplasm = true, residue = true, jerky = true, wood = true }
local MASS_ENDS = { "weed", "cloth", "meat", "silk", "dust", "moss", "wood" }

local function ItemWord(n, item)
    if n == 1 then return item end
    local last = (item:match("(%a+)$") or ""):lower()
    local mass = MASS[last] or (last:sub(-1) == "s" and last:sub(-2) ~= "ss")
    for _, e in ipairs(MASS_ENDS) do mass = mass or last:sub(-#e) == e end
    return mass and item or Plural(item)
end

local function Items(n, item)
    if n == 1 then return Count("one", item) end
    return Count(n, ItemWord(n, item))
end

-- The name a margin note is headed by, so the note reads as who you were
-- with: "with Koko", or "with someone" for a stranger whose name the
-- buffer no longer has.
function Text.MarginWho(guid)
    return "with " .. (guid and Short(guid) or "someone")
end

-- JRN-23: the line under a level's prose for a first sighting in
-- hindsight. "You first saw Koko in Mulgore. You'd meet again at level 4."
function Text.Hindsight(f)
    local name = Short(f.guid) or "someone"
    local zone = MapName(f.mapID)
    local line = "You first saw " .. name .. (zone and (" in " .. zone) or "") .. "."
    if f.metLevel and f.level and f.metLevel > f.level then
        return line .. " You'd meet again at level " .. f.metLevel .. "."
    end
    return line .. " You'd meet again before the level was out."
end

-- The hollow lozenge's tooltip: "First seen: Koko Skybluff", "Sunday, 4
-- October, at level 1".
function Text.FirstSeen(f, now)
    now = now or ns.Now()
    return "First seen: " .. (Who(f.guid) or "someone"), {
        ns.UI.DayLabel(f.t, now) .. (f.level and (", at level " .. f.level) or ""),
    }
end

-- A face on a level's rubric: "Koko Skybluff · 20 min together".
function Text.Face(face, e)
    local name = Who(face.guid) or "someone"
    for _, person in ipairs(e.people or {}) do
        if person.guid == face.guid and person.seconds >= 60 then
            return name .. "  \194\183  " .. Plain(person.seconds) .. " together"
        end
    end
    for _, f in ipairs(e.hindsight or {}) do
        if f.guid == face.guid then return name .. "  \194\183  first seen" end
    end
    for _, mark in ipairs(e.fights or {}) do
        if mark.guid == face.guid then
            return name .. "  \194\183  " .. (mark.outcome == "lost" and "killed you" or "a fight, won")
        end
    end
    return name
end

-- A pool's tooltip: its ink's meaning and time (no key on the plates).
local POOL = { fighting = "Fought here", questing = "Quested here", resting = "Rested here" }

function Text.Pool(seg)
    local kind = Text.StopKind(seg)
    local seconds = seg.seconds or (seg.to - seg.from)
    return (POOL[kind] or "Stayed here") .. ", " .. (seconds >= 60 and Plain(seconds) or "under a minute")
end

-- The line under a full-page plate (JRN-15): "levels 1 to 5 · 6 h 20 min ·
-- with Dos, Koko · 2 fights". `names` are the diary people met there, short.
function Text.ZoneFoot(z, names, fights)
    local line = Text.ZoneLine(z)
    local parts = { line ~= "" and line or nil }
    local list = List(names or {}, { max = 4, shown = 3, more = "others" })
    if list then parts[#parts + 1] = "with " .. list end
    if (fights or 0) > 0 then parts[#parts + 1] = fights == 1 and "a fight" or (fights .. " fights") end
    return table.concat(parts, "  \194\183  ")
end

--------------------------------------------------------------------------
-- The words every kind shares
--------------------------------------------------------------------------

-- What a kind's own words (its card's, its mark's tooltip, its caption
-- words) are written with, on Text, so its section can move to its
-- feature's file (Features/<Name>/, .claude/registry-refactor.md) as it
-- is, its helpers taken from here (`local When, Capital = Text.When,
-- Text.Capital`) instead of from this file's locals:
--   Glue(text)            its spaces no-break (SPACE), so it never wraps
--   Duration(seconds)     "1 h 33 min", glued
--   Spoken(seconds)       "twenty minutes", "an hour and a half"
--   Capital(text)         its first letter capitalised
--   MapName(mapID)        a map's name, or nil
--   Who(guid)             a character's full name, else their name
--   Short(guid)           their first name (a margin note's)
--   Day(t, now)           "6 October", the year once it is not this one's
--   When(t, level, now)   "Yesterday, 21:40, at level 12": a tooltip's last line
--   Place(mapID, subZone) "Lushwater Oasis, The Barrens"
--   Times(n, one, many)   "Died here", "Died here twice", "... 3 times"
--   NUMBER, WORDS         counts in words: NUMBER[n] "a", "two" ... "five";
--                         WORDS[n] "two" ... "twelve", "fifteen", "twenty", ...
--   Count(n, words)       a figure held to its noun ("31 Plainstriders")
--   Plural(name)          a creature's name for more than one
--   ItemWord(n, item)     an item's name for `n` of it ("Plainstrider Meat")
--   Items(n, item)        "one Hezrul's Head", "7 Plainstrider Meat"
--   Health(call)          "6% health", glued
--   Written(text)         the player's words, escapes taken out
--   Cut(text, most)       words cut at a word with an ellipsis; whether cut
--   Join(a, b)            two sentences as one paragraph, either missing
--   List(items, opts)     "A, B and 2 others" (ns.UI.List)
Text.Glue, Text.Capital, Text.MapName, Text.Who, Text.Day, Text.When = Glue, Capital, MapName, Who, Day, When
Text.Times, Text.NUMBER, Text.WORDS, Text.Count, Text.ItemWord, Text.Items = Times, NUMBER, WORDS, Count, ItemWord, Items
Text.Health = Health
Text.Cut, Text.Join, Text.List = Cut, Join, List

