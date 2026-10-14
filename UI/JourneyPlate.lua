-- Your Diary's plates (JRN-14, JRN-21, JRN-22): one window of a zone's map,
-- printed on a card glued into the diary's right page (UI/JournalJourney.lua
-- lays them out). A close-up shows the art at its own size, one screen
-- pixel to a pixel of the map's art (Decision 3), so every close-up agrees
-- in scale and none is blurred; the full page fits the zone's whole height.
--
-- The card is ns.UI.LooseSheet's, `glued`: one facet of flat card, turned as
-- its slot says, never fallen or put away. Everything on it is placed and
-- turned through the sheet's toolkit (K.Place, K.Quad, K.PlaceButton,
-- K.PlaceText, K.Pool), so it leans with the card. It is a physical print:
-- photo stock with a thickness (THICKNESS: its edges lit and shaded), casting a
-- shadow on the page from its height (SHADOW), the art toned as a print
-- (PLATE, VIGNETTE). What holds it in the book is drawn here (MOUNT, GLUE,
-- LIFT): folded kraft photo corners, glue squeezed out unevenly at its
-- edges, and a corner come unstuck, standing higher, darker and throwing a
-- wider, softer shadow. Laid flat ("Flat paper only"), no turn, shadow,
-- edges, vignette, glue or lift: the corners lie flat.
--
-- What is printed, from the bottom up (the zone sheet's, JRN-14, before
-- the plates replaced it):
--   the map    the window of the zone's art, with the explored areas over it
--              (UI/MapArt.lua), in a neat line of ink at 65 % (FRAME)
--   the trail  the open level's road and stops as one trail of ink (only
--              the open level's: other levels' roads and marks are left off,
--              10 Oct, where they read as clutter)
--              (UI/InkTrail.lua has the arithmetic and its numbers): a road's
--              weight is your pace, a stop's footprint the ground covered,
--              its time the ink. Only roads that meet the window are fed in,
--              cut at its edges (Clip); a stop shows when its middle is in
--              it. A plate smaller than a page has a share of the trail's
--              caps by its area (SHARE). Each pool has a tooltip (no key on
--              the plates, Decision 7): "Quested here, 25 min"
--   deaths     a death's cross on paper at a pool's upper left (no kind's
--              glyph: the tint and the tooltip say what was done there)
--   flights    dashed, in red-brown, cut at the window's edge
--   marks      what put the plate there, in ink, at one size on the screen
--              however close the plate (MARK): a level's two ends, where it
--              began (ink round paper) and where the next was reached (a
--              rubric disc), each moved off a pool with a short leader
--              (10 Oct: the level's road from pin to pin), a ring for time
--              together, a crossed stroke for a fight, a slip for a note, a
--              doorway for a dungeon, a hollow lozenge for a first
--              sighting in hindsight (JRN-23), and a drawstring pouch for
--              a first found (JRN-24: the first bag, shoulders, green,
--              blue, epic), a giver's on their margin note's leader, a
--              cross in outline for a close call (JRN-25: out of a fight
--              alive with a tenth of your health or less), a tally for
--              bad luck with a quest's drops (JRN-26) and a star for good
--              luck with them (EXT-3), and a tailpiece where a long quest
--              chain ended (JRN-28)
--              Each has a tooltip (UI/JourneyText.lua)
-- The page writes the margin notes and draws their pencil leaders (they
-- cross the plate's edge, and the page does not turn): plate.where has each
-- person's mark on the page, through plate:OnPage's transform.
--
-- Drawn once, as the page opens or turns to a level, from pools of
-- textures; nothing per frame, nothing random: the same plate lies the same
-- way after a /reload. The page keeps three plates and hands them the
-- slots it needs (SetSlot), so their textures serve whichever plate is
-- shown, never a new set per plate.

local addonName, ns = ...

local Style = ns.Style
local Trail = ns.UI.InkTrail

-- The card above the page, below the leaders. The card is aged photo
-- stock (`stock`): a warm off-white gone a little yellow, clearly lighter
-- than the page so it reads as a print glued in, never as more page, but
-- never white. The art is printed on it, not shown
-- on a screen: its colour drawn part way to grey (`desaturate`, where the
-- client can: SetDesaturation) and warmed and darkened toward the page by
-- `tint`, or by `plain` where it cannot desaturate (a warmer, darker tint
-- does the work alone). A map's art size where the client will not say (a
-- classic zone).
-- (9 Oct: at { 1, .94, .82 } alone the art stayed sunlit yellow, a screen.
-- 10 Oct: a stock of { .915, .885, .80 } read as near-white, cool card
-- against the parchment, and with the light edge as a white bevel.)
local PLATE = { level = 5, stock = { 0.90, 0.85, 0.70 }, desaturate = 0.35, tint = { 0.97, 0.91, 0.78 },
    plain = { 0.93, 0.85, 0.70 } }
local ART = { w = 1002, h = 668 }
-- The neat line round the art: ink at `alpha`, `inner` px hugging it, then
-- a `gap` and an `outer` hairline, as the mockup's double rule.
local FRAME = { inner = 1.5, gap = 1.5, outer = 1, alpha = 0.65 }
-- The print's edges darken a little, as an old print does: a band `depth`
-- (a share of the art box's shorter side) inside each side of the neat
-- line, in `tint`, from `alpha` at the edge to nothing, each side's alpha
-- given or taken `uneven` of itself (seeded per plate). Darker toward the
-- bottom right, away from the light. Under the ink: the trail, the marks
-- and the pins lie over it, so they read as they did. None laid flat.
local VIGNETTE = { depth = 0.14, tint = { 0.30, 0.20, 0.08 }, uneven = 0.3,
    alpha = { top = 0.08, left = 0.09, bottom = 0.15, right = 0.13 } }

-- The card's thickness: lit from the top left, its top and left cut edges
-- catch the light (a `width` px line `at` px from the card's edge, -1 on
-- the cut itself, over the card's ink outline, in warm `light` at
-- `lightAlpha`: a catch-light, barely there), its bottom and right edges
-- fall away (a line inside them in ink at `darkAlpha`). None laid flat.
-- (10 Oct, in the client: a line inside the edge at .55 read as a white
-- bevel, a picture frame.)
local THICKNESS = { width = 1, at = -1, light = { 1, 0.95, 0.82 }, lightAlpha = 0.22, darkAlpha = 0.32 }
-- The card's shadow on the page, cast from its height as the loose sheet's
-- is (UI/LooseSheet.lua's LIFT): gradient bands along its right and bottom
-- edges, turned with the card, never discs or rings (9 Oct, in the
-- client: discs read as rings). Where the card is glued (height 0) it falls
-- `out` px down and to the right and fades out over `blur` px more, from
-- `alpha` under the card's edge; where it stands `h` px off the page (a
-- lifted corner, LIFT.height), `out` + `gain` * h and `blur` + `spread` *
-- h, so the lifted corner's shadow is further out, wider and softer. Over
-- it, a thin `core` where the card touches the page: `out` px of ink at
-- `alpha`, fading to nothing toward a lifted corner (it does not touch
-- there). The two bands meet on a mitre at the bottom right. Their ends
-- at the top right and bottom left start in a slant, soft. A lifted corner
-- reaches at most `out` + `blur` + (`gain` + `spread`) * LIFT.height px past
-- the card: 9.9, inside the page's 10 px margin (the full page's and the
-- three-plate layout's lifted corners lie 10 px from the page's edge).
-- Glued, a dark contact line about 1.5 px and a soft band about 4.5 px; the
-- lifted corner's band is about twice as wide at the same darkness under
-- the card, so it reads as standing off the page. None laid flat.
-- (10 Oct, in the client: at out 1.2, blur 3.4, .20, core .30, a plate
-- looked pasted on, with no thickness.)
local SHADOW = { out = 1.0, blur = 3.5, alpha = 0.28, gain = 0.30, spread = 0.60,
    core = { out = 1.5, alpha = 0.40 } }

-- Photo corners: folded pockets of dark brown kraft (black read as holes
-- in the page, 9 Oct), `out` px past the card's corner, `scale` of the
-- slot's `pc` (the page's LAYOUT), in `ink` at `alpha`, each a shade
-- lighter or darker by `uneven` (seeded). Their diagonal is a fold: lit
-- from the top left, the fold of a lower right corner faces the light and
-- catches it, an upper left one faces away: a `fold` px line along it in
-- `light` at `lo` (facing away) to `hi` (facing the light). Each throws a
-- small shadow `shadow` = { right, down, alpha } in `shade`, so it stands
-- on the page and its fold on the print. Laid flat: the pocket alone. Where
-- corners cannot move, an L of two strips `strip` px wide, no fold.
-- (10 Oct, in the client: at .12 to .75 in { .78, .64, .45 } the fold could
-- not be seen: an upper right or lower left corner, half facing the light,
-- got .44. Now those get .6 in a paler light.)
local MOUNT = { out = 3.5, scale = 0.7, ink = { 0.29, 0.19, 0.105 }, alpha = 0.95, uneven = 0.08,
    fold = 1, light = { 0.88, 0.76, 0.56 }, lo = 0.20, hi = 1.0,
    shadow = { 1.1, 1.4, 0.34 }, shade = { 0.08, 0.05, 0.02 }, strip = 3 }
-- Dried glue squeezed out at the edges, amber, a little darker than the
-- page and glossy: `count` beads (at least, at most) just past the card's
-- edge, on sides drawn from `sides` (mostly the bottom and the right,
-- where the thumb pressed), each `length` (a share of its side, within)
-- and `bead` px at its fattest (within), tapering to nothing at both ends,
-- in `tint` at `alpha` (within) at its middle. They lie over the card's
-- soft shadow and under its contact line, so the shadow does not swallow
-- them. Along its crest a `gloss` line, `width` px, `length` of the bead,
-- in `tint` at `alpha`, brightest at its end toward the light: the gloss
-- is what says glue, never dirt. All seeded per plate (its map and slot),
-- so it is glued the same way every time it opens. Laid flat, none.
-- (9 Oct, in the client: discs of glue read as smudges; a uniform 1.5 px
-- bead at .10 read as nothing. 10 Oct: beads up to 2.6 px at .32 under
-- the shadow, with a .7 px gloss, could not be seen at all.)
local GLUE = {
    tint = { 0.45, 0.31, 0.10 }, count = { 3, 5 }, length = { 0.05, 0.14 }, bead = { 2.0, 3.2 },
    alpha = { 0.32, 0.46 }, sides = { "bottom", "right", "bottom", "right", "top", "bottom", "right", "left" },
    gloss = { tint = { 1, 0.96, 0.82 }, alpha = 0.60, width = 1, length = 0.6 },
}
-- A corner come unstuck: it stands `height` px off the page at the
-- corner, falling to the glued card over `reach` px along both edges
-- (its shadow is SHADOW's, from that height). It slopes away from the
-- top-left light, so `box` of the card at it darkens toward the corner
-- (to about `shade`), enough to be seen as a slope at the book's size.
-- (10 Oct, in the client: at .16 over 40 by 34 px it was not.)
local LIFT = { height = 6, reach = 46, box = { 50, 42 }, shade = { br = 0.28, bl = 0.22 } }
-- Each plate's share of the trail's caps (InkTrail's CAP) by its area
-- against `area` (the one-plate slot), at least `least`: a small plate of
-- three about a third, a lone plate or the full page the whole.
local SHARE = { least = 0.35, area = 440 * 320 }
-- Under the mouse a plate that opens a zone's full page leans in: its
-- picture (the art, the ink and the marks) grows to `scale` about the
-- card's middle over `time` seconds, eased out, and back on leaving; the
-- card, its corners, glue and turn stay as they are. The picture is held
-- in a frame clipped to the box the turned art covers, and a mat of the
-- card's own stock lies over the card's margin (MAT), so what grows past
-- the turned neat line is under card, never over it. Laid flat as well:
-- it is a way of saying "this opens", not wear.
local ZOOM = { scale = 1.16, time = 0.2 }
-- A zone's full page looks closer under the wheel (JRN-14): each notch
-- `step` times as close, toward the point under the cursor, eased over
-- `time` seconds, from the fitted view (the whole height of the zone) to
-- the art's own size (`native`, 1 screen px a px of art: closer only
-- blurs). Each notch draws the picture at once for where the wheel is
-- going (it takes a few ms), its marks and lines at that zoom's size, and
-- eases the drawing in from where it was shown, scaled and shifted, so
-- the ink is right once it is there. A drag only shifts the picture;
-- `settle` seconds after it lets go the picture is drawn again for the
-- new window. Either way the rest of the zone is drawn round it (under the card's
-- margin, clipped) so a drag never runs off the art. No closer than
-- `native`, the whole zone is no more than its art's own size (a zone's
-- 1002 by 668 px), not much more than a window and a margin round it.
local FULLZOOM = { step = 1.25, time = 0.15, settle = 0.25, native = 1, overscan = math.huge }
-- Dragging a zoomed full page pans it; a press that moves less than
-- `threshold` px is a click, which goes back.
local DRAG = { threshold = 4 }
-- The mat over the card's margin: the card's stock and its grain (as
-- UI/LooseSheet.lua lays it), over the picture, under the neat line.
local MAT = { grain = 0.14 }

-- No kind's glyph beside a pool on a plate: at close-up scale the small
-- strokes read as letters (9 Oct, in the client). The ink's tint and the
-- pool's tooltip say what was done there.
-- A death's cross on its dot of paper: `gap` px out from the footprint's
-- edge toward the upper left, so the dot (`dot` across) just touches it.
local DEATH = { gap = 5, dot = 10 }
-- Hover squares over the pools: up to `most` of them, each as wide as its
-- footprint within `size`; a droplet's the least.
local HOVER = { most = 200, size = { 12, 28 } }
-- A level pin moved off a pool: `gap` past its edge, its leader `leader`
-- wide in the pin's colour at `leaderAlpha`. The pin where the level began
-- is paper inside a ring of ink `ring` px wide, its number in ink.
local PIN = { gap = 5, leader = 1.2, leaderAlpha = 0.8, ring = 1.5 }
-- A flight: dashes `dash` long, `gap` apart, `width` wide.
local FLIGHT = { dash = 5, gap = 4, width = 1.5, alpha = 0.9, ring = 8 }
-- The marks: their sizes in pixels on the screen, the paper halo round
-- them, the square that takes the mouse. `first` is the hollow lozenge
-- (wide, tall), its ink `line` px; a note a slip with a corner folded
-- (`fold` px); a door an arch. A level's pin is as wide as its number and
-- `pinPad` more.
-- Marks never touch (9 Oct, in the client: two marks side by side read as
-- letters, "O8", "ΠE"): each keeps `clear` px round itself; one landing on
-- another moves out to the first free place on rings `step` px apart
-- (`tries` rings of eight headings), with a graphite hairline back to
-- where it belongs (`tether`: width, alpha) once it moved past its size.
-- People met on one spot share one mark (`merge` px), the likeliest to
-- matter on top (`first` of PRIORITY), its tooltip telling the rest.
local MARK = { hover = 16, halo = 0.75, together = 11, hole = 5, fight = 10, note = { 8, 10 }, noteTurn = 0.14,
    fold = 3.5, door = 10, pin = 13, pinPad = 5, first = { 8.4, 10.4 }, line = 1.2, clear = 3, step = 7, tries = 4,
    merge = 8, tether = { 0.8, 0.5 } }
