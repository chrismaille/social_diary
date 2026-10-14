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

--------------------------------------------------------------------------
-- Firsts (JRN-24)
--------------------------------------------------------------------------

-- What each first is called: on a plate ("a first bag") and in a sentence
-- ("your first bag").
local FIND = { bag = "bag", shoulder = "shoulders", uncommon = "green", rare = "blue", epic = "epic" }

local function FindWords(kind)
    local word = FIND[kind] or "find"
    return (kind == "shoulder" and "first " or "a first ") .. word, "your first " .. word
end
Text.FindWords = FindWords

-- The item's name, out of its link.
local function ItemName(link)
    return type(link) == "string" and (link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]")) or nil
end
Text.ItemName = ItemName

-- A first found card's heading (UI/FindCard.lua), in the diary's hand:
-- "Your first green item!", "Your first bag!". `what` is one kind or a
-- list of them, for one item that was the first of several ("Your first
-- bag and first green item!", a green bag), told bag, shoulders, then by
-- quality. `short` drops "item" for a narrow margin ("Your first green!").
local HEADING = { bag = "bag", shoulder = "shoulders", uncommon = "green", rare = "blue", epic = "epic" }
local HEADING_ORDER = { bag = 1, shoulder = 2, uncommon = 3, rare = 4, epic = 5 }
function Text.FindHeading(what, short)
    local list = type(what) == "table" and { unpack(what) } or { what }
    table.sort(list, function(a, b) return (HEADING_ORDER[a] or 9) < (HEADING_ORDER[b] or 9) end)
    local words = {}
    for i, kind in ipairs(list) do
        local word = HEADING[kind] or "find"
        local quality = HEADING_ORDER[kind] and HEADING_ORDER[kind] >= 3
        -- "item" once, at the end: "first green item", never "green item
        -- and first blue item".
        if quality and not short and i == #list then word = word .. " item" end
        words[#words + 1] = (i == 1 and "" or "first ") .. word
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, ", ", 1, #words - 1) .. " and " .. words[#words]
    end
    return "Your first " .. text .. "!"
end

-- The line under a first found card's item, for a gift whose giver has
-- no margin note of their own beside the plate (`named`, as
-- Text.PlateCaption takes it): "from Koko" for someone in the diary, "a
-- gift" for anyone else; nil for what was not given, or whose giver's
-- note says so already.
function Text.FindGift(rec, named)
    if not rec or rec.from ~= "trade" then return nil end
    local giver = rec.guid and ns.db.characters[rec.guid] and rec.guid or nil
    if giver and named and named[giver] then return nil end
    if giver and ns.Diary.IsDiary(giver) then
        local name = Text.Short(giver)
        if name then return "from " .. name end
    end
    return "a gift"
end

-- Who gave a first, while the diary still knows them.
local function Giver(rec)
    return rec.from == "trade" and rec.guid and ns.db.characters[rec.guid] and rec.guid or nil
end

-- One first in a sentence, how it came and where: "Found your first
-- green in Mulgore: Wolfskin Bracers." `kind`, `rec` as Journey.Firsts
-- gives them.
function Text.Find(kind, rec)
    local _, yours = FindWords(kind)
    local zone = MapName(rec.mapID)
    local in_ = zone and (" in " .. zone) or ""
    local text
    if rec.from == "trade" then
        local giver = Giver(rec)
        text = giver and (Who(giver) .. " gave you " .. yours) or (Capital(yours) .. " was a gift")
    elseif rec.from == "quest" then
        text = "A quest gave you " .. yours
    elseif rec.from == "vendor" then
        text = "Bought " .. yours .. in_
    elseif rec.from == "mail" then
        text = Capital(yours) .. " came by mail"
    else
        text = "Found " .. yours .. in_
    end
    local name = ItemName(rec.link)
    return text .. (name and (": " .. name) or "") .. "."
end

local function Finds(e)
    local lines = {}
    for _, f in ipairs(e.finds or {}) do lines[#lines + 1] = Text.Find(f.kind, f.rec) end
    if #lines == 0 then return nil end
    return table.concat(lines, " ")
end

-- A first's mark on a plate, for its tooltip: the heading ("Your first
-- bag") and the line under it, the sentence without the heading's words
-- ("Small Brown Pouch, bought at level 5, 6 October"); `bare` leaves the
-- item's name out, for under the item's own tooltip (UI/FindCard.lua).
function Text.FindTip(m, now, bare)
    local rec = m.find or m
    local _, yours = FindWords(m.what or m.kind)
    local how = ({ quest = "a quest's reward", vendor = "bought", mail = "by mail", loot = "looted" })[rec.from]
    if rec.from == "trade" then
        local giver = Giver(rec)
        how = giver and ("from " .. Who(giver)) or "a gift"
    end
    local parts = { not bare and ItemName(rec.link) or nil, how or "found",
        (rec.level and ("at level " .. rec.level) or nil), Day(rec.t, now) }
    local list = {}
    for i = 1, 4 do
        if parts[i] then list[#list + 1] = parts[i] end
    end
    return Capital(yours), table.concat(list, ", ")
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

-- The entry's paragraphs in the diary's voice, in order: the opening
-- (where and when it began), where the time went (the stops, the
-- flights), who was there (people, fights), the firsts found, the chains
-- finished (JRN-28), the professions brought to their cap (JRN-29), the
-- close calls and luck (JRN-25, JRN-26, EXT-3). The player's own note is not
-- among them: Text.Note gives it, to be set in their hand. `index` is
-- Journey.FightIndex's, built once per page.
function Text.Lines(e, now, index)
    local lines = {}
    local function Add(text) if text then lines[#lines + 1] = text end end
    Add(Opening(e, now))
    Add(Join(Stops(e), Flights(e)))
    Add(Join(People(e), Fights(e, index)))
    Add(Finds(e))
    Add(Text.FinaleLines(e))
    Add(Text.SkillLines(e))
    Add(Text.CombatLines(e))
    if #lines <= 1 then Add(Quiet(e)) end
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

local function Deaths(n)
    if n == 1 then return "a death" end
    return (NUMBER[n] or tostring(n)) .. " deaths"
end

-- A few words under a plate (JRN-21): what put it there, never a list.
-- The left page already tells the story; this only names the place.
-- The level reached there is said only when nothing else is ("Level
-- 9."): the rubric names the level already, and the words are for what
-- happened.
-- `began` (optional) is when the road began, so the very first
-- place reads as where the diary began. `named` (optional) is who the
-- margin notes beside the plate already name: [guid] = true for each,
-- and `someone`, how many strangers' notes there are. They are not named
-- again here ("With Tester." beside Tester's own note). `killer`
-- (optional) is what killed you there, as Text.KillerName writes it, when
-- its card found no room beside the plate: it goes with the deaths
-- ("Two deaths, to a Sunscale Lashtail."), so its name is
-- still written somewhere. `shown` (optional) is the firsts found whose
-- cards (UI/FindCard.lua) are drawn beside the plate, [moment] = true
-- (or [its record] = true, as a plate's marks and its moments are not the
-- same tables):
-- their card shows the item and says who gave it, so the words only name
-- the first ("A first green."); one with no card keeps its item's name
-- here ("A first green: Wolfskin Bracers."). A chain's end (JRN-28) goes
-- after the finds, or leads where nothing above it does ("The end of “Crown
-- of the Earth”."), and a profession brought to its cap (JRN-29) after
-- that, or leads where neither is ("First Aid at 75."; "Two professions
-- at their cap."). A close call (JRN-25) and bad or good
-- luck with a quest's drops (JRN-26, EXT-3) go after the deaths (", and a close
-- call", ", and 31 Plainstriders for 7 Plainstrider Meat"), or lead where
-- nothing else does ("Got away from a Plainstrider with 6% health."). `foe`
-- (optional): the card of the creature that nearly got you is beside the
-- plate, its health and fight charted on it, so a close call leading the
-- words only names it ("A close call."); without it the creature is named
-- after the deaths too (", and a close call with a Plainstrider"), as the
-- killer is. A killer's card and a close call's are two fights, so both
-- may be beside the plate, or either left off. `hunted` (optional): the
-- hunt whose card (UI/HuntCard.lua) is beside the plate; its words are on
-- the card, so the caption leaves them off, and says any
-- other slow hunt as before. `lucky` (optional): { hunt, print }, the good
-- luck told beside the plate (UI/LuckyCard.lua). On a margin card its
-- words leave the caption too, and any other lucky hunt is counted, not
-- told ("another lucky hunt", "two more lucky hunts"): told whole, the
-- second would make the words longer because a card showed. On a light
-- plate's print (`print`: the card's S, no heading) the caption names the
-- item and who dropped it, the print how it went (Text.LuckyCaption).
-- `witness` (optional): someone who was there at a death or a close call
-- on the plate (UI/KillerCard.lua's Witness) whose card
-- (UI/WitnessCard.lua) found no room beside it: told in a sentence of its
-- own after the rest, in the timeline's words ("Two deaths, to a Sunscale
-- Lashtail. Grisha mercilessly watched you die."). With the card beside
-- the plate the words say nothing of them; the creature the card names
-- is the caller's to leave out (`killer`, `foe`), as with the killer's.
-- `camped` (optional): the plate's campfire slip ("sat by a campfire",
-- UI/CampfireSlip.lua) found no room in the margin, so the words say it,
-- last of everything and as short as the rest of the list (", and a
-- campfire"), or lead where nothing else does ("By a campfire in Lushwater
-- Oasis."). With the slip beside the plate the words say nothing of it,
-- but where the fire is all there is they name its place ("Lushwater
-- Oasis.") for the slip to finish.
function Text.PlateCaption(plate, began, named, killer, shown, foe, hunted, lucky, witness, camped)
    named = named or {}
    shown = shown or {}
    local function Shown(m) return shown[m] or (m.find ~= nil and shown[m.find]) or false end
    local someone = named.someone or 0
    local of, deaths, people, strangers, company, finds = {}, 0, {}, {}, nil, {}
    local calls, hunts, fortunes, finales, caps, fires = {}, {}, {}, {}, {}, {}
    for _, m in ipairs(plate.moments) do
        if m.kind == "campfire" and m.campfire then fires[#fires + 1] = m.campfire end
        of[m.kind] = of[m.kind] or m
        if m.kind == "death" then deaths = deaths + 1 end
        if m.kind == "find" then finds[#finds + 1] = m end
        if m.kind == "close" and m.call then calls[#calls + 1] = m.call end
        if m.kind == "luck" and m.hunt and m.hunt ~= hunted then hunts[#hunts + 1] = m.hunt end
        if m.kind == "fortune" and m.hunt then fortunes[#fortunes + 1] = m.hunt end
        if m.kind == "finale" and m.finale then finales[#finales + 1] = m.finale end
        if m.kind == "skill" and m.cap then caps[#caps + 1] = m.cap end
        if (m.kind == "session" or m.kind == "note" or m.kind == "first" or m.kind == "fight") then
            if m.guid and ns.Diary.IsDiary(m.guid) then
                local name = Short(m.guid)
                if named[m.guid] then
                    company = company or m.kind
                elseif name and not people[name] then
                    people[name] = true
                    people[#people + 1] = name
                end
            elseif m.kind == "fight" then
                if (m.guid and named[m.guid]) or (not m.guid and someone > 0) then
                    if not m.guid then someone = someone - 1 end
                    company = company or "fight"
                else
                    strangers[#strangers + 1] = m
                end
            end
        end
    end

    local function Died()
        return Deaths(deaths) .. (killer and (", to " .. killer) or "")
    end
    -- A first in a few words: "a first bag", "a first bag from Koko" when
    -- Koko gave it and no margin note of hers says so already. The second
    -- value: whether who gave it is said, here or on her note.
    local function Found(m)
        local text = FindWords(m.what)
        local giver = m.gift and Giver(m.find or m)
        if m.gift and Shown(m) then return text, true end
        if giver and named[giver] then return text, true end
        if giver and ns.Diary.IsDiary(giver) then return text .. " from " .. Short(giver), true end
        return text, false
    end
    -- The close calls and the hunts in a few words each: "a close call",
    -- "a close call with a Plainstrider" (its creature's card is not beside
    -- the plate, so its name is still written somewhere), "two close
    -- calls"; "31 Plainstriders for 7 Plainstrider Meat", "two slow hunts".
    local function Calls()
        if #calls == 1 then
            local name = not foe and Text.KillerName(calls[1])
            return name and ("a close call with " .. name) or "a close call"
        end
        return (NUMBER[#calls] or tostring(#calls)) .. " close calls"
    end
    local function Hunted()
        return #hunts == 1 and Text.HuntLine(hunts[1]) or ((NUMBER[#hunts] or tostring(#hunts)) .. " slow hunts")
    end
    -- The good luck in a few words each, a list: "4 Plainstriders for 7
    -- Plainstrider Meat, 54 fewer than expected", "two lucky hunts"; with
    -- its card beside the plate, the rest counted ("another lucky hunt"),
    -- and on its print the item and who dropped it first.
    local function Lucky()
        local told = lucky and lucky.hunt
        if not told then
            if #fortunes == 0 then return {} end
            return { #fortunes == 1 and Text.HuntLine(fortunes[1])
                or ((NUMBER[#fortunes] or tostring(#fortunes)) .. " lucky hunts") }
        end
        local said, more = {}, 0
        for _, hunt in ipairs(fortunes) do
            if hunt ~= told then more = more + 1 end
        end
        if lucky.print then said[1] = Text.LuckyCaption(told) end
        if more == 1 then
            said[#said + 1] = "another lucky hunt"
        elseif more > 1 then
            said[#said + 1] = (NUMBER[more] or tostring(more)) .. " more lucky hunts"
        end
        return said
    end
    local luckyWords = Lucky()
    -- The campfires, where their slip had no room: "a campfire", sat by
    -- once or more at one place; "campfires" at several. As short as the
    -- deaths and close calls beside them: FL's print has two lines for its
    -- words (14 Oct, rasterised: "and a rest by a campfire" ran a third
    -- line past the page's foot). Where they were: the subzone they share,
    -- if it is not the zone's own name.
    local camping, told = camped and #fires > 0, false
    local function Camped()
        told = true
        if #fires == 1 or Text.CampfireAt(fires) then return "a campfire" end
        return "campfires"
    end
    local spot = #fires > 0 and Text.CampfireAt(fires, MapName(plate.mapID)) or nil
    -- A chain's end (JRN-28): "the end of “Crown of the Earth”"; "two
    -- chains finished".
    local function Ended()
        return #finales == 1 and Text.FinaleWords(finales[1])
            or ((NUMBER[#finales] or tostring(#finales)) .. " chains finished")
    end
    -- The professions brought to their cap (JRN-29): "First Aid at 75";
    -- one profession twice, "First Aid at 75, then 150"; several, "two
    -- professions at their cap".
    local function Capped()
        local trades, seen = 0, {}
        for _, cap in ipairs(caps) do
            local key = cap.skillLine or cap.name or cap
            if not seen[key] then seen[key], trades = true, trades + 1 end
        end
        if trades > 1 then return (NUMBER[trades] or tostring(trades)) .. " professions at their cap" end
        local text = Text.SkillWords(caps[1])
        for k = 2, #caps do text = text .. ", then " .. (caps[k].rank or "its cap") end
        return text
    end
    -- What else happened there, after the lead: ", and a death", ", a
    -- first bag, and two deaths", ", a death, and a close call". `skip`
    -- leaves off what the lead said: true (the finds), or { finds, finales,
    -- skills, deaths, calls, hunts, fortunes }; a lead of good luck says the
    -- rest of it last (`after`).
    local function Also(text, skip, after)
        skip = skip == true and { finds = true } or skip or {}
        local tail = {}
        if not skip.finds then
            for _, m in ipairs(finds) do tail[#tail + 1] = Found(m) end
        end
        if #finales > 0 and not skip.finales then tail[#tail + 1] = Ended() end
        if #caps > 0 and not skip.skills then tail[#tail + 1] = Capped() end
        if deaths > 0 and not skip.deaths then tail[#tail + 1] = Died() end
        if #calls > 0 and not skip.calls then tail[#tail + 1] = Calls() end
        if #hunts > 0 and not skip.hunts then tail[#tail + 1] = Hunted() end
        if not skip.fortunes then
            for _, words in ipairs(luckyWords) do tail[#tail + 1] = words end
        end
        for _, words in ipairs(after or {}) do tail[#tail + 1] = words end
        if camping and not told then tail[#tail + 1] = Camped() end
        if #tail == 0 then return text end
        if #tail == 1 then return text .. ", and " .. tail[1] end
        return text .. ", " .. table.concat(tail, ", ", 1, #tail - 1) .. ", and " .. tail[#tail]
    end
    local text
    if #people > 0 then
        text = Also("With " .. List(people, { max = 3, shown = 2, more = "others" }))
    elseif #finds > 0 then
        local m = finds[1]
        local name = #finds == 1 and deaths == 0 and not m.gift and not Shown(m) and ItemName((m.find or m).link)
        local words = {}
        for _, f in ipairs(finds) do words[#words + 1] = Found(f) end
        text = Capital(List(words)) .. (name and (": " .. name) or "")
        if #finds == 1 and m.gift and not select(2, Found(m)) then text = text .. ", a gift" end
        text = Also(text, true)
    elseif #finales > 0 then
        text = Also(Capital(Ended()), { finales = true })
    elseif #caps > 0 then
        text = Also(Capital(Capped()), { finales = true, skills = true })
    elseif #strangers > 0 then
        text = #strangers == 1 and ("A fight, " .. (strangers[1].outcome == "won" and "won" or "lost"))
            or (Capital(NUMBER[#strangers] or tostring(#strangers)) .. " fights")
        text = Also(text, { finds = true, finales = true, skills = true, deaths = true })
    elseif deaths > 0 then
        text = Also(Capital(Died()), { finds = true, finales = true, skills = true, deaths = true })
    elseif #calls > 0 then
        -- A lone close call is told whole, its creature named unless its
        -- card is beside the plate; more are counted.
        if #calls == 1 then
            text = foe and "A close call" or Text.CloseCall(calls[1]):sub(1, -2)
        else
            text = Capital(Calls())
        end
        text = Also(text, { finds = true, finales = true, skills = true, deaths = true, calls = true })
    elseif #hunts > 0 then
        text = Also(Capital(Hunted()), { finds = true, finales = true, skills = true, deaths = true, calls = true,
            hunts = true })
    elseif #luckyWords > 0 then
        local rest = {}
        for k = 2, #luckyWords do rest[#rest + 1] = luckyWords[k] end
        text = Also(Capital(luckyWords[1]), { finds = true, finales = true, skills = true, deaths = true, calls = true,
            hunts = true, fortunes = true }, rest)
    elseif of.arrive then
        if began and of.arrive.t <= began then
            text = "Where the diary began"
        else
            text = "Into " .. (MapName(plate.mapID) or "a new zone") .. " for the first time"
        end
    elseif of.dungeon then
        text = "The way into " .. (of.dungeon.name or "a dungeon")
    elseif of.stay then
        local seg = of.stay.seg
        text = seg.subZone and seg.subZone ~= MapName(seg.mapID) and seg.subZone or "A long stay"
        text = text .. ", " .. Duration(of.stay.seconds or seg.seconds or 0)
    elseif company == "fight" then
        text = "Where the fighting was"
    elseif company then
        text = "In good company"
    elseif of.campfire and camping then
        text = "By " .. Camped() .. (spot and (" in " .. spot) or "")
    elseif of.campfire and spot then
        text = spot
    elseif of.level then
        text = "Level " .. of.level.level
    else
        text = "On the road"
    end
    -- A lead with nothing after it (a first visit, a stay, ...) takes the
    -- campfire on as the only thing more.
    if camping and not told then text = text .. ", and " .. Camped() end
    return text .. "." .. (witness and (" " .. Text.WitnessCaption(witness)) or "")
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
    -- A gift first (JRN-24): a strip keeps STRIP.lines lines and cuts the
    -- rest, and the gift is what this person is remembered by here.
    for _, m in ipairs(moments) do
        if m.kind == "find" and m.gift then
            local _, yours = FindWords(m.what)
            parts[#parts + 1] = "gave you " .. Glue(yours)
        end
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

-- The killer card (UI/KillerCard.lua): what the creature did, under its
-- name: "killed you", "killed you twice", "killed you three times", held
-- together as a margin note's phrases are.
function Text.Killed(n)
    n = n or 1
    if n == 1 then return Glue("killed you") end
    if n == 2 then return Glue("killed you twice") end
    return Glue("killed you " .. (NUMBER[n] or tostring(n)) .. " times")
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

-- A creature's rank, as a tooltip says it.
local RANK = { elite = "Elite", rare = "Rare", rareelite = "Rare elite", worldboss = "Boss" }

-- What the world killed you with (the death recap's environmental kinds).
local WORLD = { FALLING = "A fall", DROWNING = "Drowned", FATIGUE = "Exhaustion", FIRE = "Fire", LAVA = "Lava",
    SLIME = "Slime" }

-- The killer card's tooltip: the creature's name, its rank, how often it
-- killed you on the plate and with what, and when it last did. A killer
-- the death recap never confirmed (`probable`) says so, quietly.
function Text.KillerTip(k, now)
    local lines = {}
    if RANK[k.rank] then lines[#lines + 1] = RANK[k.rank] end
    lines[#lines + 1] = Times(k.count or 1, "Killed you here", "Killed you here %s")
        .. (k.spell and (", with " .. k.spell) or "")
    if k.last then lines[#lines + 1] = "The last time " .. ns.UI.At(k.last, now) end
    if k.probable then lines[#lines + 1] = "As near as the diary could tell" end
    return k.name, lines
end

-- A death cross's tooltip on a plate: how many deaths it marks, then what
-- killed you there, each once, in the order it did ("Sunscale Lashtail,
-- with Bite, twice"; "A fall"). `deaths` are Journey.Deaths's records
-- matched to the cross; deaths from before they were kept have none, and
-- add only to the count.
function Text.DeathCross(count, deaths)
    local lines, at = {}, {}
    for _, d in ipairs(deaths or {}) do
        local key = d.name or (d.environment and ("world:" .. d.environment:upper()))
        if key then
            local line = at[key]
            if not line then
                line = { n = 0, name = d.name or WORLD[d.environment:upper()] or "The world" }
                at[key] = line
                lines[#lines + 1] = line
            end
            line.n = line.n + 1
            line.spell = d.spell or line.spell
        end
    end
    local out = {}
    for i, line in ipairs(lines) do
        out[i] = line.name .. (line.spell and (", with " .. line.spell) or "")
            .. (line.n == 2 and ", twice" or line.n > 2 and (", " .. line.n .. " times") or "")
    end
    return Times(math.max(count or 0, #(deaths or {}), 1), "Died here", "Died here %s"), out
end

--------------------------------------------------------------------------
-- Close calls and bad luck with a quest's drops (JRN-25, JRN-26)
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

-- A close call's creature in a sentence: "a Plainstrider", "Hogger", "a
-- Plainstrider and two others" (it was one of `foes` targeted); nil when
-- no creature was.
local function Foes(call)
    local name = Text.KillerName(call)
    if not name then return nil end
    local more = (call.foes or 1) - 1
    if more == 1 then return name .. " and another" end
    if more > 1 then return name .. " and " .. (NUMBER[more] or tostring(more)) .. " others" end
    return name
end

-- A close call in a sentence: "Got away from a Plainstrider with 6%
-- health.", or, no creature targeted, "Got out of a fight with 6%
-- health."
function Text.CloseCall(call)
    local foes = Foes(call)
    return (foes and ("Got away from " .. foes) or "Got out of a fight") .. " with " .. Health(call) .. "."
end

-- A close call's creature's level and rank, as its card's tag says them
-- (UI/KillerCard.lua): "Lv 45 (Elite)", "Lv ?? (Boss)" (a skull, -1),
-- "Lv 12" for a common creature, the rank alone where no level was kept
-- ("Elite"); nil with neither. The fight's length is never told: it said
-- nothing (11 Oct).
local TAG = { elite = "Elite", rare = "Rare", rareelite = "Rare Elite", worldboss = "Boss" }

function Text.FoeTag(call)
    local level = call and call.foeLevel
    local lv = level == -1 and "Lv ??" or (type(level) == "number" and level > 0 and ("Lv " .. level)) or nil
    local rank = call and TAG[call.rank]
    if lv and rank then return lv .. " (" .. rank .. ")" end
    return lv or rank
end

-- What a close call is called on the page: its card's heading in the
-- diary's hand (UI/KillerCard.lua), and its cross's tooltip's title, so
-- the card and the mark it points to read as one thing.
function Text.CloseHeading()
    return "A close call"
end

-- A close call's cross on a plate, for its tooltip: "A close call", then
-- what with, its level and rank, when.
function Text.CloseTip(call, now)
    local foes = Foes(call)
    local lines = { (call.pct or 0) .. "% health left" .. (foes and (", against " .. foes) or "") }
    if foes then lines[#lines + 1] = Text.FoeTag(call) end
    lines[#lines + 1] = When(call.t, call.level, now)
    return Text.CloseHeading(), lines
end

-- The card of the creature that nearly got you (UI/KillerCard.lua's
-- SetFoe): under its chart, how many it was against, "fought against
-- three"; "" against one ("fought" alone says nothing). And its tooltip.
function Text.CloseDeed(call)
    local foes = call.foes or 1
    if foes <= 1 then return "" end
    return "fought against " .. (NUMBER[foes] or tostring(foes))
end

function Text.FoeTip(call, now)
    local lines = { Text.FoeTag(call) }
    lines[#lines + 1] = "Left you with " .. (call.pct or 0) .. "% health"
    local more = (call.foes or 1) - 1
    if more > 0 then
        lines[#lines + 1] = more == 1 and "One more was in the fight"
            or (Capital(NUMBER[more] or tostring(more)) .. " more were in the fight")
    end
    lines[#lines + 1] = When(call.t, call.level, now)
    return call.name, lines
end

--------------------------------------------------------------------------
-- Witnesses to a death or a close call (Capture/Witnesses.lua)
--------------------------------------------------------------------------
--
-- The witness card (UI/WitnessCard.lua) in the margin words' register,
-- the timeline's own verbs (UI/TimelineText.lua) so the card and the
-- profile's row say the same thing: who (the subject, in the hand), what
-- they did (the hand), what it was against (small print). `w` is the
-- plate's witness (UI/KillerCard.lua's Witness).

-- Their first name, "Someone" where the buffer no longer has it.
function Text.WitnessName(w)
    return Short(w and w.guid) or "Someone"
end

-- How many more were there, after the name on the card's one line:
-- "& another", "& two others" (the user's words, 14 Oct); nil for none.
-- `prose`: as a sentence says it, "and another", "and two others".
function Text.WitnessOthers(n, prose)
    n = n or 0
    if n < 1 then return nil end
    local und = prose and "and" or "&"
    if n == 1 then return und .. " another" end
    return und .. " " .. (NUMBER[n] or tostring(n)) .. " others"
end

-- What the watching was, by how long (Witnesses.WATCHING): "saw" under
-- `saw` seconds, "merciless" from `merciless` on, else (or not timed, a
-- row from before) "watched". Nil for a helper.
function Text.WitnessLook(w)
    if not (w and w.type == "watched_death") then return nil end
    local W = ns.Witnesses and ns.Witnesses.WATCHING or { saw = 1.5, merciless = 5 }
    local s = w.watched
    if type(s) ~= "number" then return "watched" end
    if s < W.saw then return "saw" end
    if s >= W.merciless then return "merciless" end
    return "watched"
end

-- What they did, in the hand under their name: "mercilessly watched you
-- die", "watched you die", "saw you die", "tried to save you", "saved you".
-- The second value is the word the hand underlines (twice), if any.
function Text.WitnessDeed(w)
    local look = Text.WitnessLook(w)
    if look == "merciless" then return "mercilessly watched you die", "mercilessly" end
    if look == "saw" then return "saw you die" end
    if look then return "watched you die" end
    if w and w.type == "saved_you" then return "saved you" end
    return "tried to save you"
end

-- The creature, in small print under the deed: "to a Ragged Young Wolf"
-- (a death watched), "from Hogger" (a rescue, tried or not); nil where none
-- was kept.
function Text.WitnessFoe(w)
    local name = w and w.creature and Text.KillerName(w.creature)
    if not name then return nil end
    return (w.type == "watched_death" and "to " or "from ") .. name
end

-- The witness in a sentence of its own after the caption's, where the card
-- has no room: "Grisha mercilessly watched you die.", "Numa and another
-- tried to save you.", the timeline's verbs.
function Text.WitnessCaption(w)
    local who = Text.WitnessName(w)
    local others = Text.WitnessOthers(w and w.others, true)
    if others then who = who .. " " .. others end
    return who .. " " .. Text.WitnessDeed(w) .. "."
end

-- The card's tooltip: their full name, who they are, what they did (the
-- watching to a tenth of a second), whether they were alone, when.
function Text.WitnessTip(w, now)
    local record = ns.Characters.Get and ns.Characters.Get(w.guid) or nil
    local lines = {}
    if record then
        local who = {}
        if record.level then who[#who + 1] = "Level " .. record.level end
        who[#who + 1] = ns.UI.RaceName(record)
        who[#who + 1] = ns.UI.ClassName(record)
        if #who > 0 then lines[#lines + 1] = table.concat(who, " ") end
    end
    local look = Text.WitnessLook(w)
    if look then
        if type(w.watched) == "number" then
            lines[#lines + 1] = "Watched for " .. Glue(("%.1f seconds"):format(w.watched))
        end
        lines[#lines + 1] = "Not in a fight themselves"
    elseif w.type == "saved_you" then
        lines[#lines + 1] = "Joined your fight"
        lines[#lines + 1] = "You came out of it with " .. Health(w)
    else
        lines[#lines + 1] = "Joined the fight you died in"
    end
    local more = w.others or 0
    if more > 0 then
        lines[#lines + 1] = more == 1 and "One other was there too"
            or (Capital(NUMBER[more] or tostring(more)) .. " others were there too")
    end
    local at = w.death or w.call
    lines[#lines + 1] = When(w.t, at and at.level, now)
    return Who(w.guid) or Text.WitnessName(w), lines
end

-- Whether a hunt's kills were of more kinds than one (EXT-2).
local function Kinds(hunt)
    local n = 0
    for _ in pairs(hunt.byKind or {}) do n = n + 1 end
    return n
end

-- A hunt in a few words: "31 Plainstriders for 7 Plainstrider Meat"; "31
-- kills" when the creature has no name. Of several kinds, the one killed
-- most is named and the count is all of them: "31 Plainstriders and others
-- for 7 Plainstrider Meat" (12 Oct).
function Text.Hunt(hunt)
    local kills = hunt.kills or 0
    local what = hunt.name and hunt.name ~= "" and (kills == 1 and hunt.name or Plural(hunt.name))
        or (kills == 1 and "kill" or "kills")
    if Kinds(hunt) > 1 and hunt.name and hunt.name ~= "" then what = what .. " and others" end
    return Count(kills, what) .. " for " .. Items(hunt.need or 0, hunt.item or "them")
end

-- How far a hunt was from what the drop rates said (EXT-2, EXT-3): ", 14
-- more than expected", ", 54 fewer than expected"; "" where nothing was
-- expected, or it came out even.
function Text.Expected(hunt)
    if not hunt.expected then return "" end
    local off = math.floor((hunt.kills or 0) - hunt.expected + 0.5)
    if off == 0 then return "" end
    return ", " .. Count(math.abs(off), off > 0 and "more than expected" or "fewer than expected")
end

-- The hunt with it: "31 Plainstriders for 7 Plainstrider Meat, 14 more
-- than expected".
function Text.HuntLine(hunt)
    return Text.Hunt(hunt) .. Text.Expected(hunt)
end

-- A hunt's kinds, most killed first: { id, n, name }; empty with one kind.
local function SortedKinds(hunt)
    local kinds = {}
    if Kinds(hunt) <= 1 then return kinds end
    for npcID, k in pairs(hunt.byKind) do kinds[#kinds + 1] = { id = npcID, n = k.n or 0, name = k.name } end
    table.sort(kinds, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.id < b.id
    end)
    return kinds
end

-- `n` of a creature: "17 Sunscale Scytheclaws", "a kill" kept as "1 kill".
local function Killed(n, name)
    name = name and name ~= "" and (n == 1 and name or Plural(name)) or (n == 1 and "kill" or "kills")
    return Count(n, name)
end

-- Its mark's tooltip: the words, each kind's own kills where there were
-- several ("20 Plainstriders, 11 Elder Plainstriders"), the quest it was
-- for, when.
function Text.HuntTip(hunt, now)
    local lines = {}
    local kinds = SortedKinds(hunt)
    if #kinds > 0 then
        local parts = {}
        for _, k in ipairs(kinds) do parts[#parts + 1] = Killed(k.n, k.name) end
        lines[#lines + 1] = table.concat(parts, ", ")
    end
    if hunt.title and hunt.title ~= "" then lines[#lines + 1] = "For " .. hunt.title end
    lines[#lines + 1] = When(hunt.t, hunt.level, now)
    return Text.HuntLine(hunt), lines
end

-- The hunt card (UI/HuntCard.lua, JRN-26): bad luck written out in the
-- margin, its tally at length. Words for the card, the ledger's: figures,
-- "killed" said with each count so no number stands bare (12 Oct, the
-- user: "what does 36 mean?").
--
-- Its heading, in the hand: the item, as many as the quest wanted ("Intact
-- Raptor Horns", "Plainstrider Meat"; "Hezrul's Head" for one).
function Text.HuntItem(hunt)
    return ItemWord(hunt.need or 0, hunt.item or "?")
end

-- The figure at the tally's end, in the hand: "26", then "killed".
Text.HUNT_KILLED = "killed"

-- Under the stop rule, where the drop rates said it would end:
-- "expected 12" (to the whole kill, as Text.Expected rounds it).
function Text.HuntExpectedLabel(hunt)
    return "expected " .. math.floor((hunt.expected or 0) + 0.5)
end

-- The rows of a hunt without drop rates: its kills an item, "each", and
-- the character's usual, "usually"; past HuntCard's ROWS.most a figure
-- says it instead of strokes.
Text.HUNT_EACH, Text.HUNT_USUALLY = "each", "usually"

-- The lines under the tally, by kind, most killed first: with the drop
-- rates, "killed 17 Sunscale Scytheclaws", "killed 9 Sunscale Lashtails"
-- (one kind: its name alone, "Sunscale Scytheclaws", as the figure counts
-- them already); without, "killed 37 Defias Rogue Wizards for 6". Past
-- HUNT_KINDS kinds, the rest together, "killed 4 others". `short`: one
-- line, the kind most killed "and others" ("Sunscale Scytheclaws and
-- others"; without the rates, "killed 37 Defias Rogue Wizards and others
-- for 6"). A list, maybe empty.
local HUNT_KINDS = 3

function Text.HuntKills(hunt, short)
    local kills, need = hunt.kills or 0, hunt.need or 0
    local named = hunt.name and hunt.name ~= ""
    local kinds = SortedKinds(hunt)
    local rates = hunt.expected ~= nil
    -- "for 6" held together, as a count is.
    local function For(text) return rates and text or (text .. " " .. Count("for", need)) end
    if #kinds > 1 and not short then
        local lines = {}
        local shown = #kinds <= HUNT_KINDS and #kinds or HUNT_KINDS - 1
        for i = 1, shown do lines[i] = Text.HUNT_KILLED .. " " .. Killed(kinds[i].n, kinds[i].name) end
        if shown < #kinds then
            local rest = 0
            for i = shown + 1, #kinds do rest = rest + kinds[i].n end
            lines[#lines + 1] = Text.HUNT_KILLED .. " " .. Count(rest, rest == 1 and "other" or "others")
        end
        if not rates then lines[#lines] = For(lines[#lines]) end
        return lines
    end
    local others = #kinds > 1 and named
    if rates then
        if not named then return {} end
        return { Plural(hunt.name) .. (others and " and others" or "") }
    end
    local what = Killed(kills, named and hunt.name or nil) .. (others and " and others" or "")
    if not named then what = tostring(kills) end
    return { For(Text.HUNT_KILLED .. " " .. what) }
end

-- The card's tooltip: the mark's, and without the rates the usual it is
-- set against ("Usually 2 each"), when it was known.
function Text.HuntCardTip(hunt, now, usual)
    local title, lines = Text.HuntTip(hunt, now)
    if not hunt.expected and usual then
        table.insert(lines, #lines, "Usually " .. math.max(1, math.floor(usual + 0.5)) .. " each")
    end
    return title, lines
end

-- A hunt that was good luck in a sentence (EXT-3): "It took only 4
-- Plainstriders to get 7 Plainstrider Meat, 54 fewer than expected."; one
-- item off the first kill, "The first Plainstrider gave up its Sharptalon's
-- Claw, where 10 were expected."
function Text.Fortune(hunt)
    if hunt.kills == 1 and hunt.need == 1 and hunt.name and hunt.name ~= "" and Kinds(hunt) <= 1 then
        local expected = math.floor((hunt.expected or 0) + 0.5)
        return "The first " .. hunt.name .. " gave up its " .. (hunt.item or "drop") .. ", where "
            .. Count(expected, "were expected") .. "."
    end
    local words = Text.Hunt(hunt):gsub(" for ", " to get ", 1)
    return "It took only " .. words .. Text.Expected(hunt) .. "."
end

-- The lucky card (UI/LuckyCard.lua, JRN-27): good luck in the margin, the
-- drop tables' "expected 58" printed and scribbled out, and taped over it
-- a smaller slip in the diary's hand saying what happened instead. The
-- printed words are Text.HuntExpectedLabel's, as the bad-luck card's.
--
-- How soon it dropped, in the hand: "after just four", "after four";
-- off one kill, "on the first"; past ten a figure with its noun, so no
-- figure stands bare (12 Oct, the user: "what does 36 mean?"), "after
-- just 14 kills". `just` carries the surprise where there is room for it.
-- Returns the words and the count's own words (for the underline at S).
local function SoonWords(hunt, just)
    local kills = hunt.kills or 0
    if kills <= 1 then return "on the first", "first" end
    local count = kills <= 10 and WORDS[kills] or Count(kills, "kills")
    return (just and "after just " or "after ") .. count, count
end

-- The tag's lines for one of the card's forms (LuckyCard's FORMS): a list
-- of { text, under }, `under` the words the hand underlined in it.
--   XL      "dropped" / "after just four" (two lines, beside the struck words)
--   L       "dropped after just four"
--   M1      "dropped after four"
--   M2      "dropped" / "after four"
--   S       on a light plate's print: "after four", the count underlined
--   S-      the count alone, "four"; off one kill "the first"
-- One kill is "on the first" in every size but S-.
Text.LUCKY_DROPPED = "dropped"
local LUCKY_LINES = { XL = 2, L = 1, M1 = 1, M2 = 2, M2s = 2 }
local LUCKY_JUST = { XL = true, L = true }

function Text.LuckyTag(hunt, form)
    local soon, count = SoonWords(hunt, LUCKY_JUST[form])
    if form == "S" then return { { text = soon, under = count } } end
    if form == "S-" then
        if (hunt.kills or 0) <= 1 then return { { text = "the first", under = "first" } } end
        return { { text = count, under = count } }
    end
    local D = Text.LUCKY_DROPPED
    if LUCKY_LINES[form] == 2 then return { { text = D, under = D }, { text = soon } } end
    return { { text = D .. " " .. soon, under = D } }
end

-- Who dropped it, under the struck words at XL: "Kolkar Marauders", one
-- kill "Hezrul Bloodmark" (never "Hezrul Bloodmarks", as Text.HuntKills
-- would say it), several kinds "Sunscale Scytheclaws and others". Nil
-- where the creature has no name.
function Text.LuckyKind(hunt)
    if not (hunt.name and hunt.name ~= "") then return nil end
    local name = (hunt.kills or 0) == 1 and hunt.name or Plural(hunt.name)
    return Kinds(hunt) > 1 and (name .. " and others") or name
end

-- The caption's words while the luck is told on its print (the card's S,
-- which has no heading): the item and who dropped it, the numbers left to
-- the print. "7 Kolkar Booty Keys from Kolkar Marauders"; one item,
-- "Hezrul's Head from Hezrul Bloodmark"; nameless, the item alone.
function Text.LuckyCaption(hunt)
    local need, item = hunt.need or 0, hunt.item or "a drop"
    local what = need > 1 and Count(need, ItemWord(need, item)) or item
    local kind = Text.LuckyKind(hunt)
    return kind and (what .. " from " .. kind) or what
end

-- The level's close calls and luck in its prose: each close call, then
-- each hunt that was bad luck ("It took 31 Plainstriders to get 7
-- Plainstrider Meat, 14 more than expected."), then each that was good
-- (Text.Fortune), at most `most` of each, the rest counted. Nil with none.
local COMBAT = { most = 2 }

function Text.CombatLines(e)
    local parts = {}
    local calls, hunts = e.closeCalls or {}, e.hunts or {}
    for i = 1, math.min(#calls, COMBAT.most) do parts[#parts + 1] = Text.CloseCall(calls[i]) end
    local more = #calls - COMBAT.most
    if more > 0 then
        parts[#parts + 1] = more == 1 and "And one more close call." or ("And %s more close calls."):format(
            NUMBER[more] or tostring(more))
    end
    for i = 1, math.min(#hunts, COMBAT.most) do
        local h = hunts[i]
        local words = Text.Hunt(h):gsub(" for ", " to get ", 1)
        parts[#parts + 1] = "It took " .. words .. Text.Expected(h) .. "."
    end
    more = #hunts - COMBAT.most
    if more > 0 then
        parts[#parts + 1] = more == 1 and "And one more slow hunt." or ("And %s more slow hunts."):format(
            NUMBER[more] or tostring(more))
    end
    local fortunes = e.fortunes or {}
    for i = 1, math.min(#fortunes, COMBAT.most) do parts[#parts + 1] = Text.Fortune(fortunes[i]) end
    more = #fortunes - COMBAT.most
    if more > 0 then
        parts[#parts + 1] = more == 1 and "And one more lucky hunt." or ("And %s more lucky hunts."):format(
            NUMBER[more] or tostring(more))
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

--------------------------------------------------------------------------
-- Quest chain finales (JRN-28)
--------------------------------------------------------------------------

-- A quest's title as the diary quotes it: “Crown of the Earth”.
local function Quoted(title)
    return "\226\128\156" .. (title or "a quest") .. "\226\128\157"
end

-- A number of quests in words: "nine", "29".
local function Many(n)
    return WORDS[n] or tostring(n)
end

-- How long a chain took, as the prose says it: "three hours", "five
-- days", "three weeks", "two months".
local function Span(seconds)
    local days = seconds / ns.DAY
    if days < 1 then return Spoken(seconds) end
    local function Of(n, one, many)
        n = math.max(1, math.floor(n + 0.5))
        return n == 1 and one or (Many(n) .. " " .. many)
    end
    if days < 13.5 then return Of(days, "a day", "days") end
    if days < 60 then return Of(days / 7, "a week", "weeks") end
    return Of(days / 30, "a month", "months")
end

-- A finale in a few words, for a plate's caption: "the end of “Crown of
-- the Earth”".
function Text.FinaleWords(f)
    return "the end of " .. Quoted(f.title)
end

-- A finale in a sentence: "The end of “Crown of the Earth”, a chain of
-- nine begun in Shadowglen five days before." Where it began is said only
-- where the diary saw it begin.
function Text.Finale(f)
    local text = "The end of " .. Quoted(f.title)
    local n = f.n or 0
    if n > 1 then text = text .. ", a chain of " .. Many(n) end
    local start = f.started
    if start and start.t and f.t and n > 1 then
        local zone = MapName(start.mapID)
        text = text .. " begun" .. (zone and (" in " .. zone) or "") .. " " .. Span(f.t - start.t) .. " before"
    end
    return text .. "."
end

-- The level's finales in its prose, one sentence each.
function Text.FinaleLines(e)
    local parts = {}
    for _, f in ipairs(e.finales or {}) do parts[#parts + 1] = Text.Finale(f) end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

-- Its mark's tooltip: "The end of “Crown of the Earth”", then how long the
-- chain was, where and when it began, when it ended.
function Text.FinaleTip(f, now)
    local lines = {}
    if (f.n or 0) > 1 then lines[#lines + 1] = "A chain of " .. f.n .. " quests" end
    local start = f.started
    if start and start.t then
        local zone = MapName(start.mapID)
        lines[#lines + 1] = "Begun " .. (zone and ("in " .. zone .. ", ") or "") .. ns.UI.At(start.t, now)
    end
    lines[#lines + 1] = When(f.t, f.level, now)
    return Capital(Text.FinaleWords(f)), lines
end

--------------------------------------------------------------------------
-- Profession caps (JRN-29)
--------------------------------------------------------------------------

-- Who a cap is as far as the training goes: each rank's trainer's title,
-- with its article. Any other number (a cap the client adds later) is
-- told bare, without the clause.
local SKILL_RANK = { [75] = "an Apprentice", [150] = "a Journeyman", [225] = "an Expert", [300] = "an Artisan" }

-- The profession as the client called it, or "a profession" where it gave
-- no name.
local function Trade(cap)
    return cap.name and cap.name ~= "" and cap.name or "a profession"
end

-- The cap reached, as a number to say after "at": "75"; "its cap" where
-- the record has none.
local function Rank(cap)
    return cap.rank and tostring(cap.rank) or "its cap"
end

-- A cap in a few words, for a plate's caption: "First Aid at 75", "a
-- profession at 75".
function Text.SkillWords(cap)
    return Trade(cap) .. " at " .. Rank(cap)
end

-- How far the training goes, after a comma: "as far as an Apprentice
-- goes"; nil for a rank with no trainer's title.
local function AsFar(cap)
    local who = SKILL_RANK[cap.rank]
    return who and ("as far as " .. who .. " goes") or nil
end

-- A cap in a sentence: "First Aid reached 75, as far as an Apprentice
-- goes." The same profession again straight after only counts on: "Then
-- 150, as far as a Journeyman goes."
function Text.Skill(cap, before)
    local again = before and (before.skillLine or before.name) == (cap.skillLine or cap.name)
        and (cap.skillLine or cap.name) ~= nil
    local text = again and ("Then " .. Rank(cap)) or (Capital(Trade(cap)) .. " reached " .. Rank(cap))
    local far = AsFar(cap)
    return text .. (far and (", " .. far) or "") .. "."
end

-- The level's caps in its prose, one sentence each.
function Text.SkillLines(e)
    local parts, before = {}, nil
    for _, cap in ipairs(e.skillCaps or {}) do
        parts[#parts + 1] = Text.Skill(cap, before)
        before = cap
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

-- Its mark's tooltip: "First Aid at 75", then how far the training goes
-- ("As far as an Apprentice goes"), then when.
function Text.SkillTip(cap, now)
    local lines = {}
    local far = AsFar(cap)
    if far then lines[#lines + 1] = Capital(far) end
    lines[#lines + 1] = When(cap.t, cap.level, now)
    return Capital(Text.SkillWords(cap)), lines
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
-- Campfires (WoW Forever's camps, Capture/Campfire.lua)
--------------------------------------------------------------------------

-- The margin's slip for a campfire on a plate (UI/CampfireSlip.lua): the
-- user's own words (14 Oct), exactly, lower case and all, however many
-- fires the plate has. Not to be reworded.
Text.CAMPFIRE_SLIP = "sat by a campfire"

-- The subzone a plate's campfires (records { t, subZone, ... }) all share,
-- or nil where they differ, where one has none, or where it is only the
-- zone's own name (`zone`).
function Text.CampfireAt(fires, zone)
    local at
    for _, fire in ipairs(fires) do
        local sub = fire.subZone
        if type(sub) ~= "string" or sub == "" or (at and sub ~= at) then return nil end
        at = sub
    end
    if at == zone then return nil end
    return at
end

-- The fire's mark and its slip, under the mouse: "Sat by a campfire", then
-- where ("In Lushwater Oasis", where there is a subzone that is not the
-- zone's name) and when ("Yesterday, 21:40, at level 12").
function Text.CampfireTip(fire, now)
    local lines = {}
    local sub = fire.subZone
    if type(sub) == "string" and sub ~= "" and sub ~= MapName(fire.mapID) then lines[#lines + 1] = "In " .. sub end
    local j = ns.Journey.For and ns.Journey.For(ns.ownGUID)
    local level = j and ns.JourneyRecap and ns.JourneyRecap.LevelAt(j, fire.t or 0) or nil
    lines[#lines + 1] = When(fire.t or 0, level, now)
    return Capital(Text.CAMPFIRE_SLIP), lines
end
