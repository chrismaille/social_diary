-- The witness card (Your Diary's plates): someone who was there when you
-- died or nearly did (Capture/Witnesses.lua), as
-- .claude/ui-proposal/witness-card-proposal.md. It takes the killer card's
-- place in the margin (or the close call's, for a rescue: the user's call,
-- 14 Oct, a person in the moment is the better story than the creature):
-- a paper strip (UI/PaperStrip.lua) taped in the margin with a pencil
-- leader to the death cross or the close call's mark, and on it, down the
-- slip:
--
--   the name     the person, the card's subject, in the diary's hand
--                (their first name, Text.WitnessName), a way to their page
--                as a person's strip is; "Ilsabet & two others" on the one
--                line where more were there and it fits, else the name
--                alone (the tooltip still says who else was there). It never
--                takes a line of its own (14 Oct, the user, after level 14's
--                M card read on four lines)
--   the deed     what they did, in the hand, the timeline's own verbs
--                (Text.WitnessDeed): "saw you die", "watched you die",
--                "mercilessly watched you die" (the hand underlines
--                "mercilessly" twice, DOUBLE, as one does when one cannot
--                believe it); "tried to save you", "saved you"
--   the foe      what it was against, in small print (Text.WitnessFoe):
--                "to a Ragged Young Wolf", "from Hogger". Secondary: the
--                first thing given up where the margin is short, and then
--                the caption names the creature, as it does a killer whose
--                card is left off
--   the chart    a rescue's health left only, charted as the close call's
--                card charts it (UI/KillerCard.lua's VITALS: an ink box
--                filled in rubric, a graphite tick at the tenth where a
--                close call begins), the figure large in rubric, "6%": how
--                near it was, which is what they saved you from
--
-- A watcher's card was laid on a page you bled on (BLOOD): dried blood,
-- splashed across the slip's corner and off its edge onto the page, a pool,
-- a run or two over the edge and droplets flung past it, built as the heat
-- map's ink blots are (UI/InkBlot.lua: drops that run together, a darker
-- rim where it dried), in the card's own turn. It may run under the ends of
-- the lines nearest its corner, never under the name or the rest of a line,
-- and under a word it is the wash alone, lighter (BLOOD.soft, .under): the
-- words keep their contrast. The longer they watched, the more of it (a
-- glance a small stain, mercilessly a palm's splash, runs and a spray): the
-- longer you lay there. How long is in the tooltip, never on the card
-- (14 Oct, the user: no seconds count; the strokes went with it).
--
-- The family's rule holds: the hand is what happened, small print what it
-- was against. The name is in ink like everyone else's on the plates (no
-- class colour: a coloured name would read as another kind of thing, and
-- the blues read as Alliance); the tooltip says who they are.
--
-- Its size is not picked by name: card:Layout(x, y, width) tries FORMS in
-- turn (ORDER) and keeps the first that fits the width: XL the deed in the
-- name's own hand on one line; L the deed a size down, on two lines at
-- most; M the name a size down too, the bar narrower. Short of height it
-- gives up its foe's line (card:Smaller; the caption names the creature);
-- then the page leaves it off and the caption tells the witness in a
-- sentence of its own (Text.PlateCaption's `witness`).
--
-- Laid flat ("Flat paper only") the slip lies square and so does its blood;
-- the underlines, the chart and the blood are ink and stay.

local addonName, ns = ...

local Style = ns.Style

local WitnessCard = {}
ns.UI.WitnessCard = WitnessCard

-- The slip: turned at most `turn` degrees (the other cards'). Under the
-- name, `deed` px to the deed (none: the two read as one sentence), the
-- deed's lines `line` px at the hand's 16 and 14; `foe` px to the foe's
-- small print, its lines `foeLine` px; `row` px to the chart.
local WITNESS = { turn = 1.2, deed = 0, line = { [16] = 19, [14] = 17 }, foe = 1, foeLine = 13, row = 4 }
-- The arrangements, tried in turn: the least width of the box it takes
-- (`least`: XL only where a row or a caption column is wide, 190 px and
-- more; L the 150 to 176 px columns; M the 122 px column and the 142 px
-- boxes of a row), the name's size in the hand, the deed's, the most lines
-- the deed and the foe may take, and the rescue's bar's width (the close
-- call's, KillerCard.VITALS: 70, or 56 in a narrow column).
local FORMS = {
    XL = { least = 190, name = 16, deed = 16, deedLines = 1, foeLines = 1, bar = 70 },
    L = { least = 150, name = 16, deed = 14, deedLines = 2, foeLines = 2, bar = 70 },
    M = { least = 0, name = 14, deed = 14, deedLines = 3, foeLines = 2, bar = 56 },
}
local ORDER = { "XL", "L", "M" }
-- "Mercilessly" underlined twice by the hand: the lucky card's underline
-- (UI/LuckyCard.lua's UNDER, the route's pen), and a second `second` px
-- under the first, `inset` px shorter at its start and its end, as a second
-- stroke is drawn quicker.
local DOUBLE = { second = 2.6, inset = { 2, 5 } }
-- The blood on a watcher's card, all in px of the slip (from its middle,
-- y down), seeded by the card's key: a stain across one of the slip's right
-- corners and off its edges onto the page.
--   amount   by how long they watched (Text.WitnessLook): the pool's drops
--            (`pool`, run together within `spread` px of its middle), the
--            lobes it splashed into (`lobes`, each a quarter of the pool,
--            in toward the slip), the runs over the right edge (`runs`)
--            and the drips over the lower or upper one (`drips`), the
--            droplets on the page round the corner (`drops`) and back on
--            the slip (`back`). A glance a small stain and a few drops;
--            watched a stain the size of a thumb's print, a run and a drip;
--            mercilessly a palm's splash, two of each and a spray
--            (14 Oct, in the client: the first, a few drops 2 or 3 px
--            across past "Wolf", read as crumbs, not a stain)
--   low      the share of cards whose blood is at the lower corner (else
--            the upper; the left has the tape)
--   out      the most anything reaches past the slip's right edge (`side`:
--            a row's boxes are 8 px apart, a right-hand column has the
--            page's edge 8 px on) and past its lower or upper one (`foot`:
--            notes down a column are 12 px apart), each leaving 3 px or
--            more to the next note. (14 Oct, the testdata pages: at 7 and
--            10 px it came within 1 px of the note beside or under it.)
--   along    how far along the edges from the corner the droplets fall
--            (px), the nearer the likelier (`near`, a power); `tail` of them
--            trail a smaller drop back toward the pool, as a flung drop does
--   size     weights (InkBlot's: a drop's size): the pool's, a droplet's,
--            a run's or a drip's first and last
--   soft     what of the writing it may run under (the user, 14 Oct: under
--            the text's edge is fine): the right end of the `lines` deed or
--            foe lines nearest its corner, `share` of each line and at most
--            `most` px of it (its last word or two). Never the name line,
--            the underlines, the chart or the rest of a line: no drop comes
--            nearer those than `clear` px
--   under    what lies under a word is the wash alone, at this alpha (the
--            words keep at least 5:1 against it, small print in INK too);
--            the core and the rim never lie under a word
--   levels   InkBlot's: the wash (the whole stain) and the core (where it
--            pooled, darker)
--   ink      dried blood on paper, never a game decal's red: the wash a
--            brown red that lets the paper through a little, the core and
--            the rim (`rim` px, where it dried) darker and browner
--   step, warp, cap   InkBlot's grid, its wobble, the most pieces a card
local BLOOD = {
    amount = {
        saw = { pool = 7, spread = 3.6, lobes = 0, runs = 0, drips = 0, drops = 6, back = 1 },
        watched = { pool = 20, spread = 7.5, lobes = 2, runs = 1, drips = 1, drops = 11, back = 2 },
        merciless = { pool = 34, spread = 10.5, lobes = 3, runs = 2, drips = 2, drops = 18, back = 3 },
    },
    low = 0.7, out = { side = 5, foot = 8 }, along = { 44, near = 1.5, tail = 0.5 },
    size = { pool = { 0.7, 1 }, drop = { 0.26, 0.85 }, run = { 0.9, 0.35 } },
    soft = { lines = 2, share = 0.45, most = 36 }, clear = 1.5, under = 0.40,
    levels = { { sigma = 2.0, edge = 0.22, from = 0, full = 1 }, { sigma = 1.8, edge = 0.55, from = 0.8, full = 1 } },
    ink = { { 0.42, 0.11, 0.06, 0.66 }, { 0.30, 0.065, 0.04, 0.6 } }, rim = 0.8, rimInk = { 0.25, 0.05, 0.03, 0.55 },
    step = 0.8, warp = { 0.6, 8 }, cap = 560,
}

local HAND = "Interface\\AddOns\\" .. addonName .. "\\Fonts\\Neuton-Italic.ttf"

local function Width(text)
    if text.GetUnboundedStringWidth then return text:GetUnboundedStringWidth() or 0 end
    return text:GetStringWidth() or 0
end

-- `text` in the diary's hand at `size` (its own, 16, without one).
local function Hand(text, size)
    text:SetFontObject(Style.FONT.noteWritten)
    if size and size ~= 16 then text:SetFont(HAND, size, "") end
end

-- A number from a string, the same every time (PaperStrip's), and a
-- stream of them.
local function Seed(key)
    local seed = 0
    key = tostring(key or "")
    for i = 1, #key do seed = (seed + key:byte(i) * i) % 100003 end
    return seed
end
local function Random(key)
    local rand = ns.UI.InkTrail.Random(Seed(key))
    return function(a, b) return a + (b - a) * rand() end, rand
end

-- What a witness's card has to show under its words: "chart" (a rescue's
-- health left), else nil.
function WitnessCard.Evidence(w)
    if w.type == "saved_you" and type(w.pct) == "number" then return "chart" end
    return nil
end

-- How much blood a witness's card has (BLOOD.amount), nil for a helper.
function WitnessCard.Blood(w)
    local look = ns.UI.JourneyText.WitnessLook(w)
    return look and BLOOD.amount[look] or nil
end

-- Where the blood may and may not go on a card whose writing is
-- `writing` ({ name, lines, marks }: boxes { x0, y0, x1, y1 } from the
-- slip's middle, y down; `lines` the deed's and the foe's, `marks` the
-- underlines and the chart), its corner `sy` (1 the lower, -1 the upper):
-- `hard`, the boxes no drop may come near (BLOOD.soft), and `words`, every
-- box of writing (what lies under them is the wash alone, BLOOD.under).
function WitnessCard.Keep(writing, H, sy)
    local S = BLOOD.soft
    local hard, words = { writing.name }, { writing.name }
    for _, b in ipairs(writing.marks or {}) do
        hard[#hard + 1] = b
        words[#words + 1] = b
    end
    -- The lines nearest the corner, by how far their box is from it.
    local cy = sy * H / 2
    local order = {}
    for i, b in ipairs(writing.lines or {}) do
        words[#words + 1] = b
        order[#order + 1] = { i = i, d = math.min(math.abs(b[2] - cy), math.abs(b[4] - cy)) }
    end
    table.sort(order, function(a, b) return a.d < b.d or (a.d == b.d and a.i < b.i) end)
    local soft = {}
    for k = 1, math.min(S.lines, #order) do soft[order[k].i] = true end
    for i, b in ipairs(writing.lines or {}) do
        local x1 = b[3]
        if soft[i] then x1 = b[3] - math.min(S.most, S.share * (b[3] - b[1])) end
        if x1 > b[1] then hard[#hard + 1] = { b[1], b[2], x1, b[4] } end
    end
    return hard, words
end

-- The blood's drops for a card `W` by `H` (from its middle, y down) whose
-- writing is `writing` (Keep's), by `amount`, seeded by `key`: { { x, y, t
-- } } for InkBlot.Build, every one clear of the hard writing (Keep) and
-- within BLOOD.out of the slip; the corner it lies across; and Keep's
-- `hard` and `words`.
function WitnessCard.Spill(amount, W, H, writing, key)
    local B = BLOOD
    local U, rand = Random(key .. ":blood")
    local low = rand() < B.low
    local sy = low and 1 or -1
    local hw, hh = W / 2, H / 2
    local hard, words = WitnessCard.Keep(writing, H, sy)
    -- A drop's radius at weight t (a lone bump of InkBlot's wash, a little
    -- more where drops run together).
    local L = B.levels[1]
    local function Radius(t)
        if t <= L.edge then return 0 end
        return L.sigma * math.sqrt(2 * math.log(t / L.edge)) + 0.9
    end
    local function Clear(x, y, t)
        local r = Radius(t)
        if x + r > hw + B.out.side or math.abs(y) + r > hh + B.out.foot then return false end
        for _, b in ipairs(hard) do
            local dx = math.max(b[1] - x, 0, x - b[3])
            local dy = math.max(b[2] - y, 0, y - b[4])
            if dx * dx + dy * dy < (r + B.clear) ^ 2 then return false end
        end
        return true
    end
    local points = {}
    local function Spill(x, y, t)
        if Clear(x, y, t) then points[#points + 1] = { x = x, y = y, t = t } end
    end
    local function Near(most) return most * rand() ^ B.along.near end
    local function Line(x0, y0, x1, y1, n)
        local S = B.size.run
        for i = 0, n - 1 do
            local f = i / (n - 1)
            Spill(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, S[1] + (S[2] - S[1]) * f)
        end
    end
    -- The pool, across the corner, its far side at the reach's limit: most
    -- of it on the slip's corner, the rest on the page.
    local r1 = Radius(1)
    local px = hw + B.out.side - r1 - amount.spread * 0.55
    local py = sy * (hh + B.out.foot - r1 - amount.spread * 0.55)
    local function Cluster(cx, cy, n, spread)
        for k = 1, n do
            local a, d = U(0, 2 * math.pi), (k == 1 and 0 or math.sqrt(rand())) * spread
            Spill(cx + d * math.cos(a), cy + d * math.sin(a), k == 1 and 1 or U(B.size.pool[1], B.size.pool[2]))
        end
    end
    Cluster(px, py, amount.pool, amount.spread)
    -- Its lobes, splashed in toward the slip (up and left of a lower
    -- corner), so the stain is never a disc.
    local inward = math.atan2(-sy, -1)
    for _ = 1, amount.lobes do
        local a = inward + math.rad(U(-65, 65))
        local d = amount.spread * U(0.8, 1.25)
        Cluster(px + d * math.cos(a), py + d * math.sin(a), math.ceil(amount.pool / 4), amount.spread * 0.45)
    end
    -- Runs over the right edge, from the slip onto the page; drips over
    -- the lower (upper) edge.
    for k = 1, amount.runs do
        local y = py - sy * (amount.spread * U(0.7, 1.3) + (k - 1) * U(6, 10))
        Line(hw - U(8, 14), y, hw + B.out.side - 1.5, y + U(-1.2, 1.2), 9)
    end
    for k = 1, amount.drips do
        local x = px - amount.spread * U(0.8, 1.6) - (k - 1) * U(7, 12)
        Line(x, sy * (hh - U(6, 10)), x + U(-1.2, 1.2), sy * (hh + B.out.foot - 1.5), 9)
    end
    -- Droplets on the page round the corner: along the right edge, or the
    -- lower (upper) one, the nearer the corner the likelier.
    for _ = 1, amount.drops do
        local t = U(B.size.drop[1], B.size.drop[2])
        local x, y
        if rand() < 0.4 then
            x, y = hw + U(1.5, B.out.side - 1), py - sy * (amount.spread + Near(math.min(B.along[1], H)))
        else
            x, y = px - amount.spread - Near(math.min(B.along[1] * 1.5, W)), sy * (hh + U(1.5, B.out.foot - 1.5))
        end
        Spill(x, y, t)
        if rand() < B.along.tail then
            local dx, dy = px - x, py - y
            local d = math.max(math.sqrt(dx * dx + dy * dy), 1)
            local back = U(2, 3.5)
            Spill(x + dx / d * back, y + dy / d * back, t * 0.55)
        end
    end
    -- And a few back on the slip, beyond the stain.
    for _ = 1, amount.back do
        local a = inward + math.rad(U(-50, 50))
        local d = amount.spread * 1.4 + U(3, 12)
        Spill(px + d * math.cos(a), py + d * math.sin(a), U(B.size.drop[1], 0.6))
    end
    return points, low and "br" or "tr", hard, words
end

-- InkBlot's pieces for `points` in the slip's px: the wash and the core,
-- and the rim, each { x1, y1, ..., x4, y4 }; no piece crosses an edge of
-- `words` (so each lies wholly under a word or wholly clear of it).
function WitnessCard.Stain(points, W, H, words)
    local B = BLOOD
    local hw, hh = W / 2, H / 2
    local reach = math.max(B.out.side, B.out.foot) + 4
    local cutsX, cutsY = {}, {}
    for _, b in ipairs(words or {}) do
        cutsX[#cutsX + 1], cutsX[#cutsX + 2] = b[1], b[3]
        cutsY[#cutsY + 1], cutsY[#cutsY + 2] = b[2], b[4]
    end
    return ns.UI.InkBlot.Build(points, B.levels, { step = B.step, clip = { -hw - reach, -hh - reach, hw + reach,
        hh + reach }, rim = B.rim, warp = B.warp, cap = B.cap, cutsX = cutsX, cutsY = cutsY })
end

-- Whether a piece's middle lies in one of `boxes`.
function WitnessCard.Under(q, boxes)
    local x, y = (q[1] + q[3] + q[5] + q[7]) / 4, (q[2] + q[4] + q[6] + q[8]) / 4
    for _, b in ipairs(boxes) do
        if x > b[1] and x < b[3] and y > b[2] and y < b[4] then return true end
    end
    return false
end

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

-- A card on `parent` (the right page): card:SetWitness(w, seed, now, guid,
-- onClick) with the plate's witness (UI/KillerCard.lua's Witness; `guid`
-- where their page can be opened), then card:Layout(x, y, width) as a
-- strip's; card.overfull where no arrangement fits `width` (the page
-- leaves it off); card:Smaller() gives up a step. card.form says which
-- arrangement it took, card.plan.foe whether the foe's line is written,
-- card.blood what of the blood was spilt.
function WitnessCard.New(parent)
    local card = ns.UI.PaperStrip(parent)
    local Strip = ns.UI.PAPER_STRIP

    local function Texture(layer, sublevel)
        local texture = card:CreateTexture(nil, layer, nil, sublevel)
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        return texture
    end
    card.deeds = {}
    card.foes = {}
    card.figure = Style.Text(card, Style.FONT.noteWritten)
    card.ink = {}
    card.stain = {}
    card.barEdge = Texture("ARTWORK", 1)
    card.barPaper = Texture("ARTWORK", 2)
    card.barFill = Texture("ARTWORK", 3)
    card.barTick = Texture("ARTWORK", 4)
    -- Hidden measures, in the hand and in small print.
    card.measure = Style.Text(card, Style.FONT.noteWritten)
    card.measure:Hide()
    card.small = Style.Text(card, Style.FONT.small)
    card.small:Hide()

    function card:SetWitness(w, seed, now, guid, onClick)
        local Text = ns.UI.JourneyText
        self.witness, self.now, self.seedKey = w, now, seed
        self.step, self.plan, self.form = 0, nil, nil
        self:SetNote({ name = Text.WitnessName(w), strong = true, seed = seed, turn = WITNESS.turn, guid = guid,
            onClick = onClick, tip = function()
                local title, lines = Text.WitnessTip(w, now)
                local list = { { title } }
                for _, line in ipairs(lines) do list[#list + 1] = { line, 1, 1, 1, true } end
                if guid then list[#list + 1] = { "Click to open their page in the diary", 0.6, 0.6, 0.6, true } end
                return list
            end })
    end

    -- A step less, where the margin is short (UI/JournalJourney.lua's
    -- LayNotes): the foe's line. Whether there was one to give up.
    function card:Smaller()
        if (self.step or 0) >= 1 or not ns.UI.JourneyText.WitnessFoe(self.witness) then return false end
        self.step = 1
        return true
    end

    -- `text` in lines no wider than `room`, measured on `probe`; nil where
    -- it takes more than `most` or a word alone is too wide.
    local function Wrap(probe, text, room, most)
        local lines, line = {}, ""
        for word in text:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            probe:SetText(try)
            if line ~= "" and Width(probe) > room then
                lines[#lines + 1] = line
                line = word
            else
                line = try
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
        if #lines > most then return nil end
        for _, l in ipairs(lines) do
            probe:SetText(l)
            if Width(probe) > room then return nil end
        end
        return lines
    end

    -- The same, never one word alone on the last line where there are
    -- more ("mercilessly watched you / die"): wrapped again narrower,
    -- `step` px at a time down to `least` of the room, keeping as many
    -- lines (PaperStrip's STRIP.balance).
    local function Balanced(probe, text, room, most)
        local lines = Wrap(probe, text, room, most)
        if not lines or #lines < 2 or lines[#lines]:find("%s") then return lines end
        local B = Strip.STRIP.balance
        local w = room - B.step
        while w >= room * B.least do
            local try = Wrap(probe, text, w, most)
            if not try or #try ~= #lines then break end
            if try[#try]:find("%s") then return try end
            w = w - B.step
        end
        return lines
    end

    local function Widest(probe, lines)
        local w = 0
        for _, l in ipairs(lines) do
            probe:SetText(l)
            w = math.max(w, Width(probe) + 2)
        end
        return w
    end

    -- The chart's width and height, for a rescue.
    local function Row(form)
        local w = card.witness
        if WitnessCard.Evidence(w) ~= "chart" then return nil end
        local V = ns.UI.KillerCard.VITALS
        Hand(card.measure, V.figure.size)
        card.measure:SetText((w.pct or 0) .. "%")
        local fw = Width(card.measure) + 2
        return { kind = "chart", bar = FORMS[form].bar, fw = fw, w = math.ceil(FORMS[form].bar + V.figure.gap + fw),
            h = math.max(V.figure.size, V.bar.h + 2) }
    end

    -- One arrangement (FORMS[form]) in `width` px: its plan, or nil where it
    -- does not fit (`force`: planned all the same, for the page to measure
    -- and leave off). Heights and widths of what goes under the name.
    local function Try(form, width, force)
        local F = FORMS[form]
        local pad = Strip.STRIP.pad
        local room = width - pad[1] - pad[3]
        local Text = ns.UI.JourneyText
        local w = card.witness
        local step = card.step or 0
        local fail = width < F.least
        -- The name, and who else was there on its line where that fits.
        local name = card.note and card.note.name or ""
        Hand(card.name, F.name)
        local others = Text.WitnessOthers(w.others)
        local line = others and (name .. " " .. others) or name
        card.name:SetText(line)
        if others and Width(card.name) + 2 > room then
            line, others = name, nil
            card.name:SetText(line)
        end
        card.name:SetSize(0, 0)
        local nameW = Width(card.name) + 2
        local nameH = math.max(math.ceil(card.name:GetStringHeight() or 0), 14)
        if nameW > room then fail = true end
        -- The deed, in the hand.
        local deedText, under = Text.WitnessDeed(w)
        Hand(card.measure, F.deed)
        local deed = Balanced(card.measure, deedText, room, F.deedLines)
        if not deed then
            fail = true
            deed = { deedText }
        end
        local deedW = Widest(card.measure, deed)
        -- The foe, in small print.
        local foeText = step < 1 and Text.WitnessFoe(w) or nil
        local foe
        if foeText then
            foe = Balanced(card.small, foeText, room, F.foeLines)
            if not foe then
                fail = true
                foe = { foeText }
            end
        end
        local foeW = foe and Widest(card.small, foe) or 0
        -- A rescue's chart.
        local row = Row(form)
        if row and row.w > room then fail = true end
        if fail and not force then return nil end

        local lineH = WITNESS.line[F.deed] or WITNESS.line[14]
        local deedTop = WITNESS.deed
        local h = deedTop + #deed * lineH
        local foeTop
        if foe then
            foeTop = h + WITNESS.foe
            h = foeTop + #foe * WITNESS.foeLine
        end
        local rowTop
        if row then
            rowTop = h + WITNESS.row
            h = rowTop + row.h
        end
        local underW = math.max(deedW, foeW, row and row.w or 0)
        return { form = form, F = F, line = line, others = others, nameW = nameW, nameH = nameH, deed = deed,
            deedSize = F.deed, lineH = lineH, deedTop = deedTop, under = under, foe = foe, foeTop = foeTop, row = row,
            rowTop = rowTop, h = math.ceil(h), w = math.ceil(underW),
            W = math.max(math.ceil(underW) + pad[1] + pad[3], nameW + pad[1] + pad[3]) }
    end

    -- `text` laid with its left at x, its middle at y (from the slip's
    -- middle, y down).
    local function Put(text, x, y, w, h)
        card:Lay(text, x + w / 2, y, w, h)
        text:Show()
    end

    -- A piece of the pen laid flat where corners cannot move: from the
    -- middle of its start to the middle of its end (LuckyCard's).
    local function Flat(q)
        local sx, sy = (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2
        local ex, ey = (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2
        local dx, dy = ex - sx, ey - sy
        local width = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2)
            + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
        return (sx + ex) / 2, (sy + ey) / 2, math.sqrt(dx * dx + dy * dy) + 0.3, math.max(width, 0.4),
            math.atan2(-dy, dx)
    end

    -- The pen's quads on the slip, from card.ink.
    local function Ink(prims)
        for k, q in ipairs(prims) do
            local t = card.ink[k]
            if not t then
                t = Texture("ARTWORK", 5)
                card.ink[k] = t
            end
            t:SetColorTexture(q.r, q.g, q.b, q.a)
            if not card:Bend(t, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
                local mx, my, length, w, angle = Flat(q)
                card:Lay(t, mx, my, length, w, angle)
            end
            t:Show()
        end
        for k = #prims + 1, #card.ink do card.ink[k]:Hide() end
        return #prims
    end

    -- A quad of the slip (upper left, upper right, lower right, lower left,
    -- from its middle, y down) on a texture, turned with the slip, laid
    -- flat or not (the slip's own Bend only bends where it is not flat);
    -- false where the client cannot move a texture's corners.
    local VERTEX = Enum and Enum.VertexIndex or {}
    local UL, LL, UR, LR = VERTEX.UpperLeft or 1, VERTEX.LowerLeft or 2, VERTEX.UpperRight or 3, VERTEX.LowerRight or 4
    local function Quad(region, x1, y1, x2, y2, x3, y3, x4, y4)
        if not region.SetVertexOffset then return false end
        local ulx, uly = card:Screen(x1, y1)
        local urx, ury = card:Screen(x2, y2)
        local lrx, lry = card:Screen(x3, y3)
        local llx, lly = card:Screen(x4, y4)
        local w = math.max(0.1, math.sqrt(((x2 + x3) - (x1 + x4)) ^ 2 + ((y2 + y3) - (y1 + y4)) ^ 2) / 2)
        local h = math.max(0.1, math.sqrt(((x4 + x3) - (x1 + x2)) ^ 2 + ((y4 + y3) - (y1 + y2)) ^ 2) / 2)
        local mx, my = (ulx + llx + urx + lrx) / 4, (uly + lly + ury + lry) / 4
        region:ClearAllPoints()
        region:SetPoint("CENTER", card, "CENTER", mx, my)
        region:SetSize(w, h)
        if region.SetRotation then region:SetRotation(0) end
        region:SetVertexOffset(UL, ulx - (mx - w / 2), uly - (my + h / 2))
        region:SetVertexOffset(LL, llx - (mx - w / 2), lly - (my - h / 2))
        region:SetVertexOffset(UR, urx - (mx + w / 2), ury - (my + h / 2))
        region:SetVertexOffset(LR, lrx - (mx + w / 2), lry - (my - h / 2))
        return true
    end

    -- The blood, for a watcher (BLOOD): under the writing and the tape (its
    -- own layer, BORDER, over the slip's paper and grain), each level's
    -- pieces in its ink, then the rim. Where corners cannot move, none.
    local function Bleed(W, H, writing)
        local used = 0
        card.blood = nil
        local amount = WitnessCard.Blood(card.witness)
        if amount then
            local points, corner, hard, words = WitnessCard.Spill(amount, W, H, writing, card.seedKey or "witness")
            local stain = WitnessCard.Stain(points, W, H, words)
            local B = BLOOD
            local layers = {}
            for n, quads in ipairs(stain.levels) do layers[#layers + 1] = { quads, B.ink[n], n, n == 1 } end
            layers[#layers + 1] = { stain.rim, B.rimInk, 3, false }
            local drawn, under, pieces = 0, 0, {}
            for _, layer in ipairs(layers) do
                local quads, ink, sublevel, wash = layer[1], layer[2], layer[3], layer[4]
                for _, q in ipairs(quads) do
                    -- Under a word: the wash alone, lighter (BLOOD.under).
                    local beneath = WitnessCard.Under(q, words)
                    if wash or not beneath then
                        used = used + 1
                        local t = card.stain[used]
                        if not t then
                            t = Texture("BORDER", 1)
                            card.stain[used] = t
                        end
                        t:SetDrawLayer("BORDER", sublevel)
                        t:SetColorTexture(ink[1], ink[2], ink[3], beneath and B.under or ink[4])
                        if Quad(t, q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8]) then
                            t:Show()
                            drawn = drawn + 1
                            pieces[drawn] = { q = q, level = sublevel, under = beneath }
                            if beneath then under = under + 1 end
                        else
                            t:Hide()
                        end
                    end
                end
            end
            -- For the tests: the drops, the pieces, the corner, where it may
            -- not go and what is writing.
            card.blood = { points = points, stain = stain, corner = corner, drawn = drawn, under = under, hard = hard,
                words = words, pieces = pieces }
        end
        for i = used + 1, #card.stain do card.stain[i]:Hide() end
    end

    -- Everything but the name, as planned, the slip laid `W` by `H`.
    local function Draw(plan, W, H)
        local pad = Strip.STRIP.pad
        local INK, STRONG = Style.INK, Style.INK_STRONG
        local left = -W / 2 + pad[1]
        local nameTop = -H / 2 + pad[2]
        local top = nameTop + plan.nameH
        local Lucky = ns.UI.LuckyCard
        for _, part in ipairs({ card.figure, card.barEdge, card.barPaper, card.barFill, card.barTick }) do
            part:Hide()
        end
        -- Where the writing is, for the blood (WitnessCard.Keep).
        local writing = { name = { left, nameTop + 2, left + plan.nameW, nameTop + plan.nameH }, lines = {}, marks = {} }

        -- The deed, in the hand, a line at a time.
        local pieces = {}
        for i, words in ipairs(plan.deed) do
            local line = card.deeds[i]
            if not line then
                line = Style.Text(card, Style.FONT.noteWritten)
                card.deeds[i] = line
            end
            Hand(line, plan.deedSize)
            line:SetText(words)
            line:SetTextColor(STRONG[1], STRONG[2], STRONG[3])
            local ly = top + plan.deedTop + (i - 0.5) * plan.lineH
            local lw = Width(line) + 2
            Put(line, left, ly, lw, plan.lineH)
            writing.lines[#writing.lines + 1] = { left, ly - plan.lineH / 2 + 2, left + lw, ly + plan.lineH / 2 }
            -- "Mercilessly", underlined twice.
            local at = plan.under and words:find(plan.under, 1, true)
            if at then
                Hand(card.measure, plan.deedSize)
                card.measure:SetText(words:sub(1, at - 1))
                local x0 = left + (at > 1 and Width(card.measure) or 0)
                card.measure:SetText(plan.under)
                local x1 = x0 + Width(card.measure)
                local base = ly + 0.3 * plan.deedSize
                local seed = card.seedKey or "witness"
                local first = Lucky.Underline(seed .. ":u1", x0, x1, base)
                local second = Lucky.Underline(seed .. ":u2", x0 + DOUBLE.inset[1], x1 - DOUBLE.inset[2],
                    base + DOUBLE.second)
                for _, q in ipairs(Lucky.Pen(first, Lucky.UNDER)) do pieces[#pieces + 1] = q end
                for _, q in ipairs(Lucky.Pen(second, Lucky.UNDER)) do pieces[#pieces + 1] = q end
                card.underlined = { x0 = x0, x1 = x1, base = base }
                writing.marks[#writing.marks + 1] = { x0 - 2, ly, x1 + 5, base + DOUBLE.second + 5 }
            end
        end
        for i = #plan.deed + 1, #card.deeds do card.deeds[i]:Hide() end
        card.pieces = Ink(pieces)

        -- The foe, in small print.
        for i, words in ipairs(plan.foe or {}) do
            local line = card.foes[i]
            if not line then
                line = Style.Text(card, Style.FONT.small)
                card.foes[i] = line
            end
            line:SetText(words)
            line:SetTextColor(INK[1], INK[2], INK[3])
            line:SetSize(0, 0)
            local ly, lw = top + plan.foeTop + (i - 0.5) * WITNESS.foeLine, Width(line) + 2
            Put(line, left, ly, lw, WITNESS.foeLine)
            writing.lines[#writing.lines + 1] = { left, ly - WITNESS.foeLine / 2, left + lw, ly + WITNESS.foeLine / 2 }
        end
        for i = #(plan.foe or {}) + 1, #card.foes do card.foes[i]:Hide() end

        -- A rescue's chart (KillerCard.VITALS): the bar at the left, the
        -- figure beside it.
        local row = plan.row
        if row then
            local V, R, P = ns.UI.KillerCard.VITALS, Style.RUBRIC, Strip.STRIP.paper
            local B = V.bar
            local pct = math.max(0, math.min(100, card.witness.pct or 0))
            local foot = top + plan.rowTop + row.h
            local by = foot - B.h / 2 - 1
            card.barEdge:SetColorTexture(INK[1], INK[2], INK[3], B.edge)
            card:Lay(card.barEdge, left + row.bar / 2, by, row.bar + 2, B.h + 2)
            card.barPaper:SetColorTexture(P[1], P[2], P[3], 1)
            card:Lay(card.barPaper, left + row.bar / 2, by, row.bar, B.h)
            local fw = math.max(B.least, row.bar * pct / 100)
            card.barFill:SetColorTexture(R[1], R[2], R[3], 0.95)
            card:Lay(card.barFill, left + fw / 2, by, fw, B.h)
            local G, T = Style.GRAPHITE, B.tick
            card.barTick:SetColorTexture(G[1], G[2], G[3], T.alpha)
            card:Lay(card.barTick, left + row.bar * T.at, by, T.width, B.h + 2 + 2 * T.over)
            for _, part in ipairs({ card.barEdge, card.barPaper, card.barFill, card.barTick }) do part:Show() end
            Hand(card.figure, V.figure.size)
            card.figure:SetText((card.witness.pct or 0) .. "%")
            card.figure:SetTextColor(R[1], R[2], R[3])
            Put(card.figure, left + row.bar + V.figure.gap, foot - V.figure.size / 2 + 1, row.fw, V.figure.size)
            writing.marks[#writing.marks + 1] = { left - 1, foot - row.h, left + row.w, foot }
        end
        card.writing = writing
        Bleed(W, H, writing)
    end

    -- Laid as a strip, the first arrangement that fits `width` (FORMS, in
    -- ORDER), everything under the name in the room the strip keeps there.
    local layout = card.Layout
    function card:Layout(x, y, width)
        local plan
        for _, form in ipairs(ORDER) do
            plan = Try(form, width)
            if plan then break end
        end
        self.overfull = plan == nil
        plan = plan or Try(ORDER[#ORDER], width, true)
        -- The name line again at the arrangement's size (Try measured the
        -- others).
        Hand(self.name, plan.F.name)
        self.name:SetText(plan.line)
        local note = self.note
        note.under = { w = plan.w, h = plan.h, gap = 0, after = 0 }
        note.least, note.what = nil, nil
        self.plan, self.form, self.underlined = plan, plan.form, nil
        local W, H = layout(self, x, y, width)
        -- (The strip writes its note's name; the line with the others is
        -- the card's.)
        self.name:SetText(plan.line)
        Draw(plan, W, H)
        return W, H
    end

    -- The width the card would like: XL, all of it on its lines, and never
    -- less than XL's least. The page gives a row's box this much where it
    -- has it (UI/JournalJourney.lua's ROW).
    function card:Preferred()
        return math.max(FORMS.XL.least, Try("XL", 10000, true).W)
    end

    -- For the tests: the deed as written, its lines joined.
    function card:Deed()
        local parts = {}
        for i = 1, #(self.plan and self.plan.deed or {}) do parts[#parts + 1] = self.deeds[i]:GetText() end
        return table.concat(parts, " ")
    end

    -- For the tests: the foe's line as written ("" without one).
    function card:Foe()
        local parts = {}
        for i = 1, #(self.plan and self.plan.foe or {}) do parts[#parts + 1] = self.foes[i]:GetText() end
        return table.concat(parts, " ")
    end

    return card
end

-- The width a card for `w` would like (card:Preferred), measured on a card
-- of its own that is never shown.
local measurer
function WitnessCard.Preferred(w)
    measurer = measurer or WitnessCard.New(UIParent)
    measurer:SetWitness(w, "measure", 0)
    return measurer:Preferred()
end

WitnessCard.WITNESS, WitnessCard.FORMS, WitnessCard.ORDER, WitnessCard.DOUBLE, WitnessCard.BLOOD =
    WITNESS, FORMS, ORDER, DOUBLE, BLOOD