local PRIORITY = { fight = 1, session = 2, note = 3, first = 4, find = 5 }
-- A first found (JRN-24): a drawstring pouch, the loot bag of a treasure
-- map. Solid ink: a round `body` (`size` across, its middle `y` below the
-- mark's), pinched at a `neck` (`w` wide, from `y0` to `y1`) and flaring
-- above it into a `mouth` `w` wide at `top`, with a `notch` of paper in its
-- middle (`w` wide, `depth` deep) so the cloth stands up in two ears where
-- corners can move (a plain box down to the neck where they cannot). Round below
-- and flared above, so never the dungeon's arch (round above, square
-- below); solid, so never the ring of time together or the hollow lozenge
-- of a first sighting; a mass, never the death's thin cross. 12 px tall,
-- about the other marks' size. In the item's own ink (Style.QualityInk, as
-- its name is written on the page) drawn `tint` of the way from the plain
-- ink, so a green or a blue only hints at its colour; a white or grey
-- item's pouch is plain ink.
local POUCH = { body = { size = 8, y = 1.6 }, neck = { w = 2.2, y0 = -3.4, y1 = -1.6 },
    mouth = { w = 6.4, top = -6.0 }, notch = { w = 2.2, depth = 1.5 }, tint = 0.6, height = 11.6 }
-- A close call (JRN-25): the death's cross drawn in outline and never
-- filled in, the cross you nearly got. Ink round paper, as the hollow
-- lozenge of a first sighting is: a `stem` `w` wide and `h` tall, its middle
-- `y` below the mark's, and a `bar` `w` wide, its middle `y` off it, each
-- `line` px of ink round its paper. A little bigger than the death's solid
-- cross (8 px), so its paper reads at the book's size, but no heavier: the
-- death stays the darker mark. On a `dot` of paper, as the death's is.
-- (11 Oct, a rasterised render: at 12.4 px with 1.25 px of ink it
-- outweighed the death beside it.)
local CLOSE = { stem = { w = 3.8, h = 11, y = 0.5 }, bar = { w = 8.2, y = -1.9 }, line = 1.1, dot = 14 }
-- Bad luck with a quest's drops (JRN-26): a tally, the kills counted where
-- the hunt went on. Four uprights `gap` px apart, `h` tall, each leaning
-- `lean` px at its top as a hand draws them (`jitter`: each one's height
-- given or taken), and a fifth stroke across them from the lower left,
-- `over` px past the outer two. Strokes `width` px. In ink, never a letter
-- (the gate of five is no letter), never a fight's crossed strokes (two,
-- red-brown).
local TALLY = { count = 4, gap = 2.5, h = 10, lean = 0.5, jitter = { 0, 0.6, -0.4, 0.3 }, over = 1.6,
    rise = 7.2, width = 1.3, halo = 16 }
-- Good luck with a quest's drops (EXT-3), the tally's bright counterpart:
-- a lucky star, five points `r` px out from its middle, its inner corners
-- `inner` of that, turned `turn` as a hand draws it, and set `drop` of r
-- lower so it sits on its middle (its points reach further up than down).
-- Solid ink, five kites from the middle (corners on the card); where
-- corners cannot move, five strokes `ray` px wide from the middle to its
-- points. Closed and solid, so never the tally's open strokes, the
-- crosses' square arms or the fight's two red-brown strokes; drawn solid,
-- never as the five strokes of a pentagram. About 12 px, the tally's size.
-- (12 Oct, a rasterised render: at 13 px it outweighed the death beside it.)
local FORTUNE = { r = 6.2, inner = 0.45, turn = -0.10, drop = 0.095, ray = 2.4, halo = 16 }
-- The end of a long quest chain (JRN-28): a tailpiece, as an old book
-- ends a chapter. A swelled `rules` (`w` wide, `t` thick at its middle,
-- tapering to points, its middle `y` off the mark's), a shorter one under
-- it, and a full stop (`dot`: size, y). Where corners cannot move, each
-- rule a flat bar `bar` of its size. Rules lie across, so never the tally
-- or a cross; narrowing to a point, so never a pin or the ring of time
-- together. Ranked with a level's pin on the plate, so it keeps a halo as
-- big as the pin's.
local FINALE = { rules = { { w = 14, t = 2.5, y = -3.2 }, { w = 7.5, t = 2.1, y = 0.5 } }, dot = { 2.8, 4.0 },
    bar = 0.75, halo = 17, h = 10 }
-- A profession brought to its cap (JRN-29): a flight of `steps` stairs
-- rising to the right, one for each rank a trainer teaches (Apprentice,
-- Journeyman, Expert, Artisan), each `w` px wide and `rise` px higher than
-- the one before, standing on one line. The steps climbed, up to the rank
-- reached (its cap over `per`: 75 one, 300 all four), are solid ink; the
-- ones still to climb are drawn in outline, `line` px of ink round their
-- paper, so the flight is always whole and the tooltip says what it means
-- (no key on the plates). A cap past the last rank, or none kept, is the
-- whole flight. Stepped, so never the tally's strokes, a cross, the pouch
-- or the tailpiece's rules; boxes only, so it draws the same where corners
-- cannot move. Ranked with a level's pin, so it keeps a halo as big as
-- the tailpiece's. (12 Oct, a rasterised render: as a stepped line the
-- unclimbed steps blurred into a slash at the book's size; closed, they
-- read as stairs.)
local SKILL = { steps = 4, w = 3.2, rise = 2.9, line = 1.0, per = 75, halo = 17 }
-- The quality a first of each kind is, at least; a bag or shoulders say
-- theirs in their link.
local FIND_QUALITY = { uncommon = 2, rare = 3, epic = 4 }
-- A doorway's arch, as shares of its size (MARK.door on a plate; the
-- ledger's margin draws the same, LEDGER.door in UI/JournalJourney.lua):
-- a square `body` `w` wide, `h` tall, its middle `y` below the mark's
-- middle (y down), and a round `head` `size` across, its middle `y` off
-- it. The head's lower half lies in the body, so the two are one arch.
local DOOR = { body = { y = 0.18, w = 0.8, h = 0.62 }, head = { y = -0.1, size = 0.8 } }
-- What a plate marks at most; past it, the rest is left off. The trail's
-- own caps are InkTrail's.
local CAP = { meetings = 150, flights = 40, dashes = 600, dungeons = 30, pins = 80, firsts = 60, finds = 10,
    closeCalls = 20, hunts = 20, fortunes = 20, finales = 10, skills = 10 }
-- A point this far past the art's edge (px) is still on it; a piece of ink
-- may reach `SPILL` px past it (onto the neat line), and is left off past
-- that: the window cuts a pool its edge crosses, as the art is cut.
local EDGE, SPILL = 0.5, 2

-- No label on a plate: a dungeon's name is in its door's tooltip, as a
-- pool's place is in the pool's (9 Oct, in the client: a name beside its
-- door ran into the marks).

local Plate = {}

local function Clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

--------------------------------------------------------------------------
-- Windows (Decision 3)
--------------------------------------------------------------------------

-- A map's art size in its own pixels, remembered (it never changes), and
-- whether the client said; ART where it did not.
local layers = {}
local function LayerSize(mapID)
    local hit = layers[mapID]
    if hit == nil then
        local list = mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
        local layer = list and list[1]
        local LW, LH = layer and ns.Plain(layer.layerWidth), layer and ns.Plain(layer.layerHeight)
        hit = type(LW) == "number" and LW > 0 and type(LH) == "number" and LH > 0 and { LW, LH } or false
        layers[mapID] = hit
    end
    if hit then return hit[1], hit[2], true end
    return ART.w, ART.h, false
end
Plate.LayerSize = LayerSize

-- How much of `mapID`'s map (0..1 each way) a close-up of aw by ah pixels
-- covers: Recap.Plates's `cover`.
function Plate.Cover(mapID, aw, ah)
    local LW, LH = LayerSize(mapID)
    return aw / LW, ah / LH
end

-- The window { x0, y0, x1, y1 } (0..1 of the map) an aw by ah art box
-- shows, centred on cx, cy as far as the map's edges allow: at the art's
-- own size, or with `fit` the map's whole height (the full page).
function Plate.Window(mapID, cx, cy, aw, ah, fit)
    local LW, LH = LayerSize(mapID)
    local scale = fit and ah / LH or 1
    local w, h = aw / scale / LW, ah / scale / LH
    local x0 = w >= 1 and (1 - w) / 2 or Clamp((cx or 0.5) - w / 2, 0, 1 - w)
    local y0 = h >= 1 and (1 - h) / 2 or Clamp((cy or 0.5) - h / 2, 0, 1 - h)
    return { x0, y0, x0 + w, y0 + h }
end

-- The part of the line from (x1, y1) to (x2, y2) inside the box bx0..bx1
-- by by0..by1 (Liang-Barsky), and where along it that part starts and
-- ends (0..1); nil when none of it is.
local function Clip(x1, y1, x2, y2, bx0, by0, bx1, by1)
    local t0, t1 = 0, 1
    local dx, dy = x2 - x1, y2 - y1
    for _, edge in ipairs({ { -dx, x1 - bx0 }, { dx, bx1 - x1 }, { -dy, y1 - by0 }, { dy, by1 - y1 } }) do
        local p, q = edge[1], edge[2]
        if p == 0 then
            if q < 0 then return nil end
        else
            local r = q / p
            if p < 0 then
                if r > t1 then return nil end
                if r > t0 then t0 = r end
            else
                if r < t0 then return nil end
                if r < t1 then t1 = r end
            end
        end
    end
    return x1 + t0 * dx, y1 + t0 * dy, x1 + t1 * dx, y1 + t1 * dy, t0, t1
end
Plate.Clip = Clip

