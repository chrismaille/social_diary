-- The killer card (Your Diary's plates, JRN-21): what killed you on a plate,
-- as option A of .claude/ui-proposal/killer-models-proposal.md, "Cut in
-- ink". A paper strip (UI/PaperStrip.lua) taped in the plate's margin, last
-- of its notes, with a pencil leader to its death cross; on it, straight on
-- the slip's paper, the creature as a flat silhouette in ink, its head and
-- shoulders in profile, facing the cross (a Victorian cut-paper portrait,
-- the oldest keepsake picture there is), and under it its name in the
-- diary's hand and what it did, "killed you twice".
--
-- Which deaths get one (the proposal's 0.1, 0.2):
--   - only a creature's: a fall or a drowning has no card (its cross's
--     tooltip says what it was), a player's death is their fight's strip,
--     and a death from before deaths were kept is its cross alone;
--   - one card a plate: the killer that got you most there, a tie to the
--     latest; but a rare, an elite or a boss outranks any number of common
--     kills (the user's choice, 10 Oct), the higher rank first;
--   - after the people: the card is the margin's last note and the first
--     left off when the column runs out; then its name goes into the
--     caption ("Level 12, and two deaths, to a Sunscale Lashtail.").
-- A plate may also have the creature that nearly got you (JRN-25, a close
-- call: KillerCard.Foe, card:SetFoe), beside its killer's card, if any:
-- a close call and a death are two fights, even with the same creature
-- (the user's choice, 11 Oct). The same card under a heading in the
-- diary's hand, "A close call", its creature's level on a pasted label
-- over its name and the fight charted under it (VITALS), its leader to the
-- cross in outline; in the margin after the killer's, so it is left off
-- first.
--
-- The picture walks down one ladder, each card on its own (0.4): the ink
-- silhouette (a PlayerModel drawn from the creature's display with its
-- lights put out, black) where the client has everything it needs and KILLER.silhouette
-- is on; else the 2D print (the creature's portrait texture, desaturated,
-- warmed, in a rectangular window with small photo corners, the same shape
-- as the model's, Q4); else the name alone. No display kept, no picture.
-- A model that has drawn nothing after KILLER.check seconds gives way to the
-- print. The name is always written: nothing is only in the picture.
--
-- Of the model's calls the client has shown SetDisplayInfo, SetFacing, the
-- lights put out and the camera's fit (10 Oct); the rest are unproven, so
-- every one is looked up and called guarded: a method the client lacks is
-- skipped, one that errors is caught. The model is still at rest (frozen,
-- no idle), never faint, a child of the strip and never of a plate's
-- clipping frame (P5); at most one a card, so six on a page (two cards a
-- plate).

local addonName, ns = ...

local Style = ns.Style

local KillerCard = {}
ns.UI.KillerCard = KillerCard

-- The picture's room over the name: `w` by `h`, `gap` above the name;
-- `narrow` where the margin's column is under `below` px (the two-plate
-- layout's). The slip turns at most `turn` degrees (a model cannot turn
-- with it, and at about a degree no one can tell); its tape goes `tapeAt`
-- of the way along its top, clear of the picture by `clear` px, the slip
-- made wide enough for that. A name too long for the column is set at
-- `small`, the hand's smaller size (the plates' captions' second), and a
-- card whose name will not fit even so is left off.
-- The silhouette (A): on while `silhouette`, black: the model drawn with
-- its lights put out (`dark`), so only its outline shows, the cut-paper
-- portrait's black paper. In profile toward its cross: `face` is the
-- model's turn for a creature facing the page's left or right. Framed by
-- `frame`, the model always on its own camera (portrait zoom 0), which
-- fits the whole creature to the window whatever its size:
--   "body"  the whole creature, the camera at `distance` (its distance
--           scale);
--   "head"  head and shoulders (Q2), cropped from the whole: the camera
--           `head.distance` as far (closer), and the view moved by
--           `head.shift` of the window (across, away from the way it
--           faces; down) so its head and shoulders, at the top and front,
--           come into the middle. The same shares fit any creature, as
--           the camera has fitted it first. Not proven (its probes are
--           out); "body" where the client cannot move the view.
-- (10 Oct, in the client: under the portrait camera a model turned to
-- profile swung its head out of the camera's aim, a black blob; a custom
-- camera moved round it went into the model; fog did nothing at all, and
-- the lights put out drew it black. SetFacing(-pi/2) faces the viewer's
-- left.)
-- Held still in `pose` (stand: an attack can carry the head out of
-- frame; `blow` lists attacks to try first). The print (0): its portrait desaturated and warmed
-- by `tint`, edged in ink at `edge`, its photo corners `corner` px of
-- `ink` at `alpha` (MOUNT's kraft).
local KILLER = {
    picture = { w = 70, h = 48, gap = 2 }, narrow = { w = 62, h = 42, gap = 2, below = 140 },
    turn = 1.2, tapeAt = 0.8, clear = 4, small = 14,
    silhouette = true, frame = "body", distance = 1, dark = true, face = { left = -math.pi / 2, right = math.pi / 2 },
    head = { distance = 0.5, shift = { 0.2, 0.3 } },
    pose = { anim = 0, variation = 0, at = 0, blow = nil }, check = 1.5,
    print = { tint = { 1, 0.88, 0.68 }, edge = 0.55, corner = 7, ink = { 0.29, 0.19, 0.105 }, alpha = 0.95 },
}
-- The close call's card (JRN-25, SetFoe) writes the fight down under the
-- creature's name, as a nurse's chart would, so no two read alike. Down
-- the slip:
--   the heading what the card is, "A close call" (Text.CloseHeading), as
--               the margin's other cards have theirs: in the hand
--               (FONT.noteWritten) at the slip's top left, at KILLER.small
--               where the column is too narrow for it at that size. The
--               slip's tape keeps clear of it, `tapeAt` of the way along
--               (further right than a killer's, so a narrow slip still
--               holds both)
--   the picture `head.gap` px under it, as a killer's; where the margin
--               has too little height left for the card, drawn `compact`
--               (`w` by `h`), and where even that is too tall, given up
--   the tag     the creature's level and rank, "Lv 45 (Elite)", "Lv ??
--               (Boss)", "Lv 12", or the rank alone where no level was
--               kept (Text.FoeTag): a small label of `paper` pasted on the
--               slip `gap` px under the picture and `under` px over the
--               name, at its left, as a specimen's label under its
--               drawing; its words in small ink `pad` px in, an ink `edge`,
--               turned `turn` degrees (within, seeded by its words), with a
--               hair of `shadow`. Where the column is too narrow for it on
--               one line, the rank on a line under the level
--   the bar     the health you came out with: a box ruled in ink at
--               `edge`, `w` by `h` (`narrow` under KILLER.narrow.below),
--               filled from the left in rubric to the health left (at least
--               `least` px, so 1 % still shows), the rest the slip's paper;
--               a graphite `tick` at a tenth, where a close call begins,
--               `over` px past the box above and below, so how far under
--               it you were reads at a glance
--   the figure  the health left, "4%", large in the hand (`size`), in
--               rubric, `gap` px right of the bar, its foot on the bar's
--   the deed    in small ink, how many it was against ("fought against
--               three"), only when more than one: on the same row,
--               `gap` px past the figure, its foot on the bar's, where the
--               column has room; else the line under them. Kept short so
--               the card stands no taller than it must (a three-plate
--               margin has little room)
-- (11 Oct, in the client: "nearly got you" under the name alone was flat;
-- then the fight's time said nothing, and wax seals with a rank's initial
-- were not clear enough. 12 Oct, the user: a heading saying what the card
-- is, over everything, and the tag off the corner, over the name.)
local VITALS = {
    head = { gap = 0 }, tapeAt = 0.9, compact = { w = 62, h = 32 },
    bar = { w = 70, h = 7, edge = 0.8, least = 1.5, tick = { at = 0.10, over = 2, width = 1, alpha = 0.55 } },
    narrow = 56, figure = { size = 22, gap = 5 }, deed = { gap = 7 }, room = { gap = 2, after = 2 },
    tag = { paper = { 0.97, 0.94, 0.84 }, pad = { 4, 1 }, gap = 2, under = 1, turn = { 1, 2.5 }, edge = 0.30,
        shadow = { 0.6, 0.8, 0.16 } },
}
-- A death matches a cross whose stop or road it fell in, `slack` seconds
-- either side; one placed on the map but in no such time goes to the
-- nearest cross within `near` px of its spot.
local MATCH = { slack = 30, near = 24 }
-- What outranks what (Capture/Deaths.lua's ranks); a common creature none.
local RANK = { worldboss = 4, rareelite = 3, rare = 2, elite = 1 }

local HAND = "Interface\\AddOns\\" .. addonName .. "\\Fonts\\Neuton-Italic.ttf"

-- The displays a model drew nothing from this session (KILLER.check): their
-- cards are the print from the start.
local BLANK = {}

--------------------------------------------------------------------------
-- Which killer
--------------------------------------------------------------------------

-- Whether a stop or road drawn as `cross` held time `t`.
local function Holds(cross, t)
    for _, seg in ipairs(cross.segs or {}) do
        local from = seg.from or 0
        if t >= from - MATCH.slack and t <= (seg.to or from) + MATCH.slack then return true end
    end
    return false
end

local function Gap(cross, x, y)
    return (cross.x - x) ^ 2 + (cross.y - y) ^ 2
end

-- The deaths (Journey.Deaths's records) onto the plate's death crosses:
-- `crosses` { x, y (on the card), segs (the stops or road it marks), count },
-- each given its `deaths`. A death goes to a cross whose time held it (the
-- nearest of those to its spot, when it has one), else, placed on this map
-- and in the open `entry`, to the cross nearest its spot within MATCH.near.
-- `place(death)` is its spot on the card, nil off it. Before all that,
-- `countedOn(t)` (Journey.CountedOn), where given, is the segment the death
-- was counted on: it goes to that segment's cross, or to none where that
-- cross is not on this plate, whatever its time or spot (a long fight ends
-- long after its stop's last sample).
local function Marks(cross, seg)
    for _, s in ipairs(cross.segs or {}) do
        if s == seg or (s.kind == seg.kind and s.from == seg.from and s.mapID == seg.mapID) then return true end
    end
    return false
end

function KillerCard.Match(crosses, deaths, mapID, place, entry, countedOn)
    for _, cross in ipairs(crosses) do cross.deaths = {} end
    if #crosses == 0 then return crosses end
    for _, d in ipairs(deaths or {}) do
        local seg = countedOn and type(d.t) == "number" and countedOn(d.t) or nil
        if seg then
            for _, cross in ipairs(crosses) do
                if Marks(cross, seg) then
                    cross.deaths[#cross.deaths + 1] = d
                    break
                end
            end
        elseif type(d.t) == "number" and not (d.mapID and mapID and d.mapID ~= mapID) then
            local x, y
            if d.x and d.y and place then x, y = place(d) end
            local best, gap
            for _, cross in ipairs(crosses) do
                if Holds(cross, d.t) then
                    local g = x and Gap(cross, x, y) or 0
                    if not best or g < gap then best, gap = cross, g end
                end
            end
            if not best and x and (not entry or (d.t >= entry.from and d.t < entry.to)) then
                for _, cross in ipairs(crosses) do
                    local g = Gap(cross, x, y)
                    if g <= MATCH.near ^ 2 and (not best or g < gap) then best, gap = cross, g end
                end
            end
            if best then best.deaths[#best.deaths + 1] = d end
        end
    end
    return crosses
end

-- Whether a death was a creature's: a name and no world (a player's
-- death keeps no killer).
local function Creature(d)
    return type(d.name) == "string" and d.name ~= "" and not d.environment
end

-- The plate's one killer, from its crosses' deaths (Match), or nil: the
-- highest rank (RANK), then the most deaths, then the latest. { npcID,
-- name, rank, count, last (time), spell (the latest), display (the latest
-- kept), probable (none confirmed by the death recap), cross (where the
-- latest was) }.
function KillerCard.Choose(crosses)
    local by, list = {}, {}
    for _, cross in ipairs(crosses or {}) do
        for _, d in ipairs(cross.deaths or {}) do
            if Creature(d) then
                local key = d.npcID or d.name
                local k = by[key]
                if not k then
                    k = { npcID = d.npcID, name = d.name, count = 0, probable = true }
                    by[key] = k
                    list[#list + 1] = k
                end
                k.count = k.count + 1
                if (RANK[d.rank] or 0) > (RANK[k.rank] or 0) then k.rank = d.rank end
                k.probable = k.probable and d.probable == true
                if not k.last or d.t >= k.last then
                    k.last, k.cross, k.name = d.t, cross, d.name
                    k.spell = d.spell or k.spell
                end
                local display = ns.Plain(d.display)
                if type(display) == "number" and display > 0 and (not k.shown or d.t >= k.shown) then
                    k.display, k.shown = display, d.t
                end
            end
        end
    end
    table.sort(list, function(a, b)
        local ra, rb = RANK[a.rank] or 0, RANK[b.rank] or 0
        if ra ~= rb then return ra > rb end
        if a.count ~= b.count then return a.count > b.count end
        return a.last > b.last
    end)
    local k = list[1]
    if k then k.shown = nil end
    return k
end

-- The creature that nearly got you on a plate (JRN-25), from its close
-- calls' marks (plate.closeMarks: { at (on the page), list of moments }),
-- or nil: only a close call with a creature named has one. The highest
-- rank (RANK), then the least health left, then the latest. { npcID, name,
-- rank, display, call (its record), mark (where its cross is on the page) }.
function KillerCard.Foe(marks)
    local best
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local call = m.call
            if call and type(call.name) == "string" and call.name ~= "" then
                local better = not best
                if best then
                    local ra, rb = RANK[call.rank] or 0, RANK[best.call.rank] or 0
                    if ra ~= rb then
                        better = ra > rb
                    elseif (call.pct or 0) ~= (best.call.pct or 0) then
                        better = (call.pct or 0) < (best.call.pct or 0)
                    else
                        better = (call.t or 0) > (best.call.t or 0)
                    end
                end
                if better then best = { call = call, mark = mark.at } end
            end
        end
    end
    if not best then return nil end
    local call = best.call
    local display = ns.Plain(call.display)
    return { npcID = call.npcID, name = call.name, rank = call.rank, call = call, mark = best.mark,
        display = type(display) == "number" and display > 0 and display or nil }
end

-- The plate's one witness (Journey.WitnessesAt), or nil: someone who tried
-- to save the user from a death on this plate, saved them in a close call
-- on it, or watched them die on it. A witness goes before the killer card
-- (or the close call's, for one who saved the user): a person in the
-- moment is the better story than the creature (14 Oct, the user's call).
-- Who acted before who watched, then the longer watcher, then the latest.
-- `crosses` as Match left them, `marks` plate.closeMarks, `index`
-- Journey.WitnessIndex's, `onPage(x, y)` a card spot to the page.
--
-- { kind ("helped" | "watched"), type (the row's: "tried_to_help",
-- "saved_you", "watched_death"), guid, row, t, watched (seconds, a
-- watcher's), pct (health left, a rescue's), creature ({ npcID, name,
-- rank }, nil when not known), death (the Journey.Deaths record) or call
-- (the close call's), others (how many more witnessed the same moment),
-- mark (where its cross is on the page) }.
local DEATH_WITNESS = { tried_to_help = true, watched_death = true }
local CLOSE_WITNESS = { saved_you = true }

function KillerCard.Witness(crosses, marks, index, onPage)
    local Journey = ns.Journey
    local best
    local function Consider(found, extra)
        local w = found[1]
        if not w then return end
        local helped = Journey.WITNESS[w.row.type] == "helped"
        local c = w.row.context or {}
        local better = not best
        if best then
            local bh = best.kind == "helped"
            if helped ~= bh then
                better = helped
            elseif (c.watched or 0) ~= (best.watched or 0) then
                better = (c.watched or 0) > (best.watched or 0)
            else
                better = w.t > best.t
            end
        end
        if not better then return end
        best = { kind = Journey.WITNESS[w.row.type], type = w.row.type, guid = w.guid, row = w.row, t = w.t,
            watched = c.watched, pct = c.pct, others = #found - 1,
            creature = type(c.name) == "string" and { npcID = c.npcID, name = c.name, rank = c.rank } or nil }
        for key, value in pairs(extra) do best[key] = value end
    end
    for _, cross in ipairs(crosses or {}) do
        for _, d in ipairs(cross.deaths or {}) do
            local px, py = onPage(cross.x, cross.y)
            Consider(Journey.WitnessesAt(index, d.t, DEATH_WITNESS), { death = d, mark = { px, py } })
        end
    end
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            if m.call then
                Consider(Journey.WitnessesAt(index, m.call.t, CLOSE_WITNESS), { call = m.call, mark = mark.at })
            end
        end
    end
    return best
end

--------------------------------------------------------------------------
-- The model, guarded
--------------------------------------------------------------------------

-- Whether `object` has `method` (a missing one is nil in the client; the
-- tests' mock raises on it, so it is looked up guarded).
local function Can(object, method)
    local ok, fn = pcall(function() return object[method] end)
    return ok and type(fn) == "function"
end

-- `method` called on `object`, if it has it: whether it ran, and what it
-- returned.
local function Try(object, method, ...)
    if not Can(object, method) then return false end
    return pcall(object[method], object, ...)
end

-- What the silhouette cannot do without.
local NEEDS = { "SetDisplayInfo", "SetFacing", "SetLight" }

-- The lights put out (P3'), as the modern client takes them; the old
-- argument list is not tried. Nil where the client has no vectors.
local function Dark()
    if type(CreateVector3D) ~= "function" or type(CreateColor) ~= "function" then return nil end
    local ok, light = pcall(function()
        return { omnidirectional = false, point = CreateVector3D(0, 0, -1), ambientIntensity = 0,
            ambientColor = CreateColor(0, 0, 0), diffuseIntensity = 0, diffuseColor = CreateColor(0, 0, 0) }
    end)
    return ok and light or nil
end

-- Whether `model` can be the silhouette: everything in NEEDS, the lights
-- to put out, and a way to hold it still.
local function Inks(model)
    if not (model and KILLER.dark and Dark()) then return false end
    for _, method in ipairs(NEEDS) do
        if not Can(model, method) then return false end
    end
    return Can(model, "FreezeAnimation") or (Can(model, "SetAnimation") and Can(model, "SetPaused"))
end

-- Whether the client can draw the print.
local function Prints()
    return type(SetPortraitTextureFromCreatureDisplayID) == "function"
end

-- Whether `model` has drawn something: its model file, where the client
-- says; taken on trust where it cannot.
local function Drawn(model)
    if not Can(model, "GetModelFileID") then return true end
    local ok, id = Try(model, "GetModelFileID")
    if not ok then return true end
    id = ns.Plain(id)
    return type(id) == "number" and id > 0
end

-- Held still: the first of KILLER.pose's attacks the model has, else
-- standing; frozen, or else paused.
local function Freeze(model)
    local P = KILLER.pose
    local anim = P.anim
    for _, id in ipairs(P.blow or {}) do
        local ok, has = Try(model, "HasAnimation", id)
        if ok and ns.Plain(has) == true then
            anim = id
            break
        end
    end
    if Try(model, "FreezeAnimation", anim, P.variation, P.at) then return true end
    Try(model, "SetAnimation", anim)
    return (Try(model, "SetPaused", true))
end

-- The model framed (KILLER.frame) in profile toward `facing`, in a window
-- `w` by `h`: the whole creature on its own camera, or its head and
-- shoulders cropped from that.
local function Frame(model, facing, w, h)
    local head = KILLER.frame == "head" and Can(model, "SetCamDistanceScale") and Can(model, "SetViewTranslation")
        and KILLER.head
    Try(model, "SetPortraitZoom", 0)
    Try(model, "SetFacing", facing)
    Try(model, "SetCamDistanceScale", head and head.distance or KILLER.distance)
    local away = facing == KILLER.face.left and 1 or -1
    Try(model, "SetViewTranslation", head and away * head.shift[1] * w or 0, head and -head.shift[2] * h or 0)
end

-- The model as ink: framed in profile toward `facing` in a window `w` by
-- `h`, still, its lights out, its particles off. Called again once the
-- model has loaded, as a load may reset it.
local function Ink(model, facing, w, h)
    Frame(model, facing, w, h)
    Freeze(model)
    local dark = Dark()
    if dark then Try(model, "SetLight", true, dark) end
    Try(model, "SetParticlesEnabled", false)
end

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

-- A card on `parent` (the right page): a paper strip, its model made
-- when first wanted. card:SetKiller(k, seed, now) with Choose's killer
-- (and k.mark, its cross on `parent`), then card:Layout(x, y, width) as a
-- strip's; card.mode says what its picture is: "ink", "print" or "name".
function KillerCard.New(parent)
    local card = ns.UI.PaperStrip(parent)
    local Strip = ns.UI.PAPER_STRIP

    -- The print's window: its ink edge, the portrait, its photo corners.
    card.printEdge = card:CreateTexture(nil, "ARTWORK", nil, 2)
    card.print = card:CreateTexture(nil, "ARTWORK", nil, 3)
    card.corners = {}
    for i = 1, 4 do card.corners[i] = card:CreateTexture(nil, "ARTWORK", nil, 4) end
    for _, texture in ipairs({ card.printEdge, card.print, unpack(card.corners) }) do
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        texture:Hide()
    end

    -- The model: a child of the strip, a level over its textures (its tape
    -- is clear of it), never taking the mouse; made once.
    local function Model()
        if card.model == nil then
            local ok, model = pcall(CreateFrame, "PlayerModel", nil, card)
            card.model = ok and model or false
            if card.model then
                model:SetFrameLevel(card:GetFrameLevel() + 1)
                Try(model, "EnableMouse", false)
                model:Hide()
                -- A load may reset what was set before it: set again.
                local can, has = Try(model, "HasScript", "OnModelLoaded")
                if can and has then
                    model:SetScript("OnModelLoaded", function(m)
                        if card.mode == "ink" and card.picture then
                            Ink(m, card.facing, card.picture.w, card.picture.h)
                        end
                    end)
                end
            end
        end
        return card.model or nil
    end
    card.Model = Model

    -- What the picture is: the silhouette, the print or none, down the
    -- ladder.
    local function Mode(k)
        if not (k and k.display) then return "name" end
        if KILLER.silhouette and not BLANK[k.display] and Inks(Model()) then return "ink" end
        if Prints() then return "print" end
        return "name"
    end

    function card:SetKiller(k, seed, now)
        self.killer, self.foe, self.bare = k, nil, nil
        self.mode = Mode(k)
        self:SetNote({ name = k.name, what = ns.UI.JourneyText.Killed(k.count), strong = true, seed = seed,
            tapeAt = KILLER.tapeAt, turn = KILLER.turn,
            tip = function() return KillerCard.Tip(k, now) end })
    end

    -- The same card for the creature that nearly got you (JRN-25, Foe's):
    -- its heading, its name with its tag over it, the fight under it
    -- (VITALS), the close call's tooltip; its leader to the cross in
    -- outline.
    function card:SetFoe(f, seed, now)
        local Text = ns.UI.JourneyText
        self.killer, self.foe, self.bare = f, f, nil
        self.mode = Mode(f)
        self:SetNote({ name = f.name, what = Text.CloseDeed(f.call), strong = true, seed = seed,
            tapeAt = KILLER.tapeAt, turn = KILLER.turn,
            tip = function()
                local title, lines = Text.FoeTip(f.call, now)
                local list = { { title } }
                for _, line in ipairs(lines or {}) do list[#list + 1] = { line, 1, 1, 1, true } end
                return list
            end })
    end

    -- The print in the picture's room: the portrait, cropped to the room's
    -- shape, desaturated and warmed; false where it would not draw.
    local function Print(display)
        local texture = card.print
        if not (Prints() and pcall(SetPortraitTextureFromCreatureDisplayID, texture, display)) then return false end
        texture:SetDesaturated(true)
        local T = KILLER.print.tint
        texture:SetVertexColor(T[1], T[2], T[3], 1)
        return true
    end

    -- The picture laid in its room, as the card lies now.
    local function Picture()
        local pic, k = card.picture, card.killer
        local model = card.model or nil
        local ink, printed = card.mode == "ink" and pic ~= nil, card.mode == "print" and pic ~= nil
        if model then model:SetShown(ink) end
        card.print:SetShown(printed)
        card.printEdge:SetShown(printed)
        for _, corner in ipairs(card.corners) do corner:SetShown(printed) end
        if not pic then return end

        -- Toward its cross: the leader leaves on that side.
        local box = card.box
        card.facing = (k.mark and box and k.mark[1] < box[1] + box[3] / 2) and KILLER.face.left or KILLER.face.right

        if ink then
            model:ClearAllPoints()
            model:SetPoint("CENTER", card, "CENTER", pic.X, pic.Y)
            model:SetSize(pic.w, pic.h)
            if card.shownDisplay ~= k.display then
                card.shownDisplay = k.display
                Try(model, "SetDisplayInfo", k.display)
                -- One that draws nothing gives way to the print, and its
                -- display is not tried again this session.
                local display = k.display
                if C_Timer and C_Timer.After then
                    C_Timer.After(KILLER.check, function()
                        if card.shownDisplay ~= display or card.mode ~= "ink" then return end
                        -- Put away before it could load (another level
                        -- opened, the book closed): no verdict, and not laid
                        -- again, which would show it on whatever page is open
                        -- now; it is tried again when next shown. (11 Oct, in
                        -- the client: level 8's close call, opened and left
                        -- at once, lay on level 7 as a print.)
                        if not (card:IsVisible() and model:IsVisible()) then
                            card.shownDisplay = nil
                            return
                        end
                        if Drawn(model) then
                            local room = card.picture or pic
                            Ink(model, card.facing, room.w, room.h)
                        else
                            BLANK[display] = true
                            card.shownDisplay = nil
                            card.mode = Prints() and "print" or "name"
                            if card.box then card:Layout(card.box[1], card.box[2], card.column, card.room) end
                        end
                    end)
                end
            end
            Ink(model, card.facing, pic.w, pic.h)
            return
        end

        if not Print(k.display) then
            card.print:Hide()
            card.printEdge:Hide()
            for _, corner in ipairs(card.corners) do corner:Hide() end
            return
        end
        -- A square portrait shown through the room's shape: its full width,
        -- a band of its height a little above the middle (the head).
        local share = math.min(1, pic.h / pic.w)
        local v0 = math.max(0, 0.45 - share / 2)
        card.print:SetTexCoord(0, 1, v0, v0 + share)
        card:Lay(card.print, pic.lx, pic.ly, pic.w, pic.h)
        local P, INK = KILLER.print, Style.INK
        card.printEdge:SetColorTexture(INK[1], INK[2], INK[3], P.edge)
        card:Lay(card.printEdge, pic.lx, pic.ly, pic.w + 2, pic.h + 2)
        -- Its photo corners: a small pocket over each corner, a triangle
        -- where corners can move, none where they cannot.
        local c, x0, y0 = P.corner, pic.lx - pic.w / 2 - 1, pic.ly - pic.h / 2 - 1
        local x1, y1 = x0 + pic.w + 2, y0 + pic.h + 2
        local tri = {
            { x0, y0, x0 + c, y0, x0, y0 + c, x0, y0 + c },
            { x1 - c, y0, x1, y0, x1, y0 + c, x1, y0 + c },
            { x1, y1 - c, x1, y1 - c, x1, y1, x1 - c, y1 },
            { x0, y1 - c, x0, y1 - c, x0 + c, y1, x0, y1 },
        }
        for i, corner in ipairs(card.corners) do
            corner:SetColorTexture(P.ink[1], P.ink[2], P.ink[3], P.alpha)
            corner:SetShown(card:Bend(corner, unpack(tri[i])) == true)
        end
    end

    -- The close call's heading, chart and tag (VITALS): made when first
    -- wanted, drawn on the slip.
    local vitals
    local function Vitals()
        if vitals then return vitals end
        vitals = {
            heading = Style.Text(card, Style.FONT.noteWritten),
            edge = card:CreateTexture(nil, "ARTWORK", nil, 1),
            paper = card:CreateTexture(nil, "ARTWORK", nil, 2),
            fill = card:CreateTexture(nil, "ARTWORK", nil, 3),
            tick = card:CreateTexture(nil, "ARTWORK", nil, 4),
            figure = Style.Text(card, Style.FONT.noteWritten),
            deed = Style.Text(card, Style.FONT.small),
            tagShadow = card:CreateTexture(nil, "ARTWORK", nil, 1),
            tagEdge = card:CreateTexture(nil, "ARTWORK", nil, 2),
            tagPaper = card:CreateTexture(nil, "ARTWORK", nil, 3),
            tagText = Style.Text(card, Style.FONT.small),
        }
        for _, texture in ipairs({ vitals.edge, vitals.paper, vitals.fill, vitals.tick, vitals.tagShadow,
            vitals.tagEdge, vitals.tagPaper }) do
            if texture.SetSnapToPixelGrid then
                texture:SetSnapToPixelGrid(false)
                texture:SetTexelSnappingBias(0)
            end
        end
        card.vitals = vitals
        return vitals
    end
    local function HideVitals()
        if not vitals then return end
        for _, region in pairs(vitals) do region:Hide() end
    end

    local function Width(text)
        text:SetSize(0, 0)
        return math.ceil(text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth() or 0)
    end

    -- The heading's words in the hand, at FONT.noteWritten's own size or
    -- at `size`; its width and height.
    local function Heading(size)
        local v = Vitals()
        v.heading:SetFontObject(Style.FONT.noteWritten)
        if size then v.heading:SetFont(HAND, size, "") end
        v.heading:SetText(ns.UI.JourneyText.CloseHeading())
        return Width(v.heading) + 2, math.max(math.ceil(v.heading:GetStringHeight() or 0), 14)
    end

    -- The figure's words and its width, at the hand's large size.
    local function Figure(f)
        local v = Vitals()
        v.figure:SetFontObject(Style.FONT.noteWritten)
        v.figure:SetFont(HAND, VITALS.figure.size, "")
        v.figure:SetText(((f.call and f.call.pct) or 0) .. "%")
        return Width(v.figure) + 2, math.max(math.ceil(v.figure:GetStringHeight() or 0), VITALS.figure.size)
    end

    -- The tag's words (Text.FoeTag), and its size, or nil without one;
    -- `split`, its rank on a line of its own under its level.
    local function Tag(f, split)
        local words = ns.UI.JourneyText.FoeTag(f.call or f)
        if not words then return nil end
        local lines = { words }
        if split then
            local level, rank = words:match("^(.-) (%(.+%))$")
            if level then lines = { level, rank } end
        end
        -- Each line measured on its own, the widest kept.
        local v, G = Vitals(), VITALS.tag
        local w, h = 0, 0
        for _, line in ipairs(lines) do
            v.tagText:SetText(line)
            w = math.max(w, Width(v.tagText))
            h = h + math.max(math.ceil(v.tagText:GetStringHeight() or 0), 10)
        end
        words = table.concat(lines, "\n")
        v.tagText:SetText(words)
        return words, w + 2 * G.pad[1] + 1, h + 2 * G.pad[2]
    end

    -- The deed's words and width, for the row.
    local function Deed(f)
        local v = Vitals()
        v.deed:SetText(ns.UI.JourneyText.CloseDeed(f.call or {}))
        return Width(v.deed) + 2, math.max(math.ceil(v.deed:GetStringHeight() or 0), 11)
    end

    -- The chart in the room the strip kept under the name (card.under).
    -- `inline`: the deed on the row.
    local function DrawVitals(barW, inline)
        local f, room = card.foe, card.under
        if not (f and room) then return end
        local v, B, R, INK = Vitals(), VITALS.bar, Style.RUBRIC, Style.INK
        local P = Strip.STRIP.paper
        local pct = math.max(0, math.min(100, (f.call and f.call.pct) or 0))
        -- The bar at the room's left, its foot on the room's.
        local left, foot = room.lx - room.w / 2, room.ly + room.h / 2
        local bx, by = left + barW / 2, foot - B.h / 2 - 1
        v.edge:SetColorTexture(INK[1], INK[2], INK[3], B.edge)
        card:Lay(v.edge, bx, by, barW + 2, B.h + 2)
        v.paper:SetColorTexture(P[1], P[2], P[3], 1)
        card:Lay(v.paper, bx, by, barW, B.h)
        local fw = math.max(B.least, barW * pct / 100)
        v.fill:SetColorTexture(R[1], R[2], R[3], 0.95)
        card:Lay(v.fill, left + fw / 2, by, fw, B.h)
        local G, T = Style.GRAPHITE, B.tick
        v.tick:SetColorTexture(G[1], G[2], G[3], T.alpha)
        card:Lay(v.tick, left + barW * T.at, by, T.width, B.h + 2 + 2 * T.over)
        -- The figure beside it, its foot on the bar's.
        local fW, fH = Figure(f)
        v.figure:SetTextColor(R[1], R[2], R[3])
        card:Lay(v.figure, left + barW + VITALS.figure.gap + fW / 2, foot - fH / 2 + 2, fW, fH)
        for _, key in ipairs({ "edge", "paper", "fill", "tick", "figure" }) do v[key]:Show() end
        if inline then
            local dW, dH = Deed(f)
            v.deed:SetTextColor(INK[1], INK[2], INK[3])
            card:Lay(v.deed, left + barW + VITALS.figure.gap + fW + VITALS.deed.gap + dW / 2, foot - dH / 2, dW, dH)
            v.deed:Show()
        else
            v.deed:Hide()
        end
    end

    -- Over the name, in the room the strip kept there (card.picture, as
    -- laid): the heading at its top, the picture under it, the tag at its
    -- foot (`top`, Layout's plan). The picture's own room is then
    -- card.picture, nil without one.
    local function DrawTop(top)
        local v, room = Vitals(), card.picture
        if not room then return end
        local left, at = room.lx - room.w / 2, room.ly - room.h / 2
        local S = Style.INK_STRONG
        v.heading:SetTextColor(S[1], S[2], S[3])
        card:Lay(v.heading, left + top.hw / 2, at + top.hh / 2, top.hw, top.hh)
        v.heading:Show()
        -- For the tests: the heading's box on the slip, as laid flat (x0,
        -- y0, x1, y1, from the slip's middle).
        card.heading = { left, at, left + top.hw, at + top.hh }
        at = at + top.hh
        card.picture = nil
        if top.pic then
            local lx, ly = left + top.pic.w / 2, at + VITALS.head.gap + top.pic.h / 2
            local X, Y = card:Screen(lx, ly)
            local px, py = card:Out(lx, ly)
            card.picture = { lx = lx, ly = ly, w = top.pic.w, h = top.pic.h, X = X, Y = Y, x = px, y = py }
            at = at + VITALS.head.gap + top.pic.h
        end
        -- The tag, pasted at the left over the name, for a level or a rank
        -- kept.
        for _, key in ipairs({ "tagShadow", "tagEdge", "tagPaper", "tagText" }) do v[key]:SetShown(top.tag ~= nil) end
        card.tag = nil
        if not top.tag then return end
        local G, INK = VITALS.tag, Style.INK
        local tw, th = top.tw, top.th
        local tx, ty = left + tw / 2, at + G.gap + th / 2
        local seed = 0
        for i = 1, #top.tag do seed = seed + top.tag:byte(i) * i end
        local more = card.flat and 0 or math.rad(G.turn[1] + (G.turn[2] - G.turn[1]) * Style.Noise(seed))
        local D = G.shadow
        v.tagShadow:SetColorTexture(INK[1], INK[2], INK[3], card.flat and 0 or D[3])
        card:Lay(v.tagShadow, tx + D[1], ty + D[2], tw, th, more)
        v.tagEdge:SetColorTexture(INK[1], INK[2], INK[3], G.edge)
        card:Lay(v.tagEdge, tx, ty, tw + 1, th + 1, more)
        v.tagPaper:SetColorTexture(G.paper[1], G.paper[2], G.paper[3], 1)
        card:Lay(v.tagPaper, tx, ty, tw - 1, th - 1, more)
        v.tagText:SetTextColor(S[1], S[2], S[3])
        card:Lay(v.tagText, tx, ty, tw - 2 * G.pad[1], th - 2 * G.pad[2], more)
        -- For the tests: the tag's box on the slip, as the heading's.
        card.tag = { text = top.tag, box = { tx - tw / 2, ty - th / 2, tx + tw / 2, ty + th / 2 } }
    end

    -- Where the margin has too little room for a close call's card, it
    -- gives up its picture first (drawn small and still too tall: Layout's
    -- `room`), then its deed (the tooltip still says it): the chart is
    -- what it is kept for. Whether there was anything left to give up (the
    -- page lays it again).
    function card:Smaller()
        if not self.foe then return false end
        if self.mode ~= "name" then
            self.mode = "name"
            return true
        end
        if not self.bare and ns.UI.JourneyText.CloseDeed(self.foe.call or {}) ~= "" then
            self.bare = true
            return true
        end
        return false
    end

    -- The close call's deed as written, on the row or under it (for the
    -- tests).
    function card:Deed()
        if vitals and vitals.deed:IsShown() then return vitals.deed:GetText() end
        return self:What()
    end

    -- Laid as a strip, with room for its picture by the column's width
    -- (KILLER.picture, or .narrow), its name at the smaller hand where it
    -- is long, its words in ink; a close call's with room for its heading
    -- and tag round the picture and for its chart (VITALS) under the name,
    -- its picture drawn small (VITALS.compact, card.compact) where it
    -- would stand taller than `room` px (the margin's height left, where
    -- the page says). card.overfull where the name will not fit `width`
    -- even so (the page leaves it off).
    local layout = card.Layout
    local Lay
    function card:Layout(x, y, width, room)
        self.room, self.compact = room, nil
        local w, h = Lay(self, x, y, width)
        if self.foe and self.picture and room and h > room then
            self.compact = true
            w, h = Lay(self, x, y, width)
        end
        return w, h
    end
    function Lay(self, x, y, width)
        self.column = width
        local note = self.note or {}
        local pic = self.mode ~= "name" and (width < KILLER.narrow.below and KILLER.narrow or KILLER.picture) or nil
        local pad, T = Strip.STRIP.pad, Strip.TAPE
        local room = width - pad[1] - pad[3]
        -- The slip's tape `tapeAt` of the way along, the slip wide enough
        -- for it to start KILLER.clear px past what is at its top (`over`
        -- px wide): a killer's picture, a close call's heading. Its middle
        -- is at most TAPE.inset from the end.
        local function Least(over, tapeAt)
            local reach = pad[1] + over + KILLER.clear + T.w / 2
            return math.ceil(math.max(reach / tapeAt, reach + T.inset))
        end
        local barW, inline, top
        if self.foe then
            barW = width < KILLER.narrow.below and VITALS.narrow or VITALS.bar.w
            local fW, fH = Figure(self.foe)
            local dW = Deed(self.foe)
            local row = barW + VITALS.figure.gap + fW
            local deed = not self.bare and ns.UI.JourneyText.CloseDeed(self.foe.call or {}) or ""
            inline = deed ~= "" and row + VITALS.deed.gap + dW <= room
            if inline then row = row + VITALS.deed.gap + dW end
            note.what = not inline and deed or ""
            note.under = { w = row, h = math.max(fH, VITALS.bar.h + 2), gap = VITALS.room.gap,
                after = VITALS.room.after }
            -- Over the name: the heading, at the smaller hand where the
            -- slip would be too wide for it and its tape; the picture; the
            -- tag, its rank under its level where it is too wide.
            if pic and self.compact then pic = VITALS.compact end
            local hw, hh = Heading()
            if Least(hw, VITALS.tapeAt) > width then hw, hh = Heading(KILLER.small) end
            local tag, tw, th = Tag(self.foe)
            if tag and tw > room then tag, tw, th = Tag(self.foe, true) end
            top = { hw = hw, hh = hh, pic = pic, tag = tag, tw = tw, th = th }
            note.picture = { w = math.max(hw, pic and pic.w or 0, tw or 0),
                h = hh + (pic and VITALS.head.gap + pic.h or 0) + (tag and VITALS.tag.gap + th or 0),
                gap = tag and VITALS.tag.under or KILLER.picture.gap }
            note.tapeAt = VITALS.tapeAt
            note.least = Least(hw, VITALS.tapeAt)
        else
            note.under = nil
            note.picture = pic
            note.tapeAt = KILLER.tapeAt
            note.least = pic and Least(pic.w, KILLER.tapeAt) or nil
        end
        self.name:SetFontObject(Style.FONT.noteWritten)
        self.name:SetText(note.name or "")
        if (self.name:GetUnboundedStringWidth() or 0) > room then self.name:SetFont(HAND, KILLER.small, "") end
        self.overfull = (self.name:GetUnboundedStringWidth() or 0) > room
            or (note.least or 0) > width or (note.under ~= nil and note.under.w > room)
            or (note.picture ~= nil and note.picture.w > room)
        local w, h = layout(self, x, y, width)
        local INK = Style.INK
        for i = 1, self.shownLines or 0 do self.lines[i]:SetTextColor(INK[1], INK[2], INK[3]) end
        -- A killer's card has no heading, chart or tag (the pool hands the
        -- same card to a killer and a close call by turns, two a plate).
        HideVitals()
        self.tag, self.heading = nil, nil
        if self.foe then DrawTop(top) end
        Picture()
        if self.foe then DrawVitals(barW, inline) end
        return w, h
    end

    return card
end

-- The card's tooltip as Style.Tooltip takes it: the creature's name, and
-- its lines (UI/JourneyText.lua's KillerTip).
function KillerCard.Tip(k, now)
    local title, lines = ns.UI.JourneyText.KillerTip(k, now)
    local list = { { title } }
    for _, line in ipairs(lines or {}) do list[#list + 1] = { line, 1, 1, 1, true } end
    return list
end

KillerCard.KILLER, KillerCard.MATCH, KillerCard.RANK, KillerCard.VITALS = KILLER, MATCH, RANK, VITALS
KillerCard.Can, KillerCard.Inks = Can, Inks
