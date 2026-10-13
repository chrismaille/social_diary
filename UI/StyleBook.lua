-- The book itself (Style, from UI/StyleTokens.lua): the open pages with
-- the stack beneath, paper grain, the gutter, the ribbons, the leather
-- cover with its brass corners, and the loose sheet the entry editor sits
-- on outside the journal.

local addonName, ns = ...

local Style = ns.Style
local Noise = Style.Noise

--------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------

-- The pages under the open ones, showing at the outer edges as a stack.
-- Each page shows as an edge STACK_STEP pixels wide; a side with more pages
-- than fit in STACK pixels shows finer edges instead, so a thick side reads
-- as a dense block. Lower pages sit a little further out, a little shorter
-- (STACK_DROP per full step, top and bottom) and a little darker, with a
-- fine ink line where each page ends. How many pages lie on each side is
-- the caller's (book:SetStack); where a side has few, the board shows in
-- the rest of the room.
--
-- A handled book is never that regular, so on top of that some pages sit
-- out of line or have slipped (STACK_SHIFTS), one or two have a corner
-- turned down (STACK_DOG_EARS), each page's tone and ink line drift along
-- its length, and damp has foxed it in a few spots. (Grime mottling and
-- dark thumbed bands were tried here and looked wrong in the client.)
local STACK_STEP, STACK_DROP = 2, 1.5
local STACK = 12

-- Per side (left, then right), per page from the top, repeating down the
-- stack: { how far it stands out of line (negative: tucked in), how much
-- taller it is at the top, and at the bottom }, in pixels. How far out is
-- for full-width edges, and shrinks with finer ones.
local STACK_SHIFTS = {
    { { 0, 0, 0 }, { 1, 1, 0 }, { 0, 0, -1 }, { -1, 0, 1 }, { 0, -1, 0 }, { 0, 1, 1 }, { 1, 0, 0 } },
    { { 0, 0, 1 }, { 0, -1, 0 }, { 1, 2, 0 }, { 0, 0, -1 }, { 1, 0, 2 }, { 0, 1, 0 }, { -1, 0, 0 } },
}

-- Tone and ink drift between knots KNOT_MIN to KNOT_MIN + KNOT_SPREAD apart.
local KNOT_MIN, KNOT_SPREAD = 28, 64

-- Foxing: { side, height fraction, page from the top it is on, diameter,
-- alpha }. It is there while its page is.
local STACK_FOXING = {
    { 1, 0.23, 4, 5, 0.30 },
    { 1, 0.71, 2, 4, 0.24 },
    { 2, 0.38, 5, 6, 0.28 },
    { 2, 0.41, 2, 3, 0.22 },
    { 2, 0.80, 3, 4, 0.26 },
}
local FOX = { 0.50, 0.30, 0.12 }

-- Pages in the stack with a corner turned down: { side, page from the
-- top, "top" or "bottom" corner, size in pixels }. In the page's strip the
-- corner is gone (the page beneath shows, or the board when it is the last
-- on its side), then the turned-over flap. Only ever on these pages, never
-- the open ones; on edges too fine for the flap, only the gap shows.
local STACK_DOG_EARS = {
    { 1, 2, "top", 10 },
    { 2, 3, "bottom", 13 },
}

-- Bound pages bow: their top and bottom edges dip toward the binding, by
-- GUTTER_DIP pixels at the fold, easing out over GUTTER_REACH on each side.
-- The cover shows in the dip (Style.Cover puts the headband there).
local GUTTER_DIP, GUTTER_REACH, DIP_STEP = 7, 48, 2
Style.GUTTER_DIP = GUTTER_DIP

-- Shading along the pages' top and bottom edges: { top?, depth, alpha at
-- the edge }. A tight dark band where the cover's lip overhangs the pages,
-- then a long soft falloff.
local EDGE_SHADES = {
    { true, 6, 0.30 },
    { true, 34, 0.14 },
    { false, 5, 0.26 },
    { false, 24, 0.12 },
}

local function Dip(distance)
    local t = math.max(0, 1 - distance / GUTTER_REACH)
    return GUTTER_DIP * t * t
end

