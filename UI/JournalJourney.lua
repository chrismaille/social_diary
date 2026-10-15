-- Your Diary's start page (JRN-11, JRN-13, JRN-15, JRN-16, JRN-21 to
-- JRN-23): the logged-in character's own road, the journal's first
-- section, in front of People.
--
-- The left page is the character's: their name in capitals like the
-- bookplate's (UI/JournalFront.lua), who they are and their level, then
-- the recap, oldest first, one entry per level (one per week after the
-- cap). Each entry is rubricated like a day on the timeline ("LEVEL 12",
-- "so far" beside the one being played), with the faces of the people from
-- the diary crossed at it at the rubric's end: class circles, a rival's
-- ringed in rubric (JRN-22). One level is open at a time, the newest as
-- the diary falls open; the others are their rubric alone, a contents
-- line to open them by. The open one reads in three levels: the rubric,
-- then its prose in the diary's own words (UI/JourneyText.lua), each name
-- a way to their page, the player's own note quoted in their hand, any
-- first sighting written in later, in hindsight, in the diary's hand
-- (JRN-23); then a ledger of the zones it was spent in, small, with dot
-- leaders out to their times and a dungeon's doorway in the margin
-- (JRN-15: the zone index's rows, now where they happened). An honest
-- line about where the diary began goes before them all (JRN-13).
--
-- The right page shows where the open level happened (JRN-21): up to three
-- close-up plates of map glued in (UI/JourneyPlate.lua), from any zone,
-- each captioned in a few words and with the people met there written in
-- the margin, a pencil leader from each name to their mark (JRN-22).
-- Clicking a plate or a zone row shows that zone's whole map as one plate
-- across the page (JRN-14), the open level only (other levels' roads and
-- marks are left off), with a line under it and the way back. A rubric goes
-- back to its level's plates.
--
-- The left page's list is virtual (ns.UI.VirtualList): an item per rubric,
-- paragraph and zone, each paragraph measured once to its own height, so
-- the frame count stays fixed however long the road grows. The right page
-- keeps three plates and hands them out to the slots each layout needs.
--
-- With nothing on the road yet, the page teaches what will be there, in
-- the style of the empty People page (UI/JournalEmpty.lua): a word on why
-- it is empty (the setting off, or nothing walked yet), a pencilled sample
-- entry, and a pencilled plate with notes in the margin. It is a recap,
-- never a tracker: nothing here counts quests, shows a bar or keeps a score.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local Text = ns.UI.JourneyText
local Plate = ns.UI.JourneyPlate

local BOOK = ns.UI.JOURNAL
local LEFT_X, LEFT_W, RIGHT_X, RIGHT_W = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.RIGHT_X, BOOK.RIGHT_W
local BOOK_H, LIST_BAR, TOP = BOOK.BOOK_H, BOOK.LIST_BAR, BOOK.TOP
local SCROLLBAR_WIDTH = ns.UI.SCROLLBAR_WIDTH

-- The character at the top of the left page, down from the page's top:
-- the name, who they are, the short rule under them, and where the
-- entries begin. The entries stop `bottom` short of the page's foot, clear
-- of the ribbons hanging there.
local HEAD = { name = 22, who = 54, rule = 76, ruleW = 60, list = 90, bottom = 34 }
-- An entry: the rubric's paraph hangs in the margin and text lines up with
-- the rubric's words (`indent`); `leading` between lines, `para` under a
-- paragraph, `later` under a line written in hindsight, `title` the open
-- rubric's row, `zone` a zone's row, `prologue` under the opening line.
-- Closed rubrics are a contents list, set close: each a `closed` row, its
-- words `closedBase` px up from its foot (`base` on the open rubric's),
-- one under another with no gap; the open entry stands apart, `open` px
-- above its rubric and `after` px under its last row. The rubric's rule is
-- red at `ruleAlpha`, `ruleHot` under the mouse. The list is built with
-- `rows` rows of `unit` height each, and shows as many as fit.
-- (10 Oct, in the client: at 8 + 22 a closed rubric, six of them filled
-- the page above the open entry. A rival's ring is 20 px across, so two
-- rivals' faces in rubrics one under the other just touch at 19.)
--
-- Paragraphs are set apart by a clear gap, as a printed diary does (no
-- first-line indent: WoW's font strings have none to give): `para` is
-- well over the `leading`, so a new paragraph never reads as a wrapped
-- line. `more` is the small gap under a quoted note to its "And one more
-- note."; `ledger` the gap over the zone rows.
local ENTRY = { indent = 13, leading = 3, para = 10, later = 6, more = 2, title = 22, base = 6, closed = 19,
    closedBase = 4, open = 12, after = 12, zone = 17, ledger = 6, prologue = 10, unit = 17, rows = 48, paraph = 6,
    rule = 6, ruleAlpha = 0.40, ruleHot = 0.70 }
-- The ledger under the open entry (JRN-15): each zone in small type in
-- ink, a run of `dot` leaders (a font string of them, as many as the gap
-- between the name and its time holds, measured, and set flush right so
-- the dots line up down the column) `gap` px clear of both, and the time
-- at the right in faded ink, `right` px in from the row's end. A name
-- never takes more than `nameMax` of the row. The dots are ink at
-- `dotAlpha`. A dungeon's row has a doorway in the margin where a
-- rubric's paraph hangs: the plates' arch (UI/JourneyPlate.lua's DOOR, a
-- round head on a square body), `size` px, in `ink` at `alpha`. In ink, not
-- rubric: small and red, it read as a level's pin.
-- (10 Oct, in the client: two posts and a lintel in red read as "⊓", a
-- missing glyph.)
-- Under the mouse a zone's row is marked as a reader marks a line, never
-- lit: its name inked darker (INK_STRONG) and a pencil line under it,
-- `mark`: graphite in `colour` at `alpha`, `width` px, `under` px below the
-- name, as long as the name; under the line a `lip` of light at
-- `lipAlpha`, the lower side of the groove the pencil pressed, which faces
-- the top-left light. While its map is the one on the right page the line
-- is in ink (INK_STRONG at `inkAlpha`) and stays. Laid flat, no lip.
-- (10 Oct, in the client: a flat tan rectangle under the mouse was the most
-- screen-like thing left on the page.)
local LEDGER = { dot = " .", gap = 4, right = 4, nameMax = 0.72, dotAlpha = 0.55,
    door = { size = 9, ink = Style.INK_STRONG, alpha = 0.85 },
    mark = { colour = Style.GRAPHITE, alpha = 0.60, width = 1, under = 0, lip = { 1, 0.97, 0.88 }, lipAlpha = 0.22,
        inkAlpha = 0.70 } }
local PARAPHS = { Style.LAPIS, Style.RUBRIC }
-- The faces at a rubric's end (JRN-22): at most `most` class circles
-- (UI-Classes-Circles) `size` px, `gap` apart, then "+n"; each on a dark
-- edge `edge` px wider, a rival's in a rubric ring `ring` px wider still.
local FACES = { most = 4, size = 13, gap = 4, edge = 2, ring = 5, ringAlpha = 0.85 }

-- The right page, measured from its top left (RIGHT_X, TOP), as the
-- mockup's (.claude/ui-proposal/journey-moments-mockup.html): the plates'
-- slots for one, two and three places. Each: where (x, y), how big, its
-- turn in degrees (clockwise), the card's margin round the art (`pad`),
-- its photo corners' size (`pc`) and which corners, the corner come
-- unstuck (`lift`), its caption's box (and how far down its notes may
-- go, `limit`, where another plate lies below), and where its margin
-- notes go when not under the caption (`notes`). A caption to the left of
-- its plate is set flush right (`align`), its notes too, so both lean on
-- the plate they belong to instead of floating at the page's edge.
-- The plates take the whole page, as an album's photographs do: the top
-- one is glued a little above the right page's own top (the paper runs
-- 20 px higher, so its corners still stand clear of the book's edge),
-- and the lowest goes down to the foot, as far as the not-kept line in
-- the right column lets it (OFF). Of three, the second stands tall beside
-- the first, in the room under the first's caption, so that the column at
-- its left, under the first plate, is wide and runs from just under it
-- to just over the third: room for the caption, a strip and a close
-- call's card (11 Oct, in the client: at 136 by 206 px, Feivel's strip
-- took the last of it and the card for what nearly got you was left
-- off). That column is what the first and third plates gave height for,
-- and the first gave the second width: no less than 192 px, as the
-- narrowest art of a layout is the window its places are grouped by
-- (SMALLEST), and narrower lost a stay from a plate. Of two, the first
-- gives its caption 176 px: a close call's card names its creature on one
-- line in the hand (14 px at the smaller size) with its level's tag over
-- it, and a long name ("Razormane Battleguard", or longer, near 26
-- letters) needs that much (11 Oct: at 136 px the card was left off).
-- One plate whose caption is short (its heading and a line of words) has
-- the caption over it instead (`top`, the user's wish, 11 Oct), written
-- across the page, and the plate a little lower and shorter, so the page
-- under it holds its notes in a `row` of three, side by side, each with
-- room for a close call's card and its picture (about 125 px with its
-- heading and tag, the picture drawn small). Its leaders then go up into the plate and never through the
-- words. The plate's corner comes as near the words as a plate comes to
-- its caption elsewhere, about 9 px (12 Oct, in the client: at 48 the gap
-- was some 20 px, the words shorter than measured here). It is not one of
-- the layout's slots: the one plate's places are grouped by the taller
-- plate (SMALLEST), and the shorter still holds them, as a plate's moments
-- span at most PLATES.inset (0.8) of its window (Core/JourneyRecap.lua):
-- 275 px of 344, inside its 323.
local RIGHT_H = 534
local FOUR = { "tl", "tr", "bl", "br" }
local LOST = { "tl", "tr", "bl" }
local LAYOUT = {
    { { x = 10, y = 0, w = 444, h = 364, t = -1.2, pad = 10, pc = 28, corners = LOST, lift = "br",
        cap = { x = 16, y = 382, w = 260 }, notes = { x = 300, y = 378, w = 150 },
        top = { x = 10, y = 37, w = 444, h = 343, t = -1.2, pad = 10, pc = 28, corners = LOST, lift = "br",
            cap = { x = 16, y = -2, w = 434 },
            row = { { x = 10, y = 400, w = 142 }, { x = 160, y = 400, w = 142 }, { x = 310, y = 400, w = 142 } } } } },
    { { x = 8, y = -2, w = 260, h = 236, t = -1.4, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 18, w = 176, limit = 240 } },
        { x = 150, y = 254, w = 300, h = 236, t = 1.8, pad = 8, pc = 24, corners = LOST, lift = "br",
            cap = { x = 12, y = 268, w = 122, align = "RIGHT" } } },
    { { x = 8, y = -2, w = 242, h = 176, t = -1.3, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 264, y = 16, w = 194, limit = 132 } },
        { x = 264, y = 150, w = 192, h = 234, t = 2.2, pad = 7, pc = 22, corners = LOST, lift = "br",
            cap = { x = 12, y = 184, w = 232, limit = 390, align = "RIGHT" } },
        { x = 8, y = 404, w = 228, h = 126, t = 1.6, pad = 7, pc = 20, corners = {}, lift = "bl",
            cap = { x = 252, y = 406, w = 204 } } },
}
-- Weighed pages (.claude/ui-proposal/plate-weight-proposal.md, 13 Oct): a
-- page is also keyed by its plates' weights in time order, F a full plate
-- and L a light one (Core/JourneyRecap.lua's LIGHT: a place and a line of
-- words, nothing for the margin), so a first visit with a level's pin no
-- longer takes the larger slot while the plate beside it, with people, a
-- close call and a hunt, loses its margin to a narrow column (13 Oct, in
-- the client: Stormwind in 300 by 236 for a first visit and a pin;
-- Elwynn's column 176 by 222, two of its three notes left off). A light
-- plate is a small print, a snapshot (Snap): 176 by 124, its art 162 by
-- 110, its caption beside it (flush right on its left) or under it. A full
-- plate's caption is 176 px wide, as a snapshot is, so a page has two
-- widths: a 260 px column of plates and a 176 px one of words or a print.
-- Plates stay in time order down the page, as a heading counts on from
-- the plate before ("Twenty minutes later"; the user's choice, 13 Oct).
-- The album's rules hold on each: every slot turns; one corner come
-- unstuck, `br`, on a lower print; FOUR on the others; nothing nearer the
-- page's edge than 8 px, or 10 on a lifted side; and a light caption right
-- of the not-kept line (OFF, x 246) ends above it. The proposal's
-- geometry, but where its pages, laid out with the plates' real shadows
-- and photo corners (13 Oct, rasterised from the mock), had prints
-- touching: FFL's print 6 px further left and 2 up, its second plate 4 px
-- narrower, so the two no longer meet at their corners and the print's
-- lifted shadow stays on the page; LFF's second plate 4 px lower and
-- shorter, clear of the print over it, and its third 2 px narrower, its
-- lifted corner 10 px in from the page's edge after its turn. And as the
-- lowest plate of three keeps clear of the not-kept line (OFF), FLF's
-- third plate is 156 px tall (the proposal's 180) and LFF's 154 (174),
-- so neither lies over it with the setting off; both still hold the
-- three-plate window (SMALLEST) with room (13 Oct, rasterised again).
-- Only FL, LF, FLF, FFL, LFF and LFL have a page of their own (the
-- user's choice, 13 Oct). Any other pattern (FF, LL, FFF, FLL, LLF,
-- LLL) is the page above for that many plates, as before, and so is one
-- plate alone, light or not (with its `top`).
local function Snap(x, y, t, corners, lift, cap)
    return { x = x, y = y, w = 176, h = 124, t = t, pad = 7, pc = 18, corners = corners, lift = lift, cap = cap,
        light = true }
end
-- The print a light plate must fit to be drawn light (LayoutFor).
local SNAPSHOT = Snap(0, 0, 0, {})
-- A light plate's filler note (a margin kind with `filler`) goes under
-- its print's caption where there is room (LF, LFF, LFL, FLF; FFL with
-- the route kept). Under FL's print (its caption from y 474) and often
-- F+L's tucked one there is none: the note is left off there and the
-- caption's words say it. The layouts stay as they are for filler, never
-- FL turned FF for it (the user's choice, 14 Oct).
LAYOUT.FL = { { x = 8, y = -2, w = 260, h = 318, t = -1.4, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 18, w = 176, limit = 528 } },
    Snap(40, 336, 2.2, LOST, "br", { x = 42, y = 474, w = 200, limit = 528 }) }
LAYOUT.LF = { Snap(272, 4, 2.0, FOUR, nil, { x = 12, y = 28, w = 246, limit = 136, align = "RIGHT" }),
    { x = 8, y = 144, w = 260, h = 334, t = -1.2, pad = 8, pc = 24, corners = LOST, lift = "br",
        cap = { x = 282, y = 162, w = 176, limit = 528 } } }
LAYOUT.FFL = { { x = 8, y = -2, w = 260, h = 198, t = -1.3, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 18, w = 176, limit = 250 } },
    { x = 200, y = 264, w = 256, h = 158, t = 1.2, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 10, y = 214, w = 176, limit = 384, align = "RIGHT" } },
    Snap(8, 396, 1.6, LOST, "br", { x = 206, y = 432, w = 252, limit = 528 }) }