-- `road`'s pieces inside the window, onto `out`: the road itself when it
-- lies wholly inside, else one copy per stretch inside, its points cut at
-- the edge and its time shared out by length, so its pace stays its own
-- and only a piece that starts or ends where the road did joins a stop.
local function Pieces(road, w, out)
    local pts = ns.Journey.Points(road)
    local n = #pts / 2
    if n < 2 then return end
    local lx, hx, ly, hy = math.huge, -math.huge, math.huge, -math.huge
    for k = 1, #pts - 1, 2 do
        lx, hx = math.min(lx, pts[k]), math.max(hx, pts[k])
        ly, hy = math.min(ly, pts[k + 1]), math.max(hy, pts[k + 1])
    end
    if hx < w[1] or lx > w[3] or hy < w[2] or ly > w[4] then return end
    if lx >= w[1] and hx <= w[3] and ly >= w[2] and hy <= w[4] then
        out[#out + 1] = road
        return
    end
    local total = 0
    for k = 1, #pts - 3, 2 do total = total + math.sqrt((pts[k + 2] - pts[k]) ^ 2 + (pts[k + 3] - pts[k + 1]) ^ 2) end
    local from, to = road.from or 0, road.to or road.from or 0
    local function When(s) return total > 0 and from + (to - from) * s / total or from end
    local piece, start, s = nil, 0, 0
    local function Close(at)
        if piece and #piece >= 4 then
            out[#out + 1] = { kind = "road", mapID = road.mapID, from = When(start), to = When(at), act = road.act,
                levelFrom = road.levelFrom, levelTo = road.levelTo, pts = piece, of = road }
        end
        piece = nil
    end
    for k = 1, #pts - 3, 2 do
        local x1, y1, x2, y2 = pts[k], pts[k + 1], pts[k + 2], pts[k + 3]
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local cx1, cy1, cx2, cy2, t0, t1 = Clip(x1, y1, x2, y2, w[1], w[2], w[3], w[4])
        if cx1 then
            if not piece then piece, start = { cx1, cy1 }, s + t0 * len end
            piece[#piece + 1], piece[#piece + 2] = cx2, cy2
            if t1 < 1 then Close(s + t1 * len) end
        else
            Close(s)
        end
        s = s + len
    end
    Close(s)
end
Plate.Pieces = Pieces

-- Whether a segment, a mark or a moment falls in the open entry's time:
-- drawn, or else left off.
local function During(from, to, entry)
    if not entry then return true end
    if to and to > from then return from < entry.to and to > entry.from end
    return from >= entry.from and from < entry.to
end

-- The tooltip a mark shows: a title and lines (JourneyText's), the way
-- Style.Tooltip takes them.
local function Tip(title, lines)
    if not title or title == "" then return nil end
    local list = { { title } }
    for _, line in ipairs(lines or {}) do list[#list + 1] = { line, 1, 1, 1, true } end
    return list
end

--------------------------------------------------------------------------
-- A plate
--------------------------------------------------------------------------

-- `parent` is the frame the slots are measured on (the right page), `slot`
-- one of the page's LAYOUT entries: x, y (its top left), w, h, t (its turn
-- in degrees, clockwise), pad (the card's margin round the art), pc (the
-- corners' size), corners ({ "tl", ... }) and lift ("br", "bl" or nil).
local function New(parent, slot)
    -- The words, from UI/JourneyText.lua, which loads after this file.
    local Text = ns.UI.JourneyText
    local P, INK, INK_STRONG = Style.PAPER, Style.INK, Style.INK_STRONG

    local view, K = ns.UI.LooseSheet(parent, slot.w, slot.h,
        { glued = true, level = PLATE.level, paper = PLATE.stock, shadows = {} })
    local plate = view
    local S = view.sheet
    local Place, PlaceButton, PlaceText, Width = K.Place, K.PlaceButton, K.PlaceText, K.Width
    local Pool, Split, Bend, Quad, Light = K.Pool, K.Split, K.Bend, K.Quad, K.Light
    plate.counts = {}

    -- The picture's frames (ZOOM): `clip` over the box the turned art
    -- covers, taking the mouse for the hover and the click; `content` in
    -- it, holding the art, the ink and the marks, scaled to zoom (they are
    -- anchored to the card's middle, so they grow about it). `over` lies
    -- above both: the mat, the neat line, the lifted corner's shade and the
    -- photo corners, which do not zoom.
    local clip = CreateFrame("Frame", nil, S)
    clip:SetPoint("CENTER", S, "CENTER")
    clip:SetClipsChildren(true)
    local content = CreateFrame("Frame", nil, clip)
    content:SetAllPoints(clip)
    -- What the picture is placed about: the card's middle, shifted to pan
    -- (FULLZOOM). Unscaled, in the clip.
    local pivot = CreateFrame("Frame", nil, clip)
    pivot:SetSize(1, 1)
    pivot:SetPoint("CENTER", S, "CENTER")
    content.anchorTo = pivot
    plate.pivot = pivot
    local over = CreateFrame("Frame", nil, S)
    over:SetAllPoints(S)
    over:SetFrameLevel(S:GetFrameLevel() + 6)
    plate.clip, plate.content, plate.over = clip, content, over

    ----------------------------------------------------------------------
    -- Pools, from under the card up

    -- On the page under the card (the card's paper is BACKGROUND -5, its
    -- ink edge -6): the card's soft shadow, the glue's beads over it (the
    -- shadow swallowed them), and the shadow's core where the card touches.
    -- The glue's gloss lies outside the card, so it is drawn on the frame
    -- over the card (under everything there), sure to be over the core.
    local shadowPool = Pool("BACKGROUND", -8)
    local gluePool = Pool("BACKGROUND", -7)
    local corePool = Pool("BACKGROUND", -6)
    local backgroundPool = Pool("BORDER", 1, nil, content)
    local tilePool = Pool("BORDER", 2, nil, content)
    local exploredPool = Pool("BORDER", 3, nil, content)
    -- The print's darkened edges, over the art and under all the ink;
    -- placed about the card's middle, not the picture's, so they stay at
    -- the neat line while a full page pans (VIGNETTE).
    local vignettePool = Pool("BORDER", 4, function(t) t.anchorTo = nil end, content)
    plate.vignettes = vignettePool
    -- The trail: a pool of quads and one of discs for each of its layers
    -- (InkTrail's LAYER), quads and discs apart, so a texture is always the
    -- one thing.
    local trailQuads, trailDiscs, trailPools = {}, {}, {}
    for _, name in ipairs({ "wash", "halo", "road", "dab", "rim", "spatter", "nib" }) do
        local sublevel = Trail.LAYER[name]
        trailQuads[sublevel], trailDiscs[sublevel] = Pool("ARTWORK", sublevel, nil, content),
            Pool("ARTWORK", sublevel, nil, content)
        trailPools[#trailPools + 1] = trailQuads[sublevel]
        trailPools[#trailPools + 1] = trailDiscs[sublevel]
    end
    local dashPool = Pool("ARTWORK", 2, nil, content)
    local washPool = Pool("ARTWORK", 5, nil, content)
    local pinPool = Pool("ARTWORK", 6, nil, content)
    local leaderPool = Pool("ARTWORK", 6, nil, content)
    local markHaloPool = Pool("ARTWORK", 7, nil, content)
    local markPool = Pool("OVERLAY", 0, nil, content)
    local markInnerPool = Pool("OVERLAY", 1, nil, content)
    -- Over the picture: the mat on the margin, the neat line, a lifted
    -- corner's shade, and the photo corners holding the card down. The
    -- shade lies over all of the print's own (PRINT_LAYERS), so a slip glued
    -- on it slopes away from the light with it.
    local glossPool = Pool("BACKGROUND", -8, nil, over)
    local matPool = Pool("BACKGROUND", 0, nil, over)
    local matGrainPool = Pool("BORDER", 0, nil, over)
    local edgePool = Pool("ARTWORK", 1, nil, over)
    local framePool = Pool("ARTWORK", 3, nil, over)
    local liftShadePool = Pool("OVERLAY", 5, nil, over)
    local cornerShadowPool = Pool("OVERLAY", 6, nil, over)
    local cornerPool = Pool("OVERLAY", 7, nil, over)
    -- The light on the corners' folds, over the pockets: a frame of its
    -- own a level up, as the pockets take the top sublevel.
    local folds = CreateFrame("Frame", nil, S)
    folds:SetAllPoints(S)
    folds:SetFrameLevel(S:GetFrameLevel() + 7)
    local foldPool = Pool("OVERLAY", 0, nil, folds)
    plate.folds = folds

    -- Font strings and hover squares, handed out like the textures. On the
    -- picture (placed about its pivot) unless given a `frame`, a `layer` and
    -- `sublevel` on it.
    local function TextPool(font, frame, layer, sublevel)
        local pool = { used = 0 }
        function pool:Begin() self.used = 0 end
        function pool:Next()
            self.used = self.used + 1
            local text = self[self.used]
            if not text then
                text = Style.Text(frame or content, font, layer)
                if sublevel then text:SetDrawLayer(layer, sublevel) end
                if not frame then text.anchorTo = pivot end
                self[self.used] = text
            end
            text:Show()
            return text
        end
        function pool:Finish()
            for i = self.used + 1, #self do self[i]:Hide() end
        end
        return pool
    end
    local numberPool = TextPool(Style.FONT.tag)

    -- Good luck told on a light plate's print (UI/LuckyCard.lua's S): a slip
    -- glued over the print's foot, over the mat and the neat line and under
    -- the lifted corner's shade and the photo corners, its parts from the
    -- slip up: its shadow and edge, its stock, the printed words, the
    -- scribble, the icon, the tag (its shadows, edge, stock, words, the
    -- underline) and the tag's tape. Each part a pool of its own.
    local PRINT_LAYERS = { shadow = { "ARTWORK", 4 }, edge = { "ARTWORK", 4 }, paper = { "ARTWORK", 5 },
        ink = { "ARTWORK", 7 }, iconShadow = { "OVERLAY", -8 }, iconEdge = { "OVERLAY", -7 }, icon = { "OVERLAY", -6 },
        tagShadow = { "OVERLAY", -4 }, tagEdge = { "OVERLAY", -3 }, tagPaper = { "OVERLAY", -2 },
        underline = { "OVERLAY", 0 }, tape = { "OVERLAY", 1 } }
    local PRINT_TEXTS = { struck = { "ARTWORK", 6 }, count = { "OVERLAY", -5 }, tagText = { "OVERLAY", -1 } }
    local printPools, printTexts = {}, {}
    for part, at in pairs(PRINT_LAYERS) do printPools[part] = Pool(at[1], at[2], nil, over) end
    for part, at in pairs(PRINT_TEXTS) do printTexts[part] = TextPool(Style.FONT.small, over, at[1], at[2]) end

    -- A hover square passes a click on to the plate: a mark is part of it.
    local hoverPool = { used = 0 }
    function hoverPool:Begin() self.used = 0 end
    function hoverPool:Next(x, y, tip, size)
        size = size or MARK.hover
        self.used = self.used + 1
        local button = self[self.used]
        if not button then
            button = CreateFrame("Button", nil, content)
            button.anchorTo = pivot
            button:EnableMouse(true)
            Style.Tooltip(button, function(b) return b.tip and b.tip() end)
            -- A press on a mark is a press on the plate: a click opens or
            -- goes back, a drag pans.
            button:SetScript("OnMouseDown", function(_, which) plate:Press(which) end)
            button:SetScript("OnMouseUp", function(_, which) plate:Release(which) end)
            -- Over a mark the plate stays leaned in (ZOOM).
            button:HookScript("OnEnter", function() plate:Lean() end)
            button:HookScript("OnLeave", function() plate:Lean() end)
            self[self.used] = button
        end
        button.tip = tip
        PlaceButton(button, x - size / 2, y - size / 2, size, size)
        button:Show()
        return button
    end
    function hoverPool:Finish()
        for i = self.used + 1, #self do
            self[i].tip = nil
            self[i]:Hide()
        end
    end

    -- For the tests: the hover squares and their tooltips.
    plate.hover = hoverPool

    -- The mouse over good luck on the print (S): the star's tooltip over
    -- the slip and its tag, the item's own over its icon (the lucky card's,
    -- HuntCard.ShowTip). Square buttons round each as drawn (they cannot
    -- turn), on the frame over the picture, so they do not lean in; a press
    -- on them is a press on the plate.
    local function PrintButton()
        local button = CreateFrame("Button", nil, over)
        button:EnableMouse(true)
        button:SetScript("OnMouseDown", function(_, which) plate:Press(which) end)
        button:SetScript("OnMouseUp", function(_, which) plate:Release(which) end)
        button:Hide()
        return button
    end
    plate.printHit, plate.printItem = PrintButton(), PrintButton()
    Style.Tooltip(plate.printHit, function()
        local s = plate.print
        return s and Tip(Text.HuntTip(s.hunt, s.now))
    end)
    plate.printItem:SetScript("OnEnter", function(self)
        if plate.print then ns.UI.HuntCard.ShowTip(self, plate.print) end
    end)
    plate.printItem:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local TEXTURES = { gluePool, shadowPool, glossPool, corePool, backgroundPool, tilePool, exploredPool,
        vignettePool, dashPool, edgePool, framePool, liftShadePool, washPool, pinPool, leaderPool,
        markHaloPool, markPool, markInnerPool, cornerShadowPool, cornerPool, foldPool, matPool, matGrainPool }
    for _, pool in ipairs(trailPools) do TEXTURES[#TEXTURES + 1] = pool end
    for _, pool in pairs(printPools) do TEXTURES[#TEXTURES + 1] = pool end
    local ALL = { numberPool, hoverPool }
    for _, pool in ipairs(TEXTURES) do ALL[#ALL + 1] = pool end
    for _, pool in pairs(printTexts) do ALL[#ALL + 1] = pool end

    ----------------------------------------------------------------------
    -- Marking the card

    -- A flat colour; a reused texture may have been a disc, tinted.
    local function Fill(texture, r, g, b, a)
        texture:SetColorTexture(r, g, b, a)
        texture:SetVertexColor(1, 1, 1, 1)
    end

    -- A round mark of `size` at x, y, lit where it lies.
    local function Dot(pool, x, y, size, colour, alpha)
        local texture = pool:Next()
        local light = Light(x, y)
        -- Without the circle art a disc is a flat square, untinted.
        texture:SetVertexColor(1, 1, 1, 1)
        Style.Disc(texture, colour[1] * light, colour[2] * light, colour[3] * light, alpha)
        Place(texture, x - size / 2, y - size / 2, size, size)
        return texture
    end

    -- A box of w by h with its middle at x, y, turned `turn` more than
    -- the card.
    local function Box(pool, x, y, w, h, colour, alpha, turn)
        local texture = pool:Next()
        local light = Light(x, y)
        Fill(texture, colour[1] * light, colour[2] * light, colour[3] * light, alpha)
        Place(texture, x - w / 2, y - h / 2, w, h, turn)
        return texture
    end

    -- A straight stroke from one point of the card to another, `width`
    -- wide: a texture as long as the gap, turned to it. On the screen y runs
    -- up and SetRotation turns counter-clockwise, so the card's y (down) is
    -- negated. A hair longer than the gap, so strokes meet.
    local function Stroke(pool, x1, y1, x2, y2, width, colour, alpha)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        if length < 0.01 then return nil end
        local texture = pool:Next()
        local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        local light = Light(mx, my)
        Fill(texture, colour[1] * light, colour[2] * light, colour[3] * light, alpha)
        Place(texture, mx - (length + 0.6) / 2, my - width / 2, length + 0.6, width, math.atan2(-dy, dx))
        return texture
    end

    -- One of the trail's primitives (UI/InkTrail.lua) on `texture`. A quad
    -- is flat ink with its corners on the card (K.Quad), or, where the
    -- client cannot move corners, a turned rectangle along its middle line:
    -- false then. A disc is the circle art, turned with its footprint.
    local function DrawPrim(prim, texture)
        if prim.k == "q" then
            local light = Light((prim.x1 + prim.x2 + prim.x3 + prim.x4) / 4, (prim.y1 + prim.y2 + prim.y3 + prim.y4) / 4)
            Fill(texture, prim.r * light, prim.g * light, prim.b * light, prim.a)
            if Quad(texture, prim.x1, prim.y1, prim.x2, prim.y2, prim.x3, prim.y3, prim.x4, prim.y4) then return true end
            -- From the middle of its start (upper and lower left) to the
            -- middle of its end, as wide as it is on average.
            local sx, sy = (prim.x1 + prim.x4) / 2, (prim.y1 + prim.y4) / 2
            local ex, ey = (prim.x2 + prim.x3) / 2, (prim.y2 + prim.y3) / 2
            local dx, dy = ex - sx, ey - sy
            local length = math.sqrt(dx * dx + dy * dy)
            local width = (math.sqrt((prim.x1 - prim.x4) ^ 2 + (prim.y1 - prim.y4) ^ 2)
                + math.sqrt((prim.x2 - prim.x3) ^ 2 + (prim.y2 - prim.y3) ^ 2)) / 2
            local mx, my = (sx + ex) / 2, (sy + ey) / 2
            Place(texture, mx - length / 2, my - width / 2, length, width, math.atan2(-dy, dx))
            return false
        end
        local light = Light(prim.x, prim.y)
        -- Without the circle art a disc is a flat square, untinted.
        texture:SetVertexColor(1, 1, 1, 1)
        Style.Disc(texture, prim.r * light, prim.g * light, prim.b * light, prim.a)
        Place(texture, prim.x - prim.rx, prim.y - prim.ry, 2 * prim.rx, 2 * prim.ry, -prim.th)
        return true
    end

    -- The marks, each drawn round x, y with the pools given (ink, and its
    -- paper inside).
    local SHAPES = {}

    -- A death: a small cross on a dot of paper.
    function SHAPES.death(ink, _, x, y, halo)
        if halo then Dot(halo, x, y, DEATH.dot, P, 0.85) end
        Box(ink, x, y + 0.5, 1.8, 8, INK_STRONG, 1)
        Box(ink, x, y - 1.5, 5.5, 1.8, INK_STRONG, 1)
    end
    -- A dungeon: the dark arch of its doorway, a round head on a square
    -- foot (never the posts and lintel, which read as a letter), as DOOR.
    function SHAPES.dungeon(ink, _, x, y)
        local d, B, D = MARK.door, DOOR.body, DOOR.head
        Box(ink, x, y + d * B.y, d * B.w, d * B.h, INK_STRONG, 1)
        Dot(ink, x, y + d * D.y, d * D.size, INK_STRONG, 1)
    end
    function SHAPES.pin(ink, _, x, y, size)
        Dot(ink, x, y, size or MARK.pin, Style.RUBRIC, 0.92)
    end
    function SHAPES.session(ink, inner, x, y)
        Dot(ink, x, y, MARK.together, INK_STRONG, 0.95)
        Dot(inner, x, y, MARK.hole, P, 1)
    end
    function SHAPES.fight(ink, _, x, y)
        local f = MARK.fight
        Stroke(ink, x - f / 2, y - f / 2, x + f / 2, y + f / 2, 2, Style.ACCENT, 1)
        Stroke(ink, x - f / 2, y + f / 2, x + f / 2, y - f / 2, 2, Style.ACCENT, 1)
    end
    -- A note: a slip, a little turned, its upper right corner folded down
    -- in paper where corners can move (no lines on it: they read as "8").
    function SHAPES.note(ink, inner, x, y)
        local w, h, f, t = MARK.note[1], MARK.note[2], MARK.fold, MARK.noteTurn
        Box(ink, x, y, w, h, INK, 0.95, t)
        -- The slip's own turn on the card, y down (Place turns it the
        -- other way on the screen, where y runs up).
        local c, s = math.cos(t), math.sin(t)
        local function At(u, v) return x + u * c + v * s, y - u * s + v * c end
        local x1, y1 = At(w / 2 - f, -h / 2)
        local xc, yc = At(w / 2, -h / 2)
        local x2, y2 = At(w / 2, -h / 2 + f)
        local fold = inner:Next()
        Fill(fold, P[1], P[2], P[3], 0.95)
        if not Quad(fold, x1, y1, xc, yc, x2, y2, x2, y2) then fold:Hide() end
    end
    -- A first sighting (JRN-23): a hollow lozenge, ink round paper. Its
    -- corners on the card where they can move; else a square turned on its
    -- point, a little smaller.
    local function Lozenge(pool, x, y, hw, hh, colour, alpha)
        local texture = pool:Next()
        Fill(texture, colour[1], colour[2], colour[3], alpha)
        if not Quad(texture, x, y - hh, x + hw, y, x, y + hh, x - hw, y) then
            local side = (hw + hh) / math.sqrt(2)
            Place(texture, x - side / 2, y - side / 2, side, side, math.pi / 4)
        end
    end
    function SHAPES.first(ink, inner, x, y)
        local hw, hh, t = MARK.first[1] / 2, MARK.first[2] / 2, MARK.line
        Lozenge(ink, x, y, hw + t, hh + t * hh / hw, INK_STRONG, 1)
        Lozenge(inner, x, y, hw, hh, P, 0.95)
    end
    -- A first found (POUCH): a drawstring pouch in `colour` (ink, or the
    -- item's ink part way), lit where it lies.
    function SHAPES.find(ink, inner, x, y, colour)
        local B, N, M, V = POUCH.body, POUCH.neck, POUCH.mouth, POUCH.notch
        colour = colour or INK_STRONG
        Dot(ink, x, y + B.y, B.size, colour, 1)
        Box(ink, x, y + (N.y0 + N.y1) / 2, N.w, N.y1 - N.y0, colour, 1)
        local light = Light(x, y)
        local mouth = ink:Next()
        Fill(mouth, colour[1] * light, colour[2] * light, colour[3] * light, 1)
        local hw, nw = M.w / 2, N.w / 2
        if Quad(mouth, x - hw, y + M.top, x + hw, y + M.top, x + nw, y + N.y0 + 0.3, x - nw, y + N.y0 + 0.3) then
            -- The ears: a nick of paper out of the mouth's middle.
            local notch = inner:Next()
            Fill(notch, P[1], P[2], P[3], 1)
            local vw = V.w / 2
            if not Quad(notch, x - vw, y + M.top - 0.2, x + vw, y + M.top - 0.2, x, y + M.top + V.depth,
                x, y + M.top + V.depth) then
                notch:Hide()
            end
        else
            Place(mouth, x - hw * 0.8, y + M.top, M.w * 0.8, N.y0 + 0.3 - M.top)
        end
    end
    -- A close call (CLOSE): the cross in ink, then its paper inside, so
    -- the outline runs round the crossing unbroken.
    function SHAPES.close(ink, inner, x, y, halo)
        local S, B, t = CLOSE.stem, CLOSE.bar, CLOSE.line
        if halo then Dot(halo, x, y, CLOSE.dot, P, 0.85) end
        Box(ink, x, y + S.y, S.w, S.h, INK_STRONG, 1)
        Box(ink, x, y + B.y, B.w, S.w, INK_STRONG, 1)
        Box(inner, x, y + S.y, S.w - 2 * t, S.h - 2 * t, P, 1)
        Box(inner, x, y + B.y, B.w - 2 * t, S.w - 2 * t, P, 1)
    end
    -- Bad luck (TALLY): four strokes leaning a little, and one across.
    function SHAPES.luck(ink, _, x, y)
        local T = TALLY
        local half = (T.count - 1) * T.gap / 2
        for i = 1, T.count do
            local u = x - half + (i - 1) * T.gap
            local h = T.h + (T.jitter[i] or 0)
            Stroke(ink, u - T.lean / 2, y + h / 2, u + T.lean / 2, y - h / 2, T.width, INK_STRONG, 1)
        end
        local reach = half + T.over
        Stroke(ink, x - reach, y + T.rise / 2, x + reach, y - T.rise / 2, T.width, INK_STRONG, 1)
    end
    -- Good luck (FORTUNE): a solid star, one kite of ink to each point.
    function SHAPES.fortune(ink, _, x, y)
        local F = FORTUNE
        local R, r = F.r, F.r * F.inner
        y = y + R * F.drop
        local light = Light(x, y)
        local c = INK_STRONG
        local function Corner(i)
            local a = -math.pi / 2 + F.turn + (i + 0.5) * 2 * math.pi / 5
            return x + r * math.cos(a), y + r * math.sin(a)
        end
        for i = 0, 4 do
            local a = -math.pi / 2 + F.turn + i * 2 * math.pi / 5
            local px, py = x + R * math.cos(a), y + R * math.sin(a)
            local bx, by = Corner(i - 1)
            local ax, ay = Corner(i)
            local kite = ink:Next()
            Fill(kite, c[1] * light, c[2] * light, c[3] * light, 1)
            if not Quad(kite, x, y, bx, by, px, py, ax, ay) then
                kite:Hide()
                Stroke(ink, x, y, px, py, F.ray, INK_STRONG, 1)
            end
        end
    end
    -- A chain's end (FINALE): two swelled rules and a full stop.
    function SHAPES.finale(ink, _, x, y)
        local F = FINALE
        local light = Light(x, y)
        local c = INK_STRONG
        for _, rule in ipairs(F.rules) do
            local ry, hw, ht = y + rule.y, rule.w / 2, rule.t / 2
            local texture = ink:Next()
            Fill(texture, c[1] * light, c[2] * light, c[3] * light, 1)
            if not Quad(texture, x - hw, ry, x, ry - ht, x + hw, ry, x, ry + ht) then
                Place(texture, x - hw * F.bar, ry - ht * F.bar, rule.w * F.bar, rule.t * F.bar)
            end
        end
        Dot(ink, x, y + F.dot[2], F.dot[1], INK_STRONG, 1)
    end
    -- A profession's cap (SKILL): the whole flight in ink, a column to
    -- each step (each a hair wider, under the taller one beside it, so no
    -- seam shows between them), then the paper inside the steps above the
    -- rank reached. The paper of each such step reaches on under the next,
    -- so the outline runs round them as one, with no wall between.
    function SHAPES.skill(ink, inner, x, y, rank)
        local S = SKILL
        local n, w, t = S.steps, S.w, S.line
        local climbed = type(rank) == "number" and Clamp(math.floor(rank / S.per), 1, n) or n
        local x0, base = x - n * w / 2, y + n * S.rise / 2
        for i = 1, n do
            local h, wide = i * S.rise, i < n and w + 0.3 or w
            Box(ink, x0 + (i - 1) * w + wide / 2, base - h / 2, wide, h, INK_STRONG, 1)
        end
        for i = climbed + 1, n do
            local h = i * S.rise
            local left, right = x0 + (i - 1) * w + t, x0 + i * w + (i < n and t or -t)
            Box(inner, (left + right) / 2, base - h / 2, right - left, h - 2 * t, P, 1)
        end
    end

    -- The paper round a mark, so it reads over the art.
    local function Halo(x, y, size, round)
        if round then
            Dot(markHaloPool, x, y, size, P, MARK.halo)
        else
            Box(markHaloPool, x, y, size, size, P, MARK.halo * 0.8)
        end
    end

    ----------------------------------------------------------------------
    -- The mount: the card's thickness and shadow, glue, a lifted corner,
    -- photo corners

    local Noise = Style.Noise

    -- What a plate's unevenness grows from: its map and its slot, so the
    -- same plate is glued the same way every time it opens.
    local function Seed()
        local s = plate.slot
        return (plate.mapID or 0) * 0.618 + (s.x or 0) * 1.37 + (s.y or 0) * 2.11 + s.w * 0.07 + s.h * 0.13
    end

    -- A texture over four points of the card (K.Quad); where the client
    -- cannot move corners, the box x, y, w, h placed whole instead. Says
    -- which it was.
    local function QuadOr(texture, x1, y1, x2, y2, x3, y3, x4, y4, x, y, w, h)
        if Quad(texture, x1, y1, x2, y2, x3, y3, x4, y4) then return true end
        Place(texture, x, y, w, h)
        return false
    end

    -- How high the card stands at a point of its edge: a lifted corner's
    -- LIFT.height, falling to nothing over LIFT.reach along either edge
    -- that meets there; 0 where it is glued.
    local function Height(x, y)
        local s = plate.slot
        if not s.lift then return 0 end
        local d = math.max(math.abs(x - (s.lift == "br" and s.w or 0)), math.abs(y - s.h))
        return LIFT.height * math.max(0, 1 - d / LIFT.reach)
    end

    -- How far out the shadow falls at a height, and how far it blurs.
    local function Fall(h)
        return SHADOW.out + SHADOW.gain * h, SHADOW.blur + SHADOW.spread * h
    end

    -- Where along an edge `length` long the card's height changes: its two
    -- ends, and where a lifted corner's reach ends (`at` the start or the
    -- end of the edge, or nil).
    local function Stations(length, at)
        local reach = math.min(LIFT.reach, length)
        if at == "end" then return { 0, length - reach, length } end
        if at == "start" then return { 0, reach, length } end
        return { 0, length }
    end

    -- The card's shadow on the page (SHADOW): a soft band and a core
    -- along its bottom and its right edge, in pieces between the stations,
    -- each piece's ends falling from their height. The bands meet on a
    -- mitre at the bottom right; their other ends start in a slant. A
    -- piece is a gradient across (soft) or along (core) and turns with the
    -- card. Returns how many pieces stand off the page (a lifted corner's).
    local function CastShadow(W, H)
        local lift, I, C = plate.slot.lift, INK, SHADOW.core
        local c = C.out
        local lifted = 0

        -- A point of an edge's soft band, from a station: its inner end
        -- (under the card) and its outer end, out and blurred.
        local function BottomSoft(x, first, last)
            local d, b = Fall(Height(x, H))
            if last then return W - 1, H - 1, W + d + b, H + d + b, d + b end
            if first then return d + b, H - 1, d, H + d + b, d + b end
            return x + d, H - 1, x + d, H + d + b, d + b
        end
        local function RightSoft(y, first, last)
            local d, b = Fall(Height(W, y))
            if last then return W - 1, H - 1, W + d + b, H + d + b, d + b end
            if first then return W - 1, d + b, W + d + b, d, d + b end
            return W - 1, y + d, W + d + b, y + d, d + b
        end
        -- The core where the card touches: as dark as it touches.
        local function Touch(x, y)
            return C.alpha * (1 - Height(x, y) / LIFT.height)
        end
        local function BottomCore(x, first, last)
            if last then return W - 1, H - 1, W + c, H + c end
            if first then return 0.5 + c, H - 1, 0.5, H + c end
            return x, H - 1, x, H + c
        end
        local function RightCore(y, first, last)
            if last then return W - 1, H - 1, W + c, H + c end
            if first then return W - 1, 0.5 + c, W + c, 0.5 end
            return W - 1, y, W + c, y
        end

        -- Along the bottom.
        local xs = Stations(W, lift == "br" and "end" or lift == "bl" and "start" or nil)
        for k = 1, #xs - 1 do
            local first, last = k == 1, k == #xs - 1
            local ix1, iy1, ox1, oy1, r1 = BottomSoft(xs[k], first, false)
            local ix2, iy2, ox2, oy2, r2 = BottomSoft(xs[k + 1], false, last)
            local soft = shadowPool:Next()
            -- VERTICAL runs from the bottom up: clear outside, dark inside.
            Style.Shade(soft, "VERTICAL", I[1], I[2], I[3], 0, SHADOW.alpha)
            QuadOr(soft, ix1, iy1, ix2, iy2, ox2, oy2, ox1, oy1,
                ox1, H - 1, (last and ox2 or ix2) - ox1, math.max(r1, r2) + 1)
            local a1, a2 = Touch(xs[k], H), Touch(xs[k + 1], H)
            local jx1, jy1, px1, py1 = BottomCore(xs[k], first, false)
            local jx2, jy2, px2, py2 = BottomCore(xs[k + 1], false, last)
            local core = corePool:Next()
            Style.Shade(core, "HORIZONTAL", I[1], I[2], I[3], a1, a2)
            QuadOr(core, jx1, jy1, jx2, jy2, px2, py2, px1, py1, px1, H - 1, px2 - px1, c + 1)
            if Height(xs[k], H) > 0 or Height(xs[k + 1], H) > 0 then lifted = lifted + 2 end
        end

        -- Down the right side.
        local ys = Stations(H, lift == "br" and "end" or nil)
        for k = 1, #ys - 1 do
            local first, last = k == 1, k == #ys - 1
            local ix1, iy1, ox1, oy1, r1 = RightSoft(ys[k], first, false)
            local ix2, iy2, ox2, oy2, r2 = RightSoft(ys[k + 1], false, last)
            local soft = shadowPool:Next()
            Style.Shade(soft, "HORIZONTAL", I[1], I[2], I[3], SHADOW.alpha, 0)
            QuadOr(soft, ix1, iy1, ox1, oy1, ox2, oy2, ix2, iy2,
                W - 1, oy1, math.max(r1, r2) + 1, (last and H - 1 or oy2) - oy1)
            local a1, a2 = Touch(W, ys[k]), Touch(W, ys[k + 1])
            local jx1, jy1, px1, py1 = RightCore(ys[k], first, false)
            local jx2, jy2, px2, py2 = RightCore(ys[k + 1], false, last)
            local core = corePool:Next()
            -- From the bottom (the later station) up.
            Style.Shade(core, "VERTICAL", I[1], I[2], I[3], a2, a1)
            QuadOr(core, jx1, jy1, px1, py1, px2, py2, jx2, jy2, W - 1, py1, c + 1, (last and H - 1 or jy2) - py1)
            if Height(W, ys[k]) > 0 or Height(W, ys[k + 1]) > 0 then lifted = lifted + 2 end
        end
        -- For the tests: how far past the card it reaches, glued and at a
        -- lifted corner.
        local d0, b0 = Fall(0)
        local d1, b1 = Fall(lift and LIFT.height or 0)
        plate.reach = { glued = d0 + b0, lifted = d1 + b1 }
        return lifted
    end

    -- The card's thickness (THICKNESS): its top and left cut edges catching
    -- the light, on the cut (`at`), its bottom and right edges in shade, a
    -- line inside each.
    local function Edges(W, H)
        local E = THICKNESS
        local w, L, a = E.width, E.light, E.at or 0
        for _, e in ipairs({ { a, a, W - a - w, w, true }, { a, a + w, w, H - 2 * w - a, true }, { 0, H - w, W, w },
            { W - w, w, w, H - 2 * w } }) do
            local texture = edgePool:Next()
            if e[5] then
                Fill(texture, L[1], L[2], L[3], E.lightAlpha)
            else
                Fill(texture, INK[1], INK[2], INK[3], E.darkAlpha)
            end
            Place(texture, e[1], e[2], e[3], e[4])
        end
    end

    -- A photo corner's triangle on the card, in K.Quad's order: two of its
    -- corners on one point.
    local function CornerAt(which, W, H, size)
        local o = MOUNT.out
        if which == "tl" then return -o, -o, size - o, -o, -o, size - o, -o, size - o end
        if which == "tr" then return W - size + o, -o, W + o, -o, W + o, size - o, W + o, size - o end
        if which == "bl" then return -o, H - size + o, -o, H - size + o, size - o, H + o, -o, H + o end
        return W + o, H - size + o, W + o, H - size + o, W + o, H + o, W - size + o, H + o
    end

    -- A corner's fold, its diagonal: the two ends, and which way it faces
    -- (toward the print's middle), as a unit vector, y down.
    local R2 = math.sqrt(0.5)
    local function FoldAt(which, W, H, size)
        local x1, y1, x2, y2, x3, y3, x4, y4 = CornerAt(which, W, H, size)
        if which == "tl" then return x2, y2, x3, y3, R2, R2 end
        if which == "tr" then return x1, y1, x3, y3, -R2, R2 end
        if which == "bl" then return x1, y1, x3, y3, R2, -R2 end
        return x1, y1, x4, y4, -R2, -R2
    end

    -- Where corners cannot move: an L of two strips along its outer edges.
    local function CornerStrips(which, W, H, size, dx, dy, colour, alpha, pool)
        local o, t = MOUNT.out, MOUNT.strip
        local left = (which == "tl" or which == "bl") and -o or W + o - size
        local top = (which == "tl" or which == "tr") and -o or H + o - size
        local hy = (which == "tl" or which == "tr") and -o or H + o - t
        local vx = (which == "tl" or which == "bl") and -o or W + o - t
        for _, strip in ipairs({ { left, hy, size, t }, { vx, top, t, size } }) do
            local texture = pool:Next()
            Fill(texture, colour[1], colour[2], colour[3], alpha)
            Place(texture, strip[1] + dx, strip[2] + dy, strip[3], strip[4])
        end
    end

    -- A photo corner (MOUNT): its shadow, the kraft pocket a shade of its
    -- own, and the light on its fold, by how the fold faces the top-left
    -- light. Laid flat, the pocket alone.
    local function Corner(which, W, H, pc, flat, seed)
        local size = pc * MOUNT.scale
        local x1, y1, x2, y2, x3, y3, x4, y4 = CornerAt(which, W, H, size)
        local sh, M = MOUNT.shadow, MOUNT.ink
        local tone = 1 + (Noise(seed) - 0.5) * 2 * MOUNT.uneven
        local layers = { { cornerPool, 0, 0, { M[1] * tone, M[2] * tone, M[3] * tone }, MOUNT.alpha } }
        if not flat then table.insert(layers, 1, { cornerShadowPool, sh[1], sh[2], MOUNT.shade, sh[3] }) end
        for _, l in ipairs(layers) do
            local pool, dx, dy, colour, alpha = l[1], l[2], l[3], l[4], l[5]
            if view.canBend then
                local texture = pool:Next()
                Fill(texture, colour[1], colour[2], colour[3], alpha)
                Quad(texture, x1 + dx, y1 + dy, x2 + dx, y2 + dy, x3 + dx, y3 + dy, x4 + dx, y4 + dy)
            else
                CornerStrips(which, W, H, size, dx, dy, colour, alpha, pool)
            end
        end
        if flat or not view.canBend then return end
        -- The fold: a line just inside the diagonal, its ends drawn in so
        -- it stays on the pocket as it narrows to its tips.
        local ax, ay, bx, by, nx, ny = FoldAt(which, W, H, size)
        local f = MOUNT.fold
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local ux, uy = (bx - ax) / len, (by - ay) / len
        ax, ay, bx, by = ax + ux * f * 1.5, ay + uy * f * 1.5, bx - ux * f * 1.5, by - uy * f * 1.5
        -- Facing the light at the top left (-1, -1): 1; away: -1.
        local facing = (-nx - ny) * R2
        local L = MOUNT.light
        local fold = foldPool:Next()
        Fill(fold, L[1], L[2], L[3], MOUNT.lo + (MOUNT.hi - MOUNT.lo) * (facing + 1) / 2)
        Quad(fold, ax - nx * f, ay - ny * f, bx - nx * f, by - ny * f, bx, by, ax, ay)
    end

    -- A lifted corner's shade on the card: two soft edges crossing at the
    -- corner, darkest where they meet.
    local function LiftShade(which, W, H)
        local bw, bh = LIFT.box[1], LIFT.box[2]
        local a = LIFT.shade[which] / 2
        local x = which == "br" and W - bw or 0
        local across = liftShadePool:Next()
        Style.Shade(across, "HORIZONTAL", INK[1], INK[2], INK[3], which == "br" and 0 or a, which == "br" and a or 0)
        Place(across, x, H - bh, bw, bh)
        local down = liftShadePool:Next()
        Style.Shade(down, "VERTICAL", INK[1], INK[2], INK[3], a, 0)
        Place(down, x, H - bh, bw, bh)
    end

    -- A point `u` along a side and `v` out from it (GLUE): the card's
    -- edge at v = 0, the page beyond.
    local function Out(side, u, v, W, H)
        if side == "top" then return u, -v end
        if side == "bottom" then return u, H + v end
        if side == "left" then return -v, u end
        return W + v, u
    end

    -- One bead of glue: two halves, each a taper from a hair at its end to
    -- `fat` px at its middle, fading in toward the middle; and a gloss
    -- down its middle, brightest toward the light (the left, or the top).
    -- Where corners cannot move, each half is a box half as fat.
    local function Bead(side, mid, length, fat, alpha, W, H)
        local T, across = GLUE.tint, side == "top" or side == "bottom"
        local half = length / 2
        for k = 0, 1 do
            local u0, u1 = mid - half + k * half, mid + k * half
            local t0, t1 = k == 0 and 0.3 or fat, k == 0 and fat or 0.3
            local bead = gluePool:Next()
            local from, to = k == 0 and 0 or alpha, k == 0 and alpha or 0
            local x1, y1 = Out(side, u0, -0.5, W, H)
            local x2, y2 = Out(side, u1, -0.5, W, H)
            local x3, y3 = Out(side, u1, t1, W, H)
            local x4, y4 = Out(side, u0, t0, W, H)
            if view.canBend then
                Style.Shade(bead, "HORIZONTAL", T[1], T[2], T[3], from, to)
                Quad(bead, x1, y1, x2, y2, x3, y3, x4, y4)
            elseif across then
                Style.Shade(bead, "HORIZONTAL", T[1], T[2], T[3], from, to)
                Place(bead, u0, side == "top" and -fat / 2 or H, half, fat / 2)
            else
                -- VERTICAL runs from the bottom up.
                Style.Shade(bead, "VERTICAL", T[1], T[2], T[3], to, from)
                Place(bead, side == "left" and -fat / 2 or W, u0, fat / 2, half)
            end
        end
        local G = GLUE.gloss
        local g = length * G.length
        local gloss = glossPool:Next()
        local gx, gy = Out(side, mid - g / 2, fat * 0.4 + G.width / 2, W, H)
        if across then
            Style.Shade(gloss, "HORIZONTAL", G.tint[1], G.tint[2], G.tint[3], G.alpha, 0)
            Place(gloss, gx, gy - G.width, g, G.width)
        else
            Style.Shade(gloss, "VERTICAL", G.tint[1], G.tint[2], G.tint[3], 0, G.alpha)
            Place(gloss, side == "left" and gx or gx - G.width, gy, G.width, g)
        end
    end

    -- Glue squeezed out from under the card (GLUE): a few beads, where and
    -- how long, fat and dark each by the plate's seed.
    local function Glue(W, H, seed)
        local G = GLUE
        local count = G.count[1] + math.floor(Noise(seed) * (G.count[2] - G.count[1] + 1))
        for k = 1, count do
            local r = seed + k * 7.31
            local side = G.sides[1 + math.floor(Noise(r) * #G.sides)]
            local L = (side == "top" or side == "bottom") and W or H
            local length = L * (G.length[1] + Noise(r + 1) * (G.length[2] - G.length[1]))
            local mid = length / 2 + Noise(r + 2) * (L - length)
            local fat = G.bead[1] + Noise(r + 3) * (G.bead[2] - G.bead[1])
            local alpha = G.alpha[1] + Noise(r + 4) * (G.alpha[2] - G.alpha[1])
            -- None where a corner came unstuck: it pulled its glue away.
            local x0, y0 = Out(side, mid - length / 2, 0, W, H)
            local x1, y1 = Out(side, mid + length / 2, 0, W, H)
            if Height(x0, y0) == 0 and Height(x1, y1) == 0 then Bead(side, mid, length, fat, alpha, W, H) end
        end
    end

    -- How it is held and how it stands: its shadow, its edges, glue, a
    -- corner come unstuck, photo corners. Laid flat, only the corners,
    -- lying flat on it.
    local function DrawMount()
        local s, flat = plate.slot, view.flat
        local W, H, seed = s.w, s.h, Seed()
        local counts = plate.counts
        local glue, corners, lifted = gluePool.used + glossPool.used, cornerPool.used, 0
        plate.reach = nil
        if not flat then
            lifted = CastShadow(W, H)
            Edges(W, H)
            Glue(W, H, seed)
            if s.lift then LiftShade(s.lift, W, H) end
        end
        for i, which in ipairs(s.corners or {}) do Corner(which, W, H, s.pc or 24, flat, seed + i * 3.7) end
        -- For the tests: what holds it and how it stands.
        counts.glue, counts.gloss = gluePool.used + glossPool.used - glue, glossPool.used
        counts.lift = lifted + liftShadePool.used
        counts.corners, counts.folds = cornerPool.used - corners, foldPool.used
        counts.shadow, counts.core, counts.edges = shadowPool.used, corePool.used, edgePool.used
    end

    ----------------------------------------------------------------------
    -- The map

    local function Ink(x0, y0, x1, y1)
        Split(x0, y0, x1, y1, function(a, b, c, d, light)
            local texture = framePool:Next()
            Fill(texture, INK_STRONG[1] * light, INK_STRONG[2] * light, INK_STRONG[3] * light, FRAME.alpha)
            Bend(texture, a, b, c, d)
        end)
    end

    -- The neat line: a rule hugging the art, a gap, a hairline.
    local function PrintFrame(x0, y0, x1, y1)
        for _, ring in ipairs({ { 0, FRAME.inner }, { FRAME.inner + FRAME.gap, FRAME.outer } }) do
            local d, w = ring[1], ring[2]
            Ink(x0 - d - w, y0 - d - w, x1 + d + w, y0 - d)
            Ink(x0 - d - w, y1 + d, x1 + d + w, y1 + d + w)
            Ink(x0 - d - w, y0 - d, x0 - d, y1 + d)
            Ink(x1 + d, y0 - d, x1 + d + w, y1 + d)
        end
    end

    -- The mat: the card's stock over its margin, round the art box, so the
    -- picture leaning in never shows past the neat line. And the clip
    -- round the box the turned art covers.
    local grainPath = Style.Art("grain")
    local function Mat(ax, ay, aw, ah)
        local s = plate.slot
        local W, H = s.w, s.h
        local C = view.paper or P
        for _, r in ipairs({ { 0, 0, W, ay }, { 0, ay + ah, W, H }, { 0, ay, ax, ay + ah }, { ax + aw, ay, W, ay + ah } }) do
            local mat = matPool:Next()
            Fill(mat, C[1], C[2], C[3], 1)
            Place(mat, r[1], r[2], r[3] - r[1], r[4] - r[2])
            if grainPath then
                local grain = matGrainPool:Next()
                grain:SetTexture(grainPath)
                grain:SetVertexColor(1, 1, 1, 1)
                grain:SetAlpha(MAT.grain)
                grain:SetTexCoord(r[1] / W, r[3] / W, r[2] / H, r[4] / H)
                Place(grain, r[1], r[2], r[3] - r[1], r[4] - r[2])
            end
        end
        local a = math.abs(view.turn or 0)
        local c, sn = math.cos(a), math.sin(a)
        clip:SetSize(aw * c + ah * sn, aw * sn + ah * c)
    end

    -- The window of art into the art box (plain paper where there is none),
    -- and how a point of the map lands on the card: At(x, y) is nil off the
    -- window, or `clamped` to its edge.
    -- The print's darkened edges (VIGNETTE): a band inside each side of
    -- the art box, each side's darkness a little its own (seeded).
    local function Vignette(ax, ay, aw, ah)
        local V, T = VIGNETTE, VIGNETTE.tint
        local d, seed = V.depth * math.min(aw, ah), Seed()
        local function A(side, n)
            return V.alpha[side] * (1 + (Style.Noise(seed * 0.71 + n) - 0.5) * 2 * V.uneven)
        end
        -- Where each band went, for Unscale to keep it there.
        local Place = function(t, x, y, w, h)
            Place(t, x, y, w, h)
            local sx, sy = K.Screen(x + w / 2, y + h / 2)
            t.home = { sx, sy, w, h }
        end
        -- VERTICAL runs from the bottom up.
        local top = vignettePool:Next()
        Style.Shade(top, "VERTICAL", T[1], T[2], T[3], 0, A("top", 1))
        Place(top, ax, ay, aw, d)
        local bottom = vignettePool:Next()
        Style.Shade(bottom, "VERTICAL", T[1], T[2], T[3], A("bottom", 2), 0)
        Place(bottom, ax, ay + ah - d, aw, d)
        local left = vignettePool:Next()
        Style.Shade(left, "HORIZONTAL", T[1], T[2], T[3], A("left", 3), 0)
        Place(left, ax, ay, d, ah)
        local right = vignettePool:Next()
        Style.Shade(right, "HORIZONTAL", T[1], T[2], T[3], 0, A("right", 4))
        Place(right, ax + aw - d, ay, d, ah)
    end

    -- Whether the client can draw a texture part way to grey (PLATE):
    -- asked under pcall, as a build without the method may raise on it.
    local probe = K.Texture("BORDER", 0)
    local asked, desaturate = pcall(function() return probe.SetDesaturation end)
    plate.canDesaturate = asked and type(desaturate) == "function"
    probe:Hide()

    local function DrawArt(mapID, window, box)
        local s = plate.slot
        local ax, ay, aw, ah = s.pad, s.pad, s.w - 2 * s.pad, s.h - 2 * s.pad
        PrintFrame(ax, ay, ax + aw, ay + ah)
        Mat(ax, ay, aw, ah)
        if not view.flat then Vignette(ax, ay, aw, ah) end
        -- The window's art may reach past the art box (`box`, a full page
        -- drawn with room to pan): under the card's margin, clipped.
        if box then ax, ay, aw, ah = box[1], box[2], box[3], box[4] end
        local layer, pieces = ns.UI.MapArt.For(mapID)
        local LW, LH = LayerSize(mapID)
        if layer then LW, LH = layer.layerWidth, layer.layerHeight end

        local B = Style.MAP_BACKGROUND
        Split(ax, ay, ax + aw, ay + ah, function(x0, y0, x1, y1, light)
            local texture = backgroundPool:Next()
            Fill(texture, B[1] * light, B[2] * light, B[3] * light, 1)
            Bend(texture, x0, y0, x1, y1, true)
        end, box ~= nil)

        local wx0, wy0, wx1, wy1 = window[1], window[2], window[3], window[4]
        local tiles, explored = 0, 0
        -- Printed, not shown: drawn part way to grey and toned, or toned
        -- harder where the client cannot desaturate (PLATE).
        local grey = plate.canDesaturate
        if layer then
            tiles, explored = ns.UI.MapArt.Print(layer, pieces, { wx0 * LW, wy0 * LH, wx1 * LW, wy1 * LH }, ax, ay, aw,
                grey and PLATE.tint or PLATE.plain, K, tilePool, exploredPool, box ~= nil)
            for _, pool in ipairs({ tilePool, exploredPool }) do
                for i = 1, pool.used do
                    local piece = pool[i]
                    if grey then piece:SetDesaturation(PLATE.desaturate) end
                end
            end
        end
        plate.toned = grey and "desaturated" or "tinted"
        plate.tileCount, plate.exploredCount = tiles, explored
        plate.hasArt = layer ~= nil

        local sx, sy = aw / (wx1 - wx0), ah / (wy1 - wy0)
        local function At(x, y, clamped)
            if not x or not y then return nil end
            local u, v = (x - wx0) * sx, (y - wy0) * sy
            if u < -EDGE or u > aw + EDGE or v < -EDGE or v > ah + EDGE then
                if not clamped then return nil end
                u, v = Clamp(u, 0, aw), Clamp(v, 0, ah)
            end
            return ax + u, ay + v
        end
        plate.At, plate.fullW, plate.fullH = At, sx, sy
        plate.box = { ax, ay, ax + aw, ay + ah }
        return At, sx, sy
    end

    ----------------------------------------------------------------------
    -- The road

    -- Marks never touch (MARK): each claims a disc, its radius `r` and
    -- MARK.clear round it. One landing on another steps out: along `ax`,
    -- `ay` (a unit vector) when given, so a mark beside a pool only ever
    -- moves further out from it; else to the first free place on rings
    -- round where it belongs, up and to the right first. Moved past its
    -- size, it is tethered back by a graphite hairline.
    local spots = {}
    local function Clear(x, y, r)
        for _, s in ipairs(spots) do
            local dx, dy = s[1] - x, s[2] - y
            local d = r + s[3] + MARK.clear
            if dx * dx + dy * dy < d * d then return false end
        end
        return true
    end

    local function Tether(x0, y0, x, y, r)
        local dx, dy = x - x0, y - y0
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= r + 1 then return end
        local G = Style.GRAPHITE
        Stroke(leaderPool, x0, y0, x - dx / d * r, y - dy / d * r, MARK.tether[1], G, MARK.tether[2])
    end

    local function Apart(x, y, r, ax, ay)
        r = r or MARK.together / 2
        local x0, y0 = x, y
        if not Clear(x, y, r) then
            local found
            for ring = 1, MARK.tries do
                if ax then
                    local tx, ty = x0 + ax * MARK.step * ring, y0 + ay * MARK.step * ring
                    if Clear(tx, ty, r) then found = { tx, ty } end
                else
                    for k = 0, 7 do
                        local a = -math.pi / 4 + k * math.pi / 4
                        local tx, ty = x0 + math.cos(a) * MARK.step * ring, y0 + math.sin(a) * MARK.step * ring
                        if Clear(tx, ty, r) then
                            found = { tx, ty }
                            break
                        end
                    end
                end
                if found then break end
            end
            if found then
                x, y = found[1], found[2]
                Tether(x0, y0, x, y, r)
            end
        end
        spots[#spots + 1] = { x, y, r }
        return x, y
    end
    -- For the tests: where the marks went, and how much room each took.
    plate.spots = spots
    -- The death crosses drawn: { x, y (on the card), segs (the stops or
    -- the road it marks), count }, each given the deaths kept with their
    -- killers that fell in it (UI/KillerCard.lua's Match).
    local crosses = {}
    plate.crosses = crosses

    -- A stop's kind, for the trail.
    local function KindOf(seg)
        return Text.StopKind(seg) or "stayed"
    end

    -- The open entry's trail (UI/InkTrail.lua) from the stops in the window
    -- and the pieces of its roads, each primitive from its layer's pool;
    -- then a death's cross beside a pool, at its upper left, outside its
    -- footprint. Returns the pools, longest first.
    local function DrawTrail(sheet, entry, At, fullW, fullH, pxPerYard, opts)
        local window = plate.window
        local stops, roads = {}, {}
        for _, seg in ipairs(sheet.stops) do
            if During(seg.from, seg.to, entry) and At(seg.x, seg.y) then stops[#stops + 1] = seg end
        end
        for _, road in ipairs(sheet.roads) do
            if During(road.from, road.to, entry) then Pieces(road, window, roads) end
        end

        local box = { at = function(x, y) return At(x, y) end, fullW = fullW, fullH = fullH, pxPerYard = pxPerYard }
        local prims, built, pools = Trail.Build({ stops = stops, roads = roads }, box,
            { points = ns.Journey.Points, kind = KindOf, cap = opts.cap })
        -- Ink the window's edge would cut is left off (SPILL).
        local b = plate.box
        local function Inside(prim)
            local x0, y0, x1, y1
            if prim.k == "q" then
                x0, x1 = math.min(prim.x1, prim.x2, prim.x3, prim.x4), math.max(prim.x1, prim.x2, prim.x3, prim.x4)
                y0, y1 = math.min(prim.y1, prim.y2, prim.y3, prim.y4), math.max(prim.y1, prim.y2, prim.y3, prim.y4)
            else
                local r = math.max(prim.rx, prim.ry)
                x0, y0, x1, y1 = prim.x - r, prim.y - r, prim.x + r, prim.y + r
            end
            return x0 >= b[1] - SPILL and y0 >= b[2] - SPILL and x1 <= b[3] + SPILL and y1 <= b[4] + SPILL
        end
        local fallback, cut = 0, 0
        for _, prim in ipairs(prims) do
            if Inside(prim) then
                local pool = (prim.k == "q" and trailQuads or trailDiscs)[prim.layer]
                if not DrawPrim(prim, pool:Next()) then fallback = fallback + 1 end
            else
                cut = cut + 1
            end
        end

        local D = 0.7071
        for _, pool in ipairs(pools) do
            local e = pool.e
            if pool.drawn and pool.deaths > 0 then
                local d = Trail.Extent(e, -D, -D) + DEATH.gap
                pool.cx, pool.cy = Apart(e.x - d * D, e.y - d * D, DEATH.dot / 2, -D, -D)
                SHAPES.death(markInnerPool, nil, pool.cx, pool.cy, markHaloPool)
                crosses[#crosses + 1] = { x = pool.cx, y = pool.cy, segs = pool.segs or { pool.seg },
                    count = pool.deaths }
            end
        end

        local counts = plate.counts
        for _, key in ipairs({ "quads", "dots", "dabs", "pools", "droplets", "stops", "roads", "step" }) do
            counts[key] = built[key]
        end
        counts.areas, counts.fallback, counts.cut = #pools, fallback, cut
        -- For the tests: the pools and the primitives drawn.
        plate.pools, plate.areas, plate.prims = pools, pools, prims
        return pools
    end

    -- A flight's end in the window, its other end where the client can say
    -- (ns.ProjectMapPos), the dashes between cut at the window's edge, in
    -- red-brown: the open entry's only.
    local function DrawFlights(flights, mapID, At, entry, now)
        local shown, dashes = 0, 0
        local step = FLIGHT.dash + FLIGHT.gap
        local w = plate.window
        for i = 1, math.min(#flights, CAP.flights) do
            local seg = flights[i]
            local hx, hy, other, ox, oy
            if seg.mapID1 == mapID and seg.x1 then
                hx, hy, other, ox, oy = seg.x1, seg.y1, seg.mapID2, seg.x2, seg.y2
            elseif seg.mapID2 == mapID and seg.x2 then
                hx, hy, other, ox, oy = seg.x2, seg.y2, seg.mapID1, seg.x1, seg.y1
            end
            if hx and During(seg.from, seg.to, entry) then
                local tx, ty
                if ox and other ~= mapID then
                    tx, ty = ns.ProjectMapPos(other, mapID, ox, oy)
                elseif ox then
                    tx, ty = ox, oy
                end
                if tx then
                    local cx1, cy1, cx2, cy2 = Clip(hx, hy, tx, ty, w[1], w[2], w[3], w[4])
                    if cx1 then
                        local ax, ay = At(cx1, cy1, true)
                        local bx, by = At(cx2, cy2, true)
                        local dx, dy = bx - ax, by - ay
                        local length = math.sqrt(dx * dx + dy * dy)
                        local d = 0
                        while d < length and dashes < CAP.dashes do
                            local t1, t2 = d / length, math.min(d + FLIGHT.dash, length) / length
                            Stroke(dashPool, ax + dx * t1, ay + dy * t1, ax + dx * t2, ay + dy * t2,
                                FLIGHT.width, Style.ACCENT, FLIGHT.alpha)
                            dashes = dashes + 1
                            d = d + step
                        end
                    end
                end
                -- Its end here: a small red-brown ring.
                local ends = { { hx, hy } }
                if other == mapID and seg.mapID1 == mapID and seg.mapID2 == mapID and seg.x2 then
                    ends[2] = { seg.x2, seg.y2 }
                end
                for k, at in ipairs(ends) do
                    local x, y = At(at[1], at[2])
                    if x then
                        if k == 1 then shown = shown + 1 end
                        x, y = Apart(x, y, FLIGHT.ring / 2 + 1)
                        Halo(x, y, FLIGHT.ring + 4, true)
                        Dot(markPool, x, y, FLIGHT.ring, Style.ACCENT, 0.95)
                        Dot(markInnerPool, x, y, FLIGHT.ring - 4, P, 1)
                        if k == 1 then hoverPool:Next(x, y, function() return Tip(Text.Flight(seg, mapID, now)) end) end
                    end
                end
            end
        end
        plate.counts.flights, plate.counts.dashes = shown, dashes
    end

    -- A page point for a point of the card: through the card's turn, from
    -- its middle on the page.
    local function OnPage(x, y)
        local s = plate.slot
        local X, Y = K.Screen(x, y)
        return s.x + s.w / 2 + X, s.y + s.h / 2 - Y
    end
    plate.SheetToPage = function(_, x, y) return OnPage(x, y) end

    ----------------------------------------------------------------------
    -- Drawing

    -- How much room a mark of `kind` claims (Apart's radius).
    local function Radius(kind)
        if kind == "fight" then return MARK.fight / 2 + 1 end
        if kind == "note" then return MARK.note[2] / 2 + 1 end
        if kind == "first" then return MARK.first[2] / 2 + 1 end
        if kind == "dungeon" then return MARK.door / 2 + 1 end
        if kind == "find" then return POUCH.height / 2 + 1 end
        if kind == "close" then return CLOSE.stem.h / 2 + 1 end
        if kind == "luck" then return TALLY.h / 2 + 2 end
        if kind == "fortune" then return FORTUNE.r + 1 end
        if kind == "finale" then return FINALE.rules[1].w / 2 end
        if kind == "skill" then return SKILL.steps * SKILL.w / 2 + 1 end
        return MARK.together / 2 + 1
    end

    -- A level's pin at x, y: a disc as wide as its number, the number on
    -- it, stepped clear of the marks already down, on a wash of paper. The
    -- level reached in rubric, its number light; where the level began
    -- (`start`) ink round paper, its number in ink. Returns where it went.
    local function Pin(pin, x, y, now, start)
        local number = numberPool:Next()
        number:SetText(tostring(pin.level))
        local size = math.max(MARK.pin, Width(number) + MARK.pinPad)
        x, y = Apart(x, y, size / 2)
        Dot(washPool, x, y, size + 4, P, MARK.halo)
        local text = Style.TAG_TEXT
        if start then
            Dot(pinPool, x, y, size, INK_STRONG, 0.92)
            Dot(markHaloPool, x, y, size - 2 * PIN.ring, P, 1)
            text = INK_STRONG
        else
            SHAPES.pin(pinPool, nil, x, y, size)
        end
        number:SetTextColor(text[1], text[2], text[3])
        PlaceText(number, x, y, "CENTER")
        hoverPool:Next(x, y, function() return Tip(Text.Pin(pin, now)) end)
        return x, y
    end

    -- A meeting's or a first sighting's tooltip: a title and its lines.
    local function MomentTip(m, entry, now, fights)
        if m.kind == "first" then return Text.FirstSeen(m.first or m, now) end
        return Text.Meeting({ kind = m.kind, t = m.t, session = m.session, mark = m.mark, note = m.note,
            level = entry and entry.level }, now, fights)
    end

    -- The marks of what happened in the open entry (Recap.Moments), in
    -- ink: dungeons, the levels reached, then the people's marks. People
    -- met on one spot share one mark (MARK.merge), the likeliest to matter
    -- on top (PRIORITY) and its tooltip telling the rest. Each person's
    -- moment's mark is kept on the page (plate.where) for the margin
    -- notes' leaders.
    local PEOPLE = { session = true, fight = true, note = true, first = true }

    local function DrawMoments(sheet, moments, mapID, At, pools, entry, now, fights)
        local counts = plate.counts
        local where, people = {}, {}
        plate.where, plate.people = where, people
        local here = {}
        for _, m in ipairs(moments or {}) do
            if m.mapID == mapID and During(m.t, m.t, entry) then
                local x, y = At(m.x, m.y)
                if x then here[#here + 1] = { m = m, x = x, y = y } end
            end
        end

        -- Dungeons: the arch of their door; their name is in its tooltip.
        local doors = 0
        for _, h in ipairs(here) do
            if h.m.kind == "dungeon" and doors < CAP.dungeons then
                doors = doors + 1
                local seg = h.m.seg
                local x, y = Apart(h.x, h.y, Radius("dungeon"))
                Halo(x, y, MARK.door + 5, true)
                SHAPES.dungeon(markPool, markInnerPool, x, y)
                hoverPool:Next(x, y, function() return Tip(Text.Dungeon(seg, now)) end)
            end
        end

        -- The levels reached in its time (the entry's own, and in a week
        -- past the cap any other), and the next level reached, where a
        -- level's entry ends: the level's road from pin to pin. A level's
        -- own pin is where it began; the rubric marks a level reached.
        -- A pin on a pool moves out past its
        -- footprint (away from its middle, up and right from a pin right
        -- on it), with a short leader back, so it never hides the pool.
        local pins, moved = 0, 0
        plate.pinMarks = {}
        for i = 1, #sheet.pins do
            local pin = sheet.pins[i]
            local x, y = At(pin.x, pin.y)
            local inside = During(pin.at, pin.at, entry)
            local out = entry and entry.out and entry.out.level == pin.level
            local start = inside and entry and entry.kind == "level"
            if x and (inside or out) and pins < CAP.pins then
                pins = pins + 1
                local host
                for _, pool in ipairs(pools) do
                    local e = pool.e
                    local dx, dy = x - e.x, y - e.y
                    local d = math.sqrt(dx * dx + dy * dy)
                    local edge = d < 0.5 and e.a1 or Trail.Extent(e, dx / d, dy / d)
                    if pool.drawn and d < edge + MARK.pin / 2 + 2
                        and (not host or e.a1 * e.a2 > host.e.a1 * host.e.a2) then
                        host = pool
                    end
                end
                if host then
                    local e = host.e
                    local dx, dy = x - e.x, y - e.y
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d < 1 then dx, dy, d = 1, -1, math.sqrt(2) end
                    dx, dy = dx / d, dy / d
                    local edge = Trail.Extent(e, dx, dy)
                    local reach = edge + PIN.gap + MARK.pin / 2
                    x, y = e.x + dx * reach, e.y + dy * reach
                    Stroke(leaderPool, e.x + dx * edge, e.y + dy * edge, x - dx * MARK.pin / 2,
                        y - dy * MARK.pin / 2, PIN.leader, start and INK_STRONG or Style.RUBRIC, PIN.leaderAlpha)
                    moved = moved + 1
                end
                x, y = Pin(pin, x, y, now, start)
                plate.pinMarks[#plate.pinMarks + 1] = { pin = pin, x = x, y = y, host = host, start = start }
            end
        end

        -- The people's spots: moments within MARK.merge of each other are
        -- one spot.
        local spotsOf, deaths = {}, {}
        for _, h in ipairs(here) do
            local m = h.m
            if PEOPLE[m.kind] then
                local into
                for _, c in ipairs(spotsOf) do
                    if math.abs(c.x - h.x) <= MARK.merge and math.abs(c.y - h.y) <= MARK.merge then
                        into = c
                        break
                    end
                end
                if not into and #spotsOf < CAP.meetings then
                    into = { x = h.x, y = h.y, list = {} }
                    spotsOf[#spotsOf + 1] = into
                end
                if into then into.list[#into.list + 1] = m end
            elseif m.kind == "death" and m.seg and m.seg.kind ~= "stop" then
                deaths[#deaths + 1] = h
            end
        end

        local meetings, firsts, marks = 0, 0, 0
        for _, c in ipairs(spotsOf) do
            -- What is on it, each once (a session's people share it), the
            -- likeliest to matter first.
            local seen, what = {}, {}
            for _, m in ipairs(c.list) do
                local key = m.session or m.mark or m.note or m.first or m
                if not seen[key] then
                    seen[key] = true
                    what[#what + 1] = m
                    if m.kind == "first" then firsts = firsts + 1 else meetings = meetings + 1 end
                end
            end
            table.sort(what, function(a, b)
                local pa, pb = PRIORITY[a.kind] or 9, PRIORITY[b.kind] or 9
                if pa ~= pb then return pa < pb end
                return a.t < b.t
            end)
            local top = what[1]
            local x, y = Apart(c.x, c.y, Radius(top.kind))
            marks = marks + 1
            if top.kind == "first" then
                Halo(x, y, MARK.first[2] + 5, true)
            else
                Halo(x, y, (top.kind == "note" and 14 or MARK.together) + 4, true)
            end
            SHAPES[top.kind](markPool, markInnerPool, x, y)
            hoverPool:Next(x, y, function()
                local list = Tip(MomentTip(top, entry, now, fights)) or {}
                for k = 2, #what do
                    local title, lines = MomentTip(what[k], entry, now, fights)
                    if title and title ~= "" then list[#list + 1] = { title } end
                    for _, line in ipairs(lines or {}) do list[#list + 1] = { line, 1, 1, 1, true } end
                end
                return #list > 0 and list or nil
            end)
            local px, py = OnPage(x, y)
            for _, m in ipairs(c.list) do
                where[m] = { px, py, x = x, y = y }
                people[#people + 1] = m
            end
        end

        -- The firsts found (JRN-24): a pouch where each was found, firsts
        -- on one spot (a green bag is a first bag and a first green) one
        -- pouch, in the ink of the best of them, its tooltip telling each.
        -- A gift from someone in the diary is that person's moment as well:
        -- kept with their marks (plate.where), so it joins their margin
        -- note ("gave you your first blue") and its leader may come here.
        local found, pouches = {}, 0
        plate.findMarks = {}
        for _, h in ipairs(here) do
            if h.m.kind == "find" then
                local into
                for _, c in ipairs(found) do
                    if math.abs(c.x - h.x) <= MARK.merge and math.abs(c.y - h.y) <= MARK.merge then
                        into = c
                        break
                    end
                end
                if not into and #found < CAP.finds then
                    into = { x = h.x, y = h.y, list = {} }
                    found[#found + 1] = into
                end
                if into then into.list[#into.list + 1] = h.m end
            end
        end
        local function Quality(m)
            local rec = m.find or m
            return math.max(FIND_QUALITY[m.what] or 0, ns.Timeline.Quality(rec.link) or 0)
        end
        for _, c in ipairs(found) do
            table.sort(c.list, function(a, b)
                local qa, qb = Quality(a), Quality(b)
                if qa ~= qb then return qa > qb end
                return a.t < b.t
            end)
            local list = c.list
            local x, y = Apart(c.x, c.y, Radius("find"))
            pouches = pouches + 1
            Halo(x, y, POUCH.height + 4, true)
            local colour = INK_STRONG
            local own = Quality(list[1]) >= 2 and Style.QualityInk(Quality(list[1]))
            if own then
                local t = POUCH.tint
                colour = { INK_STRONG[1] + (own[1] - INK_STRONG[1]) * t, INK_STRONG[2] + (own[2] - INK_STRONG[2]) * t,
                    INK_STRONG[3] + (own[3] - INK_STRONG[3]) * t }
            end
            SHAPES.find(markPool, markInnerPool, x, y, colour)
            hoverPool:Next(x, y, function()
                local tip = {}
                for _, m in ipairs(list) do
                    local title, line = Text.FindTip(m, now)
                    tip[#tip + 1] = { title }
                    if line and line ~= "" then tip[#tip + 1] = { line, 1, 1, 1, true } end
                end
                return tip
            end)
            -- `at`: where it lies on the page, for a first found card's
            -- leader (UI/FindCard.lua).
            local px, py = OnPage(x, y)
            plate.findMarks[#plate.findMarks + 1] = { x = x, y = y, list = list, colour = colour,
                at = { px, py, x = x, y = y } }
            for _, m in ipairs(list) do
                if m.gift and m.guid and ns.Diary.IsDiary(m.guid) then
                    where[m] = { px, py, x = x, y = y }
                    people[#people + 1] = m
                end
            end
        end
        counts.finds = pouches

        -- Close calls (JRN-25), bad and good luck with a quest's drops
        -- (JRN-26, EXT-3), the ends of long quest chains (JRN-28) and the
        -- professions brought to their cap (JRN-29):
        -- a mark where each was, those on one spot (MARK.merge) one mark,
        -- its tooltip telling each. The close calls' marks are kept
        -- (plate.closeMarks) for the creature that nearly got you, its card
        -- in the margin (plate.foe, below).
        local function Spots(kind, cap)
            local list = {}
            for _, h in ipairs(here) do
                if h.m.kind == kind then
                    local into
                    for _, c in ipairs(list) do
                        if math.abs(c.x - h.x) <= MARK.merge and math.abs(c.y - h.y) <= MARK.merge then
                            into = c
                            break
                        end
                    end
                    if not into and #list < cap then
                        into = { x = h.x, y = h.y, list = {} }
                        list[#list + 1] = into
                    end
                    if into then into.list[#into.list + 1] = h.m end
                end
            end
            return list
        end
        local function Tell(list, words)
            return function()
                local tip = {}
                for _, m in ipairs(list) do
                    local title, lines = words(m, now)
                    tip[#tip + 1] = { title }
                    for _, line in ipairs(lines or {}) do tip[#tip + 1] = { line, 1, 1, 1, true } end
                end
                return tip
            end
        end
        -- A long chain's end (JRN-28) first: it ranks with the level's pin,
        -- so it keeps its place and the crosses and tallies step round it.
        local tailpieces = 0
        for _, c in ipairs(Spots("finale", CAP.finales)) do
            local x, y = Apart(c.x, c.y, Radius("finale"))
            Halo(x, y, FINALE.halo, true)
            SHAPES.finale(markPool, markInnerPool, x, y)
            hoverPool:Next(x, y, Tell(c.list, function(m) return Text.FinaleTip(m.finale, now) end), FINALE.halo)
            tailpieces = tailpieces + 1
        end
        counts.finales = tailpieces
        -- A profession brought to its cap (JRN-29), ranked with them too:
        -- its flight of stairs, the steps climbed by the best cap on the
        -- spot.
        local flights = 0
        for _, c in ipairs(Spots("skill", CAP.skills)) do
            local x, y = Apart(c.x, c.y, Radius("skill"))
            local rank
            for _, m in ipairs(c.list) do
                if type(m.cap.rank) == "number" and (not rank or m.cap.rank > rank) then rank = m.cap.rank end
            end
            Halo(x, y, SKILL.halo, true)
            SHAPES.skill(markPool, markInnerPool, x, y, rank)
            hoverPool:Next(x, y, Tell(c.list, function(m) return Text.SkillTip(m.cap, now) end), SKILL.halo)
            flights = flights + 1
        end
        counts.skills = flights

        plate.closeMarks = {}
        for _, c in ipairs(Spots("close", CAP.closeCalls)) do
            local x, y = Apart(c.x, c.y, Radius("close"))
            SHAPES.close(markPool, markInnerPool, x, y, markHaloPool)
            hoverPool:Next(x, y, Tell(c.list, function(m) return Text.CloseTip(m.call, now) end), CLOSE.dot)
            local px, py = OnPage(x, y)
            plate.closeMarks[#plate.closeMarks + 1] = { x = x, y = y, list = c.list, at = { px, py } }
        end
        counts.closeCalls = #plate.closeMarks
        -- The tallies are kept (plate.huntMarks) for the plate's one hunt
        -- card (UI/HuntCard.lua): the hunt furthest past its yardstick,
        -- against the character's usual where the drop rates are not
        -- known (plate.hunt).
        local tallies = 0
        plate.huntMarks = {}
        for _, c in ipairs(Spots("luck", CAP.hunts)) do
            local x, y = Apart(c.x, c.y, Radius("luck"))
            Halo(x, y, TALLY.halo, true)
            SHAPES.luck(markPool, markInnerPool, x, y)
            hoverPool:Next(x, y, Tell(c.list, function(m) return Text.HuntTip(m.hunt, now) end), TALLY.halo)
            tallies = tallies + 1
            local px, py = OnPage(x, y)
            plate.huntMarks[tallies] = { x = x, y = y, list = c.list, at = { px, py } }
        end
        counts.hunts = tallies
        local usual = tallies > 0 and ns.Journey.UsualLuck(ns.Journey.For(ns.ownGUID)) or nil
        plate.hunt = ns.UI.HuntCard.Choose(plate.huntMarks, usual)
        -- Good luck (EXT-3), the tally's counterpart: a star. The stars are
        -- kept (plate.fortuneMarks) for the plate's one lucky card
        -- (UI/LuckyCard.lua): the luckiest hunt (plate.lucky), in the
        -- margin, or on the print of a light plate (DrawPrint).
        local stars = 0
        plate.fortuneMarks = {}
        for _, c in ipairs(Spots("fortune", CAP.fortunes)) do
            local x, y = Apart(c.x, c.y, Radius("fortune"))
            Halo(x, y, FORTUNE.halo, true)
            SHAPES.fortune(markPool, markInnerPool, x, y)
            hoverPool:Next(x, y, Tell(c.list, function(m) return Text.HuntTip(m.hunt, now) end), FORTUNE.halo)
            stars = stars + 1
            local px, py = OnPage(x, y)
            plate.fortuneMarks[stars] = { x = x, y = y, list = c.list, at = { px, py } }
        end
        counts.fortunes = stars
        plate.lucky = ns.UI.LuckyCard.Choose(plate.fortuneMarks)

        -- A death on the road has no pool to sit beside.
        for _, h in ipairs(deaths) do
            local x, y = Apart(h.x, h.y, DEATH.dot / 2)
            SHAPES.death(markInnerPool, nil, x, y, markHaloPool)
            local seg = h.m.seg
            crosses[#crosses + 1] = { x = x, y = y, segs = { seg }, count = seg.act and seg.act.deaths or 1 }
        end
        counts.dungeons, counts.pins, counts.pinsMoved = doors, pins, moved
        counts.meetings, counts.firsts, counts.marks = meetings, firsts, marks
    end

    -- The deaths kept with their killers (Journey.Deaths) onto the crosses
    -- they fell at: a cross that knows its killers tells them under the
    -- mouse ("Died here twice" / "Sunscale Lashtail, with Bite"), and the
    -- plate's one killer is chosen from them (UI/KillerCard.lua), with
    -- where its card's leader ends on the page (plate.killer.mark).
    local function DrawKillers(deaths, mapID, At, entry, witnesses)
        local Card = ns.UI.KillerCard
        local j = ns.Journey.For(ns.ownGUID)
        Card.Match(crosses, deaths, mapID, function(d) return At(d.x, d.y) end, entry,
            function(t) return ns.Journey.CountedOn(j, t) end)
        for _, cross in ipairs(crosses) do
            if #cross.deaths > 0 then
                hoverPool:Next(cross.x, cross.y, function() return Tip(Text.DeathCross(cross.count, cross.deaths)) end,
                    DEATH.dot + 4)
            end
        end
        local k = Card.Choose(crosses)
        if k then
            local px, py = OnPage(k.cross.x, k.cross.y)
            k.mark = { px, py }
        end
        plate.killer = k
        -- The creature that nearly got you (JRN-25), from the close calls'
        -- marks: its card goes in the margin beside the killer's, if there
        -- is one (a close call and a death are two fights, even with the
        -- same creature).
        plate.foe = Card.Foe(plate.closeMarks)
        -- Someone who was there (Capture/Witnesses.lua) goes before the
        -- creature: a witness to a death takes the killer card's place, one
        -- who saved the user in a close call the close call's card's
        -- (14 Oct, the user's call). plate.witness is UI/KillerCard.lua's
        -- Witness.
        plate.witness = Card.Witness(crosses, plate.closeMarks, witnesses, OnPage)
        if plate.witness and plate.witness.death then plate.killer = nil end
        if plate.witness and plate.witness.call then plate.foe = nil end
    end

    -- Good luck told on the print (UI/LuckyCard.lua's S): on a light
    -- plate's slot (a snapshot or the tucked print), which has no margin,
    -- the plate's lucky hunt on a slip across the print's foot, drawn
    -- through the card's toolkit so it turns and lies with the print.
    -- plate.print says where it went (for the page: the caption's words, a
    -- leader to the star where the star is not beside it) or is nil where it
    -- did not fit, and the caption keeps the hunt's words.
    local printKit = { Place = Place, Quad = Quad,
        Texture = function(part) return printPools[part]:Next() end,
        Text = function(part) return printTexts[part]:Next() end }
    local function DrawPrint(entry, now)
        plate.print = nil
        plate.printHit:Hide()
        plate.printItem:Hide()
        local chosen, slot = plate.lucky, plate.slot
        if not (chosen and slot and slot.light) then return end
        local hunt = chosen.hunt
        local seed = table.concat({ "lucky", hunt.questID or hunt.item or "", plate.mapID or 0,
            entry and (entry.level or entry.week) or 0 }, ":") .. ":print"
        local s = ns.UI.LuckyCard.Print(printKit, chosen, slot, seed, view.flat)
        if not s then return end
        local hit, item = s.hit, s.iconHit
        PlaceButton(plate.printHit, hit.x, hit.y, hit.w, hit.h)
        plate.printHit:SetFrameLevel(over:GetFrameLevel() + 1)
        plate.printHit:Show()
        PlaceButton(plate.printItem, item.x, item.y, item.w, item.h)
        plate.printItem:SetFrameLevel(over:GetFrameLevel() + 2)
        plate.printItem:Show()
        -- On the page: its corners, its top edge, and a leader's way from
        -- that edge to the star, where the star is far enough off to need
        -- one (PRINT.near).
        local function Page(list)
            local out = {}
            for i, p in ipairs(list) do out[i] = { OnPage(p[1], p[2]) } end
            return out
        end
        local edge = Page(s.edge)
        local mark, far = chosen.mark, false
        if s.star then
            local ex = math.max(s.edge[1][1], math.min(s.edge[2][1], s.star[1]))
            local d = math.sqrt((s.star[1] - ex) ^ 2 + (s.star[2] - s.top) ^ 2)
            far = d >= ns.UI.LuckyCard.PRINT.near
        end
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        local polys = { label = Page(s.label), tag = Page(s.tag), icon = Page(s.icon) }
        for _, poly in pairs(polys) do
            for _, p in ipairs(poly) do
                x0, y0, x1, y1 = math.min(x0, p[1]), math.min(y0, p[2]), math.max(x1, p[1]), math.max(y1, p[2])
            end
        end
        plate.print = { hunt = hunt, now = now, itemID = s.itemID, form = s.form, s = s, mark = mark, far = far,
            polys = polys, box = { x0, y0, x1 - x0, y1 - y0 }, plate = plate }
        -- A leader's way off it (UI/JournalJourney.lua's Aim): the point of
        -- its top edge nearest the mark, on the page.
        function plate.print:Nearest(x, y)
            local ax, ay, bx, by = edge[1][1], edge[1][2], edge[2][1], edge[2][2]
            local dx, dy = bx - ax, by - ay
            local t = ((x - ax) * dx + (y - ay) * dy) / math.max(dx * dx + dy * dy, 1e-6)
            t = math.max(0, math.min(1, t))
            return ax + dx * t, ay + dy * t
        end
        function plate.print:IsShown() return plate:IsShown() end
    end

    -- Where it is glued: one of the page's slots.
    function plate:SetSlot(s)
        self.slot = s
        K.Mount(s.x, s.y, s.w, s.h, -math.rad(s.t or 0))
    end

    -- Draws `window` ({ x0, y0, x1, y1 }, 0..1 of the map, Plate.Window) of
    -- `sheet` (Recap.Sheet: one zone's road and meetings), the open
    -- `entry` (a level or a week: only its from..to is drawn). `opts`:
    -- moments (Recap.Moments of the entry: its marks), cap (the plate's
    -- share of the caps, Plate.Share), fights (Journey.FightIndex, built
    -- once), deaths (Journey.Deaths: the deaths kept with their killers),
    -- witnesses (Journey.WitnessIndex, built once).
    function plate:Draw(sheet, entry, window, opts)
        opts = opts or {}
        local started = debugprofilestop and debugprofilestop()
        local now = opts.now or ns.Now()
        local fights = opts.fights or ns.Journey.FightIndex()
        local mapID = sheet.mapID
        self.mapID, self.entry, self.window, self.data = mapID, entry, window, sheet
        wipe(spots)
        wipe(crosses)
        self.counts = {}

        -- Drawn lying back, never leaned in.
        self.Settle()
        K.Lay()
        for _, pool in ipairs(ALL) do pool:Begin() end

        DrawMount()
        local At, fullW, fullH = DrawArt(mapID, window, opts.box)

        -- Yards serve only stops saved before shapes were kept.
        local yards = ns.Journey.MapYards(mapID)
        if type(yards) ~= "number" or yards <= 0 then yards = Trail.FOOT.yards end
        local pools = DrawTrail(sheet, entry, At, fullW, fullH, fullW / yards, opts)
        DrawFlights(sheet.flights, mapID, At, entry, now)

        -- Hover squares over the pools, as wide as their footprints (within
        -- reason), droplets too; the marks over them are placed after, so
        -- theirs lie on top. The pool's ink in words (no key, Decision 7).
        local HS = HOVER.size
        local hovered = 0
        for _, pool in ipairs(pools) do
            if hovered >= HOVER.most then break end
            if pool.drawn then
                hovered = hovered + 1
                local size = pool.droplet and HS[1] or math.max(HS[1], math.min(HS[2], 2 * pool.e.a1))
                hoverPool:Next(pool.e.x, pool.e.y, function()
                    local title, lines = Text.Stop(pool.seg, now, pool.more)
                    lines[1] = Text.Pool(pool.seg)
                    return Tip(title, lines)
                end, size)
            end
        end

        DrawMoments(sheet, opts.moments, mapID, At, pools, entry, now, fights)
        DrawKillers(opts.deaths, mapID, At, entry, opts.witnesses or ns.Journey.WitnessIndex())
        DrawPrint(entry, now)
        self.counts.labels = 0

        for _, pool in ipairs(ALL) do pool:Finish() end
        local textures = 0
        for _, pool in ipairs(TEXTURES) do textures = textures + pool.used end
        self.counts.textures = textures
        -- How long it took to draw (/sd journey reports it).
        if started then self.buildMs = debugprofilestop() - started end
    end

    -- Where a point of the map (0..1) lies on the page, through the card's
    -- window and turn: for a leader to it.
    function plate:OnPage(x, y)
        local px, py = self.At(x, y, true)
        return OnPage(px, py)
    end

    -- What a click on the card does (the full page); nil for nothing.
    -- What a click on the card does: `fn(plate)`, nil for nothing. With
    -- `lean` (the close-ups), it leans in under the mouse (ZOOM).
    function plate:SetClick(fn, lean)
        self.onClick, self.leans = fn, fn ~= nil and lean ~= false
        S:SetScript("OnMouseUp", fn and function() fn(plate) end or nil)
        clip:EnableMouse(fn ~= nil)
        self:Lean()
    end

    -- Leaning in (ZOOM): `zoom` from 0 to 1, eased out, run by a short
    -- OnUpdate that stops itself once it gets there; it follows the mouse
    -- over the picture, its marks included, so moving onto a mark never
    -- lets it go. plate.onZoom(plate, scale) hears each step (the page's
    -- leaders follow their marks).
    plate.zoom, plate.scale = 0, 1
    local function Want()
        return (plate.leans and clip:IsMouseOver()) and 1 or 0
    end
    local function Apply()
        local t = 1 - (1 - plate.zoom) ^ 4
        plate.scale = 1 + (ZOOM.scale - 1) * t
        content:SetScale(plate.scale)
        if plate.onZoom then plate.onZoom(plate, plate.scale) end
    end
    local function Step(_, elapsed)
        local target, step = Want(), (elapsed or 0) / ZOOM.time
        if target > plate.zoom then
            plate.zoom = math.min(target, plate.zoom + step)
        else
            plate.zoom = math.max(target, plate.zoom - step)
        end
        Apply()
        if plate.zoom == target then clip:SetScript("OnUpdate", nil) end
    end
    function plate:Lean()
        if Want() ~= self.zoom then clip:SetScript("OnUpdate", Step) end
    end

    ----------------------------------------------------------------------
    -- Looking closer (FULLZOOM, DRAG): a full page under the wheel

    -- `look`: the view shown, `f` (screen px a px of art), `cx`, `cy` (the
    -- map point at the card's middle, 0..1); `drawn`, the view the picture
    -- was drawn at; `goal`, where the wheel is taking it; `fit`, `c0` the
    -- fitted view; LW, LH the art's size; onSettle(f, cx, cy) draws again.
    local look

    -- The print's darkened edges are in the picture (under its ink) but
    -- stay at the neat line: scaled with it by `scale`, each band is put
    -- back where it was drawn, so the wheel does not take them with it.
    local function Unscale(scale)
        for i = 1, vignettePool.used do
            local t = vignettePool[i]
            local h = t.home
            if h then
                t:ClearAllPoints()
                t:SetPoint("CENTER", S, "CENTER", h[1] / scale, h[2] / scale)
                t:SetSize(h[3] / scale, h[4] / scale)
            end
        end
    end

    -- The picture placed for the view shown against the view drawn: scaled
    -- by their ratio about the card's middle and shifted, in the card's own
    -- turn, so the map point at the middle is the one wanted.
    local function Show()
        local d, f = look.drawn, look.f
        local lx, ly = (d.cx - look.cx) * f * look.LW, (d.cy - look.cy) * f * look.LH
        local a = view.turn or 0
        local c, sn = math.cos(a), math.sin(a)
        pivot:ClearAllPoints()
        pivot:SetPoint("CENTER", S, "CENTER", lx * c + ly * sn, lx * sn - ly * c)
        plate.scale = f / d.f
        content:SetScale(plate.scale)
        Unscale(plate.scale)
    end

    -- A view kept on the map: zoomed out to the fit, the fitted framing;
    -- else the middle no nearer an edge than half the window.
    local function Hold(f, cx, cy)
        f = Clamp(f, look.fit, FULLZOOM.native)
        if f <= look.fit + 1e-9 then return look.fit, look.c0[1], look.c0[2] end
        local s = plate.slot
        local hw, hh = (s.w - 2 * s.pad) / 2 / (f * look.LW), (s.h - 2 * s.pad) / 2 / (f * look.LH)
        cx = hw >= 0.5 and 0.5 or Clamp(cx, hw, 1 - hw)
        cy = hh >= 0.5 and 0.5 or Clamp(cy, hh, 1 - hh)
        return f, cx, cy
    end

    -- The wheel's easing, then the wait to draw sharp again: one short
    -- OnUpdate on the pivot, stopping itself once it has drawn. Held, only
    -- a new zoom is drawn (a drag draws again once let go); the press is
    -- carried on over the drawing.
    local Drag
    local function Redraw(whole)
        local pressed = look.pressed
        look.redraws = (look.redraws or 0) + 1
        local g = look.goal
        look.onSettle(g.f, g.cx, g.cy, whole)
        if pressed and look then
            look.pressed = pressed
            clip:SetScript("OnUpdate", Drag)
        end
    end
    local function Tick(_, elapsed)
        local m = look.move
        if m then
            m.t = m.t + (elapsed or 0)
            local p = math.min(1, m.t / FULLZOOM.time)
            local e = 1 - (1 - p) ^ 4
            look.f = m.f + (look.goal.f - m.f) * e
            look.cx = m.cx + (look.goal.cx - m.cx) * e
            look.cy = m.cy + (look.goal.cy - m.cy) * e
            if p >= 1 then
                look.f, look.cx, look.cy, look.move = look.goal.f, look.goal.cx, look.goal.cy, nil
            end
            Show()
            return
        end
        look.still = look.still + (elapsed or 0)
        if look.still >= FULLZOOM.settle then
            pivot:SetScript("OnUpdate", nil)
            local d, pressed = look.drawn, look.pressed
            look.goal = { f = look.f, cx = look.cx, cy = look.cy }
            -- Back out to the fit, drawn whole for the way there: drawn
            -- again as the fit is, at the same size, so nothing shifts.
            local whole = d.whole and look.f <= look.fit + 1e-9
            if d.f ~= look.f or (not pressed and (whole or d.cx ~= look.cx or d.cy ~= look.cy)) then
                Redraw()
            end
        end
    end
    local function Wait()
        look.still = 0
        pivot:SetScript("OnUpdate", Tick)
    end

    -- The point under the cursor: on the screen (UI units), and on the card
    -- from its middle, unturned, y down. Fields, so the tests can say.
    function plate.CursorScreen()
        local x, y = GetCursorPosition()
        local scale = clip:GetEffectiveScale() or 1
        return x / scale, y / scale
    end
    function plate.CursorLocal()
        local x, y = plate.CursorScreen()
        local mx, my = S:GetCenter()
        local X, Y = x - (mx or 0), y - (my or 0)
        local a = view.turn or 0
        local c, sn = math.cos(a), math.sin(a)
        return X * c + Y * sn, X * sn - Y * c
    end

    -- A notch of the wheel at qx, qy on the card: closer (up) or further,
    -- the map point there staying under it.
    function plate:Wheel(delta, qx, qy)
        if not look then return end
        if not qx then qx, qy = plate.CursorLocal() end
        local g = look.goal
        local mx, my = g.cx + qx / (g.f * look.LW), g.cy + qy / (g.f * look.LH)
        local f = Clamp(g.f * FULLZOOM.step ^ (delta or 0), look.fit, FULLZOOM.native)
        local cx, cy = mx - qx / (f * look.LW), my - qy / (f * look.LH)
        f, cx, cy = Hold(f, cx, cy)
        local shown = { f = look.f, cx = look.cx, cy = look.cy }
        look.goal = { f = f, cx = cx, cy = cy }
        -- Drawn now for where it is going, the whole zone round it (the
        -- fit too, so the way out has art), and eased in from where it was.
        local d = look.drawn
        if d.f ~= f or d.cx ~= cx or d.cy ~= cy then Redraw(true) end
        look.f, look.cx, look.cy = shown.f, shown.cx, shown.cy
        look.move = { t = 0, f = shown.f, cx = shown.cx, cy = shown.cy }
        Show()
        Wait()
    end
    clip:SetScript("OnMouseWheel", function(_, delta) plate:Wheel(delta) end)

    -- A press on the picture: a click, or once zoomed a drag that pans.
    function Drag()
        local p = look and look.pressed
        if not p then
            clip:SetScript("OnUpdate", nil)
            return
        end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            plate:Release("LeftButton")
            return
        end
        local x, y = plate.CursorScreen()
        local X, Y = x - p.x, y - p.y
        if X * X + Y * Y > DRAG.threshold * DRAG.threshold then p.moved = true end
        if not p.moved or look.f <= look.fit + 1e-9 then return end
        local a = view.turn or 0
        local c, sn = math.cos(a), math.sin(a)
        local lx, ly = X * c + Y * sn, X * sn - Y * c
        local f, cx, cy = Hold(look.f, p.cx - lx / (look.f * look.LW), p.cy - ly / (look.f * look.LH))
        look.f, look.cx, look.cy, look.move = f, cx, cy, nil
        look.goal = { f = f, cx = cx, cy = cy }
        Show()
    end
    plate.Drag = Drag

    function plate:Press(which)
        if which and which ~= "LeftButton" then return end
        if not look then return end
        local x, y = plate.CursorScreen()
        look.pressed = { x = x, y = y, cx = look.cx, cy = look.cy }
        clip:SetScript("OnUpdate", Drag)
    end

    function plate:Release(which)
        if which and which ~= "LeftButton" then return end
        if not look then
            if self.onClick then self.onClick(self) end
            return
        end
        local p = look.pressed
        look.pressed = nil
        clip:SetScript("OnUpdate", nil)
        if p and p.moved and look.f > look.fit + 1e-9 then
            Wait()
        elseif self.onClick then
            self.onClick(self)
        end
    end
    clip:SetScript("OnMouseDown", function(_, which) plate:Press(which) end)
    clip:SetScript("OnMouseUp", function(_, which) plate:Release(which) end)

    -- Looking closer at a full page drawn at `o` = { f, cx, cy, fit, c0 =
    -- { cx, cy }, LW, LH, onSettle }; nil for none (a close-up).
    function plate:Look(o)
        pivot:SetScript("OnUpdate", nil)
        look = o and { f = o.f, cx = o.cx, cy = o.cy, fit = o.fit, c0 = o.c0, LW = o.LW, LH = o.LH,
            onSettle = o.onSettle, drawn = { f = o.f, cx = o.cx, cy = o.cy, whole = o.whole },
            goal = { f = o.f, cx = o.cx, cy = o.cy }, still = 0, redraws = o.redraws } or nil
        self.look = look
        clip:EnableMouseWheel(look ~= nil)
        pivot:ClearAllPoints()
        pivot:SetPoint("CENTER", S, "CENTER")
    end

    -- As it was, at once: drawn again, or put away mid-lean, mid-wheel or
    -- mid-drag: nothing left running or held, the picture at its place.
    local function Settle()
        plate.zoom = 0
        clip:SetScript("OnUpdate", nil)
        pivot:SetScript("OnUpdate", nil)
        if look then look.pressed, look.move = nil, nil end
        pivot:ClearAllPoints()
        pivot:SetPoint("CENTER", S, "CENTER")
        Apply()
        if look then Unscale(plate.scale) end
    end
    plate.Settle = Settle
    clip:SetScript("OnEnter", function() plate:Lean() end)
    clip:SetScript("OnLeave", function() plate:Lean() end)
    view:HookScript("OnHide", function()
        Settle()
        plate:Look(nil)
    end)

    plate:SetSlot(slot)
    plate:Hide()
    return plate
end

-- A plate's share of the trail's caps, by its area (SHARE).
function Plate.Share(slot)
    return math.min(1, math.max(SHARE.least, slot.w * slot.h / SHARE.area))
end

Plate.MOUNT, Plate.GLUE, Plate.LIFT, Plate.SHARE, Plate.MARK = MOUNT, GLUE, LIFT, SHARE, MARK
Plate.PRIORITY, Plate.DOOR, Plate.POUCH = PRIORITY, DOOR, POUCH
Plate.ZOOM, Plate.FULLZOOM, Plate.DRAG = ZOOM, FULLZOOM, DRAG
Plate.PLATE, Plate.SHADOW, Plate.THICKNESS, Plate.VIGNETTE = PLATE, SHADOW, THICKNESS, VIGNETTE

-- The window a full page shows at `f` (screen px a px of art) round cx, cy
-- in an art box aw by ah, and, with `over`, the window drawn round it and
-- its box on the card (x, y, w, h, the card's margin `pad` in): the
-- window plus `over` of itself each side, within the map.
function Plate.Frame(mapID, f, cx, cy, aw, ah, pad, over)
    local LW, LH = LayerSize(mapID)
    local w, h = aw / (f * LW), ah / (f * LH)
    local x0, y0 = cx - w / 2, cy - h / 2
    local window = { x0, y0, x0 + w, y0 + h }
    if not over or over <= 0 then return window, nil end
    local d = { math.max(0, x0 - w * over), math.max(0, y0 - h * over), math.min(1, x0 + w + w * over),
        math.min(1, y0 + h + h * over) }
    local box = { pad + (d[1] - x0) * f * LW, pad + (d[2] - y0) * f * LH, (d[3] - d[1]) * f * LW, (d[4] - d[2]) * f * LH }
    return d, box
end

ns.UI.JourneyPlate = setmetatable(Plate, { __call = function(_, parent, slot) return New(parent, slot) end })