local function PageStack(book, height)
    local P, INK = Style.PAPER, Style.INK
    local circle = Style.Art("circle")
    -- Wear that `/sd art grain` scales, with the paper grain.
    book.grain = {}

    -- Per side, a function that lays it out with `count` pages and returns
    -- how far in from the outer edge the stack ends.
    local layouts = {}

    for s, side in ipairs({ -1, 1 }) do
        -- Textures per sublevel, made as the stack first needs them and
        -- handed out again each time it is laid out; the rest are hidden.
        local pools = {}

        -- A rectangle `near`..`far` in from this side's outer edge and
        -- `top`..`bottom` down from the top.
        local function Place(sublevel, near, far, top, bottom)
            local pool = pools[sublevel]
            if not pool then
                pool = { used = 0 }
                pools[sublevel] = pool
            end
            pool.used = pool.used + 1
            local texture = pool[pool.used]
            if not texture then
                texture = book:CreateTexture(nil, "BACKGROUND", nil, sublevel)
                -- Edges finer than a pixel blend in instead of snapping away.
                if texture.SetSnapToPixelGrid then
                    texture:SetSnapToPixelGrid(false)
                    texture:SetTexelSnappingBias(0)
                end
                pool[pool.used] = texture
            end
            texture:ClearAllPoints()
            if side < 0 then
                texture:SetPoint("TOPLEFT", book, "TOPLEFT", near, -top)
                texture:SetPoint("BOTTOMRIGHT", book, "TOPLEFT", far, -bottom)
            else
                texture:SetPoint("TOPLEFT", book, "TOPRIGHT", -far, -top)
                texture:SetPoint("BOTTOMRIGHT", book, "TOPRIGHT", -near, -bottom)
            end
            texture:Show()
            return texture
        end
        -- Flat colour as a gradient, so a texture handed out again does not
        -- keep the gradient it had before.
        local function Flat(texture, colour)
            Style.Gradient(texture, "VERTICAL", colour, colour)
        end

        -- A strip whose colour drifts along its length: `Tone(n)` is the
        -- { r, g, b, a } at knot n, and each piece blends between two knots.
        local function Drift(sublevel, near, far, top, bottom, seed, Tone)
            local y, j, upper = top, 0, Tone(seed)
            while y < bottom do
                j = j + 1
                local y2 = math.min(bottom, y + KNOT_MIN + KNOT_SPREAD * Noise(seed + j + 0.5))
                local lower = Tone(seed + j)
                Style.Gradient(Place(sublevel, near, far, y, y2), "VERTICAL", lower, upper)
                y, upper = y2, lower
            end
        end
        local function Ink(alpha)
            return function(n) return { INK[1], INK[2], INK[3], alpha * (0.25 + Noise(n + 0.25)) } end
        end

        local function Tone(shade, n)
            local tone = shade * (0.97 + 0.06 * Noise(n))
            -- Some stretches have yellowed more than others.
            return { P[1] * tone, P[2] * tone, P[3] * tone * (0.95 + 0.05 * Noise(n + 0.5)), 1 }
        end
        -- Darker the further out from the open page.
        local function Shade(depth) return 0.97 - 0.0175 * depth end

        -- The open page's own edge, over the first page beneath it. Laid
        -- once: the stack's layouts leave this sublevel alone.
        Drift(-6, STACK, STACK + 1, 0, height, s * 1000, Ink(0.35))

        -- A dark core in a fainter halo, per spot on this side.
        local foxing = {}
        if circle then
            for _, spot in ipairs(STACK_FOXING) do
                if spot[1] == s then
                    for _, disc in ipairs({ { 1, 1 }, { 1.8, 0.35 } }) do
                        local texture = book:CreateTexture(nil, "BACKGROUND", nil, -5)
                        texture:SetSize(spot[4] * disc[1], spot[4] * disc[1])
                        texture:SetTexture(circle)
                        texture:SetVertexColor(FOX[1], FOX[2], FOX[3])
                        book.grain[#book.grain + 1] = { texture = texture, alpha = spot[5] * disc[2] }
                        foxing[#foxing + 1] = { texture = texture, spot = spot }
                    end
                end
            end
        end

        layouts[s] = function(count)
            pools[-8] = pools[-8] or { used = 0 }
            pools[-7] = pools[-7] or { used = 0 }
            pools[-8].used, pools[-7].used = 0, 0
            local step = math.min(STACK_STEP, STACK / math.max(count, 1))
            local scale = step / STACK_STEP
            local inkWidth = math.min(1, step / 2)

            -- Where each page lies. Each shows from its own outer side to
            -- the outer side of the page above; one tucked in behind its
            -- neighbours does not show.
            local pages, above, bottomPage = {}, STACK, nil
            for k = 1, count do
                local shift = STACK_SHIFTS[s][(k - 1) % #STACK_SHIFTS[s] + 1]
                local outer = STACK - k * step - shift[1] * scale
                local drop = k * STACK_DROP * scale
                pages[k] = {
                    outer = outer, above = above,
                    top = math.max(0, drop - shift[2]),
                    bottom = height - math.max(0, drop - shift[3]),
                }
                if outer < above then bottomPage = k end
                above = math.min(above, outer)
            end

            for k, page in ipairs(pages) do
                local outer, above, top, bottom = page.outer, page.above, page.top, page.bottom
                local seed = s * 1000 + k * 100
                if outer < above then
                    local width = above - outer
                    -- A turned-down corner, row by row from the corner:
                    -- where `x + row < size` (x in from the page's outer
                    -- side) the corner is gone, then comes the flap and
                    -- its fold.
                    local ear = {}
                    for _, dog in ipairs(STACK_DOG_EARS) do
                        if dog[1] == s and dog[2] == k then ear[dog[3]] = dog[4] end
                    end
                    for corner, size in pairs(ear) do
                        for row = 0, size - 1 do
                            local y = corner == "top" and top + row or bottom - row - 1
                            local fold = size - row
                            if k < count then
                                -- The page beneath, in the flap's shadow.
                                Flat(Place(-8, outer, outer + math.min(fold, width), y, y + 1),
                                    Tone(Shade(STACK - outer + step) * 0.90, seed + row))
                            end
                            if fold < width then
                                Flat(Place(-8, outer + fold, above, y, y + 1),
                                    Tone(Shade(STACK - outer) * 1.04, seed + row))
                                Flat(Place(-7, outer + fold, outer + fold + inkWidth, y, y + 1),
                                    { INK[1], INK[2], INK[3], 0.45 })
                            end
                        end
                    end
                    local from, to = top + (ear.top or 0), bottom - (ear.bottom or 0)
                    Drift(-8, outer, above, from, to, seed, function(n) return Tone(Shade(STACK - outer), n) end)
                    Drift(-7, outer, outer + inkWidth, from, to, seed + 50, Ink(k == bottomPage and 0.55 or 0.30))
                end
            end

            for _, sublevel in ipairs({ -8, -7 }) do
                local pool = pools[sublevel]
                for i = pool.used + 1, #pool do pool[i]:Hide() end
            end

            for _, fox in ipairs(foxing) do
                local page = pages[fox.spot[3]]
                local shown = page ~= nil and page.outer < page.above
                fox.texture:SetShown(shown)
                if shown then
                    fox.texture:ClearAllPoints()
                    fox.texture:SetPoint("CENTER", book, side < 0 and "TOPLEFT" or "TOPRIGHT",
                        -side * (page.outer + page.above) / 2, -fox.spot[2] * height)
                end
            end

            return bottomPage and pages[bottomPage].outer or STACK
        end
    end

    -- Lays the stack out with `left` and `right` pages beneath the open
    -- ones. Returns how far in from the book's left and right edges the
    -- stack now ends, for the board's shadow (Style.Cover's FitPages).
    function book:SetStack(left, right)
        self.stackPages = { left, right }
        return layouts[1](left), layouts[2](right)
    end
    book:SetStack(2, 2)
end

-- The open book: two parchment pages, a gutter between them, darker edges,
-- and the stack of pages beneath showing at the outer edges. Positions on
-- the pages stay measured from the book's own edges; the open pages start
-- STACK in from the outer ones.
function Style.Book(parent, leftWidth, width, height)
    local book = CreateFrame("Frame", nil, parent)
    local BOOK_RIGHT = width - STACK

    -- The page colour: two flat bodies, and narrow strips near the fold that
    -- step down into the dip. Each piece carries its own shading along the
    -- top and bottom edge, so the shadow bends into the dip with the paper.
    local P, INK = Style.PAPER, Style.INK
    local function Paper(x1, x2, inset)
        local strip = book:CreateTexture(nil, "BACKGROUND", nil, -8)
        strip:SetPoint("TOPLEFT", x1, -inset)
        strip:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", x2, inset)
        strip:SetColorTexture(P[1], P[2], P[3], 1)

        for _, shade in ipairs(EDGE_SHADES) do
            local top, depth, alpha = shade[1], shade[2], shade[3]
            local band = book:CreateTexture(nil, "BACKGROUND", nil, -6)
            if top then
                band:SetPoint("TOPLEFT", x1, -inset)
                band:SetPoint("TOPRIGHT", book, "TOPLEFT", x2, -inset)
                band:SetHeight(depth)
                Style.Shade(band, "VERTICAL", INK[1], INK[2], INK[3], 0, alpha)
            else
                band:SetPoint("BOTTOMLEFT", x1, inset)
                band:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", x2, inset)
                band:SetHeight(depth)
                Style.Shade(band, "VERTICAL", INK[1], INK[2], INK[3], alpha, 0)
            end
        end
    end
    Paper(STACK, leftWidth - GUTTER_REACH, 0)
    for d = 0, GUTTER_REACH - DIP_STEP, DIP_STEP do
        local inset = Dip(d + DIP_STEP / 2)
        Paper(leftWidth - d - DIP_STEP, leftWidth - d, inset)
        Paper(leftWidth + d, leftWidth + d + DIP_STEP, inset)
    end
    Paper(leftWidth + GUTTER_REACH, BOOK_RIGHT, 0)
    PageStack(book, height)

    book.paperLeft = book:CreateTexture(nil, "BACKGROUND", nil, -7)
    book.paperLeft:SetPoint("TOPLEFT", STACK, 0)
    book.paperLeft:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", leftWidth, 0)

    book.paperRight = book:CreateTexture(nil, "BACKGROUND", nil, -7)
    book.paperRight:SetPoint("TOPLEFT", leftWidth, 0)
    book.paperRight:SetPoint("BOTTOMRIGHT", -STACK, 0)

    function book:ApplyPaper()
        for _, side in ipairs({ "Left", "Right" }) do
            local texture = self["paper" .. side]
            local path = Style.Art("paper" .. side)
            texture:SetTexture(path)
            texture:SetShown(path ~= nil)
        end
    end
    book:ApplyPaper()
    Style.Grain(book, leftWidth)

    local function Edge(a, ax, b, bx, w, h, orientation, from, to)
        local edge = book:CreateTexture(nil, "BACKGROUND", nil, -6)
        edge:SetPoint(a, ax, 0)
        edge:SetPoint(b, bx, 0)
        if w then edge:SetWidth(w) else edge:SetHeight(h) end
        Style.Shade(edge, orientation, INK[1], INK[2], INK[3], from, to)
    end
    Edge("TOPLEFT", STACK, "BOTTOMLEFT", STACK, 26, nil, "HORIZONTAL", 0.32, 0)
    Edge("TOPRIGHT", -STACK, "BOTTOMRIGHT", -STACK, 26, nil, "HORIZONTAL", 0, 0.32)

    Style.Gutter(book, leftWidth, height)

    return book
end

-- Uneven age over the flat page: the stationery texture twice per page, at
-- different crops, flips and strengths so the layers drift against each
-- other and neither page mirrors the other, plus a few faint stains. Each
-- entry is { page, texcoords (l, r, t, b), alpha }; `page` 1 is the left.
-- Drawn in the BORDER layer, above the page colour and the ribbon, so the
-- ribbon takes the same grain and the cloth and paper read as one surface.
local GRAIN_LAYERS = {
    { 1, { 0.10, 0.95, 0.02, 0.98 }, 0.25 },
    { 1, { 0.90, 0.20, 0.95, 0.15 }, 0.11 },
    { 2, { 0.95, 0.12, 0.04, 0.96 }, 0.21 },
    { 2, { 0.35, 0.92, 0.45, 0.98 }, 0.125 },
}

-- { x, y as fractions of the book, diameter in pixels, alpha }. Each stain is
-- three stacked discs, so its edge steps off instead of ending sharp.
local STAINS = {
    { 0.06, 0.88, 120, 0.044 },
    { 0.27, 0.18, 70, 0.031 },
    { 0.52, 0.80, 170, 0.038 },
    { 0.83, 0.62, 90, 0.031 },
    { 0.95, 0.10, 140, 0.038 },
    { 0.70, 0.95, 60, 0.038 },
}

local grainStrength = 1

-- Adds to book.grain, which PageStack started with the stack's wear.
function Style.Grain(book, leftWidth)
    local path = Style.Art("grain")
    if path then
        for _, layer in ipairs(GRAIN_LAYERS) do
            local texture = book:CreateTexture(nil, "BORDER", nil, 0)
            -- Clear of the dip at the fold, where it would lighten the leather.
            if layer[1] == 1 then
                texture:SetPoint("TOPLEFT", STACK, -GUTTER_DIP)
                texture:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", leftWidth, GUTTER_DIP)
            else
                texture:SetPoint("TOPLEFT", leftWidth, -GUTTER_DIP)
                texture:SetPoint("BOTTOMRIGHT", -STACK, GUTTER_DIP)
            end
            texture:SetTexture(path)
            texture:SetTexCoord(unpack(layer[2]))
            book.grain[#book.grain + 1] = { texture = texture, alpha = layer[3] }
        end
    end

    local circle = Style.Art("circle")
    if circle then
        local INK = Style.INK
        book.stains = {}
        for _, stain in ipairs(STAINS) do
            for step = 1, 3 do
                local size = stain[3] * (1.1 - step * 0.2)
                local disc = book:CreateTexture(nil, "BORDER", nil, 1)
                disc:SetSize(size, size)
                disc:SetTexture(circle)
                disc:SetVertexColor(INK[1], INK[2], INK[3], 1)
                book.stains[#book.stains + 1] = { texture = disc, alpha = stain[4] / 2, x = stain[1], y = stain[2] }
            end
        end
        book:SetScript("OnSizeChanged", function(self, width, height)
            for _, stain in ipairs(self.stains) do
                stain.texture:ClearAllPoints()
                stain.texture:SetPoint("CENTER", self, "TOPLEFT", stain.x * width, -stain.y * height)
            end
        end)
    end

    function book:ApplyGrain()
        for _, layer in ipairs(self.grain) do layer.texture:SetAlpha(layer.alpha * grainStrength) end
        for _, stain in ipairs(self.stains or {}) do stain.texture:SetAlpha(stain.alpha * grainStrength) end
    end
    book:ApplyGrain()
end

-- `/sd art grain <percent>`: 100 is the designed strength, 0 is flat colour.
function Style.SetGrain(percent)
    grainStrength = math.max(0, math.min(percent, 300)) / 100
    ns.Print("paper grain at %d%%.", grainStrength * 100)
    ns.Fire("SD_PAPER_CHANGED")
end

-- A red cloth bookmark hanging from the top edge of a page, its tail cut in
-- a swallowtail: a paper-coloured diamond over the end makes the notch. The
-- cloth is the journal's red ribbon's (Style.RIBBONS, below).
function Style.Ribbon(book, x, width, length)
    local RED, EDGE = Style.RIBBONS.red.cloth, Style.RIBBONS.red.edge

    local function Piece(sublevel, left, right, r, g, b, a)
        local piece = book:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        piece:SetPoint("TOPLEFT", x + left, 4)
        piece:SetPoint("BOTTOMRIGHT", book, "TOPLEFT", x + width - right, -length)
        piece:SetColorTexture(r, g, b, a)
        return piece
    end

    -- Cloth, darker selvedges, a soft sheen off-centre.
    Piece(-4, 0, 0, RED[1], RED[2], RED[3], 1)
    Piece(-3, 0, width - 2, EDGE[1], EDGE[2], EDGE[3], 1)
    Piece(-3, width - 2, 0, EDGE[1], EDGE[2], EDGE[3], 1)
    Piece(-3, 5, width - 9, 1, 0.55, 0.45, 0.16)

    local notch = book:CreateTexture(nil, "BACKGROUND", nil, -2)
    local size = width * 0.72
    notch:SetSize(size, size)
    notch:SetPoint("CENTER", book, "TOPLEFT", x + width / 2, -length)
    notch:SetColorTexture(Style.PAPER[1], Style.PAPER[2], Style.PAPER[3], 1)
    notch:SetRotation(math.pi / 4)

    -- Its shadow on the page, to the right, where the light falls from.
    local shadow = book:CreateTexture(nil, "BACKGROUND", nil, -5)
    shadow:SetPoint("TOPLEFT", x + width, 0)
    shadow:SetPoint("BOTTOMRIGHT", book, "TOPLEFT", x + width + 4, -length + 6)
    Style.Shade(shadow, "HORIZONTAL", Style.INK[1], Style.INK[2], Style.INK[3], 0.22, 0)
end

-- The journal's page markers: cloth bookmarks that come out from between the
-- pages at the bottom of the book, cross the cover and fall over its edge.
-- Each one is a page of the journal, so they are the navigation: the open
-- page's ribbon hangs longer and in full colour, the others shorter and
-- dimmer.
--
-- Cloth does not fall straight. Past the cover's edge each ribbon lies on
-- the world along its own drape, and the purple one has a half twist in it.
-- To bend, a ribbon is built from RIBBON_STEP-pixel slices down its length,
-- each shifted sideways.
--
-- The light is the book's, from the top left. The ribbon's shadow falls
-- close, down and to the right: in ink on the page, darker on the leather
-- and on the world. Right below the cover the world is already in the
-- book's shadow (DropShadow), which falls across the ribbon too; the ribbon
-- adds no second shadow there, since shade does not darken shade.
--
-- Below the book there is no paper to cut a swallowtail into, so the tail
-- ends in a point instead: a square of the same cloth turned 45 degrees,
-- centred on the end and turned with it. Parented to the book, so the ribbon
-- draws over the cover; it starts a few pixels up the page, where no text
-- sits.
--
-- `drape` is the sideways offset in pixels every RIBBON_KNOT pixels past the
-- cover's edge, with a smooth curve through them; `twist` is { distance past
-- the edge, half its length, how much narrower the cloth looks at its
-- middle }. `sheen` is the light on the cloth, warm by default; grey cloth
-- would turn pink under it.
Style.RIBBONS = {
    red = { cloth = { 0.52, 0.07, 0.05 }, edge = { 0.28, 0.03, 0.02 },
        drape = { 0, -1.2, -3.4, -5.2, -5.8 } },
    purple = { cloth = { 0.34, 0.12, 0.42 }, edge = { 0.17, 0.05, 0.22 },
        drape = { 0, 1.2, 2.6, 5.0, 6.2 }, twist = { 18, 11, 0.22 } },
    gray = { cloth = { 0.40, 0.39, 0.37 }, edge = { 0.21, 0.20, 0.19 },
        drape = { 0, -0.6, -1.4, -1.6, -0.8 }, sheen = { 1, 1, 0.95 } },
    -- Your Diary's (8.11): bottle green, the first ribbon.
    green = { cloth = { 0.15, 0.30, 0.17 }, edge = { 0.06, 0.14, 0.07 },
        drape = { 0, 0.8, 1.6, 3.0, 3.8 }, twist = { 14, 8, 0.18 } },
}
local SHEEN = { 1, 0.6, 0.55 }

-- The book's shadow on the world: how far it reaches, and its alpha at the
-- book's edge, fading to nothing.
local BOOK_SHADOW, BOOK_SHADOW_ALPHA = 14, 0.5

local RIBBON_TUCK = 8                         -- how far up the page it starts
local RIBBON_HANG = { open = 58, shut = 40 }  -- how far below the book it ends
local RIBBON_DIM = 0.72
local RIBBON_STEP, RIBBON_KNOT = 1, 12
local RIBBON_PARTS = { "shadow", "softLeft", "softRight", "body", "leftEdge", "rightEdge", "sheen", "shade" }
local BLACK = { 0, 0, 0 }

-- The ribbon's shadow, by what it falls on: { offset down and right, colour,
-- alpha, width of its soft edge }.
local RIBBON_CAST = {
    page = { 1.5, Style.INK, 0.42, 2 },
    cover = { 2, BLACK, 0.55, 2.5 },
    world = { 2, BLACK, 0.45, 2.5 },
}

-- The drape's sideways offset `d` pixels past the cover's edge: a
-- Catmull-Rom curve through the knots, level past the last one.
local function Drape(knots, d)
    local f = math.max(0, d) / RIBBON_KNOT
    local i = math.floor(f)
    local t = f - i
    local function K(n) return knots[math.max(1, math.min(#knots, n + 1))] end
    local p0, p1, p2, p3 = K(i - 1), K(i), K(i + 1), K(i + 2)
    return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
        + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)
end

-- How much narrower the cloth looks `d` past the edge as it turns through
-- a twist: 0 where it lies flat.
local function Twist(twist, d)
    if not twist then return 0 end
    local t = (d - twist[1]) / twist[2]
    if math.abs(t) >= 1 then return 0 end
    local c = math.cos(t * math.pi / 2)
    return twist[3] * c * c
end

-- The book's shadow `d` pixels below the cover's edge.
local function BookShade(d)
    if d < 0 or d >= BOOK_SHADOW then return 0 end
    return BOOK_SHADOW_ALPHA * (1 - d / BOOK_SHADOW)
end

-- `cover` is how far the cover reaches past the pages.
function Style.BookRibbon(book, x, width, cover, colour, label, onClick)
    local cloth = Style.RIBBONS[colour] or Style.RIBBONS.red
    local edge = RIBBON_TUCK + cover  -- where it goes over the cover's edge

    local ribbon = CreateFrame("Button", nil, book)
    ribbon:SetWidth(width)
    ribbon:SetPoint("TOPLEFT", book, "BOTTOMLEFT", x, RIBBON_TUCK)
    ribbon.label = label

    -- Clicks reach as far as the drape swings, and no further: the
    -- neighbouring ribbon is close.
    local lo, hi = 0, 0
    for _, knot in ipairs(cloth.drape) do lo, hi = math.min(lo, knot), math.max(hi, knot) end
    ribbon:SetHitRectInsets(math.floor(lo), -math.ceil(hi), 0, 0)

    local function Texture(layer, sublevel)
        return ribbon:CreateTexture(nil, layer, nil, sublevel)
    end
    -- `left` and `top` in from the ribbon's top left.
    local function Place(texture, left, top, w, h)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", ribbon, "TOPLEFT", left, -top)
        texture:SetSize(w, h)
        texture:Show()
    end
    local function Cast(texture, colour, from, to)
        if from == to then
            texture:SetColorTexture(colour[1], colour[2], colour[3], from)
        else
            Style.Shade(texture, "HORIZONTAL", colour[1], colour[2], colour[3], from, to)
        end
    end

    -- The slices, made as the ribbon first needs them.
    local slices = {}
    local function Slice(i)
        if not slices[i] then
            slices[i] = {
                shadow = Texture("BACKGROUND", 0),
                softLeft = Texture("BACKGROUND", 0),
                softRight = Texture("BACKGROUND", 0),
                body = Texture("ARTWORK", 0),
                leftEdge = Texture("ARTWORK", 1),
                rightEdge = Texture("ARTWORK", 1),
                sheen = Texture("ARTWORK", 2),
                shade = Texture("ARTWORK", 3),  -- the book's shadow across it
            }
        end
        return slices[i]
    end

    ribbon.tipShadow = Texture("BACKGROUND", 0)
    ribbon.tip = Texture("ARTWORK", 0)

    local count, tipLight = 0, 1

    local function Layout()
        local length = RIBBON_TUCK + (ribbon.active and RIBBON_HANG.open or RIBBON_HANG.shut)
        ribbon:SetHeight(length)

        count = math.ceil(length / RIBBON_STEP)
        for i = count + 1, #slices do
            for _, part in ipairs(RIBBON_PARTS) do slices[i][part]:Hide() end
        end

        for i = 1, count do
            local slice = Slice(i)
            local top = (i - 1) * RIBBON_STEP
            local bottom = math.min(length, top + RIBBON_STEP)
            local mid, h = (top + bottom) / 2, bottom - top
            local narrow = Twist(cloth.twist, mid - edge)
            local w = width * (1 - narrow)
            local left = Drape(cloth.drape, mid - edge) + (width - w) / 2

            Place(slice.body, left, top, w, h)
            Place(slice.leftEdge, left, top, 2, h)
            Place(slice.rightEdge, left + w - 2, top, 2, h)
            -- The sheen keeps its place across the cloth as it turns.
            Place(slice.sheen, left + 5 * w / width, top, 4 * w / width, h)
            slice.light = 1 - 0.7 * narrow
            slice.shine = math.max(0, 1 - 3 * narrow)

            local nearTop, nearBottom = BookShade(top - edge), BookShade(bottom - edge)
            if nearTop > 0 or nearBottom > 0 then
                Place(slice.shade, left, top, w, h)
                Style.Shade(slice.shade, "VERTICAL", 0, 0, 0, nearBottom, nearTop)
            else
                slice.shade:Hide()
            end

            -- Its shadow, cut off where the surface under it ends.
            local surface, ends = "world", length + RIBBON_STEP + 4
            if mid < RIBBON_TUCK then
                surface, ends = "page", RIBBON_TUCK
            elseif mid < edge then
                surface, ends = "cover", edge
            end
            local o, colour, alpha, soft = unpack(RIBBON_CAST[surface])
            if surface == "world" then
                local shade = BookShade(mid + o - edge)
                alpha = math.max(0, (alpha - shade) / (1 - shade))
            end
            local shadowTop = top + o
            local shadowH = math.min(bottom + o, ends) - shadowTop
            if shadowH > 0 and alpha > 0 then
                Place(slice.shadow, left + o, shadowTop, w, shadowH)
                Cast(slice.shadow, colour, alpha, alpha)
                Place(slice.softLeft, left + o - soft, shadowTop, soft, shadowH)
                Cast(slice.softLeft, colour, 0, alpha)
                Place(slice.softRight, left + o + w, shadowTop, soft, shadowH)
                Cast(slice.softRight, colour, alpha, 0)
            else
                slice.shadow:Hide()
                slice.softLeft:Hide()
                slice.softRight:Hide()
            end
        end

        -- The point, turned to the way the cloth runs at the end.
        local d = length - edge
        local narrow = Twist(cloth.twist, d)
        local w = width * (1 - narrow)
        local sway = Drape(cloth.drape, d)
        local angle = math.atan((sway - Drape(cloth.drape, d - 2)) / 2)
        local size = w / math.sqrt(2)
        local o, colour, alpha = unpack(RIBBON_CAST.world)
        for _, part in ipairs({ { ribbon.tip, 0 }, { ribbon.tipShadow, o } }) do
            local texture, shift = part[1], part[2]
            texture:ClearAllPoints()
            texture:SetSize(size, size)
            texture:SetPoint("CENTER", ribbon, "TOPLEFT", sway + width / 2 + shift, -length - shift)
            texture:SetRotation(math.pi / 4 + angle)
        end
        Cast(ribbon.tipShadow, colour, alpha, alpha)
        tipLight = (1 - 0.7 * narrow) * (1 - BookShade(d))
    end

    local hovered = false

    local function Paint()
        local dim = ribbon.active and 1 or RIBBON_DIM
        local c, e, sheen = cloth.cloth, cloth.edge, cloth.sheen or SHEEN
        local function Dye(texture, color, k)
            texture:SetColorTexture(color[1] * k, color[2] * k, color[3] * k, 1)
        end
        for i = 1, count do
            local slice = slices[i]
            local k = dim * slice.light
            Dye(slice.body, c, k)
            Dye(slice.leftEdge, e, k)
            Dye(slice.rightEdge, e, k)
            slice.sheen:SetColorTexture(sheen[1], sheen[2], sheen[3], (hovered and 0.30 or 0.16) * slice.shine)
        end
        Dye(ribbon.tip, c, dim * tipLight)
    end

    function ribbon:SetActive(active)
        self.active = active and true or false
        Layout()
        Paint()
    end

    Style.Tooltip(ribbon, function(self) return { { self.label, 1, 1, 1 } } end, "ANCHOR_BOTTOM",
        function(_, over)
            hovered = over
            Paint()
        end)
    ribbon:SetScript("OnClick", function(self)
        if onClick then onClick(self) end
    end)

    ribbon:SetActive(false)
    return ribbon
end

-- Where the pages meet. Each page curves down into the binding, so the
-- shadow deepens faster the closer it gets: three gradients of falling width
-- stack into that curve. Just before the dip the paper bulges toward the
-- light, so a faint highlight band sits there. A crease line marks the fold
-- itself, and the binding thread shows through it, in the ribbon's red.
--
-- { distance from the fold, width, alpha at the fold side }, mirrored on
-- both pages.
local GUTTER_SHADOWS = {
    { 0, 46, 0.10 },
    { 0, 20, 0.16 },
    { 0, 7, 0.28 },
}
local GUTTER_LIGHT = { 20, 9, 0.10 }  -- distance, half width, peak alpha
local STITCH_SPACING, STITCH_LENGTH = 46, 9

function Style.Gutter(book, x, height)
    local INK = Style.INK

    -- `side` is -1 for the left page, 1 for the right. `from` and `to` are
    -- distances from the fold; alphas follow the same direction.
    local function Band(sublevel, side, from, to, r, g, b, nearAlpha, farAlpha)
        local band = book:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        local left, right = x + side * from, x + side * to
        if side < 0 then left, right = right, left end
        band:SetPoint("TOPLEFT", left, 0)
        band:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", right, 0)
        -- HORIZONTAL runs left to right, so the near end flips with the side.
        if side < 0 then
            Style.Shade(band, "HORIZONTAL", r, g, b, farAlpha, nearAlpha)
        else
            Style.Shade(band, "HORIZONTAL", r, g, b, nearAlpha, farAlpha)
        end
    end

    for _, side in ipairs({ -1, 1 }) do
        for _, shadow in ipairs(GUTTER_SHADOWS) do
            Band(-5, side, shadow[1], shadow[1] + shadow[2], INK[1], INK[2], INK[3], shadow[3], 0)
        end
        local d, half, peak = GUTTER_LIGHT[1], GUTTER_LIGHT[2], GUTTER_LIGHT[3]
        Band(-4, side, d, d + half, 1, 0.97, 0.88, 0, peak)
        Band(-4, side, d + half, d + 2 * half, 1, 0.97, 0.88, peak, 0)
    end

    local crease = book:CreateTexture(nil, "BACKGROUND", nil, -3)
    crease:SetPoint("TOPLEFT", x - 1, -GUTTER_DIP)
    crease:SetPoint("BOTTOMRIGHT", book, "BOTTOMLEFT", x + 1, GUTTER_DIP)
    crease:SetColorTexture(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3], 0.45)

    local count = math.floor((height - STITCH_SPACING / 2) / STITCH_SPACING)
    local top = (height - (count - 1) * STITCH_SPACING) / 2
    for i = 1, count do
        local stitch = book:CreateTexture(nil, "BACKGROUND", nil, -2)
        stitch:SetSize(2, STITCH_LENGTH)
        stitch:SetPoint("CENTER", book, "TOPLEFT", x, -(top + (i - 1) * STITCH_SPACING))
        stitch:SetColorTexture(0.40, 0.07, 0.05, 0.8)
    end
end

-- The book's cover, in place of a window frame: a leather board a margin
-- larger than the pages on every side. Lit from the top left, like the
-- game's own art: the board falls from light to shadow across its face, its
-- edge is raised (light top and left, shadow bottom and right), the leather
-- is mottled twice (dark and light, at different crops), the gold tooling is
-- pressed in, and the brass corner guards are shaded metal casting a shadow
-- on the leather. The spine darkens across the middle; the pages shadow the
-- board all round; the book shadows the world. `spineX` is the fold, from
-- the frame's left.
local LEATHER = { 0.32, 0.14, 0.07 }
local HINGE = 26  -- the hinge grooves, either side of the spine
local SPINE_BULGE = 7  -- how far the spine's back stands out at the bottom
local SPINE_NOTCH = 7  -- and how deep it curves in at the top
local SPINE_HALF, SPINE_STEP = HINGE + 2, 2
local BRASS_LIGHT, BRASS_MID, BRASS_DARK = { 0.96, 0.82, 0.50 }, { 0.70, 0.53, 0.24 }, { 0.30, 0.20, 0.08 }
-- The medallions (UI/StyleWidgets.lua) are ringed in the same brass.
Style.BRASS_LIGHT, Style.BRASS_MID, Style.BRASS_DARK = BRASS_LIGHT, BRASS_MID, BRASS_DARK

-- Leather grime: { texcoords, tint, alpha }. Different crops (and so
-- different feature sizes), one of them flipped.
local LEATHER_GRIME = {
    { { 0.05, 0.85, 0.10, 0.70 }, { 0.12, 0.06, 0.03 }, 0.26 },
    { { 0.95, 0.55, 0.95, 0.35 }, { 0.10, 0.05, 0.02 }, 0.18 },
}

-- Brass wear, one entry per arm (two per corner, eight in all): where in the
-- grime texture its crop starts (u, v), then tarnish and patina strength.
local BRASS_TARNISH, BRASS_PATINA = { 0.22, 0.14, 0.05 }, { 0.30, 0.42, 0.32 }
local BRASS_WEAR = {
    { 0.10, 0.30, 0.32, 0.08 }, { 0.55, 0.20, 0.22, 0.12 },
    { 0.32, 0.68, 0.36, 0.05 }, { 0.71, 0.58, 0.27, 0.09 },
    { 0.18, 0.82, 0.20, 0.14 }, { 0.62, 0.05, 0.34, 0.06 },
    { 0.44, 0.40, 0.25, 0.11 }, { 0.05, 0.12, 0.30, 0.04 },
}

-- A frame's shadow on the world, `size` out below and to the right: a strip
-- down the right side and one along the bottom, each fading out, and in the
-- corner between them a square that fades both ways, row by row, so the
-- strips meet without overlapping into a dark block.
local function DropShadow(frame, size)
    local function Texture() return frame:CreateTexture(nil, "BACKGROUND", nil, -8) end
    local right = Texture()
    right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -size)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, 0)
    Style.Shade(right, "HORIZONTAL", 0, 0, 0, BOOK_SHADOW_ALPHA, 0)
    local below = Texture()
    below:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", size, 0)
    below:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -size)
    Style.Shade(below, "VERTICAL", 0, 0, 0, 0, BOOK_SHADOW_ALPHA)
    for row = 0, size - 1 do
        local corner = Texture()
        corner:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT", 0, -row)
        corner:SetSize(size, 1)
        Style.Shade(corner, "HORIZONTAL", 0, 0, 0, BOOK_SHADOW_ALPHA * (1 - (row + 0.5) / size), 0)
    end