LAYOUT.FLF = { { x = 8, y = -2, w = 260, h = 196, t = -1.3, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 18, w = 176, limit = 204 } },
    Snap(280, 212, 2.0, LOST, "br", { x = 12, y = 232, w = 252, limit = 330, align = "RIGHT" }),
    { x = 8, y = 344, w = 260, h = 156, t = 1.2, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 354, w = 176, limit = 528 } } }
LAYOUT.LFF = { Snap(14, 4, -2.0, FOUR, nil, { x = 206, y = 26, w = 252, limit = 132 }),
    { x = 8, y = 144, w = 260, h = 188, t = 1.2, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 160, w = 176, limit = 340 } },
    { x = 196, y = 346, w = 258, h = 154, t = -1.0, pad = 8, pc = 24, corners = LOST, lift = "br",
        cap = { x = 10, y = 362, w = 176, limit = 528, align = "RIGHT" } } }
LAYOUT.LFL = { Snap(272, 4, 2.0, FOUR, nil, { x = 12, y = 26, w = 248, limit = 132, align = "RIGHT" }),
    { x = 8, y = 140, w = 260, h = 226, t = -1.2, pad = 8, pc = 24, corners = FOUR,
        cap = { x = 282, y = 156, w = 176, limit = 392 } },
    Snap(22, 392, 1.6, LOST, "br", { x = 214, y = 412, w = 244, limit = 528 }) }
-- FL may instead be the one plate's page with the light plate's print
-- tucked in (`tucked`, F+L, the proposal mockup's TUCKED, which it turned
-- down as the default; the user wants it as an option, 13 Oct): the full
-- plate under its caption written across the page, as `top`, its notes in
-- a `row` of two, and in the row's third place the print, smaller (140 by
-- 100, its art 128 by 88), its caption under it. It is tried first and
-- kept only where nothing is lost by it (DrawPlates): its caption short,
-- as `top`'s; all of its margin in the row (`whole`); and both plates
-- held by their windows here. The full plate is as high as `top`'s, its
-- corner as near the words (12 Oct, in the client), and 278 px tall (the
-- mockup's 292 less 14), so the row and the print sit 31 px higher than the
-- mockup's: the print's caption, 148 px wide, has room for three lines of
-- words (a zone's name alone over them, the day moved into the words)
-- and ends above the not-kept line, as every caption right of it does
-- (at 284 px three lines ran down onto it; 13 Oct, rasterised from the
-- mock), and its lifted corner lies 14 px
-- in from the page's edge, its shadow (9.9 px at most,
-- UI/JourneyPlate.lua's SHADOW) inside the page's margin and clear of the
-- caption under it.
LAYOUT["F+L"] = { { x = 10, y = 37, w = 444, h = 278, t = -1.2, pad = 10, pc = 28, corners = FOUR,
        cap = { x = 16, y = -2, w = 434 }, row = { { x = 10, y = 333, w = 142 }, { x = 160, y = 333, w = 142 } },
        whole = true },
    { x = 314, y = 329, w = 140, h = 100, t = 2.0, pad = 6, pc = 16, corners = LOST, lift = "br",
        cap = { x = 312, y = 442, w = 148 }, light = true } }
LAYOUT.FL.tucked = LAYOUT["F+L"]
-- The full page: one plate, the zone's whole height (JRN-14).
local FULL = { x = 10, y = 8, w = 446, h = 484, t = 1.0, pad = 10, pc = 28, corners = LOST, lift = "br" }
-- A caption, as under a photograph in an album: one line by hand in ink,
-- "The Barrens, yesterday" (FONT.noteWritten), at the first of the `hand`
-- sizes that fits its column on one line (`handFile`, the font
-- FONT.noteWritten is cut from, for the smaller sizes); where none does,
-- the zone alone and the day moved into the words. `under` it the words; the margin
-- notes' strips (UI/PaperStrip.lua) `notes` under those and `gap` apart,
-- room for the tape over each; nothing written past `limit` (the page's
-- foot), or `offLimit` while the not-kept line stands there.
local CAPTION = { hand = { 16, 14 }, handFile = "Interface\\AddOns\\" .. addonName .. "\\Fonts\\Neuton-Italic.ttf",
    under = 1, notes = 16, gap = 12, limit = 528, offLimit = 506 }
-- A margin note's pencil leader (JRN-22), short and drawn by hand:
-- graphite at `alpha`, `width` px. It leaves its strip at the edge nearest
-- its mark and comes onto the plate over the plate's edge nearest the
-- strip, so it crosses as little of the map as it can: where on that edge
-- is `lean` of the way from level with the mark toward the strip, kept
-- `inset` px in from the corners, clear of the photo corners there. It bows a little, `bow` of its length
-- toward the page's foot, as a hand's line sags, and ends `stop` px short
-- of the mark in a pencil dot `dot` px across at `dotAlpha`.
-- It is drawn with the route's pen (UI/InkTrail.lua: the curve resampled,
-- mitred and stroked into flat pieces that share their edges, so it bends
-- smoothly and never gaps), but as a pencil, so it never reads as a road
-- across the map (`pen`): graphite at `alpha`, `width` px, a nib whose
-- thick and thin differ little (`nib`, against the route's .55 to 1.25),
-- lighter where it leaves its strip (`taper`: `from` of its width there,
-- full `over` px on), and none of the route's flow, beads or sprinkles.
-- A piece every `step` px of the curve, longer where that would pass
-- `most` pieces. Where the client cannot move a texture's corners, each
-- piece is a straight stroke, turned.
-- (10 Oct, in the client: a hairline of .9 px at .62 vanished against the
-- map art, and four turned flat strokes showed their elbows and stair-
-- stepped edges; the user wants the pen's line, with no fading edges.)
local LEADER = { colour = { 0.27, 0.26, 0.24 }, alpha = 0.85, stop = 9, lean = 0.3, inset = 30, bow = 0.06,
    dot = 3.6, dotAlpha = 0.9,
    pen = { width = 1.7, nib = { angle = 40, thin = 0.85, thick = 1.1 }, taper = { from = 0.55, over = 18 },
        step = 4, most = 24, curve = 24 } }
-- Frame levels over the right page: the leaders over the plates (PLATE's
-- 5, UI/JourneyPlate.lua), the strips over both.
local LEADERS, STRIPS = { level = 20 }, { level = 25 }
-- The line under the full page: its top, the gap between its parts, the
-- second line's gap when it wraps, and under it all the hint, which says
-- how to look closer and how to go back. There is no back link: a click on
-- the map is the way back (FULLZOOM's DRAG), so the hint is what tells it.
local FOOT = { y = 506, gap = 10, under = 3, hint = 3, words = "Scroll to look closer; click the map to go back." }
-- A level with nothing kept: its faded line, `y` down the page. The
-- setting off: its line and link in the right column at the foot (`x`,
-- `y`), or on the full page's last line (`fullY`).
local NOTHING = { x = 12, y = 40, w = 440 }
local OFF = { x = 246, y = 512, fullX = 12, fullY = 552 }

-- The empty page: where its words begin, the gaps between them, and the
-- pencilled plate on the right (top left, size, the turn it lies at, in
-- degrees, its corners' size and how far past the card) with its margin
-- notes (where they stand, how wide, the ink of their leaders, how far
-- short of what they point to).
local EMPTY = { top = 92, gap = 14, under = 6 }
local SKETCH = { x = RIGHT_X + 8, y = 58, w = 270, h = 190, turn = -1.3, alpha = 0.75, pc = 22, out = 4 }
local NOTES = { x = RIGHT_X + 296, w = 166, leader = 0.55, gap = 6 }

local page

--------------------------------------------------------------------------
-- The character
--------------------------------------------------------------------------

-- Whose road: the name as the bookplate has it, then "Level 14 Tauren
-- Hunter".
local function FillHeader()
    local own = ns.ownGUID and ns.OwnCharacters()[ns.ownGUID] or {}
    local name = table.concat({ own.first or ns.Plain(UnitName("player")) or "", own.surname or "" }, " ")
        :gsub("%s+$", "")
    page.name:SetFontObject(FONT.title)
    page.name:SetText(name:upper())
    if (page.name:GetUnboundedStringWidth() or 0) > LEFT_W then page.name:SetFontObject(FONT.titleSmall) end

    local level = ns.Plain(UnitLevel("player"))
    local race, class = ns.Plain(UnitRace("player")), ns.Plain(UnitClass("player"))
    local parts = {}
    if type(level) == "number" and level > 0 then parts[#parts + 1] = "Level " .. level end
    if type(race) == "string" and race ~= "" then parts[#parts + 1] = race end
    if type(class) == "string" and class ~= "" then parts[#parts + 1] = class end
    page.who:SetText(table.concat(parts, " "))
end

-- A name is a way to their page: People, open at them.
local function ToPerson(guid)
    if not guid then return end
    GameTooltip:Hide()
    Style.PlaySound("pageTurn")
    ns.UI.SetJournalView("people")
    ns.UI.SelectPerson(guid)
end

--------------------------------------------------------------------------
-- The entries (left page)
--------------------------------------------------------------------------

-- How tall `text` wraps in `font` across the entries' text width, on a
-- font string of the page's own that is never shown.
local function Measure(font, text)
    local m = page.measure
    m:SetFontObject(font)
    m:SetText(text)
    return math.ceil(m:GetStringHeight() or 0)
end

-- Whether Text.Lines opened `e` with its dateline (where and when it began),
-- which is set in faded ink. Mirrors JourneyText's Opening.
local function HasOpening(e)
    if e.kind == "week" then return e.reached ~= nil end
    return not e.known or e.first or e.reached ~= nil
end

-- The names in an entry's prose made links to their pages (JRN-22): the
-- people from the diary crossed there, by the name the prose gives them,
-- the longest first so "Koko Skybluff" is never cut to "Koko".
local LINK = "|Hsdperson:%s|h|cff" .. Style.HEX.accent .. "%s|r|h"

local function NamesOf(e)
    local names, seen = {}, {}
    local function Add(guid)
        if not guid or seen[guid] then return end
        seen[guid] = true
        local name = ns.Characters.FullName(guid) or ns.Characters.Name(guid)
        if name and name ~= "" then names[#names + 1] = { name = name, guid = guid } end
    end
    for _, face in ipairs(e.faces or {}) do Add(face.guid) end
    for _, person in ipairs(e.people or {}) do
        if ns.Diary.IsDiary(person.guid) then Add(person.guid) end
    end
    table.sort(names, function(a, b) return #a.name > #b.name end)
    return names
end

local function Linked(line, names)
    local marks = {}
    for i, n in ipairs(names) do
        local pattern = n.name:gsub("%p", "%%%0")
        line = line:gsub(pattern, function()
            marks[#marks + 1] = LINK:format(n.guid, n.name)
            return "\001" .. #marks .. "\002"
        end)
    end
    return (line:gsub("\001(%d+)\002", function(k) return marks[tonumber(k)] end))
end

-- The recap as list items: the prologue, then per entry its rubric. Only
-- the open entry says more (journey-revamp-plan §3): its paragraphs, the
-- player's note in their hand, the hindsight lines, then its ledger of
-- zones. A closed entry is its rubric and faces alone, so wherever the
-- list stands, the first thing under the character is a rubric, never
-- another level's zone rows. Returns the items and the index of each
-- entry's rubric.
local function EntryItems(recap, now, fights)
    local items, rubrics = {}, {}
    local function Add(item) items[#items + 1] = item end
    local prologue = Text.Prologue(recap.prologue)
    if prologue then
        Add({ text = prologue, font = FONT.faded, height = Measure(FONT.faded, prologue) + ENTRY.prologue })
    end
    for i, e in ipairs(recap.entries) do
        -- Closed rubrics close up; the open entry stands apart.
        local open = i == page.open
        if open and (i > 1 or prologue) then
            Add({ height = ENTRY.open })
        elseif i > 1 and i - 1 == page.open then
            Add({ height = ENTRY.after })
        end
        Add({ title = Text.Title(e, now), aside = Text.Current(e), paraph = i, entry = i,
            faces = e.faces, e = e, open = open, height = open and ENTRY.title or ENTRY.closed })
        rubrics[i] = #items
        if i == page.open then
            local opening, names = HasOpening(e), NamesOf(e)
            for k, line in ipairs(Text.Lines(e, now, fights)) do
                local font = (k == 1 and opening) and FONT.faded or FONT.body
                Add({ text = Linked(line, names), font = font, height = Measure(font, line) + ENTRY.para })
            end
            -- The player's own words, in their hand, as written.
            local quote, more = Text.Note(e)
            if quote then
                Add({ text = quote, font = FONT.noteWritten, note = true,
                    height = Measure(FONT.noteWritten, quote) + (more and ENTRY.more or ENTRY.para) })
                if more then
                    Add({ text = more, font = FONT.small, height = Measure(FONT.small, more) + ENTRY.para })
                end
            end
            for _, f in ipairs(e.hindsight or {}) do
                local line = Text.Hindsight(f)
                Add({ text = line, font = FONT.noteWritten, later = f,
                    height = Measure(FONT.noteWritten, line) + ENTRY.later })
            end
            if #(e.places or {}) > 0 then Add({ height = ENTRY.ledger }) end
            for _, place in ipairs(e.places or {}) do
                local mapID = place.mapID or (place.dungeon and place.dungeon.seg.mapID)
                Add({ zone = place, mapID = mapID, entry = i, height = ENTRY.zone,
                    current = page.mode == "full" and place.mapID ~= nil and place.mapID == page.fullMap })
            end
        end
    end
    return items, rubrics
end

-- A face at a rubric's end: the class circle on its dark edge, ringed in
-- rubric for a rival; its tooltip says who and what happened, and a click
-- opens their page.
local function Face(row)
    local face = CreateFrame("Button", nil, row)
    face:SetSize(FACES.size, FACES.size)
    face.ring = face:CreateTexture(nil, "ARTWORK", nil, 0)
    face.ring:SetSize(FACES.size + FACES.edge + FACES.ring, FACES.size + FACES.edge + FACES.ring)
    face.ring:SetPoint("CENTER")
    local R = Style.RUBRIC
    Style.Disc(face.ring, R[1], R[2], R[3], FACES.ringAlpha)
    face.edge = face:CreateTexture(nil, "ARTWORK", nil, 1)
    face.edge:SetSize(FACES.size + FACES.edge, FACES.size + FACES.edge)
    face.edge:SetPoint("CENTER")
    local S = Style.INK_STRONG
    Style.Disc(face.edge, S[1], S[2], S[3], 0.9)
    face.icon = face:CreateTexture(nil, "ARTWORK", nil, 2)
    face.icon:SetAllPoints()
    Style.Tooltip(face, function(self) return self.tip end, "ANCHOR_TOP")
    face:SetScript("OnClick", function(self) ToPerson(self.guid) end)
    return face
end

local function SetFace(face, f, e)
    local record = ns.db.characters[f.guid]
    face.guid = f.guid
    face.tip = Text.Face(f, e)
    if not Style.SetClassIcon(face.icon, record and record.class) then
        local INK = Style.INK
        face.icon:SetTexCoord(0, 1, 0, 1)
        Style.Disc(face.icon, INK[1], INK[2], INK[3], 0.6)
    end
    face.ring:SetShown(f.rival == true)
end

local OpenLevel, OpenFull, Marked

-- The ledger's dot leaders: as many LEDGER.dot as fit `room` px, by the
-- width of one measured once (on the page's own measure, at a run of
-- twenty for a true average). Nothing where the client gave no width yet:
-- it is measured again next time.
local function Dots(room)
    if not page.dotW then
        local m = page.measure
        m:SetFontObject(FONT.small)
        m:SetText(LEDGER.dot:rep(20))
        local w = (m:GetUnboundedStringWidth() or 0) / 20
        page.dotW = w > 0 and w or nil
    end
    if not page.dotW or room < page.dotW then return "" end
    return LEDGER.dot:rep(math.floor(room / page.dotW))
end

-- A zone's row as it stands (LEDGER.mark): under the mouse (`row.hot`)
-- its name darker and a pencil line under it; while its map is on the
-- right page, darker and the line in ink.
function Marked(row, item)
    local M = LEDGER.mark
    local current = item.current == true
    local on = current or row.hot == true
    local ink = on and Style.INK_STRONG or Style.INK
    row.zone:SetTextColor(ink[1], ink[2], ink[3], 1)
    if current then
        local S = Style.INK_STRONG
        row.underline:SetColorTexture(S[1], S[2], S[3], M.inkAlpha)
    else
        local G = M.colour
        row.underline:SetColorTexture(G[1], G[2], G[3], M.alpha)
    end
    row.underline:SetShown(on)
    -- Laid flat ("Flat paper only"), the line alone: no light on it.
    row.lip:SetShown(on and ns.Setting("flatSheets") ~= true)
end

local function BuildEntryRow(list)
    local row = CreateFrame("Button", nil, list)
    local w = LEFT_W - SCROLLBAR_WIDTH - 2 - ENTRY.indent
    local INK = Style.INK

    row.text = Style.Text(row, FONT.body)
    row.text:SetPoint("TOPLEFT", ENTRY.indent, 0)
    row.text:SetWidth(w)
    row.text:SetWordWrap(true)
    row.text:SetSpacing(ENTRY.leading)
    -- The names in the prose are links to their pages.
    if row.SetHyperlinksEnabled then row:SetHyperlinksEnabled(true) end
    row:SetScript("OnHyperlinkClick", function(_, link)
        local guid = type(link) == "string" and link:match("^sdperson:(.+)$")
        if guid then ToPerson(guid) end
    end)

    -- The rubric: paraph, red capitals, "so far", a red rule fading out to
    -- the faces.
    row.header = Style.Text(row, FONT.headingRubric)
    row.header:SetPoint("BOTTOMLEFT", ENTRY.indent, ENTRY.base)
    row.paraph = row:CreateTexture(nil, "ARTWORK")
    row.paraph:SetSize(ENTRY.paraph, ENTRY.paraph)
    row.paraph:SetRotation(math.pi / 4)
    row.paraph:SetPoint("CENTER", row.header, "LEFT", -ENTRY.indent / 2 - 1, 0)
    row.aside = Style.Text(row, FONT.small)
    row.aside:SetPoint("LEFT", row.header, "RIGHT", 7, 0)
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    row.more = Style.Text(row, FONT.small)
    row.more:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.more:SetJustifyH("RIGHT")
    row.faces = {}

    -- A zone in the ledger (LEDGER): its name in small type, dot leaders
    -- out to its time at the right in faded ink, and a dungeon's doorway
    -- in the margin.
    row.zone = Style.Text(row, FONT.small)
    row.zone:SetPoint("LEFT", ENTRY.indent, 0)
    row.zone:SetWordWrap(false)
    row.time = Style.Text(row, FONT.small)
    row.time:SetPoint("RIGHT", -LEDGER.right, 0)
    row.time:SetJustifyH("RIGHT")
    row.dots = Style.Text(row, FONT.small)
    row.dots:SetPoint("RIGHT", row.time, "LEFT", -LEDGER.gap, 0)
    row.dots:SetJustifyH("RIGHT")
    row.dots:SetWordWrap(false)
    row.dots:SetAlpha(LEDGER.dotAlpha)
    -- The doorway: the plates' arch, its body then its round head (y up
    -- here, down in DOOR).
    local D, A = LEDGER.door, Plate.DOOR
    local s, I, at = D.size, D.ink, ENTRY.indent / 2 - 1
    local body = row:CreateTexture(nil, "ARTWORK")
    body:SetSize(s * A.body.w, s * A.body.h)
    body:SetPoint("CENTER", row, "LEFT", at, -s * A.body.y)
    body:SetColorTexture(I[1], I[2], I[3], D.alpha)
    local head = row:CreateTexture(nil, "ARTWORK")
    head:SetSize(s * A.head.size, s * A.head.size)
    head:SetPoint("CENTER", row, "LEFT", at, -s * A.head.y)
    Style.Disc(head, I[1], I[2], I[3], D.alpha)
    row.door = { body, head }

    -- The reader's mark under a zone's name (LEDGER.mark): the pencil
    -- line, and the light on its groove's lower side.
    local M = LEDGER.mark
    row.underline = row:CreateTexture(nil, "ARTWORK")
    row.underline:SetHeight(M.width)
    row.underline:SetPoint("TOPLEFT", row.zone, "BOTTOMLEFT", 0, -M.under)
    row.lip = row:CreateTexture(nil, "ARTWORK")
    row.lip:SetHeight(1)
    row.lip:SetPoint("TOPLEFT", row.underline, "BOTTOMLEFT", 0, 0)
    row.lip:SetColorTexture(M.lip[1], M.lip[2], M.lip[3], M.lipAlpha)

    row:SetScript("OnClick", function(self)
        local item = self.item
        if not item then return end
        if item.title then
            Style.PlaySound("pageTurn")
            OpenLevel(item.entry)
        elseif item.zone and item.mapID then
            Style.PlaySound("pageTurn")
            OpenFull(item.mapID, item.entry)
        end
    end)
    -- Under the mouse, a rubric's rule darkens: it opens its level. A
    -- zone's row that opens its map is marked (LEDGER.mark).
    local function Hot(self, on)
        local item = self.item
        if item and item.zone then
            self.hot = on and item.mapID ~= nil
            Marked(self, item)
            return
        end
        if not (item and item.title) then return end
        local R = Style.RUBRIC
        Style.Shade(self.rule, "HORIZONTAL", R[1], R[2], R[3], on and ENTRY.ruleHot or ENTRY.ruleAlpha, 0)
    end
    row:SetScript("OnEnter", function(self) Hot(self, true) end)
    row:SetScript("OnLeave", function(self) Hot(self, false) end)
    return row
end

local function UpdateEntryRow(row, item)
    local isTitle, isZone = item.title ~= nil, item.zone ~= nil
    row.header:SetShown(isTitle)
    row.paraph:SetShown(isTitle)
    row.rule:SetShown(isTitle)
    row.aside:SetShown(isTitle)
    row.more:SetShown(false)
    row.text:SetShown(item.text ~= nil)
    row.zone:SetShown(isZone)
    row.time:SetShown(isZone)
    row.dots:SetShown(isZone)
    for _, piece in ipairs(row.door) do piece:SetShown(isZone and item.zone.dungeon ~= nil) end
    row.underline:SetShown(false)
    row.lip:SetShown(false)
    if not (isZone and item.mapID) then row.hot = nil end
    for _, face in ipairs(row.faces) do face:Hide() end

    if isTitle then
        -- A closed rubric's words sit lower in its shorter row.
        row.header:SetPoint("BOTTOMLEFT", ENTRY.indent, item.open and ENTRY.base or ENTRY.closedBase)
        row.header:SetText(item.title)
        local paraph = PARAPHS[item.paraph % 2 == 1 and 1 or 2]
        row.paraph:SetColorTexture(paraph[1], paraph[2], paraph[3], 1)
        row.aside:SetText(item.aside or "")
        local R = Style.RUBRIC
        Style.Shade(row.rule, "HORIZONTAL", R[1], R[2], R[3], ENTRY.ruleAlpha, 0)

        -- The faces, from the right: "+n" past the most, then the circles
        -- in the order met; the rule runs out to the first of them.
        local faces = item.faces or {}
        local shown = math.min(#faces, FACES.most)
        local to, point, x = row, "RIGHT", -2
        if #faces > FACES.most then
            row.more:SetText("+" .. (#faces - FACES.most))
            row.more:Show()
            to, point, x = row.more, "LEFT", -FACES.gap
        end
        for k = shown, 1, -1 do
            local face = row.faces[k] or Face(row)
            row.faces[k] = face
            SetFace(face, faces[k], item.e)
            face:ClearAllPoints()
            face:SetPoint("RIGHT", to, point, x, 0)
            face:Show()
            to, point, x = face, "LEFT", -FACES.gap
        end
        row.rule:ClearAllPoints()
        row.rule:SetPoint("LEFT", row.aside, "RIGHT", ENTRY.rule, 0)
        row.rule:SetPoint("RIGHT", to, point, to == row and -2 or -ENTRY.rule, 0)
    elseif isZone then
        local place = item.zone
        row.zone:SetFontObject(FONT.small)
        row.zone:SetWidth(0)
        row.zone:SetText(place.dungeon and (place.name or "An instance") or Text.ZoneName(place))
        row.time:SetText((place.seconds or 0) >= 60 and Text.LedgerTime(place.seconds) or "")
        -- The name never crowds out the leaders: past its share of the row
        -- it is cut short (the client adds the ellipsis).
        local rowW = LEFT_W - SCROLLBAR_WIDTH - 2
        local nameW = row.zone:GetUnboundedStringWidth() or 0
        local most = math.floor(LEDGER.nameMax * (rowW - ENTRY.indent))
        if nameW > most then
            row.zone:SetWidth(most)
            nameW = most
        end
        local timeW = row.time:GetUnboundedStringWidth() or 0
        row.dots:SetText(Dots(rowW - ENTRY.indent - nameW - timeW - LEDGER.right - 2 * LEDGER.gap))
        -- The mark under the name, as long as the name.
        row.underline:SetWidth(math.max(1, nameW))
        row.lip:SetWidth(math.max(1, nameW))
        Marked(row, item)
    elseif item.text then
        row.text:SetFontObject(item.font or FONT.body)
        row.text:SetText(item.text)
    end
end

--------------------------------------------------------------------------
-- The plates (right page)
--------------------------------------------------------------------------

-- The art box of a slot: the card less its margin.
local function ArtSize(slot)
    return slot.w - 2 * slot.pad, slot.h - 2 * slot.pad
end

-- The smallest art box of each layout: the window a plate of it must fit.
local SMALLEST = {}
for n, slots in ipairs(LAYOUT) do
    local aw, ah = math.huge, math.huge
    for _, slot in ipairs(slots) do
        local w, h = ArtSize(slot)
        aw, ah = math.min(aw, w), math.min(ah, h)
    end
    SMALLEST[n] = { aw, ah }
end

-- Whether `plate` (Recap.Plates's) holds in `slot`: its moments span no
-- more than PLATES.inset of the slot's art, on its own map.
local function Holds(plate, slot)
    local w, h = Plate.Cover(plate.mapID, ArtSize(slot))
    return ns.JourneyRecap.Holds(plate, w, h)
end

-- The page for `plates`, keyed by their weights in time order (LAYOUT's
-- FL, LFF, ...; any other pattern the page for that many), and that key.
-- A light plate is drawn light only where a snapshot holds it: a level's
-- pin far from the first spot is drawn full, so nothing on it goes
-- missing (the user's choice, 13 Oct). Nil where a slot does not hold its
-- plate, for the plates to be grouped at a smaller window.
local function LayoutFor(plates)
    if #plates == 0 then return {}, "" end
    local key = {}
    for i, p in ipairs(plates) do key[i] = (p.light and Holds(p, SNAPSHOT)) and "L" or "F" end
    key = table.concat(key)
    local layout = LAYOUT[key] or LAYOUT[#plates]
    for i, p in ipairs(plates) do
        if not Holds(p, layout[i]) then return nil end
    end
    return layout, key
end

-- An entry's plates (JRN-21), worked out once per recap and kept on the
-- entry with their page (LayoutFor) and its key: grouped for the one-plate
-- layout's window first, and only where a plate does not hold in its slot
-- on the page that grouping gives, for the windows of the layout that
-- many take, so a level spent on one hillside is one large plate and a
-- level that travelled has three small ones. Slots of one page differ in
-- size now (a snapshot beside a tall plate), so each plate is asked of its
-- own; two plates at the two-plate window always hold, as before, and
-- three where every slot holds them are no longer split smaller.
local function PlatesOf(e)
    if e.plates then return e.plates, e.layout, e.pattern end
    local j = ns.Journey.For(ns.ownGUID)
    local plates, layout, key = {}, nil, nil
    for n = 1, #SMALLEST do
        local aw, ah = SMALLEST[n][1], SMALLEST[n][2]
        plates = ns.JourneyRecap.Plates(j, e, page.ctx or {}, function(mapID) return Plate.Cover(mapID, aw, ah) end)
        layout, key = LayoutFor(plates)
        if layout then break end
    end
    -- The last window always holds in the page for its count, as before.
    if not layout then layout, key = LAYOUT[#plates], string.rep("F", #plates) end
    e.plates, e.layout, e.pattern = plates, layout, key
    return plates, layout, key
end

-- A zone's road and meetings (Recap.Sheet), and an entry's moments
-- (Recap.Moments), once per recap.
local function SheetOf(mapID)
    local sheet = page.sheets[mapID]
    if not sheet then
        sheet = ns.JourneyRecap.Sheet(ns.Journey.For(ns.ownGUID), mapID, page.ctx or {})
        page.sheets[mapID] = sheet
    end
    return sheet
end

local function MomentsOf(e)
    local list = page.moments[e]
    if not list then
        list = ns.JourneyRecap.Moments(ns.Journey.For(ns.ownGUID), e, page.ctx or {})
        page.moments[e] = list
    end
    return list
end

-- The middle of everything on a zone's road: where the full page centres.
local function RoadMiddle(sheet)
    local lx, hx, ly, hy = math.huge, -math.huge, math.huge, -math.huge
    local function Take(x, y)
        if x and y then
            lx, hx, ly, hy = math.min(lx, x), math.max(hx, x), math.min(ly, y), math.max(hy, y)
        end
    end
    for _, seg in ipairs(sheet.stops) do Take(seg.x, seg.y) end
    for _, road in ipairs(sheet.roads) do
        local pts = ns.Journey.Points(road)
        for k = 1, #pts - 1, 2 do Take(pts[k], pts[k + 1]) end
    end
    for _, seg in ipairs(sheet.dungeons) do Take(seg.x, seg.y) end
    if lx > hx then return 0.5, 0.5 end
    return (lx + hx) / 2, (ly + hy) / 2
end

-- What follows a plate as it leans in (its leaders), below.
local Follow

local function PlateAt(i)
    local plate = page.plates[i]
    if not plate then
        plate = Plate(page.right, LAYOUT[1][1])
        plate.onZoom = function(p, scale) Follow(p, scale) end
        page.plates[i] = plate
    end
    return plate
end

-- Font strings and textures on the right page, handed out in turn and the
-- rest hidden after a drawing, like the plates' own pools.
local function Handout(make)
    local pool = { used = 0 }
    function pool:Begin() self.used = 0 end
    function pool:Next()
        self.used = self.used + 1
        local item = self[self.used]
        if not item then
            item = make()
            self[self.used] = item
        end
        item:Show()
        return item
    end
    function pool:Finish()
        for i = self.used + 1, #self do self[i]:Hide() end
    end
    return pool
end

-- Text at x, y of the right page (its top left), `width` wide and wrapped,
-- set flush to `align` (left by default); returns its height. `font` nil
-- keeps the font the string already has (a heading fitted by hand).
local function Write(text, font, words, x, y, width, align)
    if font then text:SetFontObject(font) end
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", page.right, "TOPLEFT", x, -y)
    text:SetWidth(width)
    text:SetJustifyH(align or "LEFT")
    text:SetText(words)
    return math.ceil(text:GetStringHeight() or 0)
end

-- One straight stroke from x1, y1 to x2, y2, `width` wide, turned: a
-- leader's piece where corners cannot move.
local function Stroke(stroke, x1, y1, x2, y2, width)
    if not stroke.SetRotation then
        stroke:Hide()
        return
    end
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    stroke:ClearAllPoints()
    stroke:SetSize(length + 0.5, width)
    stroke:SetPoint("CENTER", page.right, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    stroke:SetRotation(math.atan2(-dy, dx))
    stroke:Show()
end

-- A leader along `points` (x, y, x, y, ...: its curve on the right page,
-- from the strip to the mark), with the route's pen as a pencil
-- (LEADER.pen): resampled, mitred, each vertex's width its nib's share of
-- `width`, tapered off the strip, and stroked into flat quads, one texture
-- each from the link's; the rest hidden. Returns how many were drawn.
local function Pencil(link, points)
    local Ink, Pen = ns.UI.InkTrail, LEADER.pen
    local length = 0
    for k = 1, #points - 3, 2 do
        length = length + math.sqrt((points[k + 2] - points[k]) ^ 2 + (points[k + 3] - points[k + 1]) ^ 2)
    end
    local P = Ink.Resample(points, math.max(Pen.step, length / (#link.strokes - 1)))
    local prims = {}
    if #P >= 2 then
        local M = Ink.Mitres(P)
        local n, T = #P, Pen.taper
        local function Half(i)
            local a, b = P[math.max(i - 1, 1)], P[math.min(i + 1, n)]
            local taper = T.from + (1 - T.from) * math.min(1, P[i].s / T.over)
            return Pen.width / 2 * Ink.Nib(b.x - a.x, b.y - a.y, Pen.nib) * taper
        end
        Ink.Stroke(prims, 0, P, M, Half, function() return 0 end, function() return LEADER.alpha end,
            LEADER.colour, nil, #link.strokes)
    end
    for k, stroke in ipairs(link.strokes) do
        local q = prims[k]
        if q then
            stroke:SetColorTexture(q.r, q.g, q.b, q.a)
            if Style.Quad(stroke, page.right, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                stroke:Show()
            else
                -- From the middle of its start to the middle of its end.
                local w = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2)
                    + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
                Stroke(stroke, (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2, (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2, w)
            end
        else
            stroke:Hide()
        end
    end
    link.prims, link.drawn = prims, math.min(#prims, #link.strokes)
    return link.drawn
end

local function HideLeader(link)
    for _, stroke in ipairs(link.strokes) do stroke:Hide() end
    link.drawn = 0
    link.dot:Hide()
end

local function Clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- A leader aimed at its mark as the plate shows it now: leaning in
-- (ZOOM, UI/JourneyPlate.lua), the picture grows about the card's middle,
-- and the mark with it. From the edge of its strip nearest the mark, onto
-- the plate over its edge nearest the strip, bowing a little, to a pencil
-- dot a little short of the mark (LEADER); none while the mark is out of
-- the plate's window. Worked in the card's own frame, through its turn
-- (none laid flat), so "the nearest edge" is the card's.
local function Aim(link, scale)
    local s, mark = link.plate.slot, link.mark
    local cx, cy = s.x + s.w / 2, s.y + s.h / 2
    local mx, my = cx + (mark[1] - cx) * scale, cy + (mark[2] - cy) * scale
    if math.abs(mx - cx) > s.w / 2 - s.pad or math.abs(my - cy) > s.h / 2 - s.pad then
        HideLeader(link)
        return
    end
    local sx, sy = link.strip:Nearest(mx, my)
    local a = ns.Setting("flatSheets") == true and 0 or math.rad(s.t or 0)
    local cos, sin = math.cos(a), math.sin(a)
    local function Card(x, y)
        local dx, dy = x - cx, y - cy
        return dx * cos + dy * sin, -dx * sin + dy * cos
    end
    local function OnPage(u, v)
        return cx + u * cos - v * sin, cy + u * sin + v * cos
    end

    -- Where it comes onto the plate.
    local su, sv = Card(sx, sy)
    local mu, mv = Card(mx, my)
    local hw, hh, inset = s.w / 2, s.h / 2, LEADER.inset
    local outU, outV = math.abs(su) - hw, math.abs(sv) - hh
    local eu, ev
    if outU <= 0 and outV <= 0 then
        eu, ev = (su + mu) / 2, (sv + mv) / 2
    elseif outU >= outV then
        eu = su < 0 and -hw or hw
        ev = Clamp(mv + (sv - mv) * LEADER.lean, -hh + inset, hh - inset)
    else
        ev = sv < 0 and -hh or hh
        eu = Clamp(mu + (su - mu) * LEADER.lean, -hw + inset, hw - inset)
    end
    local ex, ey = OnPage(eu, ev)

    -- Where it ends: short of the mark, along the way it comes in.
    local dx, dy = mx - ex, my - ey
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= LEADER.stop then
        ex, ey = (sx + mx) / 2, (sy + my) / 2
        dx, dy = mx - sx, my - sy
        d = math.sqrt(dx * dx + dy * dy)
    end
    if d <= LEADER.stop then
        HideLeader(link)
        return
    end
    local tx, ty = mx - dx / d * LEADER.stop, my - dy / d * LEADER.stop
    local lx, ly = tx - sx, ty - sy
    local length = math.sqrt(lx * lx + ly * ly)
    if length < 1 then
        HideLeader(link)
        return
    end

    -- The bow: the curve bends toward the way in, pushed a little toward
    -- the page's foot, across the line from the strip to the end.
    local nx, ny = -ly / length, lx / length
    if ny < 0 then nx, ny = -nx, -ny end
    local kx, ky = ex + nx * LEADER.bow * length, ey + ny * LEADER.bow * length
    -- The curve, finely enough for the pen to resample (LEADER.pen.curve
    -- points).
    local steps = LEADER.pen.curve
    local points = { sx, sy }
    for i = 1, steps do
        local t = i / steps
        local u = 1 - t
        points[#points + 1] = u * u * sx + 2 * u * t * kx + t * t * tx
        points[#points + 1] = u * u * sy + 2 * u * t * ky + t * t * ty
    end
    link.points = points
    Pencil(link, points)
    local dot, C = link.dot, LEADER.colour
    Style.Disc(dot, C[1], C[2], C[3], LEADER.dotAlpha)
    dot:ClearAllPoints()
    dot:SetSize(LEADER.dot, LEADER.dot)
    dot:SetPoint("CENTER", page.right, "TOPLEFT", tx, -ty)
    dot:Show()
end

function Follow(plate, scale)
    for _, link in ipairs(page.links or {}) do
        if link.plate == plate then Aim(link, scale) end
    end
end

-- The one mark a strip's leader goes to (10 Oct, in the client: a leader
-- to each of a person's marks drew long pencil lines across the plate):
-- the mark of their likeliest to matter (the plate's PRIORITY: a fight,
-- then time together, a note, a first sighting, then a feature's moment
-- joined to theirs), and of
-- those the nearest the strip, so the line crosses as little of the map
-- as it can. A strip that quotes a note leads to where it was written,
-- whatever else they did there: the words under the name say what the
-- mark is (12 Oct, in the client: the quote was written in the south, the
-- leader went north to the time together).
local function LeaderMark(g, strip, plate)
    local quoted = Text.MarginQuoted(g.moments)
    if quoted and plate.where[quoted] then return plate.where[quoted] end
    local P = Plate.PRIORITY
    local best, rank, gap
    for _, m in ipairs(g.moments) do
        local at = plate.where[m]
        if at then
            local r = P[m.kind] or math.huge
            local sx, sy = strip:Nearest(at[1], at[2])
            local d = (sx - at[1]) ^ 2 + (sy - at[2]) ^ 2
            if not best or r < rank or (r == rank and d < gap) then best, rank, gap = at, r, d end
        end
    end
    return best
end

-- A strip's leader, to its one mark on `plate` (LeaderMark), kept
-- (page.links) so it follows the plate as it leans in.
local function Leader(strip, mark, plate)
    if not mark then return end
    local strokes = {}
    for i = 1, LEADER.pen.most do strokes[i] = page.leaderPool:Next() end
    local link = { strokes = strokes, dot = page.dotPool:Next(), strip = strip, mark = mark, plate = plate }
    page.links[#page.links + 1] = link
    Aim(link, plate.scale or 1)
end

-- A margin note: a paper strip taped beside the plate, a name in the
-- diary's hand that opens their page and what happened under it.
local function NewNote()
    local strip = ns.UI.PaperStrip(page.right)
    -- Above the plates and the leaders: a strip lies on the page over the
    -- start of its leader, and takes the mouse before anything under it.
    strip:SetFrameLevel(page.right:GetFrameLevel() + STRIPS.level)
    return strip
end

-- The people on a plate (JRN-22): one note per person, a stranger never
-- grouped with another, ordered by their marks' height so the leaders do
-- not cross. Each { guid, moments, marks (page points), top }.
local function People(plate)
    local groups, byGuid = {}, {}
    for _, m in ipairs(plate.people or {}) do
        local at = plate.where[m]
        local g = m.guid and byGuid[m.guid]
        if not g then
            g = { guid = m.guid, moments = {}, marks = {}, top = at[2] }
            groups[#groups + 1] = g
            if m.guid then byGuid[m.guid] = g end
        end
        g.moments[#g.moments + 1] = m
        local known = false
        for _, p in ipairs(g.marks) do
            if p[1] == at[1] and p[2] == at[2] then known = true end
        end
        if not known then g.marks[#g.marks + 1] = at end
        g.top = math.min(g.top, at[2])
    end
    table.sort(groups, function(a, b) return a.top < b.top end)
    return groups
end

-- Who a note names: its person, if the diary knows them, else no one
-- (a stranger, "someone").
local function NoteGuid(g)
    return g.guid and ns.db.characters[g.guid] ~= nil and g.guid or nil
end

-- Who the first `n` notes name, for the caption not to name them again
-- (Text.PlateCaption's `named`).
local function Named(groups, n)
    local named = { someone = 0 }
    for i = 1, math.min(n, #groups) do
        local guid = NoteGuid(groups[i])
        if guid then named[guid] = true else named.someone = named.someone + 1 end
    end
    return named
end

-- Whether `guid` is a rival: a diary entry tagged "foe".
local function Rival(guid)
    local entry = guid and ns.db.diary[guid]
    for _, tag in ipairs(entry and entry.tags or {}) do
        if tag == "foe" then return true end
    end
    return false
end

-- How much a person's note matters in the margin, by what they did there:
-- 1 for something done together (time in a group, a fight, a note), 2 for
-- a first sighting seen in hindsight, 3 for paths only crossed; a
-- feature's moment joined to theirs says its own (its `person.tier`, Core/
-- JourneyRecap.lua's RegisterMoment: something they gave you is 1). A
-- person is their best moment's tier. (11 Oct, in the client: two first
-- sightings took the column and the killer card was left off.)
local TIER = { session = 1, fight = 1, note = 1, added = 1, first = 2, crossed = 3 }

local function Tier(g)
    local best = 3
    for _, m in ipairs(g.moments) do
        best = math.min(best, TIER[m.kind] or (m.person and m.person.tier) or 2)
    end
    return best
end

--------------------------------------------------------------------------
-- The margin's kinds (JourneyMargin.Register)
--------------------------------------------------------------------------

-- What a plate's margin holds, in the order it is given room (MarginOrder):
-- the people who did something with you, then the features' cards by how
-- much they matter, then the people only seen, then filler (the order is
-- the user's, case by case). The people are the diary's own and placed
-- here; every other kind of note (a card, a slip) registers itself, so a
-- feature's file (Features/<Name>/, loaded after UI/) puts its note in
-- every plate's margin without this file knowing of it
-- (.claude/registry-refactor.md, phase 4). Each registration's comment
-- says why it stands where it does.
--
-- Each kind is laid as the people's strips are (LayNotes): from its own
-- pool, down the boxes, a leader from it to its mark, left off where it
-- has no room (and everything after it), then laid again by its marks'
-- heights; and the caption's words told what it showed, so whatever had
-- no room is said there instead (Text.PlateCaption's `said`).
--
-- `spec` (JourneyMargin.Register(kind, spec)), `kind` the name its items
-- carry (it.kind, plate.margin's; never "person"):
--   order    its place in the margin: lowest first, and first left off
--            last. The people who did something with you stand at
--            PEOPLE.close (10) and those only seen at PEOPLE.seen (80);
--            at equal numbers the people go first, then the kinds in the
--            order they registered. A kind registered from
--            Features/<Name>/ says its number there. Leave gaps.
--   item     function(plate) → one item or nil; or
--   items    function(plate) → a list of them (a card each item).
--            An item is { top, x, ... }: `top` its mark's height on the
--            page (the column is laid again in that order, so leaders do
--            not cross), `x` where across the page its leader likeliest
--            goes (for a row of notes under the plate), and its own fields
--            (it.killer, it.hunt, ...: the tests read them). `kind` and
--            `rank` (its place in the order) are set here.
--   pool     the page's key for its pool of notes (page.killerPool, ...);
--            kinds may share one (a killer's and a close call's card are
--            one card, the killer card).
--   new      function(parent) → a new note for the pool, the first time it
--            is needed. It is laid over the plates (STRIPS). A note has
--            :Layout(x, y, w, room) → w, h; :Nearest(x, y) → the point of
--            its edge nearest a mark; and, optionally, :Smaller() (it
--            draws itself smaller, false when it cannot) and `overfull`.
--   write    function(note, it, c): the note written for its item. `c`:
--            plate, e (the entry), level, named (who the people's notes
--            name), now, Seed(...) (its parts joined with the plate's map
--            and level: a note's seeded look, the same each time),
--            ToPerson(guid) (a name that opens their page).
--   mark     function(it, note) → { x, y } on the page: where its leader
--            goes.
--   wants    optional function(it) → the width it would like in a row of
--            fewer notes than boxes (Shared): a hunt's card its wide
--            arrangement.
--   assume   optional function(said, plate, slot, plan): tells the words,
--            before the margin is laid, what it would show if all of it
--            had room (said[...], Text.PlateCaption's `said`).
--   say      optional function(said, shown, plate): tells the words what
--            it showed (`shown`, its items that had room, maybe none), so
--            what had none goes into them. Asked in `order`, so a kind may
--            leave a later one's word to it (a witness's creature, which a
--            killer's card left off overrules).
--   count    optional: the page's key counting its notes written
--            (page.killersWritten, ...: the tests'), set to 0 as the
--            plates are drawn; counted(shown, plate) → how many where it
--            is not just its shown items (good luck on a print counts).
--   filler   true: it is filler (the user, 14 Oct). Left off, its words go
--            in the caption (`say` is asked only then) but never cost the
--            caption its place over the plate nor run it past its foot;
--            `flag` names the plate field saying whether the words told
--            it.
--   fits     optional function(plan, slot) → false where what it puts on
--            a light plate's print will not go on the smaller print tucked
--            into F+L (`slot`): the page is FL then.
--   after    optional function(plate, c): once the margin is laid, for
--            what it draws besides its notes; c.Leader(from, mark) draws a
--            leader (good luck's print up to its star).
local MARGIN, MARGIN_ORDER, marginSeq = {}, {}, 0
local NONE = {}
local PEOPLE = { close = 10, seen = 80 }
local Margin = { KINDS = MARGIN, ORDER = MARGIN_ORDER, PEOPLE = PEOPLE }
ns.UI.JourneyMargin = Margin

-- The right page's pools for every registered kind, made as they are first
-- needed, and the lists of them: the margin's (Mark, Undo) and the whole
-- right page's (DrawRight).
local function EnsurePools()
    if not page then return end
    local margin, right = { "notePool" }, { page.leaderPool, page.dotPool, page.headingPool, page.captionPool,
        page.notePool }
    local seen = { notePool = true }
    for _, spec in ipairs(MARGIN_ORDER) do
        local key = spec.pool
        if not page[key] then
            local new = spec.new
            page[key] = Handout(function()
                local note = new(page.right)
                note:SetFrameLevel(page.right:GetFrameLevel() + STRIPS.level)
                return note
            end)
        end
        if not seen[key] then
            seen[key] = true
            margin[#margin + 1] = key
            right[#right + 1] = page[key]
        end
    end
    margin[#margin + 1], margin[#margin + 2] = "leaderPool", "dotPool"
    page.marginPools, page.rightPools = margin, right
end

function Margin.Register(kind, spec)
    assert(type(kind) == "string" and kind ~= "person" and type(spec) == "table"
        and (spec.item or spec.items) and type(spec.pool) == "string" and spec.new and spec.write and spec.mark,
        "JourneyMargin.Register(kind, { order, item | items, pool, new, write, mark, ... })")
    Margin.Remove(kind)
    marginSeq = marginSeq + 1
    spec.kind, spec.seq, spec.order = kind, marginSeq, spec.order or 100
    MARGIN[kind] = spec
    MARGIN_ORDER[#MARGIN_ORDER + 1] = spec
    table.sort(MARGIN_ORDER, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.seq < b.seq
    end)
    EnsurePools()
    return spec
end

-- Takes a kind out of every margin again (a test's own kind). Its pool
-- stays, unused.
function Margin.Remove(kind)
    local old = MARGIN[kind]
    if not old then return end
    MARGIN[kind] = nil
    for i = #MARGIN_ORDER, 1, -1 do
        if MARGIN_ORDER[i] == old then table.remove(MARGIN_ORDER, i) end
    end
    EnsurePools()
end

-- A kind's items on `plate`, a list.
local function ItemsOf(spec, plate)
    if spec.items then return spec.items(plate) or {} end
    local item = spec.item(plate)
    return item and { item } or {}
end

-- The margin's items for `plate` in their order. Each { kind = "person"
-- or a registered kind's, top, x, rank, ... }; a person's { g, index }.
local function MarginOrder(plate, groups)
    local order = {}
    local function Add(item)
        item.rank = #order + 1
        order[#order + 1] = item
    end
    -- A person's: the mark LeaderMark would choose first, leftmost of
    -- equals (the strip it would be nearest is not laid yet).
    local function Across(g)
        local quoted = Text.MarginQuoted(g.moments)
        if quoted and plate.where[quoted] then return plate.where[quoted][1] end
        local x, rank
        for _, m in ipairs(g.moments) do
            local at = plate.where[m]
            local r = at and (Plate.PRIORITY[m.kind] or math.huge)
            if at and (not x or r < rank or (r == rank and at[1] < x)) then x, rank = at[1], r end
        end
        return x or 0
    end
    -- The people of tier 1 (close) or past it, in their marks' order.
    local function People(close)
        for i, g in ipairs(groups) do
            if (Tier(g) == 1) == close then Add({ kind = "person", g = g, index = i, top = g.top, x = Across(g) }) end
        end
    end
    local close, seen = false, false
    for _, spec in ipairs(MARGIN_ORDER) do
        if not close and spec.order >= PEOPLE.close then close = People(true) or true end
        if not seen and spec.order >= PEOPLE.seen then seen = People(false) or true end
        for _, item in ipairs(ItemsOf(spec, plate)) do
            item.kind = spec.kind
            Add(item)
        end
    end
    if not close then People(true) end
    if not seen then People(false) end
    return order
end

-- How many lines a person's quoted note may take on their strip, tried
-- in turn while the margin will not hold all it has (WriteMargin): its
-- strip's most (UI/PaperStrip.lua's STRIP.quote), then fewer. The one
-- being tried is `quoteMost`.
local QUOTES = { 3, 2, 1 }
local quoteMost

-- The note for one of MarginOrder's items, from its pool, written: a
-- person's strip here, any other kind's note by its own `write`
-- (JourneyMargin.Register). `named` is who the people's notes name
-- (Named), so a card does not say again what a person's note says.
local function MarginNote(plate, e, it, named)
    local level = e.level or e.week or 0
    if it.kind == "person" then
        local strip = page.notePool:Next()
        local g, guid = it.g, NoteGuid(it.g)
        -- Their latest note quoted under the name; where it was cut, here
        -- or on the strip, the tooltip has the rest.
        local quote, cut, whole = Text.MarginQuote(g.moments)
        local function Tip()
            if not (cut or strip.quoteCut) then return nil end
            return { { "Your note" }, { whole, 1, 1, 1, true } }
        end
        strip:SetNote({ name = Text.MarginWho(guid), what = Text.MarginWhat(g.moments, e.level), quote = quote,
            quoteLines = quoteMost, guid = guid, rival = Rival(guid), onClick = ToPerson, tip = quote and Tip or nil,
            seed = table.concat({ guid or ("someone" .. it.index), plate.mapID or 0, level }, ":") })
        return strip
    end
    local spec = MARGIN[it.kind]
    local note = page[spec.pool]:Next()
    spec.write(note, it, { plate = plate, e = e, level = level, named = named, now = page.now, ToPerson = ToPerson,
        Seed = function(...)
            local parts, n = { ... }, select("#", ...)
            parts[n + 1], parts[n + 2] = plate.mapID or 0, level
            return table.concat(parts, ":")
        end })
    return note
end

-- Where a note's leader goes: a person's likeliest mark (LeaderMark), any
-- other kind's by its own `mark`.
local function MarginMark(plate, it, note)
    if it.kind == "person" then return LeaderMark(it.g, note, plate) end
    return MARGIN[it.kind].mark(it, note)
end

-- `items` laid in turn down the `boxes` ({ x, y, w, limit, align }), each
-- with its leader: down the first box as far as it goes, then on down the
-- next, never past the page's foot; a box set flush right lays each note
-- against its right side. Stops at the first that finds no room (it is
-- hidden). Returns how many were laid.
-- Boxes side by side (`boxes.row`, the one plate's row under it, TOP)
-- take a note each where they can: each the box nearest its mark across
-- the page, in turn left to right, a box kept for each note still to
-- come (Columns); more notes than boxes share them, the first boxes one
-- more. A note with no room in its box still goes on to the next.
local function Columns(items, boxes)
    local n, m, at = #items, #boxes, {}
    for i, it in ipairs(items) do
        if n > m then
            -- Shared: box k holds n / m notes, the first n % m one more.
            local k, before = 1, 0
            while before + math.floor(n / m) + (k <= n % m and 1 or 0) < i do
                before = before + math.floor(n / m) + (k <= n % m and 1 or 0)
                k = k + 1
            end
            at[i] = k
        else
            local near, gap = 1, math.huge
            for k, box in ipairs(boxes) do
                local d = math.abs((it.x or 0) - (box.x + box.w / 2))
                if d < gap then near, gap = k, d end
            end
            at[i] = math.min(math.max(near, (at[i - 1] or 0) + 1), m - (n - i))
        end
    end
    return at
end

-- `replay`: the notes laid again in another order (WriteMargin's by
-- height), each as small as it was in the order of importance
-- (it.smaller) and no smaller: a note of less importance laid first must
-- not make one of more give up its room (12 Oct: a hunt's card cost the
-- close call's its deed); where they then do not fit, the order of
-- importance stands.
-- A row under one plate (LAYOUT[1][1].top.row) with fewer notes than
-- boxes shares its width among the notes there are (Shared): a box for
-- each, as wide as the widest note would like (its kind's `wants`: a hunt
-- card's wide arrangement, Features/Hunts/HuntCard.lua's card:Preferred,
-- or a lucky card's, its tag beside the struck words,
-- Features/Hunts/LuckyCard.lua) and no wider than its
-- share of the row (217 px for two) or `most` px; never narrower than the
-- row's own boxes. (26 kills, 12 expected, want 187 px; 37 for about 15,
-- some 212.)
-- Each box lies as near its note's mark as the row lets it. A person's
-- strip keeps the row's own width (its quote would run out into a
-- banner), and any note narrower than its box lies under its mark.
-- (12 Oct, in the client: a hunt card wrapped its count into a 142 px box
-- with the row's left box empty beside it.)
local ROW = { most = 220 }

-- `boxes` (a row) for `order` (MarginOrder): the row as it is, or with
-- fewer notes than boxes, a box each, shared out (ROW).
local function Shared(order, boxes)
    local n = #order
    if not boxes.row or n == 0 or n >= #boxes then return boxes end
    local first, last = boxes[1], boxes[#boxes]
    local want = first.w
    for _, it in ipairs(order) do
        local spec = MARGIN[it.kind]
        if spec and spec.wants then want = math.max(want, spec.wants(it)) end
    end
    if want <= first.w then return boxes end
    local x0, x1 = first.x, last.x + last.w
    local gap = boxes[2].x - first.x - first.w
    local w = math.floor(math.min(want, ROW.most, (x1 - x0 - gap * (n - 1)) / n))
    -- In the order of their marks across the page, each box under its
    -- mark where it can be: right of the one before, room left for those
    -- after.
    local marks = {}
    for i, it in ipairs(order) do marks[i] = it.x or 0 end
    table.sort(marks)
    local shared = { row = true, shared = true, base = first.w }
    local at = x0
    for i = 1, n do
        local most = x1 - (n - i + 1) * w - (n - i) * gap
        local x = math.max(at, math.min(most, marks[i] - w / 2))
        shared[i] = { x = x, y = first.y, w = w, limit = first.limit }
        at = x + w + gap
    end
    return shared
end

local function LayNotes(plate, e, items, boxes, named, replay)
    local foot = ns.JourneyCapture.On() and CAPTION.limit or CAPTION.offLimit
    local k, box = 1, boxes[1]
    local y = box.y
    local columns = boxes.row and Columns(items, boxes) or nil
    for i, it in ipairs(items) do
        if columns and columns[i] > k then
            k = columns[i]
            box = boxes[k]
            y = box.y
        end
        local note = MarginNote(plate, e, it, named)
        -- The height left in the box: a note that can fit itself to it (a
        -- close call's card draws its picture smaller) does so before it
        -- goes on to the next box, which in a row is another note's.
        local function Room() return math.min(box.limit or foot, foot) - y end
        local function Over(h) return note.overfull or h > Room() end
        local smaller = 0
        if replay then
            while smaller < (it.smaller or 0) and rawget(note, "Smaller") and note:Smaller() do
                smaller = smaller + 1
            end
        end
        -- In a shared row (Shared) a person's strip keeps the row's width.
        local function Wide() return (boxes.shared and it.kind == "person") and math.min(box.w, boxes.base) or box.w end
        local w, h = note:Layout(box.x, y, Wide(), Room())
        while Over(h) and boxes[k + 1] do
            k = k + 1
            box = boxes[k]
            y = box.y
            w, h = note:Layout(box.x, y, Wide(), Room())
        end
        -- A note that can do with less (a close call's card, the killer card's:
        -- its picture, then its deed; a hunt's, Features/Hunts/HuntCard.lua:
        -- its lines; a lucky card's, Features/Hunts/LuckyCard.lua: its
        -- creature's line, its icon)
        -- tries that before it is left off.
        while not replay and Over(h) and rawget(note, "Smaller") and note:Smaller() do
            smaller = smaller + 1
            w, h = note:Layout(box.x, y, Wide(), Room())
        end
        if not replay then it.smaller = smaller end
        if Over(h) then
            note:Hide()
            return i - 1
        end
        if box.align == "RIGHT" and type(w) == "number" and w < box.w then
            note:Layout(box.x + box.w - w, y, box.w, Room())
        elseif boxes.shared and type(w) == "number" and w < box.w then
            -- Under its mark, as near as the box lets it.
            local x = math.max(box.x, math.min(box.x + box.w - w, (it.x or 0) - w / 2))
            if x ~= box.x then note:Layout(x, y, Wide(), Room()) end
        end
        Leader(note, MarginMark(plate, it, note), plate)
        -- The note as laid, for the caption (Plated: whether a witness's
        -- card kept its foe's line).
        it.note = note
        y = y + h + CAPTION.gap
    end
    return #items
end

-- What the right page's pools and leaders hold now, and back to it: a
-- margin laid again from there. The pools are the people's strips', every
-- registered kind's (EnsurePools) and the leaders'.
local function Mark()
    local at = { links = #page.links }
    for _, key in ipairs(page.marginPools) do at[key] = page[key].used end
    return at
end

local function Undo(at)
    for _, key in ipairs(page.marginPools) do
        local pool = page[key]
        for i = at[key] + 1, pool.used do pool[i]:Hide() end
        pool.used = at[key]
    end
    for i = #page.links, at.links + 1, -1 do page.links[i] = nil end
end

-- A plate's margin (MarginOrder) laid down `boxes`: as much of it as there
-- is room for, in its order of importance, the rest left off. What is
-- shown is then laid again in the order of its marks' heights (across the
-- page, for a row of boxes), so the leaders do not cross, where that
-- still fits; else in its order of importance. Returns the items shown,
-- and all there were to show (MarginOrder's).
local function WriteMargin(plate, e, groups, boxes)
    local order = MarginOrder(plate, groups)
    boxes = Shared(order, boxes)
    local close = {}
    for _, it in ipairs(order) do
        if it.kind == "person" and Tier(it.g) == 1 then close[#close + 1] = it.g end
    end
    local named = Named(close, #close)
    local at = Mark()
    -- Quoted notes are kept to fewer lines (QUOTES) rather than cost
    -- anything after them its place; where fewer lines make no more room,
    -- they keep the most that showed as much.
    local n, best, most
    for k = 1, #QUOTES do
        quoteMost = QUOTES[k]
        n = LayNotes(plate, e, order, boxes, named)
        if n == #order then break end
        if not best or n > best then best, most = n, QUOTES[k] end
        Undo(at)
        if k == #QUOTES then
            quoteMost = most
            n = LayNotes(plate, e, order, boxes, named)
        end
    end
    local shown = {}
    for i = 1, n do shown[i] = order[i] end
    if n > 1 then
        local sorted = {}
        for i, it in ipairs(shown) do sorted[i] = it end
        local key = boxes.row and "x" or "top"
        table.sort(sorted, function(a, b)
            if a[key] ~= b[key] then return a[key] < b[key] end
            return a.rank < b.rank
        end)
        Undo(at)
        if LayNotes(plate, e, sorted, boxes, named, true) < n then
            Undo(at)
            LayNotes(plate, e, shown, boxes, named)
        end
    end
    return shown, order
end

-- A plate's heading by hand, "The Barrens, yesterday", in ink: on one line
-- at the first of CAPTION.hand's sizes that fits `width`. Where none does,
-- the zone alone (at the size that fits, else the smallest, wrapping), and
-- the day is returned to open the words under it. Returns the heading and
-- that day, if moved. A plate the same day as the one `before` it counts
-- on from it ("Forty-five minutes later").
local function Heading(text, p, width, before)
    local line, zone, day = Text.PlateHeading(p, page.now, before)
    local file = CAPTION.handFile
    local function Fits(words)
        for _, size in ipairs(CAPTION.hand) do
            text:SetFontObject(FONT.noteWritten)
            if file and size ~= CAPTION.hand[1] then text:SetFont(file, size, "") end
            text:SetText(words)
            if (text:GetUnboundedStringWidth() or 0) <= width then return true end
            if not file then return false end
        end
        return false
    end
    if Fits(line) then return line, nil end
    Fits(zone)
    return zone, day
end

-- One plate (ctx: the entry `e`, its plan `p`, the `plate`, its
-- `heading` and `words`, the plate `before` it, when the road `began`,
-- the journey `j`) drawn in `slot`, with its caption and margin notes.
-- `over`: the caption over the plate and its notes in a row under it
-- (TOP), which holds only while the caption is short: its heading on one
-- line and its words on one at most, as first written and again once the
-- margin is laid and whatever had no room is named in them. Where it is
-- not, nothing is left laid and it returns false (the plate goes under its
-- caption instead: decided once, on the words as written last, so it
-- never flips back). A slot that must hold its plate's margin `whole`
-- (FL's `tucked`, its row shared with a print) returns false in the same
-- way when anything of it had no room in the row. Returns true.
local function Plated(ctx, slot, over)
    local e, p, plate, heading, words = ctx.e, ctx.p, ctx.plate, ctx.heading, ctx.words
    plate:SetSlot(slot)
    local aw, ah = ArtSize(slot)
    plate:Draw(SheetOf(p.mapID), e, Plate.Window(p.mapID, p.cx, p.cy, aw, ah), { moments = MomentsOf(e),
        cap = Plate.Share(slot), fights = page.fights, witnesses = page.witnesses, now = page.now })
    plate.share, plate.plan = Plate.Share(slot), p
    plate:SetClick(function()
        Style.PlaySound("pageTurn")
        OpenFull(p.mapID)
    end)
    plate:Show()

    -- Its caption, written by hand on the page beside it; who its
    -- notes name is not named again in the words.
    local cap = slot.cap
    local groups = People(plate)
    local headingWords, day = Heading(heading, p, cap.w, ctx.before)
    -- A line of each, measured as written, for what "short" means.
    local oneHeading = Write(heading, nil, "Ag", cap.x, cap.y, cap.w, cap.align)
    local h = Write(heading, nil, headingWords, cap.x, cap.y, cap.w, cap.align)
    local oneLine = Write(words, FONT.body, "Ag", cap.x, cap.y, cap.w, cap.align)
    local function Short(tall) return tall <= oneLine * 1.5 end
    if over and h > oneHeading * 1.5 then return false end
    -- The words, told what the margin shows (Text.PlateCaption's `said`),
    -- the day first where the heading had no room for it.
    local function Words(said)
        local text = Text.PlateCaption(p, ctx.began, said)
        return day and (day:sub(1, 1):upper() .. day:sub(2) .. ". " .. text) or text
    end
    -- The margin (WriteMargin) under the words, and the words naming
    -- what had no room in the margin: written once more and the margin
    -- laid again until the words are as tall as the margin was laid
    -- under (11 Oct, in the client: a strip lay over the words' second
    -- line, written longer after it was placed). Over the plate the words
    -- are clear of the margin, so once is enough.
    local top = cap.y + h + CAPTION.under
    -- First as if the margin had room for all of it: the people's notes
    -- and every kind's (its `assume`: what its cards would show), each
    -- taken as shown until it is left off.
    local first = { named = Named(groups, #groups) }
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.assume then spec.assume(first, plate, slot, p) end
    end
    local tall = Write(words, FONT.body, Words(first), cap.x, top, cap.w, cap.align)
    if over and not Short(tall) then return false end
    local at, shown, all = Mark(), nil, 0
    local people, byKind, left, rewrite, quiet
    for pass = 1, 4 do
        -- Its notes: in their own column first and then under the
        -- caption, or under the caption; over the plate, in the row
        -- under it.
        local boxes
        if over then
            boxes = { row = true }
            for k, box in ipairs(slot.row) do boxes[k] = box end
        else
            local under = { x = cap.x, y = top + tall + CAPTION.notes, w = cap.w, limit = cap.limit,
                align = cap.align }
            boxes = slot.notes and { slot.notes, under } or { under }
        end
        local order
        shown, order = WriteMargin(plate, e, groups, boxes)
        all = #order
        -- What it showed, by kind, and the filler it left off: a kind
        -- with an item in the margin and none of it shown.
        people, byKind, left = {}, {}, {}
        for _, it in ipairs(shown) do
            if it.kind == "person" then
                people[#people + 1] = it.g
            else
                local list = byKind[it.kind] or {}
                byKind[it.kind] = list
                list[#list + 1] = it
            end
        end
        local filler = false
        for _, it in ipairs(order) do
            local spec = MARGIN[it.kind]
            if spec and spec.filler and not byKind[it.kind] then left[it.kind], filler = true, true end
        end
        -- Whoever and whatever has no note goes back into the words: each
        -- kind's `say`, in the margin's order, told what of it showed (a
        -- witness in a sentence of their own, and the creature their card
        -- did not name; a killer whose card had no room). Filler only
        -- with `withFiller`.
        rewrite = function(withFiller)
            local said = { named = Named(people, #people) }
            for _, spec in ipairs(MARGIN_ORDER) do
                if spec.say and (withFiller or not spec.filler) then
                    spec.say(said, byKind[spec.kind] or NONE, plate)
                end
            end
            return Write(words, FONT.body, Words(said), cap.x, top, cap.w, cap.align)
        end
        local again = rewrite(filler)
        if over or again <= tall or pass == 4 then
            -- Over the plate, filler's words never cost the caption its
            -- place there (the user, 14 Oct): it is left to its mark.
            if over and not Short(again) and filler then
                local plain = rewrite(false)
                if Short(plain) then again, quiet = plain, true end
            end
            tall = math.max(tall, again)
            if over and (not Short(again) or (slot.whole and #shown < all)) then
                Undo(at)
                return false
            end
            break
        end
        tall = again
        Undo(at)
    end
    -- Nor where saying it would run the words past their foot: they leave
    -- it to its mark on the plate and its tooltip. (14 Oct, rasterised:
    -- level 13's FL print, whose caption has two lines, ran a third off the
    -- page.) Each filler kind's `flag` on the plate says whether the words
    -- told it.
    local told = next(left) ~= nil and not quiet
    if told and not over and top + tall > (cap.limit or CAPTION.limit) then
        tall = math.min(tall, rewrite(false))
        told = false
    end
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.filler and spec.flag then plate[spec.flag] = told and left[spec.kind] == true end
    end
    page.notesWritten = page.notesWritten + #people
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.count then
            local list = byKind[spec.kind] or NONE
            page[spec.count] = (page[spec.count] or 0) + (spec.counted and spec.counted(list, plate) or #list)
        end
    end
    -- What a kind draws besides its notes (good luck's leader up its print).
    local drawn = { Leader = function(from, mark) Leader(from, mark, plate) end }
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.after then spec.after(plate, drawn) end
    end
    -- For the tests: where the words end, what the margin shows, and
    -- whether the caption is over the plate.
    plate.captionFoot, plate.margin, plate.captionOver = top + tall, shown, over
    return true
end

-- The open level's plates, laid out on the page their weights and count
-- give (PlatesOf), each with its caption and margin notes.
local function DrawPlates(e)
    local plates, layout, pattern = PlatesOf(e)
    page.layout, page.pattern = #plates, pattern
    page.notesWritten = 0
    for _, spec in ipairs(MARGIN_ORDER) do
        if spec.count then page[spec.count] = 0 end
    end
    if #plates == 0 then
        -- JRN-21: a level whose road was not kept says so, faded.
        page.nothing:SetText("Nothing of this level's road was kept.")
        page.nothing:Show()
        return 0
    end
    local j = ns.Journey.For(ns.ownGUID)
    local began = j and j.startedAt
    -- FL tries its print tucked into the full plate's row first (`tucked`,
    -- F+L) where both plates are held by their windows there; whether it
    -- stays is the full plate's to say (Plated: its caption short, its
    -- margin whole), decided once, so the print follows it.
    local tucked = layout.tucked
    if tucked and not (Holds(plates[1], tucked[1]) and Holds(plates[2], tucked[2])) then tucked = nil end
    -- Nor where what a kind puts on the print will not go on the smaller
    -- one (its `fits`: good luck's S, Features/Hunts/LuckyCard.lua):
    -- nothing may be lost by tucking it in, and FL's snapshot has room
    -- for it.
    for _, spec in ipairs(MARGIN_ORDER) do
        if tucked and spec.fits and not spec.fits(plates[2], tucked[2]) then tucked = nil end
    end
    for i, p in ipairs(plates) do
        local slot = layout[i]
        local plate = PlateAt(i)
        local heading, words = page.headingPool:Next(), page.captionPool:Next()
        local ctx = { e = e, p = p, plate = plate, heading = heading, words = words, before = plates[i - 1],
            began = began, j = j }
        if i == 1 and tucked then
            if Plated(ctx, tucked[1], true) then
                layout, page.pattern = tucked, "F+L"
            else
                Plated(ctx, slot, false)
            end
        -- One plate with a short caption has it over the plate (TOP); a
        -- caption that will not stay short is under it, as on every other
        -- page.
        elseif not (slot.top and Plated(ctx, slot.top, true)) then
            Plated(ctx, slot, false)
        end
    end
    return #plates
end

-- Back from the full page to the level's plates: a click on the map.
local function Back()
    Style.PlaySound("pageTurn")
    OpenLevel(page.open)
end

-- The full page's plate drawn at a view (FULLZOOM, UI/JourneyPlate.lua):
-- `f` px on the screen a px of the map's art, round cx, cy; nil for the
-- fitted view (the zone's whole height, centred on the road). Looked at
-- closer, or with `whole` (the wheel on its way out to the fit), the
-- window is drawn with the whole zone round it.
local function DrawFullPlate(e, view)
    local mapID = page.fullMap
    local plate = PlateAt(1)
    plate:SetSlot(FULL)
    local sheet = SheetOf(mapID)
    local aw, ah = ArtSize(FULL)
    local LW, LH = Plate.LayerSize(mapID)
    local rx, ry = RoadMiddle(sheet)
    local fit = Plate.Window(mapID, rx, ry, aw, ah, true)
    local f0, c0 = ah / ((fit[4] - fit[2]) * LH), { (fit[1] + fit[3]) / 2, (fit[2] + fit[4]) / 2 }
    local f, cx, cy = f0, c0[1], c0[2]
    if view then f, cx, cy = view.f, view.cx, view.cy end
    local whole = view and view.whole
    local window, box = Plate.Frame(mapID, f, cx, cy, aw, ah, FULL.pad,
        (whole or f > f0 + 1e-9) and Plate.FULLZOOM.overscan or nil)
    plate:Draw(sheet, e, window, { moments = MomentsOf(e), cap = 1, fights = page.fights,
        witnesses = page.witnesses, now = page.now, box = box })
    plate.share, plate.plan = 1, nil
    plate:SetClick(Back, false)
    plate:Look({ f = f, cx = cx, cy = cy, fit = f0, c0 = c0, LW = LW, LH = LH,
        redraws = view and view.redraws, whole = whole,
        onSettle = function(nf, ncx, ncy, nwhole)
            DrawFullPlate(e, { f = nf, cx = ncx, cy = ncy, whole = nwhole,
                redraws = plate.look and plate.look.redraws })
        end })
    plate:Show()
    return plate, sheet
end

-- The diary people met on a zone, by their short names (not rivals), and
-- its fights: the full page's line (Text.ZoneFoot).
local function Company(sheet)
    local names, seen, fights = {}, {}, 0
    local function Add(guid)
        if not guid or seen[guid] or not ns.Diary.IsDiary(guid) then return end
        seen[guid] = true
        for _, tag in ipairs(ns.db.diary[guid].tags or {}) do
            if tag == "foe" then return end
        end
        local name = Text.Short(guid)
        if name then names[#names + 1] = name end
    end
    for _, m in ipairs(sheet.meetings) do
        if m.kind == "session" then
            local guids = {}
            for guid in pairs(m.session.participants or {}) do guids[#guids + 1] = guid end
            table.sort(guids)
            for _, guid in ipairs(guids) do Add(guid) end
        elseif m.kind == "note" then
            for guid in pairs(m.note.about or {}) do Add(guid) end
        elseif m.kind == "fight" then
            fights = fights + 1
        end
    end
    return names, fights
end

-- One zone's whole map across the page (JRN-14), the open level's road.
local function DrawFull(e)
    local mapID = page.fullMap
    local _, sheet = DrawFullPlate(e)
    page.layout = "full"

    local z
    for _, zone in ipairs(page.recap.zones) do
        if zone.mapID == mapID then z = zone end
    end
    local foot = page.foot
    foot.name:SetText((z and Text.ZoneName(z) or ns.MapName(mapID) or ("Map " .. mapID)):upper())
    local names, fights = Company(sheet)
    foot.meta:SetText(z and Text.ZoneFoot(z, names, fights) or "Nothing of your road is on this map yet.")
    -- On one line where it fits, else the line under the name; the hint
    -- under them both.
    local nameW = foot.name:GetUnboundedStringWidth() or 0
    local metaW = foot.meta:GetUnboundedStringWidth() or 0
    foot.meta:ClearAllPoints()
    foot.hint:ClearAllPoints()
    if 12 + nameW + FOOT.gap + metaW <= RIGHT_W - 10 then
        foot.meta:SetPoint("BOTTOMLEFT", foot.name, "BOTTOMRIGHT", FOOT.gap, 2)
        foot.hint:SetPoint("TOPLEFT", foot.name, "BOTTOMLEFT", 0, -FOOT.hint)
    else
        foot.meta:SetPoint("TOPLEFT", foot.name, "BOTTOMLEFT", 0, -FOOT.under)
        foot.hint:SetPoint("TOPLEFT", foot.meta, "BOTTOMLEFT", 0, -FOOT.hint)
    end
    for _, part in pairs({ foot.name, foot.meta, foot.hint }) do part:Show() end
    return 1
end

-- The setting off with a road kept: said under the plates, with the way
-- back.
local function PlaceOff(full)
    page.off:ClearAllPoints()
    page.keep:ClearAllPoints()
    if full then
        page.off:SetPoint("TOPLEFT", page.right, "TOPLEFT", OFF.fullX, -OFF.fullY)
        page.keep:SetPoint("LEFT", page.off, "RIGHT", 8, 0)
    else
        page.off:SetPoint("TOPLEFT", page.right, "TOPLEFT", OFF.x, -OFF.y)
        page.keep:SetPoint("TOPLEFT", page.off, "BOTTOMLEFT", 0, -2)
    end
end

-- The right page for the open entry: its plates, or one zone's full page.
-- Drawn as it opens or turns, from pools; never per frame.
local function DrawRight()
    local recap = page.recap
    local e = recap and recap.entries[page.open]
    for _, pool in ipairs(page.rightPools) do pool:Begin() end
    page.links = {}
    page.nothing:Hide()
    for _, part in pairs({ page.foot.name, page.foot.meta, page.foot.hint }) do part:Hide() end
    local shown = 0
    if e then
        if page.mode == "full" and page.fullMap then
            shown = DrawFull(e)
        else
            page.mode = "plates"
            shown = DrawPlates(e)
        end
    end
    for i = shown + 1, #page.plates do page.plates[i]:Hide() end
    for _, pool in ipairs(page.rightPools) do pool:Finish() end
    PlaceOff(page.mode == "full")
end

--------------------------------------------------------------------------
-- The empty page
--------------------------------------------------------------------------

local function Paragraph(parent, font, width)
    local text = Style.Text(parent, font)
    text:SetWidth(width)
    text:SetSpacing(2)
    return text
end

-- Pencil at x, y on the page (y down from its top).
local function Pencilled(parent, font, x, y, text)
    local t = Style.Text(parent, font)
    t:SetPoint("TOPLEFT", x, -y)
    t:SetText(text)
    return t
end

-- A point of the sketch (0..1 across and down it) on the page, turned with
-- it about its middle.
local function SketchAt(u, v)
    local S = SKETCH
    local a = math.rad(S.turn)
    local cx, cy = (u - 0.5) * S.w, (v - 0.5) * S.h
    return S.x + S.w / 2 + cx * math.cos(a) - cy * math.sin(a), S.y + S.h / 2 + cx * math.sin(a) + cy * math.cos(a)
end

-- A round pencil mark at a point of the sketch.
local function SketchDisc(parent, layer, sublevel, u, v, size, colour, alpha)
    local x, y = SketchAt(u, v)
    local disc = parent:CreateTexture(nil, layer, nil, sublevel)
    disc:SetSize(size, size)
    disc:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
    Style.Disc(disc, colour[1], colour[2], colour[3], alpha)
    return disc
end

-- The right page, empty: a plate sketched in pencil, glued in at three
-- corners, what each mark will be written beside it, its caption under
-- it, and the promise.
local function BuildEmptyRight(e)
    local G, P, A = Style.GRAPHITE, Style.PAPER, Style.ACCENT
    local lede = Style.Text(e, FONT.faded)
    lede:SetPoint("TOPLEFT", RIGHT_X, -22)
    lede:SetText("Each level's places are glued in here:")

    -- The card's edge, a little askew, and the art's frame inside it.
    local function Edge(u1, v1, u2, v2, alpha)
        local x1, y1 = SketchAt(u1, v1)
        local x2, y2 = SketchAt(u2, v2)
        Style.Stroke(e, "ARTWORK", x1, y1, x2, y2, G, alpha, 1)
    end
    for _, box in ipairs({ { 0, 1, SKETCH.alpha }, { 0.04, 0.96, 0.45 } }) do
        local a, b = box[1], box[2]
        local c, d = a == 0 and 0 or 0.055, b == 1 and 1 or 0.945
        Edge(a, c, b, c, box[3])
        Edge(b, c, b, d, box[3])
        Edge(b, d, a, d, box[3])
        Edge(a, d, a, c, box[3])
    end
    -- Photo corners, outlined, at three corners; the fourth come unstuck.
    local pu, pv = SKETCH.pc / SKETCH.w, SKETCH.pc / SKETCH.h
    local ou, ov = SKETCH.out / SKETCH.w, SKETCH.out / SKETCH.h
    for _, c in ipairs({ { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 } }) do
        local u0, v0 = c[1] - c[3] * ou, c[2] - c[4] * ov
        local u1, v1 = u0 + c[3] * pu, v0 + c[4] * pv
        Edge(u0, v0, u1, v0, 0.8)
        Edge(u0, v0, u0, v1, 0.8)
        Edge(u1, v0, u0, v1, 0.8)
    end

    -- A road through three stops, a flight off the edge, a dungeon's door.
    local road = { { 0.12, 0.78 }, { 0.22, 0.70 }, { 0.30, 0.58 }, { 0.42, 0.52 }, { 0.55, 0.50 },
        { 0.62, 0.40 }, { 0.70, 0.30 }, { 0.80, 0.26 } }
    for i = 2, #road do
        local x1, y1 = SketchAt(road[i - 1][1], road[i - 1][2])
        local x2, y2 = SketchAt(road[i][1], road[i][2])
        Style.Stroke(e, "ARTWORK", x1, y1, x2, y2, G, 0.85, 1.3)
    end
    SketchDisc(e, "ARTWORK", 0, 0.30, 0.58, 30, G, 0.18)
    SketchDisc(e, "ARTWORK", 1, 0.30, 0.58, 16, G, 0.45)
    SketchDisc(e, "ARTWORK", 0, 0.70, 0.30, 20, G, 0.14)
    SketchDisc(e, "ARTWORK", 1, 0.70, 0.30, 10, G, 0.35)
    -- The flight, dashed, from the last stop off to the right edge.
    local fx1, fy1 = SketchAt(0.80, 0.26)
    local fx2, fy2 = SketchAt(0.94, 0.12)
    local dx, dy = fx2 - fx1, fy2 - fy1
    local length = math.sqrt(dx * dx + dy * dy)
    for d = 0, length - 3, 7 do
        local t1, t2 = d / length, math.min(d + 4, length) / length
        Style.Stroke(e, "ARTWORK", fx1 + dx * t1, fy1 + dy * t1, fx1 + dx * t2, fy1 + dy * t2, A, 0.75, 1.2)
    end
    -- The dungeon's door: two posts and a lintel.
    local gx, gy = SketchAt(0.55, 0.72)
    Style.Stroke(e, "OVERLAY", gx - 4, gy - 4, gx - 4, gy + 4, G, 0.9, 1.6)
    Style.Stroke(e, "OVERLAY", gx + 4, gy - 4, gx + 4, gy + 4, G, 0.9, 1.6)
    Style.Stroke(e, "OVERLAY", gx - 5, gy - 4.5, gx + 5, gy - 4.5, G, 0.9, 1.6)
    local road2 = { { 0.55, 0.50 }, { 0.56, 0.60 }, { 0.55, 0.68 } }
    for i = 2, #road2 do
        local x1, y1 = SketchAt(road2[i - 1][1], road2[i - 1][2])
        local x2, y2 = SketchAt(road2[i][1], road2[i][2])
        Style.Stroke(e, "ARTWORK", x1, y1, x2, y2, G, 0.6, 1)
    end
    -- Who you were with: a ring at the first stop. A level reached: a
    -- numbered mark on the road.
    SketchDisc(e, "OVERLAY", 0, 0.36, 0.62, 11, G, 0.9)
    SketchDisc(e, "OVERLAY", 1, 0.36, 0.62, 5, P, 1)
    SketchDisc(e, "OVERLAY", 0, 0.47, 0.51, 15, G, 0.85)
    local px, py = SketchAt(0.47, 0.51)
    local pin = Style.Text(e, FONT.tag)
    pin:SetPoint("CENTER", e, "TOPLEFT", px, -py)
    pin:SetText("12")

    -- The notes in the margin: { y of the note, what it points to (u, v) }.
    local notes = {
        { 4, "Where you stayed a while, darker the longer.", 0.30, 0.58 },
        { 44, "The roads between.", 0.22, 0.70 },
        { 80, "Flights, dashed. Dungeons, where you went in.", 0.87, 0.19 },
        { 122, "Who you met there, written in the margin.", 0.36, 0.62 },
        { 160, "Where the level came.", 0.47, 0.51 },
    }
    for _, n in ipairs(notes) do
        local text = Style.Text(e, FONT.margin)
        text:SetPoint("TOPLEFT", NOTES.x, -SKETCH.y - n[1])
        text:SetWidth(NOTES.w)
        text:SetText(n[2])
        local fx, fy = NOTES.x - 4, SKETCH.y + n[1] + 7
        local tx, ty = SketchAt(n[3], n[4])
        tx = tx + NOTES.gap
        Style.Curve(e, "ARTWORK", fx, fy, (fx + tx) / 2, fy, tx, ty, A, NOTES.leader, 1, 4)
    end

    -- Its caption, pencilled under it, and what a caption is.
    local y = SKETCH.y + SKETCH.h + 26
    Pencilled(e, FONT.pencil, RIGHT_X + 8, y, "The Barrens, Tuesday")
    Pencilled(e, FONT.pencil, RIGHT_X + 8, y + 18, "Level 12, and a death by the oasis.")
    local note = Style.Text(e, FONT.margin)
    note:SetPoint("TOPLEFT", NOTES.x, -y - 4)
    note:SetWidth(NOTES.w)
    note:SetText("A few words for each place, up to three a level.")
    Style.Curve(e, "ARTWORK", NOTES.x - 4, y + 11, NOTES.x - 20, y + 11, RIGHT_X + 8 + 250, y + 25, A,
        NOTES.leader, 1, 3)

    local INK = Style.INK
    local rule = e:CreateTexture(nil, "ARTWORK")
    rule:SetSize(60, 1)
    rule:SetPoint("TOPLEFT", RIGHT_X, -470)
    rule:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)
    local promise = Paragraph(e, FONT.body, RIGHT_W)
    promise:SetPoint("TOPLEFT", RIGHT_X, -482)
    promise:SetText("A recap of where you went and who you were with. It counts no quests and keeps no score.")
end

-- The left page, empty: why, and an entry as it will read, in pencil.
local function BuildEmptyLeft(e)
    e.heading = Style.Rubric(e, LEFT_W)
    e.heading:SetPoint("TOPLEFT", LEFT_X, -EMPTY.top)
    e.why = Paragraph(e, FONT.body, LEFT_W)
    e.why:SetPoint("TOPLEFT", e.heading, "BOTTOMLEFT", 0, -EMPTY.under)

    -- With the setting off: the way to keep it, and what it keeps.
    e.keep = Style.Link(e, FONT.body, function()
        ns.JourneyCapture.SetEnabled(true)
        ns.UI.RefreshJourneyPage(true)
    end)
    e.keep:SetText("Keep my own route")
    e.keep:SetPoint("TOPLEFT", e.why, "BOTTOMLEFT", 0, -EMPTY.under)
    e.only = Paragraph(e, FONT.small, LEFT_W)
    e.only:SetPoint("TOPLEFT", e.keep, "BOTTOMLEFT", 0, -4)
    e.only:SetText("Only your own position, never anyone else's.")

    -- The sample entry, under whichever of the two ends lower.
    e.sampleLede = Paragraph(e, FONT.faded, LEFT_W)
    e.sampleLede:SetText("Each level gets an entry, like this:")

    local G = Style.GRAPHITE
    e.sampleTitle = Style.Text(e, FONT.pencilSmall)
    e.sampleTitle:SetPoint("TOPLEFT", e.sampleLede, "BOTTOMLEFT", ENTRY.indent, -EMPTY.gap)
    e.sampleTitle:SetText("LEVEL 12")
    local paraph = e:CreateTexture(nil, "ARTWORK")
    paraph:SetSize(ENTRY.paraph, ENTRY.paraph)
    paraph:SetRotation(math.pi / 4)
    paraph:SetPoint("CENTER", e.sampleTitle, "LEFT", -ENTRY.indent / 2 - 1, 0)
    paraph:SetColorTexture(G[1], G[2], G[3], 0.8)
    local rule = e:CreateTexture(nil, "ARTWORK")
    rule:SetSize(LEFT_W - ENTRY.indent - 70, 1)
    rule:SetPoint("LEFT", e.sampleTitle, "RIGHT", ENTRY.rule, 0)
    Style.Shade(rule, "HORIZONTAL", G[1], G[2], G[3], 0.45, 0)

    local previous = e.sampleTitle
    for i, line in ipairs({
        "Reached on 6 October at the Crossroads, The Barrens.",
        "An hour of quests round the Crossroads. Then Lushwater Oasis.",
        "With Thex Theximus for forty minutes.",
    }) do
        local t = Paragraph(e, i == 1 and FONT.pencilSmall or FONT.pencil, LEFT_W - ENTRY.indent)
        t:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(i == 1 and 8 or ENTRY.para))
        t:SetText(line)
        previous = t
    end
    -- And its ledger: the zones it was spent in, each a way to its map,
    -- with dot leaders out to their times, as the entries have it.
    local right = LEFT_X + LEFT_W - LEDGER.right
    for i, zone in ipairs({ { "The Barrens", "1 h 20" }, { "Stonetalon Mountains", "40 min" } }) do
        local name = Style.Text(e, FONT.pencilSmall)
        name:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(i == 1 and ENTRY.para or 4))
        name:SetText(zone[1])
        local time = Style.Text(e, FONT.pencilSmall)
        time:SetPoint("RIGHT", e, "TOPLEFT", right, 0)
        time:SetPoint("TOP", name, "TOP", 0, 0)
        time:SetText(zone[2])
        local dots = Style.Text(e, FONT.pencilSmall)
        dots:SetPoint("TOPRIGHT", time, "TOPLEFT", -LEDGER.gap, 0)
        dots:SetJustifyH("RIGHT")
        dots:SetWordWrap(false)
        dots:SetAlpha(LEDGER.dotAlpha)
        dots:SetText(LEDGER.dot:rep(20))
        local dotW = (dots:GetUnboundedStringWidth() or 0) / 20
        local room = LEFT_W - ENTRY.indent - LEDGER.right - 2 * LEDGER.gap
            - (name:GetUnboundedStringWidth() or 0) - (time:GetUnboundedStringWidth() or 0)
        dots:SetText(dotW > 0 and room > dotW and LEDGER.dot:rep(math.floor(room / dotW)) or "")
        previous = name
    end
end

local function BuildEmpty(parent)
    local e = CreateFrame("Frame", nil, parent)
    e:SetAllPoints(parent)
    e:Hide()
    BuildEmptyLeft(e)
    BuildEmptyRight(e)
    return e
end

-- Which of the two empty pages: the setting off, or nothing walked yet.
local function FillEmpty(e, on)
    e.heading:SetText(on and "Your road starts here" or "Not keeping your road", not on)
    e.why:SetText(on and "Nothing is on it yet. From now on the diary keeps where this character goes:"
        .. " the places you stay a while, the roads between, flights and dungeons, and who you were with."
        or "The diary is not keeping this character's road just now, so there is nothing to tell here yet.")
    e.keep:SetShown(not on)
    e.only:SetShown(not on)
    e.sampleLede:ClearAllPoints()
    e.sampleLede:SetPoint("TOPLEFT", on and e.why or e.only, "BOTTOMLEFT", 0, -EMPTY.gap - 4)
end

--------------------------------------------------------------------------
-- Construction and refresh
--------------------------------------------------------------------------

function ns.UI.BuildJourneyPage(parent)
    page = { parent = parent, plates = {}, sheets = {}, moments = {}, mode = "plates", links = {} }
    local INK = Style.INK

    -- The character.
    page.name = Style.Text(parent, FONT.title)
    page.name:SetPoint("TOPLEFT", LEFT_X, -HEAD.name)
    page.who = Style.Text(parent, FONT.faded)
    page.who:SetPoint("TOPLEFT", LEFT_X, -HEAD.who)
    page.rule = parent:CreateTexture(nil, "ARTWORK")
    page.rule:SetSize(HEAD.ruleW, 1)
    page.rule:SetPoint("TOPLEFT", LEFT_X, -HEAD.rule)
    Style.Shade(page.rule, "HORIZONTAL", INK[1], INK[2], INK[3], Style.HAIRLINE, 0)

    page.measure = Style.Text(parent, FONT.body)
    page.measure:SetWidth(LEFT_W - SCROLLBAR_WIDTH - 2 - ENTRY.indent)
    page.measure:SetWordWrap(true)
    page.measure:SetSpacing(ENTRY.leading)
    page.measure:Hide()

    -- The entries.
    local listH = BOOK_H - HEAD.list - HEAD.bottom
    page.entries = ns.UI.VirtualList(parent, ENTRY.unit, ENTRY.rows, BuildEntryRow, UpdateEntryRow)
    page.entries:SetPoint("TOPLEFT", LEFT_X, -HEAD.list)
    page.entries:SetWidth(LEFT_W)
    page.entries:SetBarColors(LIST_BAR[1], LIST_BAR[2])
    page.entries:SetNumRows(math.floor(listH / ENTRY.unit))

    -- The right page: the plates, their captions and notes, the leaders
    -- over the plates, and the full page's line.
    page.right = CreateFrame("Frame", nil, parent)
    page.right:SetPoint("TOPLEFT", RIGHT_X, -TOP)
    page.right:SetSize(RIGHT_W, RIGHT_H)
    page.leaders = CreateFrame("Frame", nil, page.right)
    page.leaders:SetAllPoints(page.right)
    page.leaders:SetFrameLevel(page.right:GetFrameLevel() + LEADERS.level)
    page.leaderPool = Handout(function()
        local stroke = page.leaders:CreateTexture(nil, "OVERLAY")
        if stroke.SetSnapToPixelGrid then
            stroke:SetSnapToPixelGrid(false)
            stroke:SetTexelSnappingBias(0)
        end
        return stroke
    end)
    page.dotPool = Handout(function()
        local dot = page.leaders:CreateTexture(nil, "OVERLAY")
        if dot.SetSnapToPixelGrid then
            dot:SetSnapToPixelGrid(false)
            dot:SetTexelSnappingBias(0)
        end
        return dot
    end)
    page.headingPool = Handout(function()
        local text = Style.Text(page.right, FONT.noteWritten)
        text:SetWordWrap(true)
        return text
    end)
    page.captionPool = Handout(function()
        local text = Style.Text(page.right, FONT.body)
        text:SetWordWrap(true)
        text:SetSpacing(2)
        return text
    end)
    page.notePool = Handout(NewNote)
    -- Every registered kind's notes (JourneyMargin.Register): the cards
    -- and slips, each kind's pool made here (page[spec.pool]), and the
    -- lists of pools the page draws and the margin rolls back.
    EnsurePools()

    page.nothing = Style.Text(page.right, FONT.faded)
    page.nothing:SetPoint("TOPLEFT", NOTHING.x, -NOTHING.y)
    page.nothing:SetWidth(NOTHING.w)
    page.nothing:Hide()

    local foot = {}
    page.foot = foot
    foot.name = Style.Text(page.right, FONT.page)
    foot.name:SetPoint("TOPLEFT", 12, -FOOT.y)
    foot.meta = Style.Text(page.right, FONT.small)
    -- No way back but the map itself: a click on it (FULLZOOM's DRAG), so
    -- the hint says so.
    foot.hint = Style.Text(page.right, FONT.small)
    foot.hint:SetText(FOOT.words)
    for _, part in pairs(foot) do part:Hide() end

    -- The setting off with a road already kept: said under the plates.
    page.off = Style.Text(page.right, FONT.small)
    page.off:SetText("Your road is not being kept just now.")
    page.keep = Style.Link(page.right, FONT.body, function()
        ns.JourneyCapture.SetEnabled(true)
        ns.UI.RefreshJourneyPage()
    end)
    page.keep:SetText("Keep it again")
    PlaceOff(false)

    page.empty = BuildEmpty(parent)
    return page
end

-- What the page shows: "entries" (a road to recap: anything kept, the
-- stop or road still open included, or a level reached), or "on" or "off"
-- for the empty page, by the setting.
local function State()
    local j = ns.Journey.Mine()
    if ns.Journey.Any(j) then return "entries" end
    return ns.JourneyCapture.On() and "on" or "off"
end

local function ShowRoad(shown)
    page.entries:SetShown(shown)
    page.right:SetShown(shown)
    page.empty:SetShown(not shown)
end

-- The left page's items for the recap as it is open now. `keep` holds the
-- reader's place; `steady` (an entry's index) keeps that entry's rubric
-- where it was on the page as others open and close round it.
local function Rebuild(keep, steady)
    local before = steady and page.rubrics and page.rubrics[steady]
    local offset = page.entries.offset or 0
    local items, rubrics = EntryItems(page.recap, page.now, page.fights)
    page.items, page.rubrics = items, rubrics
    page.newest = rubrics[#page.recap.entries]
    page.entries:SetData(items, keep)
    if before and rubrics[steady] then
        page.entries:SetOffset(math.max(0, rubrics[steady] - (before - offset)))
    end
end

-- Opens entry `i`: its prose on the left, its plates on the right.
function OpenLevel(i)
    if not (page and page.recap and page.recap.entries[i]) then return end
    GameTooltip:Hide()
    page.open, page.mode, page.fullMap = i, "plates", nil
    Rebuild(true, i)
    DrawRight()
end

-- Shows `mapID`'s whole map across the right page, the entry `i` in ink
-- (the open one when not given).
function OpenFull(mapID, i)
    if not (page and page.recap and mapID) then return end
    GameTooltip:Hide()
    i = i or page.open
    page.open, page.mode, page.fullMap = i, "full", mapID
    Rebuild(true, i)
    DrawRight()
end

-- `opening`: the page is being turned to, so it falls open at the newest
-- entry and its plates. Otherwise (the diary changed while it lies open)
-- it stays where it was read. Cheap when nothing changed: the recap is
-- cached by version (JourneyRecap.For), and the page is only rebuilt when
-- it, or the day (relative dates), moved on, or as it opens.
function ns.UI.RefreshJourneyPage(opening)
    if not page then return end
    -- Called by the book as it turns here: that is an opening.
    if opening == nil then opening = true end
    FillHeader()

    local state = State()
    page.state = state
    local route = state == "entries"
    ShowRoad(route)
    local on = ns.JourneyCapture.On()
    page.off:SetShown(route and not on)
    page.keep:SetShown(route and not on)
    if not route then
        FillEmpty(page.empty, state == "on")
        page.recap = nil
        return
    end

    local recap, ctx = ns.JourneyRecap.For(ns.ownGUID)
    if not recap then return end
    local now = ns.Now()
    local day = ns.DayStart(now)
    local changed = recap ~= page.recap or day ~= page.day
    if changed then
        page.recap, page.ctx, page.day, page.now = recap, ctx, day, now
        page.fights = ns.Journey.FightIndex()
        page.witnesses = ns.Journey.WitnessIndex()
        page.sheets, page.moments = {}, {}
    end
    local count = #recap.entries
    if opening or not page.open or page.open > count then
        page.open, page.mode, page.fullMap = count, "plates", nil
    end
    if changed or opening then
        Rebuild(not opening)
        DrawRight()
    end
    if opening and page.rubrics[page.open] then page.entries:SetOffset(page.rubrics[page.open] - 1) end
end

-- Draws the right page again as it is (/sd pen, after the pen changed).
function ns.UI.RedrawJourneyPage()
    if page and page.recap and page.state == "entries" then DrawRight() end
end

-- Kept up to date while it lies open: a session, a note or a fight written
-- elsewhere changes what the entries say.
ns.On("SD_DIARY_CHANGED", function()
    if ns.UI.JournalShowing("journey") then ns.UI.RefreshJourneyPage(false) end
end)

-- For the tests.
function ns.UI.JourneyPage()
    return page
end
ns.UI.JourneyLook = { ENTRY = ENTRY, LEDGER = LEDGER, CAPTION = CAPTION, LEADER = LEADER, LAYOUT = LAYOUT, FOOT = FOOT,
    ROW = ROW, Shared = Shared, SNAPSHOT = SNAPSHOT, LayoutFor = LayoutFor }

-- A zone's whole map on the right page (JRN-14): at the open level when
-- it was there, else the latest level that was.
function ns.UI.OpenZoneSheet(mapID)
    if not (page and mapID) then return end
    ns.UI.RefreshJourneyPage(false)
    local recap = page.recap
    if not recap then return end
    local function Visited(e)
        for _, place in ipairs(e and e.places or {}) do
            if place.mapID == mapID then return true end
        end
        return false
    end
    local i = page.open
    if not Visited(recap.entries[i]) then
        for k = #recap.entries, 1, -1 do
            if Visited(recap.entries[k]) then
                i = k
                break
            end
        end
    end
    OpenFull(mapID, i)
end