end

function Style.Cover(frame, margin, spineX)
    local function Texture(sublevel)
        return frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    end
    local function Between(texture, a, ax, ay, b, bx, by)
        texture:SetPoint(a, frame, a, ax, ay)
        texture:SetPoint(b, frame, b, bx, by)
        return texture
    end
    -- A strip `size` thick along one side, from point `a` to point `b` on
    -- that side. Its thickness has to be set: two points on the same side
    -- leave it open, and the client then falls back to the art's own size
    -- (1024 wide for the grime) or to nothing for a plain colour.
    local function Strip(texture, a, ax, ay, b, bx, by, size)
        Between(texture, a, ax, ay, b, bx, by)
        if a:find("LEFT") and b:find("RIGHT") then texture:SetHeight(size) else texture:SetWidth(size) end
        return texture
    end
    local function Solid(sublevel, r, g, b, a)
        local texture = Texture(sublevel)
        texture:SetColorTexture(r, g, b, a)
        return texture
    end

    -- The book's shadow on the world.
    DropShadow(frame, BOOK_SHADOW)

    -- Every layer that spans the board's width leaves out the spine column
    -- [c1, c2], which is built from strips below so its top edge can curve
    -- in. `band` is "full", "top" or "bottom" (then `height` tall, `dy` in
    -- from that edge); `paint(texture, u1, u2)` styles a piece covering the
    -- fractions u1..u2 of the width, so gradients and texture crops carry on
    -- across the gap.
    local W = frame:GetWidth()
    local c1, c2 = spineX - SPINE_HALF, spineX + SPINE_HALF
    local function Split(sublevel, band, height, dy, paint)
        for _, piece in ipairs({ { 0, c1 }, { c2, W } }) do
            local x1, x2 = piece[1], piece[2]
            local texture = Texture(sublevel)
            if band == "full" then
                texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x1, 0)
                texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", x2, 0)
            elseif band == "top" then
                texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x1, -dy)
                texture:SetPoint("TOPRIGHT", frame, "TOPLEFT", x2, -dy)
                texture:SetHeight(height)
            else
                texture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1, dy)
                texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", x2, dy)
                texture:SetHeight(height)
            end
            paint(texture, x1 / W, x2 / W)
        end
    end
    local function Mix(a, b, t)
        local out = {}
        for i = 1, #a do out[i] = a[i] + (b[i] - a[i]) * t end
        return out
    end
    local function Flat(color)
        return function(texture) texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    end
    local function Ramp(orientation, from, to)
        return function(texture, u1, u2)
            if orientation == "HORIZONTAL" then
                Style.Gradient(texture, orientation, Mix(from, to, u1), Mix(from, to, u2))
            else
                Style.Gradient(texture, orientation, from, to)
            end
        end
    end

    -- The boards, mottled.
    Split(-7, "full", nil, 0, Flat(LEATHER))
    local path = Style.Art("grain")
    if path then
        for _, layer in ipairs({
            { { 0.9, 0.05, 0.1, 0.95 }, { 0.35, 0.14, 0.06 }, 0.55 },  -- dark blotches
            { { 0.2, 0.75, 0.6, 0.05 }, { 1.00, 0.62, 0.40 }, 0.16 },  -- worn, lighter patches
        }) do
            local l, r, t, b = unpack(layer[1])
            Split(-6, "full", nil, 0, function(mottle, u1, u2)
                mottle:SetTexture(path)
                mottle:SetTexCoord(l + (r - l) * u1, l + (r - l) * u2, t, b)
                mottle:SetVertexColor(layer[2][1], layer[2][2], layer[2][3])
                mottle:SetAlpha(layer[3])
            end)
        end
    end

    -- Grime: two dark layers at different crops and scales, so the dirt
    -- drifts unevenly instead of lying like a pattern; then lighter scuffing
    -- in a band round the edges, where hands wear a cover.
    local grime = Style.Art("grime")
    local function Grime(texture, crop, u1, u2, tint, alpha)
        local l, r, t, b = crop[1], crop[2], crop[3], crop[4]
        texture:SetTexture(grime)
        texture:SetTexCoord(l + (r - l) * u1, l + (r - l) * u2, t, b)
        texture:SetVertexColor(tint[1], tint[2], tint[3])
        texture:SetAlpha(alpha)
    end
    if grime then
        for _, layer in ipairs(LEATHER_GRIME) do
            Split(-6, "full", nil, 0, function(texture, u1, u2)
                Grime(texture, layer[1], u1, u2, layer[2], layer[3])
            end)
        end

        local band, SCUFF = 10, { 1, 0.80, 0.60 }
        Split(-6, "top", band, 0, function(texture, u1, u2)
            Grime(texture, { 0.0, 1.0, 0.20, 0.24 }, u1, u2, SCUFF, 0.08)
        end)
        Split(-6, "bottom", band, 0, function(texture, u1, u2)
            Grime(texture, { 1.0, 0.0, 0.70, 0.74 }, u1, u2, SCUFF, 0.10)
        end)
        for _, side in ipairs({ { "TOPLEFT", "BOTTOMLEFT", { 0.40, 0.44, 0.0, 1.0 } },
            { "TOPRIGHT", "BOTTOMRIGHT", { 0.86, 0.90, 1.0, 0.0 } } }) do
            local texture = Strip(Texture(-6), side[1], 0, 0, side[2], 0, 0, band)
            Grime(texture, side[3], 0, 1, SCUFF, 0.09)
        end
    end

    -- Light across the face: brighter top left, darker bottom right.
    local LIGHT_FACE, DARK_FACE = { 1, 0.85, 0.65, 0.10 }, { 0, 0, 0, 0.22 }
    Split(-5, "full", nil, 0, Ramp("HORIZONTAL", LIGHT_FACE, DARK_FACE))
    Split(-5, "full", nil, 0, Ramp("VERTICAL", { 0, 0, 0, 0.30 }, { 1, 0.85, 0.65, 0.08 }))

    -- Worn edges, darker toward every side.
    local w = 16
    Style.Shade(Strip(Texture(-4), "TOPLEFT", 0, 0, "BOTTOMLEFT", 0, 0, w), "HORIZONTAL", 0, 0, 0, 0.40, 0)
    Style.Shade(Strip(Texture(-4), "TOPRIGHT", 0, 0, "BOTTOMRIGHT", 0, 0, w), "HORIZONTAL", 0, 0, 0, 0, 0.50)
    Split(-4, "top", w, 0, Ramp("VERTICAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.30 }))
    Split(-4, "bottom", w, 0, Ramp("VERTICAL", { 0, 0, 0, 0.55 }, { 0, 0, 0, 0 }))

    -- A raised edge: dark outline, light top and left, shadow bottom and right.
    local function Edge(sublevel, a, ax, ay, b, bx, by, thickness, color)
        Strip(Solid(sublevel, color[1], color[2], color[3], color[4]), a, ax, ay, b, bx, by, thickness)
    end
    local OUTLINE, LIGHT, SHADOW = { 0, 0, 0, 0.95 }, { 1, 0.80, 0.58, 0.30 }, { 0, 0, 0, 0.45 }
    Split(-3, "top", 1, 0, Flat(OUTLINE))
    Split(-3, "bottom", 1, 0, Flat(OUTLINE))
    Edge(-3, "TOPLEFT", 0, 0, "BOTTOMLEFT", 0, 0, 1, OUTLINE)
    Edge(-3, "TOPRIGHT", 0, 0, "BOTTOMRIGHT", 0, 0, 1, OUTLINE)
    Split(-3, "top", 2, 1, Flat(LIGHT))
    Edge(-3, "TOPLEFT", 1, -1, "BOTTOMLEFT", 1, 1, 2, LIGHT)
    Split(-3, "bottom", 2, 1, Flat(SHADOW))
    Edge(-3, "TOPRIGHT", -1, -1, "BOTTOMRIGHT", -1, 1, 2, SHADOW)

    -- The spine column. Seen in perspective its top end curves away, so the
    -- edge dips in (an arc SPINE_NOTCH deep) where the bottom end bulges out
    -- (below). Strips carry the leather, the light falling down the face and
    -- the hollow darkening toward the middle, with the outline on the arc.
    local function Notch(x)
        local d = (x - spineX) / SPINE_HALF
        return SPINE_NOTCH * math.sqrt(math.max(0, 1 - d * d))
    end
    for x = c1, c2 - SPINE_STEP, SPINE_STEP do
        local middle = x + SPINE_STEP / 2
        local hollow = 0.10 + 0.55 * (1 - math.abs(middle - spineX) / SPINE_HALF)
        local inset = Notch(middle)
        local top = Mix(LEATHER, { 1, 0.85, 0.65 }, 0.08)
        local bottom = Mix(LEATHER, { 0, 0, 0 }, 0.30)

        local strip = Texture(-7)
        strip:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -inset)
        strip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", x + SPINE_STEP, 0)
        Style.Gradient(strip,
            "VERTICAL", { bottom[1] * (1 - hollow), bottom[2] * (1 - hollow), bottom[3] * (1 - hollow), 1 },
            { top[1] * (1 - hollow), top[2] * (1 - hollow), top[3] * (1 - hollow), 1 })

        local rim = Solid(-3, OUTLINE[1], OUTLINE[2], OUTLINE[3], OUTLINE[4])
        rim:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -inset)
        rim:SetSize(SPINE_STEP, 1)
    end
    local base = Solid(-3, OUTLINE[1], OUTLINE[2], OUTLINE[3], OUTLINE[4])
    base:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", c1, 0)
    base:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", c2, 0)
    base:SetHeight(1)

    -- A line between two points, each { point, x, y } on the frame.
    local function Line(sublevel, from, to, color, horizontal)
        local line = Solid(sublevel, color[1], color[2], color[3], color[4])
        local function Row(point) return point:find("^TOP") and "TOP" or "BOTTOM" end
        line:SetPoint(horizontal and (Row(from[1]) .. "LEFT") or "TOP", frame, from[1], from[2], from[3])
        line:SetPoint(horizontal and (Row(to[1]) .. "RIGHT") or "BOTTOM", frame, to[1], to[2], to[3])
        if horizontal then line:SetHeight(1) else line:SetWidth(1) end
    end

    -- The hinges: a pressed groove each side of the spine, light on its
    -- far lip. They start below the arc.
    for _, x in ipairs({ spineX - HINGE, spineX + HINGE }) do
        local below = -math.ceil(Notch(x)) - 1
        Line(-3, { "TOPLEFT", x, below }, { "BOTTOMLEFT", x, 0 }, { 0, 0, 0, 0.7 })
        Line(-3, { "TOPLEFT", x + 1, below }, { "BOTTOMLEFT", x + 1, 0 }, { 1, 0.80, 0.58, 0.22 })
    end

    -- Tooled gold line, pressed in, one frame per board: its dark lip sits
    -- up and to the left.
    local t, gap = 6, HINGE + 6
    local LIP, GOLD = { 0, 0, 0, 0.55 }, { 0.86, 0.68, 0.36, 0.55 }
    for _, board in ipairs({ { t, spineX - gap, "TOPLEFT", "BOTTOMLEFT", "TOPLEFT", "BOTTOMLEFT" },
        { spineX + gap, -t, "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local x1, x2, top1, bottom1, top2, bottom2 = unpack(board)
        for _, line in ipairs({ { LIP, -1, 1 }, { GOLD, 0, 0 } }) do
            local color, dx, dy = line[1], line[2], line[3]
            Line(-2, { top1, x1 + dx, -t + dy }, { top2, x2 + dx, -t + dy }, color, true)
            Line(-2, { bottom1, x1 + dx, t + dy }, { bottom2, x2 + dx, t + dy }, color, true)
            Line(-2, { top1, x1 + dx, -t + dy }, { bottom1, x1 + dx, t + dy }, color)
            Line(-2, { top2, x2 + dx, -t + dy }, { bottom2, x2 + dx, t + dy }, color)
        end
    end

    -- At the top and bottom of the fold you see down into the hollow back
    -- of the spine, and the headband: red and gold thread round the pages.
    local circle = Style.Art("circle")
    local dip = Style.GUTTER_DIP
    for _, vertical in ipairs({ { "TOPLEFT", -1 }, { "BOTTOMLEFT", 1 } }) do
        local point, sign = vertical[1], vertical[2]
        local edgeY = sign * (margin + dip)

        local hollow = Texture(-1)
        hollow:SetSize(2 * HINGE - 6, 18)
        hollow:SetPoint("CENTER", frame, point, spineX, edgeY)
        Style.Disc(hollow, 0, 0, 0, circle and 0.7 or 0.5)

        local band = Solid(2, 0.12, 0.05, 0.02, 1)
        band:SetSize(18, 7)
        band:SetPoint("CENTER", frame, point, spineX, edgeY - sign * 2)
        for i = 1, 4 do
            local red = i % 2 == 1
            local thread = Solid(3, red and 0.58 or 0.86, red and 0.10 or 0.66, red and 0.07 or 0.30, 1)
            thread:SetSize(4, 5)
            thread:SetPoint("LEFT", band, "LEFT", 1 + (i - 1) * 4, 0)
        end
        local shine = Solid(4, 1, 0.9, 0.7, 0.35)
        shine:SetPoint("TOPLEFT", band, "TOPLEFT", 1, -1)
        shine:SetPoint("TOPRIGHT", band, "TOPRIGHT", -1, -1)
        shine:SetHeight(1)
    end

    -- At the bottom the spine's rounded back bulges past the boards' edge:
    -- half an oval of leather between the hinges, outlined, its underside in
    -- shadow. (At the top it curves away instead; see the spine column.)
    if circle then
        local width, rise = 2 * HINGE + 4, SPINE_BULGE
        -- The lower half of the circle, hung from the boards' bottom edge.
        local function Half(sublevel, w, h, color)
            local half = Texture(sublevel)
            half:SetTexture(circle)
            half:SetTexCoord(0, 1, 0.5, 1)
            half:SetVertexColor(color[1], color[2], color[3], color[4])
            half:SetSize(w, h)
            half:SetPoint("TOP", frame, "BOTTOMLEFT", spineX, 0)
            return half
        end
        Half(5, width + 2, rise + 1, { 0, 0, 0, 0.95 })
        Half(6, width, rise, { LEATHER[1] * 0.9, LEATHER[2] * 0.9, LEATHER[3] * 0.9, 1 })
        Half(7, width - 8, rise - 2, { 0, 0, 0, 0.35 })
    end

    -- The pages' shadow on the board, all round. frame:FitPages moves it in
    -- to where the stack ends on each side, `left` and `right` pixels in from
    -- the pages' full width (what the book's SetStack returns).
    local d = 7
    local shadows = { Texture(-2), Texture(-2), Texture(-2), Texture(-2) }
    Style.Shade(shadows[1], "HORIZONTAL", 0, 0, 0, 0, 0.55)
    Style.Shade(shadows[2], "HORIZONTAL", 0, 0, 0, 0.55, 0)
    Style.Shade(shadows[3], "VERTICAL", 0, 0, 0, 0.55, 0)
    Style.Shade(shadows[4], "VERTICAL", 0, 0, 0, 0, 0.55)
    function frame:FitPages(left, right)
        local l, r = margin + left, margin + right
        for _, shadow in ipairs(shadows) do shadow:ClearAllPoints() end
        Strip(shadows[1], "TOPLEFT", l - d, -margin, "BOTTOMLEFT", l - d, margin, d)
        Strip(shadows[2], "TOPRIGHT", -r + d, -margin, "BOTTOMRIGHT", -r + d, margin, d)
        Strip(shadows[3], "TOPLEFT", l, -margin + d, "TOPRIGHT", -r, -margin + d, d)
        Strip(shadows[4], "BOTTOMLEFT", l, margin - d, "BOTTOMRIGHT", -r, margin - d, d)
    end
    frame:FitPages(0, 0)

    -- Brass corner guards: an L along each edge and a domed rivet.
    local arm, thick = 30, 9
    local wear = 0
    for _, corner in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 },
        { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local point, sx, sy = corner[1], corner[2], corner[3]
        for _, horizontal in ipairs({ true, false }) do
            wear = wear + 1
            local w, h = horizontal and arm or thick, horizontal and thick or arm

            -- Its shadow on the leather, down and to the right.
            local cast = Solid(-1, 0, 0, 0, 0.45)
            cast:SetSize(w, h)
            cast:SetPoint(point, frame, point, 2, -2)

            local outline = Solid(0, BRASS_DARK[1], BRASS_DARK[2], BRASS_DARK[3], 1)
            outline:SetSize(w, h)
            outline:SetPoint(point, frame, point, 0, 0)

            -- Metal, light where it faces the light.
            local metal = Texture(1)
            metal:SetSize(w - 2, h - 2)
            metal:SetPoint(point, frame, point, sx, sy)
            local light = { BRASS_LIGHT[1], BRASS_LIGHT[2], BRASS_LIGHT[3], 1 }
            local dark = { BRASS_MID[1] * 0.75, BRASS_MID[2] * 0.75, BRASS_MID[3] * 0.75, 1 }
            if horizontal then
                Style.Gradient(metal, "VERTICAL", dark, light)
            else
                Style.Gradient(metal, "HORIZONTAL", light, dark)
            end

            -- Tarnish and a little patina, cropped differently on every arm.
            if grime then
                local spot = BRASS_WEAR[wear]
                for _, layer in ipairs({ { spot[1], spot[2], BRASS_TARNISH, spot[3] },
                    { spot[2], spot[1], BRASS_PATINA, spot[4] } }) do
                    local u, v = layer[1], layer[2]
                    local du, dv = horizontal and 0.24 or 0.07, horizontal and 0.07 or 0.24
                    local texture = Texture(2)
                    texture:SetAllPoints(metal)
                    texture:SetTexture(grime)
                    texture:SetTexCoord(u, u + du, v, v + dv)
                    texture:SetVertexColor(layer[3][1], layer[3][2], layer[3][3])
                    texture:SetAlpha(layer[4])
                end
            end

            -- A bright edge along the side the light catches.
            local shine = Solid(2, 1, 0.95, 0.75, 0.7)
            shine:SetPoint("TOPLEFT", metal, "TOPLEFT")
            if horizontal then
                shine:SetPoint("TOPRIGHT", metal, "TOPRIGHT")
                shine:SetHeight(1)
            else
                shine:SetPoint("BOTTOMLEFT", metal, "BOTTOMLEFT")
                shine:SetWidth(1)
            end
        end

        -- The rivet: a dark dome with a highlight up and to the left.
        for i, part in ipairs({ { 6, BRASS_DARK, 0, 0 }, { 4, BRASS_MID, 0, 0 }, { 2, BRASS_LIGHT, -0.7, 0.7 } }) do
            local dot = Texture(2 + i)
            dot:SetSize(part[1], part[1])
            dot:SetPoint("CENTER", frame, point, sx * 5 + part[3], sy * 5 + part[4])
            Style.Disc(dot, part[2][1], part[2][2], part[2][3], 1)
        end
    end
end

-- A loose page on its own, for the entry editor outside the journal: the
-- journal's paper, grain and edge shading on one sheet, two more sheets
-- askew underneath, and its shadow on the world.
local UNDER_SHEETS = { { -1.6, -6, -4, 0.90 }, { 1.1, 5, -6, 0.94 } }  -- degrees, dx, dy, shade

function Style.Sheet(frame)
    local P, INK = Style.PAPER, Style.INK

    DropShadow(frame, 12)

    for _, under in ipairs(UNDER_SHEETS) do
        local angle, dx, dy, shade = math.rad(under[1]), under[2], under[3], under[4]
        local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        edge:SetPoint("TOPLEFT", dx - 1, dy + 1)
        edge:SetPoint("BOTTOMRIGHT", dx + 1, dy - 1)
        edge:SetColorTexture(INK[1], INK[2], INK[3], 0.55)
        edge:SetRotation(angle)
        local sheet = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        sheet:SetPoint("TOPLEFT", dx, dy)
        sheet:SetPoint("BOTTOMRIGHT", dx, dy)
        sheet:SetColorTexture(P[1] * shade, P[2] * shade, P[3] * shade, 1)
        sheet:SetRotation(angle)
    end

    local leaf = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    leaf:SetAllPoints()
    leaf:SetColorTexture(P[1], P[2], P[3], 1)

    local function Edge(a, b, size, orientation, from, to)
        local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        edge:SetPoint(a)
        edge:SetPoint(b)
        if orientation == "HORIZONTAL" then edge:SetWidth(size) else edge:SetHeight(size) end
        Style.Shade(edge, orientation, INK[1], INK[2], INK[3], from, to)
    end
    Edge("TOPLEFT", "BOTTOMLEFT", 22, "HORIZONTAL", 0.24, 0)
    Edge("TOPRIGHT", "BOTTOMRIGHT", 22, "HORIZONTAL", 0, 0.24)
    Edge("TOPLEFT", "TOPRIGHT", 5, "VERTICAL", 0, 0.22)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", 5, "VERTICAL", 0.22, 0)

    Style.Hairline(frame, "BACKGROUND", -4, Style.HAIRLINE)

    -- The grain follows `/sd art grain` as the book's does: frame.grain in
    -- book.grain's shape, and ApplyGrain to call on SD_PAPER_CHANGED.
    frame.grain = {}
    local path = Style.Art("grain")
    if path then
        for _, layer in ipairs({ { { 0.10, 0.95, 0.02, 0.98 }, 0.18 }, { { 0.90, 0.20, 0.95, 0.15 }, 0.08 } }) do
            local grain = frame:CreateTexture(nil, "BORDER", nil, 0)
            grain:SetAllPoints()
            grain:SetTexture(path)
            grain:SetTexCoord(unpack(layer[1]))
            frame.grain[#frame.grain + 1] = { texture = grain, alpha = layer[2] }
        end
    end

    function frame:ApplyGrain()
        for _, layer in ipairs(self.grain) do layer.texture:SetAlpha(layer.alpha * grainStrength) end
    end
    frame:ApplyGrain()
end

--------------------------------------------------------------------------
-- The book closed
--------------------------------------------------------------------------

-- The journal shut, seen from the front, for the parcel at login
-- (UI/Intro.lua). It is the open book's material (Style.Cover): the same
-- leather, mottled and grimed the same way, lit from the top left, its edge
-- raised; the hinge groove beside the spine on the left; a tooled gold frame
-- pressed in, its dark lip up and to the left, and a fainter one inside it;
-- the title in gold capitals with a rule and a lozenge under it; brass
-- guards on the two outer corners; the headband peeping out at the top of
-- the spine; and the pages' edges showing past the board at the fore edge
-- and the foot. In its own coordinates, x right and y down from the board's
-- top left:
--   block   the pages: in from the spine, and how far they show past the
--           fore edge and the foot
--   hinge   the groove's x, and its dark, light and dark widths
--   tool    the gold frame's insets (left, top, right, bottom), the inner
--           one's further inset, and their alphas
--   title   the title's top; the rule's gap under it, each half's length
--           and the lozenge's size
--   guard   the corner guards' arm, thickness and how far they stand out
--   head    the headband: x, y (above the board) and size
--   shadow  its shadow on what it lies on: down, right and dark
local CLOSED = {
    block = { left = 10, top = 5, fore = 3, foot = 4 },
    hinge = { x = 16, widths = { 2, 3, 1 } },
    tool = { left = 32, top = 12, right = 12, bottom = 12, inner = 6, alpha = 0.60, innerAlpha = 0.38 },
    title = { top = 92, gap = 14, half = 24, lozenge = 5 },
    guard = { arm = 26, thick = 8, out = 2 },
    head = { x = 3, y = -4, w = 12, h = 5 },
    shadow = { 3, 4, 0.30 },
}
local PAGE_EDGES = { { 0.91, 0.85, 0.69 }, { 0.80, 0.72, 0.54 } }
local TOOL_GOLD, TOOL_LIP = { 0.86, 0.68, 0.36 }, { 0, 0, 0, 0.55 }

-- Returns the frame, `w` by `h`, with `shadows` (for "Flat paper only" to
-- take away), `title` and `count` (how many textures it took).
function Style.ClosedBook(parent, w, h, title)
    local C = CLOSED
    local book = CreateFrame("Frame", nil, parent)
    book:SetSize(w, h)
    book.shadows, book.count = {}, 0

    local function Texture(layer, sublevel)
        book.count = book.count + 1
        return book:CreateTexture(nil, layer, nil, sublevel)
    end
    local function Rect(layer, sublevel, x, y, rw, rh, colour)
        local texture = Texture(layer, sublevel)
        texture:SetPoint("TOPLEFT", book, "TOPLEFT", x, -y)
        texture:SetSize(rw, rh)
        if colour then texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1) end
        return texture
    end

    -- Its shadow, then the pages: a block of paper with a darker line
    -- between every other leaf where it shows.
    local B = C.block
    local bw, bh = w - B.left + B.fore, h - B.top + B.foot
    local S = C.shadow
    book.shadows[1] = Rect("BACKGROUND", -8, B.left + S[1], B.top + S[2], bw, bh, { 0, 0, 0, S[3] })
    Rect("BACKGROUND", -7, B.left, B.top, bw, bh, PAGE_EDGES[1])
    for x = w + 1, w + B.fore - 1, 2 do Rect("BACKGROUND", -6, x, B.top + 1, 1, bh - 1, PAGE_EDGES[2]) end
    for y = h + 1, h + B.foot - 1, 2 do Rect("BACKGROUND", -6, B.left + 1, y, bw - 1, 1, PAGE_EDGES[2]) end

    -- The board: leather, mottled and grimed as the open cover is.
    Rect("BACKGROUND", -5, 0, 0, w, h, LEATHER)
    local grain = Style.Art("grain")
    if grain then
        for _, layer in ipairs({
            { { 0.9, 0.05, 0.1, 0.95 }, { 0.35, 0.14, 0.06 }, 0.55 },  -- dark blotches
            { { 0.2, 0.75, 0.6, 0.05 }, { 1.00, 0.62, 0.40 }, 0.16 },  -- worn, lighter patches
        }) do
            local mottle = Rect("BACKGROUND", -4, 0, 0, w, h)
            mottle:SetTexture(grain)
            mottle:SetTexCoord(unpack(layer[1]))
            mottle:SetVertexColor(layer[2][1], layer[2][2], layer[2][3])
            mottle:SetAlpha(layer[3])
        end
    end
    local grime = Style.Art("grime")
    if grime then
        for _, layer in ipairs(LEATHER_GRIME) do
            local dirt = Rect("BACKGROUND", -4, 0, 0, w, h)
            dirt:SetTexture(grime)
            dirt:SetTexCoord(unpack(layer[1]))
            dirt:SetVertexColor(layer[2][1], layer[2][2], layer[2][3])
            dirt:SetAlpha(layer[3])
        end
    end

    -- Light across the face, brighter top left; darker toward the spine
    -- and the fore edge.
    Style.Gradient(Rect("BACKGROUND", -3, 0, 0, w, h), "HORIZONTAL", { 1, 0.85, 0.65, 0.08 }, { 0, 0, 0, 0.18 })
    Style.Gradient(Rect("BACKGROUND", -3, 0, 0, w, h), "VERTICAL", { 0, 0, 0, 0.25 }, { 1, 0.85, 0.65, 0.10 })
    Style.Shade(Rect("BACKGROUND", -2, 0, 0, 14, h), "HORIZONTAL", 0, 0, 0, 0.40, 0)
    Style.Shade(Rect("BACKGROUND", -2, w - 12, 0, 12, h), "HORIZONTAL", 0, 0, 0, 0, 0.45)

    -- A raised edge: a dark outline, light top and left, shadow bottom and
    -- right.
    local OUTLINE, LIGHT, SHADOW = { 0, 0, 0, 0.95 }, { 1, 0.80, 0.58, 0.30 }, { 0, 0, 0, 0.45 }
    Rect("BORDER", 0, 0, 0, w, 1, OUTLINE)
    Rect("BORDER", 0, 0, h - 1, w, 1, OUTLINE)
    Rect("BORDER", 0, 0, 0, 1, h, OUTLINE)
    Rect("BORDER", 0, w - 1, 0, 1, h, OUTLINE)
    Rect("BORDER", 1, 1, 1, w - 2, 2, LIGHT)
    Rect("BORDER", 1, 1, 1, 2, h - 2, LIGHT)
    Rect("BORDER", 1, 1, h - 3, w - 2, 2, SHADOW)
    Rect("BORDER", 1, w - 3, 1, 2, h - 2, SHADOW)

    -- The hinge: dark, light on its far lip, dark again.
    local x = C.hinge.x
    for i, colour in ipairs({ { 0, 0, 0, 0.45 }, { 1, 0.80, 0.58, 0.12 }, { 0, 0, 0, 0.20 } }) do
        local width = C.hinge.widths[i]
        Rect("BORDER", 2, x, 1, width, h - 2, colour)
        x = x + width
    end

    -- Tooled gold: a frame pressed in, its lip up and to the left, and a
    -- fainter one inside it.
    local T = C.tool
    local function Frame(x1, y1, x2, y2, colour, alpha)
        local c = { colour[1], colour[2], colour[3], alpha }
        Rect("BORDER", 3, x1, y1, x2 - x1 + 1, 1, c)
        Rect("BORDER", 3, x1, y2, x2 - x1 + 1, 1, c)
        Rect("BORDER", 3, x1, y1, 1, y2 - y1 + 1, c)
        Rect("BORDER", 3, x2, y1, 1, y2 - y1 + 1, c)
    end
    local x1, y1, x2, y2 = T.left, T.top, w - T.right, h - T.bottom
    Frame(x1 - 1, y1 - 1, x2 - 1, y2 - 1, TOOL_LIP, TOOL_LIP[4])
    Frame(x1, y1, x2, y2, TOOL_GOLD, T.alpha)
    Frame(x1 + T.inner, y1 + T.inner, x2 - T.inner, y2 - T.inner, TOOL_GOLD, T.innerAlpha)

    -- The title, centred in the frame, and a rule with a lozenge under it.
    local mid = (x1 + x2) / 2
    book.title = Style.Text(book, Style.FONT.cover)
    book.title:SetJustifyH("CENTER")
    book.title:SetSpacing(3)
    book.title:SetText(title)
    book.title:SetPoint("TOP", book, "TOPLEFT", mid, -C.title.top)
    local L = C.title
    for _, side in ipairs({ -1, 1 }) do
        local rule = Texture("ARTWORK", 0)
        rule:SetSize(L.half, 1)
        rule:SetPoint("CENTER", book.title, "BOTTOM", side * (L.lozenge + 4 + L.half / 2), -L.gap)
        rule:SetColorTexture(TOOL_GOLD[1], TOOL_GOLD[2], TOOL_GOLD[3], 0.7)
    end
    book.count = book.count + 1
    local lozenge = Style.Lozenge(book, "ARTWORK", L.lozenge, TOOL_GOLD, 1)
    lozenge:SetPoint("CENTER", book.title, "BOTTOM", 0, -L.gap)

    -- Brass guards on the outer corners: an L each, shaded metal casting a
    -- shadow on the leather, and a domed rivet.
    local G = C.guard
    for _, corner in ipairs({ { "TOPRIGHT", -1, -1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local point, sx, sy = corner[1], corner[2], corner[3]
        local ox, oy = G.out, sy < 0 and G.out or -G.out
        for _, horizontal in ipairs({ true, false }) do
            local aw, ah = horizontal and G.arm or G.thick, horizontal and G.thick or G.arm
            local function Arm(layer, sublevel, dx, dy, iw, ih)
                local texture = Texture(layer, sublevel)
                texture:SetSize(iw, ih)
                texture:SetPoint(point, book, point, ox + dx, oy + dy)
                return texture
            end
            local cast = Arm("ARTWORK", 1, 2, -2, aw, ah)
            cast:SetColorTexture(0, 0, 0, 0.45)
            book.shadows[#book.shadows + 1] = cast
            Arm("ARTWORK", 2, 0, 0, aw, ah):SetColorTexture(BRASS_DARK[1], BRASS_DARK[2], BRASS_DARK[3], 1)
            local metal = Arm("ARTWORK", 3, sx, sy, aw - 2, ah - 2)
            local light = { BRASS_LIGHT[1], BRASS_LIGHT[2], BRASS_LIGHT[3], 1 }
            local dark = { BRASS_MID[1] * 0.75, BRASS_MID[2] * 0.75, BRASS_MID[3] * 0.75, 1 }
            if horizontal then
                Style.Gradient(metal, "VERTICAL", dark, light)
            else
                Style.Gradient(metal, "HORIZONTAL", light, dark)
            end
            local shine = Texture("ARTWORK", 4)
            shine:SetColorTexture(1, 0.95, 0.75, 0.7)
            shine:SetPoint("TOPLEFT", metal, "TOPLEFT")
            if horizontal then
                shine:SetPoint("TOPRIGHT", metal, "TOPRIGHT")
                shine:SetHeight(1)
            else
                shine:SetPoint("BOTTOMLEFT", metal, "BOTTOMLEFT")
                shine:SetWidth(1)
            end
        end
        for i, part in ipairs({ { 5, BRASS_DARK, 0, 0 }, { 3, BRASS_MID, 0, 0 }, { 1.5, BRASS_LIGHT, -0.5, 0.5 } }) do
            local dot = Texture("ARTWORK", 4 + i)
            dot:SetSize(part[1], part[1])
            dot:SetPoint("CENTER", book, point, ox + sx * 4 + part[3], oy + sy * 4 + part[4])
            Style.Disc(dot, part[2][1], part[2][2], part[2][3], 1)
        end
    end

    -- The headband over the top of the spine: red and gold thread in a
    -- dark binding.
    local H = C.head
    Rect("BACKGROUND", -7, H.x, H.y, H.w, H.h, { 0.12, 0.05, 0.02, 1 })
    for i = 1, 3 do
        local red = i % 2 == 1
        Rect("BACKGROUND", -6, H.x + 1 + (i - 1) * 3.4, H.y + 1, 3.4, H.h - 2,
            red and { 0.58, 0.10, 0.07 } or { 0.86, 0.66, 0.30 })
    end

    return book
end
