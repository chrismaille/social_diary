-- The parcel at login (PRV-4): the diary has just arrived, and opening it
-- is the first moment of role-play. A few seconds after login, until the
-- book's introduction has been read -- the frontispiece
-- (UI/JournalFrontispiece.lua), then the front matter (UI/JournalFront.lua),
-- which says what is kept -- it lies near the top of the screen:
--
--   wrapped  the first time: a book-shaped parcel in brown paper, tied with
--            twine under a wax seal, the maker's name, an address, a stamp
--            and its postmark, and a label saying what is inside. "Tear it
--            open", or a click on the seal, tears it (parcelOpened)
--   torn     the paper ripped open, its flaps torn back, the twine cut and
--            the label torn aside: the closed book inside, its ribbons
--            hanging out of the foot, and beside it the diary's own note in
--            pencil, with how many it has pencilled in already. "Open me"
--            opens the book at the frontispiece
--   again    a later login, still unread: torn already, the note greeting
--            you again
--
-- The parcel is its maker's: gnomish for Alliance, goblin for Horde (seal,
-- stamp, postmark, sender, address). The book and the note are the
-- diary's, the same for both. The label's last line says nothing leaves
-- this computer, so someone who only ever clicks Later has read it; the
-- retention days are left to the frontispiece and the settings.
--
-- It comes back at every login until the front matter has been read
-- (frontRead): Later, and Escape, only put it away until then. It never
-- shows in a fight: it waits for the fight to end, and a fight that starts
-- while it is up puts it away until then.
--
-- The parcel and the book are plain frames lying straight (frames cannot
-- turn in the client): textures, gradients and font strings, torn edges as
-- rows of small triangles (Style.TornEdge), the closed book the journal's
-- own leather (Style.ClosedBook). Only the note is a loose sheet
-- (UI/LooseSheet.lua), so it turns and takes the light like the book's
-- sheets. Everything is built once, at its first showing; laying it again
-- only sets its words, its maker's marks and what shows. "Flat paper only"
-- (flatSheets) evens the tears and takes away the turns of what lies
-- loose and every shadow.
--
-- The reference is .claude/ui-proposal/parcel-mockup.html: the numbers
-- below are its sizes and offsets.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local SHOW_DELAY = 4

--------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------
--
-- In the scene's own coordinates, x right and y down, the mockup's at scale
-- 1; inside a piece (the parcel, a flap, the book) from that piece's top
-- left. Turns are in degrees clockwise, as the mockup gives them.

-- The part of the mockup the scene covers (left, top, w, h), how far below
-- the screen's top it hangs, which x lies on the screen's middle in each
-- state, and one scale for the whole of it.
local SCENE = { left = 145, top = 30, w = 690, h = 470, y = -40, middle = { wrapped = 450, torn = 490 },
    scale = 1 }

-- Brown paper, its paler inside, and the ink printed on it.
local KRAFT = { paper = { 0.64, 0.47, 0.29 }, inside = { 0.77, 0.62, 0.44 }, ink = { 0.16, 0.08, 0.02 } }

-- The wrapped parcel: where, how big, and its shadows ({ right, down,
-- larger, dark }). The links lie `links` under it. Its edges: light top
-- and left, dark bottom and right (`edge` wide), then the paper folding
-- over the book's edges (`folds`: left, right, top, bottom: width and
-- dark, light at the top). `crease`: a fold across it, from x1, y1 to x2,
-- y2, its width and dark. `fibres`: the grain art's alpha on it.
local PARCEL = {
    x = 305, y = 70, w = 290, h = 370, links = 22,
    shadows = { { 4, 6, 0, 0.22 }, { 8, 12, 3, 0.10 } },
    edge = { 2, 0.25, 0.30 },
    folds = { left = { 10, 0.18 }, right = { 10, 0.22 }, top = { 10, 0.12 }, bottom = { 12, 0.24 } },
    crease = { 0, 108, 290, 262, 3, 0.10 },
    fibres = 0.22,
}

-- The twine round it both ways: the vertical's x and the horizontal's y
-- (on the parcel), its width, its light core's, and its shadow (right,
-- down, dark). The bow under the seal: its box's top left on the parcel,
-- the loops and tails as the mockup's curves (in that box), how finely
-- each curve is drawn, and its two widths.
local TWINE = { core = { 0.89, 0.81, 0.64 }, edge = { 0.71, 0.60, 0.41 }, bow = { 0.79, 0.69, 0.50 },
    x = 172, y = 150, width = 5, coreWidth = 3, shadow = { 1, 1.5, 0.35 } }
local BOW = {
    x = 146, y = 128, steps = 5, outer = 4, inner = 2,
    curves = {
        { 29, 24, 14, 6, 2, 14, 8, 24 }, { 8, 24, 14, 32, 24, 28, 29, 24 },
        { 29, 24, 34, 28, 44, 32, 50, 24 }, { 50, 24, 56, 14, 44, 6, 29, 24 },
    },
    tails = { { 27, 27, 20, 48 }, { 31, 27, 40, 47 } },
}

-- The wax seal on the knot: its box on the parcel, its rim, body and the
-- ring pressed into it, the light on it (x, y from its middle, w, h, turn,
-- alpha), its shadow, and how much brighter it is under the mouse. The
-- gnomes' cog (hub, hole, tooth, how far out the teeth stand) and the
-- goblins' milled coin (dots round a struck G).
local SEAL = {
    x = 151, y = 130, size = 46, rim = 43, body = 39, ring = 27, ringIn = 24,
    lit = { -6, -9, 14, 7, -30, 0.55 }, shadow = { 1, 1.5, 0.35 }, hover = 0.22,
    cog = { hub = 14, hole = 5, tooth = { 3, 4 }, reach = 8 },
    coin = { dots = 10, r = 8.5, dot = 1.8 },
}
-- The makers' wax: red for the gnomes, green for the goblins.
local WAX = {
    gnome = { wax = { 0.56, 0.12, 0.07 }, dark = { 0.35, 0.06, 0.04 }, lit = { 0.72, 0.25, 0.16 } },
    goblin = { wax = { 0.24, 0.42, 0.17 }, dark = { 0.13, 0.25, 0.10 }, lit = { 0.37, 0.56, 0.27 } },
}

-- The stamp, top right on the parcel: its box, turn, paper and shadow, the
-- bites of its perforation along the top and bottom (how many, how big),
-- the picture inset, and the cog drawn smaller on it.
local STAMP = {
    x = 226, y = 16, w = 46, h = 56, turn = 4, paper = { 0.94, 0.89, 0.75 }, shadow = { 0.6, 0.8, 0.35 },
    bites = 7, bite = 4, inset = 4,
    cog = { hub = 11, hole = 4, tooth = { 2.4, 3.2 }, reach = 6.5 },
}
-- The postmark struck half over it: its box and turn, its ink, the ring's
-- alpha and strokes, the words' line step, and the cancelling lines (on
-- its box: x, first y, length, how many, the step, alpha).
local POSTMARK = {
    x = 184, y = 34, size = 62, turn = -12, ink = { 0.10, 0.05, 0.02 }, ring = 0.48, strokes = 16, step = 12,
    cancel = { x = 54, y = 20, w = 46, lines = 3, step = 6, alpha = 0.40 },
}
-- The sender, printed top left (its two lines' y), and the address in the
-- maker's hand.
local SENDER = { x = 18, y = 24, step = 15, alpha = { 0.78, 0.70 } }
local ADDRESS = { x = 18, y = 84, step = 20, ink = { 0.11, 0.06, 0.02 } }

-- The label: what is inside, before anything else. Its top on the parcel,
-- size, paper, the inked frame `outline` in, and its lines' middles. A
-- little wider than the mockup's 252: Friz is wider than its stand-in, and
-- the last line must not touch the frame.
local LABEL = { y = 222, w = 266, h = 92, paper = { 0.92, 0.85, 0.69 }, outline = 5, alpha = 0.55,
    title = 23, italic = 44, rule = 61, keeps = 76, shadows = { { 0.6, 0.8, 0, 0.40 }, { 1, 1.5, 0.5, 0.25 } } }

-- The links on the game world, light, under the wrapped parcel.
local LINK = { base = { 0.95, 0.90, 0.78 }, hot = { 1, 0.95, 0.81 }, aside = { 1, 0.94, 0.78, 0.75 } }

-- Torn open. What is left of the paper: its box, its corners (as fractions
-- of it, clockwise from the top left), each side's teeth and seed, how
-- deep they tear, and its shadow.
local PAPER = {
    x = 200, y = 62, w = 330, h = 410, depth = 8,
    corners = { { 0.01, 0.03 }, { 0.99, 0.01 }, { 0.98, 0.99 }, { 0.02, 0.97 } },
    sides = { { 20, 11 }, { 24, 47 }, { 20, 83 }, { 24, 131 } },
    shadows = { { 6, 8, 0, 0.22 }, { 9, 12, 3, 0.10 } },
}
-- The flaps torn back, paler inside up: each a box, its turn, its corners
-- in the box (upper left, upper right, lower right, lower left), which two
-- the tear runs between (going clockwise), its teeth, depth and seed.
local FLAPS = {
    shadow = { 1.5, 2, 0.30 },
    { box = { 170, 40, 140, 110 }, turn = -10, points = { { 0, 0 }, { 140, 4.4 }, { 8.4, 110 }, { 8.4, 110 } },
        tear = { 2, 3 }, teeth = 16, depth = 7, seed = 201 },
    { box = { 450, 276, 120, 170 }, turn = 7, points = { { 112.8, 0 }, { 120, 0 }, { 120, 170 }, { 0, 170 } },
        tear = { 4, 1 }, teeth = 18, depth = 8, seed = 307 },
}
-- The twine, cut, lying loose: its box, the mockup's two curves in it.
local LOOSE = { x = 160, y = 442, steps = 6, outer = 4, inner = 2,
    curves = { { 4, 40, 40, 20, 70, 54, 110, 34 }, { 110, 34, 150, 14, 170, 18, 196, 30 } } }
-- The label torn aside with its paper.
local TORN_LABEL = { x = 426, y = 432, w = 200, h = 52, turn = 7, title = 18, italic = 37 }

-- The closed book (Style.ClosedBook), and its four ribbons out of the foot:
-- where they start (y on the book), how wide, the notch cut in their end,
-- their dark edges, the sheen (x in, width, alpha), their shadow, and each
-- one's cloth (Style.RIBBONS), x on the book, how far it hangs and its turn.
local BOOK = { x = 238, y = 96, w = 250, h = 330, title = "SOCIAL\nDIARY" }
local RIBBONS = {
    top = 322, width = 16, notch = 6, edge = 2, sheen = { 4, 3, 0.14 }, shadow = { 1, 1, 0.30 },
    { "green", 40, 64, 4 }, { "red", 62, 52, -2 }, { "purple", 84, 70, 6 }, { "gray", 106, 46, 1 },
}

-- The diary's note, beside the book: its top left and size, its margin and
-- turn, the middles of the first line and the step to its second (the
-- greeting wraps: "again" is longer than the note is wide), of the body's
-- first and the step to the next (at most `most`), the count's after the
-- body, and the links, the rule and the plain line from the bottom.
local NOTE = { x = 520, y = 150, w = 300, h = 252, margin = 20, turn = 2.4,
    hello = 28, helloLine = 20, body = 57, line = 19, most = 5, count = 28, links = 57, rule = 37, keeps = 22 }
-- Hardly crumpled, its corners curling a little, no folds: it was written
-- and laid in the parcel flat.
local CREASE = {
    columns = { 0, 0.5, 1 },
    rows = { 0, 0.5, 1 },
    folds = { columns = {}, rows = {} },
    crumple = 0.6, drift = 0.4, edge = 0.6, wander = 0,
    curl = { lift = 4, pull = 2 },
}

-- The makers. Placeholders until checked against real NPCs.
local MAKERS = {
    gnome = { sender = { "WIZZLEBOLT & DAUGHTER", "Diarywrights, Tinker Town" },
        address = { "To whoever picks", "this up" }, postmark = { "TINKER", "TOWN" } },
    goblin = { sender = { "GRIZZIK'S DIARIES", "Ratchet \194\183 no refunds" },
        address = { "To the new owner", "(paid in full)" }, aside = true, postmark = { "RATCHET" } },
}

-- What the note says.
local HELLO = { first = "Oh \226\128\148 hello. I'm your new diary.", again = "Your diary, still here whenever you're ready." }
local BODY = "I write down the people you meet, all by myself, so that months from now you still know who they"
    .. " were. It's only pencil, until you ink someone in."
local KEEPS = "I keep to myself: nothing leaves this computer."

local function Pencilled(n)
    if n == 0 then return "Nobody yet. Give me a minute." end
    if n == 1 then return "I've pencilled in one already." end
    return ("I've pencilled in %d already."):format(n)
end

--------------------------------------------------------------------------
-- Type
--------------------------------------------------------------------------
--
-- The parcel's own: print and the maker's hand on the paper, the label,
-- the stamp's and seal's letters, and links on the game world (light, with
-- a shadow, as they lie on whatever is behind).

local MORPHEUS, FRIZ = "Fonts\\MORPHEUS.TTF", "Fonts\\FRIZQT__.TTF"
local NEUTON = "Interface\\AddOns\\" .. addonName .. "\\Fonts\\Neuton-Italic.ttf"

local function Font(name, file, size, colour, shadow)
    local font = CreateFont(name)
    font:SetFont(file, size, "")
    font:SetTextColor(colour[1], colour[2], colour[3], colour[4] or 1)
    if shadow then
        font:SetShadowColor(0, 0, 0, shadow)
        font:SetShadowOffset(1, -1)
    else
        font:SetShadowOffset(0, 0)
    end
    return font
end

local PF = {
    print = Font("SocialDiaryFontParcelPrint", FRIZ, 11, KRAFT.ink),
    hand = Font("SocialDiaryFontParcelHand", NEUTON, 17, ADDRESS.ink),
    handSmall = Font("SocialDiaryFontParcelHandSmall", NEUTON, 14, ADDRESS.ink),
    postmark = Font("SocialDiaryFontParcelPostmark", FRIZ, 11, { POSTMARK.ink[1], POSTMARK.ink[2], POSTMARK.ink[3], 0.62 }),
    stamp = Font("SocialDiaryFontParcelStamp", MORPHEUS, 18, STAMP.paper),
    seal = Font("SocialDiaryFontParcelSeal", MORPHEUS, 13, WAX.goblin.dark),
    italic = Font("SocialDiaryFontParcelItalic", NEUTON, 15, Style.INK),
    tornTitle = Font("SocialDiaryFontParcelTornTitle", MORPHEUS, 16, Style.INK_STRONG),
    tornItalic = Font("SocialDiaryFontParcelTornItalic", NEUTON, 13, Style.INK),
    link = Font("SocialDiaryFontParcelLink", FRIZ, 13, LINK.base, 0.9),
    aside = Font("SocialDiaryFontParcelAside", FRIZ, 11, LINK.aside, 0.9),
}

--------------------------------------------------------------------------
-- Placing
--------------------------------------------------------------------------

local slip
-- "Later" this login, a fight it is waiting out, and torn this session (so
-- the note greets you for the first time, not again).
local later, waiting, tornNow = false, false, false

-- Degrees clockwise (the mockup's) as SetRotation's radians.
local function Rad(degrees) return -math.rad(degrees or 0) end

-- x, y turned `turn` (SetRotation's) about ox, oy; y down.
local function Turn(x, y, turn, ox, oy)
    if not turn or turn == 0 then return x, y end
    local c, s = math.cos(turn), math.sin(turn)
    local dx, dy = x - ox, oy - y
    return ox + dx * c - dy * s, oy - (dx * s + dy * c)
end

-- The scene's kit: placing in its coordinates on `root` (the host: every
-- frame of the scene covers it), and counting the textures it takes.
-- `owner` is the frame a texture is made on, for its level; a stroke or a
-- tear is placed on its owner, which has to cover the root.
local function Kit(root)
    local L, T = SCENE.left, SCENE.top
    local S = { made = 0, teeth = 0, shadows = {} }

    function S.Texture(owner, layer, sublevel, colour)
        S.made = S.made + 1
        local texture = owner:CreateTexture(nil, layer, nil, sublevel)
        if colour then texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1) end
        return texture
    end

    -- Colours a texture again: a round one through its tint.
    function S.Paint(texture, colour, alpha)
        if texture.round then
            texture:SetVertexColor(colour[1], colour[2], colour[3], alpha or 1)
        else
            texture:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
        end
    end

    -- `region` over x, y, w by h, turned `turn` about ox, oy, and turning
    -- itself where it can.
    function S.Box(region, x, y, w, h, turn, ox, oy)
        local cx, cy = Turn(x + w / 2, y + h / 2, turn, ox, oy)
        region:ClearAllPoints()
        region:SetPoint("CENTER", root, "TOPLEFT", cx - L, -(cy - T))
        region:SetSize(w, h)
        if region.SetRotation and (turn or region.turned) then
            region:SetRotation(turn or 0)
            region.turned = (turn or 0) ~= 0
            if region.turned and region.SetSnapToPixelGrid then
                region:SetSnapToPixelGrid(false)
                region:SetTexelSnappingBias(0)
            end
        end
    end

    function S.Rect(owner, layer, sublevel, x, y, w, h, colour, turn, ox, oy)
        local texture = S.Texture(owner, layer, sublevel, colour)
        S.Box(texture, x, y, w, h, turn, ox, oy)
        return texture
    end

    -- A spot of colour centred on x, y: round where the art allows.
    function S.Disc(owner, layer, sublevel, x, y, size, colour, alpha, turn, ox, oy)
        local texture = S.Texture(owner, layer, sublevel)
        texture.round = Style.Disc(texture, colour[1], colour[2], colour[3], alpha or 1)
        S.Box(texture, x - size / 2, y - size / 2, size, size, turn, ox, oy)
        return texture
    end

    -- A line of text, its middle at height y, starting at x ("LEFT"),
    -- ending there ("RIGHT") or centred on it; measured unbounded, so it is
    -- never cut short.
    function S.Line(text, x, y, justify, turn, ox, oy)
        text:SetSize(0, 0)
        local w = (text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth() or 0) + 2
        local h = (text:GetStringHeight() or 0) + 2
        if justify == "RIGHT" then x = x - w elseif justify == "CENTER" then x = x - w / 2 end
        S.Box(text, x, y - h / 2, w, h, turn, ox, oy)
    end

    -- Over any four points: upper left, upper right, lower right, lower
    -- left. False where corners cannot move.
    function S.Quad(texture, x1, y1, x2, y2, x3, y3, x4, y4)
        return Style.Quad(texture, root, x1 - L, y1 - T, x2 - L, y2 - T, x3 - L, y3 - T, x4 - L, y4 - T)
    end

    function S.Stroke(owner, layer, sublevel, x1, y1, x2, y2, colour, alpha, width)
        S.made = S.made + 1
        return Style.Stroke(owner, layer, x1 - L, y1 - T, x2 - L, y2 - T, colour, alpha, width, sublevel)
    end

    -- One of the mockup's cubic curves (x1, y1, two controls, x2, y2),
    -- offset by ox, oy, as `steps` strokes.
    function S.Curve(owner, layer, sublevel, c, ox, oy, steps, colour, width)
        local function At(t)
            local u = 1 - t
            local a, b, d, e = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
            return ox + a * c[1] + b * c[3] + d * c[5] + e * c[7], oy + a * c[2] + b * c[4] + d * c[6] + e * c[8]
        end
        local px, py = At(0)
        for i = 1, steps do
            local x, y = At(i / steps)
            S.Stroke(owner, layer, sublevel, px, py, x, y, colour, 1, width)
            px, py = x, y
        end
    end

    function S.Tear(owner, layer, sublevel, x1, y1, x2, y2, teeth, depth, seed, colour)
        S.teeth, S.made = S.teeth + teeth, S.made + teeth
        return Style.TornEdge(owner, layer, sublevel, x1 - L, y1 - T, x2 - L, y2 - T, teeth, depth, seed, colour)
    end

    -- A shadow, taken away laid flat.
    function S.Shadow(texture)
        S.shadows[#S.shadows + 1] = texture
        return texture
    end

    return S
end

-- A frame covering the host, for one part of the scene.
local function Cover(host, parent)
    local frame = CreateFrame("Frame", nil, parent or host)
    frame:SetAllPoints(host)
    return frame
end

-- A link on the game world: light, brighter under the mouse.
local function LightLink(parent, text, colour, onClick)
    local link = Style.Link(parent, PF.link, onClick)
    link:SetText(text)
    link:SetColor(colour[1], colour[2], colour[3])
    link:SetScript("OnEnter", function(self)
        self.label:SetTextColor(LINK.hot[1], LINK.hot[2], LINK.hot[3])
        self.line:SetColorTexture(LINK.hot[1], LINK.hot[2], LINK.hot[3], Style.HAIRLINE_HOT)
    end)
    link:SetScript("OnLeave", function(self)
        self.label:SetTextColor(colour[1], colour[2], colour[3])
        self.line:SetColorTexture(colour[1], colour[2], colour[3], Style.HAIRLINE)
    end)
    return link
end

-- A cog about cx, cy, turned `turn` about ox, oy: a hub and eight teeth in
-- `colour`, a hole in `hole`'s. Returns its textures, the hole last.
local function Cog(S, owner, layer, sublevel, cx, cy, C, colour, hole, turn, ox, oy)
    local parts = {}
    local hx, hy = Turn(cx, cy, turn, ox, oy)
    parts[1] = S.Disc(owner, layer, sublevel, hx, hy, C.hub, colour)
    for k = 0, 7 do
        local a = math.rad(k * 45)
        local x, y = Turn(cx + C.reach * math.sin(a), cy - C.reach * math.cos(a), turn, ox, oy)
        local tw, th = C.tooth[1], C.tooth[2]
        parts[#parts + 1] = S.Rect(owner, layer, sublevel, x - tw / 2, y - th / 2, tw, th, colour, -a + (turn or 0), x, y)
    end
    parts[#parts + 1] = S.Disc(owner, layer, sublevel + 1, hx, hy, C.hole, hole)
    return parts
end

-- Today, as the postmark strikes it: "9 OCT".
local function Day()
    return ("%d %s"):format(tonumber(date("%d")) or 1, (date("%b") or ""):upper())
end

--------------------------------------------------------------------------
-- Wrapped
--------------------------------------------------------------------------

local function BuildWrapped(host, S)
    local F = Cover(host)
    host.wrapped = F
    local P = PARCEL
    local px, py, pw, ph = P.x, P.y, P.w, P.h
    local marks = { gnome = {}, goblin = {} }
    host.marks = marks
    local function Mark(maker, region) marks[maker][#marks[maker] + 1] = region end
    local SHADE = { KRAFT.ink[1], KRAFT.ink[2], KRAFT.ink[3] }

    -- Its shadow, the paper and its grain.
    for i, s in ipairs(P.shadows) do
        S.Shadow(S.Rect(F, "BACKGROUND", -9 + i, px + s[1] - s[3], py + s[2] - s[3], pw + 2 * s[3], ph + 2 * s[3],
            { 0, 0, 0, s[4] }))
    end
    S.Rect(F, "BACKGROUND", -5, px, py, pw, ph, KRAFT.paper)
    local grain = Style.Art("grain")
    if grain then
        local fibres = S.Rect(F, "BACKGROUND", -4, px, py, pw, ph)
        fibres:SetTexture(grain)
        fibres:SetTexCoord(0.05, 0.95, 0.10, 0.40)
        fibres:SetVertexColor(0.35, 0.22, 0.10)
        fibres:SetAlpha(P.fibres)
    end
    -- The light on it, from the top left.
    Style.Gradient(S.Rect(F, "BACKGROUND", -3, px, py, pw, ph), "HORIZONTAL",
        { 1, 0.92, 0.78, 0.16 }, { SHADE[1], SHADE[2], SHADE[3], 0.14 })
    Style.Gradient(S.Rect(F, "BACKGROUND", -3, px, py, pw, ph), "VERTICAL",
        { SHADE[1], SHADE[2], SHADE[3], 0.10 }, { 1, 0.92, 0.78, 0.08 })
    -- Folded over the book's edges, and the edges themselves.
    local D = P.folds
    Style.Shade(S.Rect(F, "BACKGROUND", -2, px, py, D.left[1], ph), "HORIZONTAL", SHADE[1], SHADE[2], SHADE[3],
        D.left[2], 0)
    Style.Shade(S.Rect(F, "BACKGROUND", -2, px + pw - D.right[1], py, D.right[1], ph), "HORIZONTAL",
        SHADE[1], SHADE[2], SHADE[3], 0, D.right[2])
    Style.Shade(S.Rect(F, "BACKGROUND", -2, px, py, pw, D.top[1]), "VERTICAL", 1, 0.92, 0.78, 0, D.top[2])
    Style.Shade(S.Rect(F, "BACKGROUND", -2, px, py + ph - D.bottom[1], pw, D.bottom[1]), "VERTICAL",
        SHADE[1], SHADE[2], SHADE[3], D.bottom[2], 0)
    local e = P.edge[1]
    local light, dark = { 1, 0.9, 0.75, P.edge[2] }, { SHADE[1], SHADE[2], SHADE[3], P.edge[3] }
    S.Rect(F, "BACKGROUND", -1, px, py, pw, e, light)
    S.Rect(F, "BACKGROUND", -1, px, py + e, e, ph - e, light)
    S.Rect(F, "BACKGROUND", -1, px + e, py + ph - e, pw - e, e, dark)
    S.Rect(F, "BACKGROUND", -1, px + pw - e, py + e, e, ph - 2 * e, dark)
    local c = P.crease
    S.Stroke(F, "BORDER", 0, px + c[1], py + c[2], px + c[3], py + c[4], SHADE, c[6], c[5])

    -- The sender, printed, and the address in the maker's hand.
    host.sender = { Style.Text(F, PF.print), Style.Text(F, PF.print) }
    for i, text in ipairs(host.sender) do text:SetAlpha(SENDER.alpha[i]) end
    host.address = { Style.Text(F, PF.hand), Style.Text(F, PF.hand) }

    -- The stamp, the maker's mark on it, and the postmark half over it.
    local M = STAMP
    local sx, sy = px + M.x, py + M.y
    local scx, scy = sx + M.w / 2, sy + M.h / 2
    local turn = Rad(M.turn)
    S.Shadow(S.Rect(F, "BORDER", 1, sx + M.shadow[1], sy + M.shadow[2], M.w, M.h,
        { SHADE[1], SHADE[2], SHADE[3], M.shadow[3] }, turn, scx, scy))
    S.Rect(F, "BORDER", 2, sx, sy, M.w, M.h, M.paper, turn, scx, scy)
    for _, y in ipairs({ sy, sy + M.h }) do
        for i = 1, M.bites do
            local bx, by = Turn(sx + (i - 0.5) * M.w / M.bites, y, turn, scx, scy)
            S.Disc(F, "BORDER", 3, bx, by, M.bite, KRAFT.paper)
        end
    end
    host.stampPicture = S.Rect(F, "BORDER", 4, sx + M.inset, sy + M.inset, M.w - 2 * M.inset, M.h - 2 * M.inset,
        WAX.gnome.dark, turn, scx, scy)
    host.stampCog = Cog(S, F, "BORDER", 5, scx, scy, M.cog, M.paper, WAX.gnome.dark, turn, scx, scy)
    for _, part in ipairs(host.stampCog) do Mark("gnome", part) end
    host.stampLetter = Style.Text(F, PF.stamp)
    host.stampLetter:SetText("G")
    Mark("goblin", host.stampLetter)

    local K = POSTMARK
    local kx, ky = px + K.x + K.size / 2, py + K.y + K.size / 2
    local kturn = Rad(K.turn)
    local r = K.size / 2 - 1
    for i = 1, K.strokes do
        local a, b = 2 * math.pi * (i - 1) / K.strokes, 2 * math.pi * i / K.strokes
        S.Stroke(F, "BORDER", 6, kx + r * math.cos(a), ky + r * math.sin(a), kx + r * math.cos(b),
            ky + r * math.sin(b), K.ink, K.ring, 1.5)
    end
    local C = K.cancel
    for i = 0, C.lines - 1 do
        local x1, y1 = Turn(px + K.x + C.x, py + K.y + C.y + i * C.step, kturn, kx, ky)
        local x2, y2 = Turn(px + K.x + C.x + C.w, py + K.y + C.y + i * C.step, kturn, kx, ky)
        S.Stroke(F, "BORDER", 6, x1, y1, x2, y2, K.ink, C.alpha, 1.2)
    end
    host.postmark = {}
    for i = 1, 3 do host.postmark[i] = Style.Text(F, PF.postmark) end

    -- The twine both ways, and the bow on the knot.
    local W = TWINE
    local tx, ty = px + W.x, py + W.y
    local inset = (W.width - W.coreWidth) / 2
    for _, strip in ipairs({ { tx, py - 2, W.width, ph + 4, true }, { px - 2, ty, pw + 4, W.width } }) do
        local x, y, w, h, upright = strip[1], strip[2], strip[3], strip[4], strip[5]
        S.Shadow(S.Rect(F, "ARTWORK", 0, x + W.shadow[1], y + W.shadow[2], w, h,
            { SHADE[1], SHADE[2], SHADE[3], W.shadow[3] }))
        S.Rect(F, "ARTWORK", 1, x, y, w, h, W.edge)
        if upright then
            S.Rect(F, "ARTWORK", 2, x + inset, y, W.coreWidth, h, W.core)
        else
            S.Rect(F, "ARTWORK", 2, x, y + inset, w, W.coreWidth, W.core)
        end
    end
    local B = BOW
    for _, pass in ipairs({ { W.bow, B.outer, 3 }, { W.core, B.inner, 4 } }) do
        local colour, width, sublevel = pass[1], pass[2], pass[3]
        for _, curve in ipairs(B.curves) do
            S.Curve(F, "ARTWORK", sublevel, curve, px + B.x, py + B.y, B.steps, colour, width)
        end
        for _, tail in ipairs(B.tails) do
            S.Stroke(F, "ARTWORK", sublevel, px + B.x + tail[1], py + B.y + tail[2], px + B.x + tail[3],
                py + B.y + tail[4], colour, 1, width)
        end
    end

    -- The label, pasted on: paper, an inked frame, its words and a rule.
    local A = LABEL
    local lx, ly = px + (pw - A.w) / 2, py + A.y
    for i, s in ipairs(A.shadows) do
        S.Shadow(S.Rect(F, "ARTWORK", 5 + i, lx + s[1] - s[3], ly + s[2] - s[3], A.w + 2 * s[3], A.h + 2 * s[3],
            { SHADE[1], SHADE[2], SHADE[3], s[4] }))
    end
    S.Rect(F, "ARTWORK", 7, lx, ly, A.w, A.h, A.paper)
    local o, ink = A.outline, { Style.INK[1], Style.INK[2], Style.INK[3], A.alpha }
    S.Rect(F, "OVERLAY", -2, lx + o, ly + o, A.w - 2 * o, 1, ink)
    S.Rect(F, "OVERLAY", -2, lx + o, ly + A.h - o - 1, A.w - 2 * o, 1, ink)
    S.Rect(F, "OVERLAY", -2, lx + o, ly + o, 1, A.h - 2 * o, ink)
    S.Rect(F, "OVERLAY", -2, lx + A.w - o - 1, ly + o, 1, A.h - 2 * o, ink)
    S.Rect(F, "OVERLAY", -2, lx + 12, ly + A.rule, A.w - 24, 1, { Style.INK[1], Style.INK[2], Style.INK[3], 0.25 })
    local label = { title = Style.Text(F, FONT.page), italic = Style.Text(F, PF.italic), keeps = Style.Text(F, FONT.small) }
    label.title:SetText("ONE SOCIAL DIARY")
    label.italic:SetText("writes itself")
    label.keeps:SetText("Keeps to itself: nothing leaves this computer.")
    S.Line(label.title, lx + A.w / 2, ly + A.title, "CENTER")
    S.Line(label.italic, lx + A.w / 2, ly + A.italic, "CENTER")
    S.Line(label.keeps, lx + A.w / 2, ly + A.keeps, "CENTER")
    host.label = label

    -- The seal on the knot: a button, as a click on it tears the paper.
    -- Its parts are coloured for the maker as it is laid.
    local E = SEAL
    local seal = CreateFrame("Button", nil, F)
    seal:SetSize(E.size, E.size)
    seal:SetPoint("TOPLEFT", host, "TOPLEFT", px + E.x - SCENE.left, -(py + E.y - SCENE.top))
    host.seal = seal
    local cx, cy = px + E.x + E.size / 2, py + E.y + E.size / 2
    local WHITE = { 1, 1, 1 }
    seal.shadow = S.Shadow(S.Disc(seal, "ARTWORK", 0, cx + E.shadow[1], cy + E.shadow[2], E.rim, { 0, 0, 0 },
        E.shadow[3]))
    seal.rim = S.Disc(seal, "ARTWORK", 1, cx, cy, E.rim, WHITE)
    seal.body = S.Disc(seal, "ARTWORK", 2, cx, cy, E.body, WHITE)
    seal.ring = S.Disc(seal, "ARTWORK", 3, cx, cy, E.ring, WHITE)
    seal.ringIn = S.Disc(seal, "ARTWORK", 4, cx, cy, E.ringIn, WHITE)
    local lit = E.lit
    seal.lit = S.Texture(seal, "ARTWORK", 5)
    seal.lit.round = Style.Disc(seal.lit, 1, 1, 1, lit[6])
    S.Box(seal.lit, cx + lit[1] - lit[3] / 2, cy + lit[2] - lit[4] / 2, lit[3], lit[4], Rad(lit[5]),
        cx + lit[1], cy + lit[2])
    seal.cog = Cog(S, seal, "OVERLAY", 0, cx, cy, E.cog, WHITE, WHITE)
    for _, part in ipairs(seal.cog) do Mark("gnome", part) end
    seal.dots = {}
    for i = 1, E.coin.dots do
        local a = 2 * math.pi * i / E.coin.dots
        seal.dots[i] = S.Disc(seal, "OVERLAY", 0, cx + E.coin.r * math.cos(a), cy + E.coin.r * math.sin(a),
            E.coin.dot, WHITE)
        Mark("goblin", seal.dots[i])
    end
    seal.letter = Style.Text(seal, PF.seal)
    seal.letter:SetText("G")
    S.Line(seal.letter, cx, cy, "CENTER")
    Mark("goblin", seal.letter)
    seal.hover = S.Disc(seal, "OVERLAY", 3, cx, cy, E.body, { 1, 0.95, 0.85 }, E.hover)
    seal.hover:Hide()
    seal:SetScript("OnEnter", function(self) self.hover:Show() end)
    seal:SetScript("OnLeave", function(self) self.hover:Hide() end)
    seal:SetScript("OnClick", function() host:Tear() end)

    -- The links under it, on the game world.
    local y = py + ph + P.links
    host.tear = LightLink(F, "Tear it open", LINK.hot, function() host:Tear() end)
    host.tear:SetPoint("LEFT", host, "TOPLEFT", px + 4 - SCENE.left, -(y - SCENE.top))
    host.later = LightLink(F, "Later", LINK.base, function()
        later = true
        ns.UI.HideSlip(false)
    end)
    host.later:SetPoint("LEFT", host.tear, "RIGHT", 14, 0)
    host.aside = Style.Text(F, PF.aside)
    host.aside:SetText("or type /sd")
    host.aside:SetPoint("RIGHT", host, "TOPLEFT", px + pw - 4 - SCENE.left, -(y - SCENE.top))
end

-- The maker's marks and words, today's postmark, the seal's wax.
local function LayWrapped(host, S, maker)
    local m, wax = MAKERS[maker], WAX[maker]
    for key, list in pairs(host.marks) do
        for _, region in ipairs(list) do region:SetShown(key == maker) end
    end
    local px, py = PARCEL.x, PARCEL.y
    local textTurn = host.turnsText

    for i, text in ipairs(host.sender) do
        text:SetText(m.sender[i])
        S.Line(text, px + SENDER.x, py + SENDER.y + (i - 1) * SENDER.step, "LEFT")
    end
    host.address[2]:SetFontObject(m.aside and PF.handSmall or PF.hand)
    for i, text in ipairs(host.address) do
        text:SetText(m.address[i])
        S.Line(text, px + ADDRESS.x, py + ADDRESS.y + (i - 1) * ADDRESS.step, "LEFT")
    end

    local seal = host.seal
    S.Paint(seal.rim, wax.dark)
    S.Paint(seal.body, wax.wax)
    S.Paint(seal.ring, wax.dark)
    S.Paint(seal.ringIn, wax.wax)
    S.Paint(seal.lit, wax.lit, SEAL.lit[6])
    for i, part in ipairs(seal.cog) do S.Paint(part, i == #seal.cog and wax.wax or wax.dark) end
    for _, dot in ipairs(seal.dots) do S.Paint(dot, wax.dark) end
    seal.letter:SetTextColor(wax.dark[1], wax.dark[2], wax.dark[3])

    local M = STAMP
    local scx, scy = px + M.x + M.w / 2, py + M.y + M.h / 2
    S.Paint(host.stampPicture, wax.dark)
    S.Paint(host.stampCog[#host.stampCog], wax.dark)
    S.Line(host.stampLetter, scx, scy, "CENTER", textTurn and Rad(M.turn), scx, scy)

    local K = POSTMARK
    local kx, ky = px + K.x + K.size / 2, py + K.y + K.size / 2
    local lines = {}
    for i, line in ipairs(m.postmark) do lines[i] = line end
    lines[#lines + 1] = Day()
    for i, text in ipairs(host.postmark) do
        text:SetText(lines[i] or "")
        text:SetShown(lines[i] ~= nil)
        if lines[i] then
            S.Line(text, kx, ky + (i - (#lines + 1) / 2) * K.step, "CENTER", textTurn and Rad(K.turn), kx, ky)
        end
    end
end

--------------------------------------------------------------------------
-- Torn open
--------------------------------------------------------------------------

-- The ribbons out of the foot of the closed book, each turned a little:
-- cloth with darker edges, a sheen, and a notch cut in its end. Drawn on
-- the book, in its coordinates. Where corners cannot move, a plain strip.
local function Ribbons(S, book)
    local R = RIBBONS
    local half = R.width / 2
    for _, ribbon in ipairs(R) do
        local look = Style.RIBBONS[ribbon[1]]
        local x, hang, phi = ribbon[2], ribbon[3], math.rad(ribbon[4])
        local c, s = math.cos(phi), math.sin(phi)
        -- u across from its middle, v down from its top; turned clockwise.
        local function At(u, v) return x + half + u * c - v * s, R.top + u * s + v * c end
        local function Foot(u) return hang - R.notch * (1 - math.abs(u) / half) end
        local strips = {}
        local function Strip(sublevel, u1, u2, colour, alpha, dx, dy)
            S.made = S.made + 1
            local texture = book:CreateTexture(nil, "OVERLAY", nil, sublevel)
            texture:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
            local ax, ay = At(u1, 0)
            local bx, by = At(u2, 0)
            local cx, cy = At(u2, Foot(u2))
            local ex, ey = At(u1, Foot(u1))
            dx, dy = dx or 0, dy or 0
            texture.bent = Style.Quad(texture, book, ax + dx, ay + dy, bx + dx, by + dy, cx + dx, cy + dy, ex + dx, ey + dy)
            strips[#strips + 1] = texture
            return texture
        end
        local sh, sheen = R.shadow, look.sheen or { 1, 0.6, 0.55 }
        S.Shadow(Strip(-4, -half, 0, { 0, 0, 0 }, sh[3], sh[1], sh[2]))
        S.Shadow(Strip(-4, 0, half, { 0, 0, 0 }, sh[3], sh[1], sh[2]))
        local body = Strip(-3, -half, 0, look.cloth)
        Strip(-3, 0, half, look.cloth)
        Strip(-2, -half, -half + R.edge, look.edge)
        Strip(-2, half - R.edge, half, look.edge)
        Strip(-1, -half + R.sheen[1], -half + R.sheen[1] + R.sheen[2], sheen, R.sheen[3])
        if not body.bent then
            for _, strip in ipairs(strips) do
                strip:Hide()
                strip.never = true
            end
            body:Show()
            body.never = nil
            body:ClearAllPoints()
            body:SetPoint("TOPLEFT", book, "TOPLEFT", x, -R.top)
            body:SetSize(R.width, hang)
        end
    end
end

local function BuildTorn(host, S)
    local F = Cover(host)
    host.torn = F
    host.edges = {}
    local SHADE = KRAFT.ink

    -- What is left of the paper: a quad inside the tear, its shadow, the
    -- light on it, and the tear all round.
    local P = PAPER
    local corners = {}
    for i, c in ipairs(P.corners) do corners[i] = { P.x + c[1] * P.w, P.y + c[2] * P.h } end
    local function Over(texture, dx, dy, grow)
        local g = grow or 0
        local a, b, cc, d = corners[1], corners[2], corners[3], corners[4]
        return S.Quad(texture, a[1] + dx - g, a[2] + dy - g, b[1] + dx + g, b[2] + dy - g,
            cc[1] + dx + g, cc[2] + dy + g, d[1] + dx - g, d[2] + dy + g)
    end
    for i, s in ipairs(P.shadows) do
        Over(S.Shadow(S.Texture(F, "BACKGROUND", -9 + i, { 0, 0, 0, s[4] })), s[1], s[2], s[3])
    end
    Over(S.Texture(F, "BACKGROUND", -5, KRAFT.paper), 0, 0)
    local light = S.Texture(F, "BACKGROUND", -4)
    Style.Gradient(light, "HORIZONTAL", { 1, 0.92, 0.78, 0.14 }, { SHADE[1], SHADE[2], SHADE[3], 0.12 })
    Over(light, 0, 0)
    for i, side in ipairs(P.sides) do
        local a, b = corners[i], corners[i % 4 + 1]
        host.edges[#host.edges + 1] = S.Tear(F, "BACKGROUND", -5, a[1], a[2], b[1], b[2], side[1], P.depth, side[2],
            KRAFT.paper)
    end

    -- The flaps torn back, paler inside up, ragged along the tear.
    local FS = FLAPS.shadow
    for _, flap in ipairs(FLAPS) do
        local bx, by, bw, bh = flap.box[1], flap.box[2], flap.box[3], flap.box[4]
        local turn, ox, oy = Rad(flap.turn), bx + bw / 2, by + bh / 2
        local pts = {}
        for k, p in ipairs(flap.points) do pts[k] = { Turn(bx + p[1], by + p[2], turn, ox, oy) } end
        local function Over4(texture, dx, dy)
            return S.Quad(texture, pts[1][1] + dx, pts[1][2] + dy, pts[2][1] + dx, pts[2][2] + dy,
                pts[3][1] + dx, pts[3][2] + dy, pts[4][1] + dx, pts[4][2] + dy)
        end
        local shadow = S.Shadow(S.Texture(F, "BORDER", 0, { SHADE[1], SHADE[2], SHADE[3], FS[3] }))
        local inside = S.Texture(F, "BORDER", 1, KRAFT.inside)
        local sheen = S.Texture(F, "BORDER", 2)
        Style.Gradient(sheen, "HORIZONTAL", { 1, 0.94, 0.82, 0.22 }, { SHADE[1], SHADE[2], SHADE[3], 0.10 })
        Over4(shadow, FS[1], FS[2])
        Over4(sheen, 0, 0)
        -- A flap is no rectangle: where corners cannot move, there is none.
        if not Over4(inside, 0, 0) then
            for _, texture in ipairs({ shadow, inside, sheen }) do
                texture:Hide()
                texture.never = true
            end
        end
        local a, b = pts[flap.tear[1]], pts[flap.tear[2]]
        host.edges[#host.edges + 1] = S.Tear(F, "BORDER", 1, a[1], a[2], b[1], b[2], flap.teeth, flap.depth, flap.seed,
            KRAFT.inside)
    end

    -- The twine, cut, lying loose.
    for _, pass in ipairs({ { TWINE.edge, LOOSE.outer, 0 }, { TWINE.core, LOOSE.inner, 1 } }) do
        for _, curve in ipairs(LOOSE.curves) do
            S.Curve(F, "ARTWORK", pass[3], curve, LOOSE.x, LOOSE.y, LOOSE.steps, pass[1], pass[2])
        end
    end

    -- The closed book, and its ribbons.
    local book = Style.ClosedBook(F, BOOK.w, BOOK.h, BOOK.title)
    book:SetPoint("TOPLEFT", host, "TOPLEFT", BOOK.x - SCENE.left, -(BOOK.y - SCENE.top))
    S.made = S.made + book.count
    for _, shadow in ipairs(book.shadows) do S.Shadow(shadow) end
    host.book = book
    Ribbons(S, book)

    -- The label, torn aside with its paper, over the book's edge.
    local tag = Cover(host, F)
    tag:SetFrameLevel(book:GetFrameLevel() + 2)
    local A, Z = LABEL, TORN_LABEL
    local ink = { Style.INK[1], Style.INK[2], Style.INK[3], A.alpha }
    local o = A.outline
    local parts = {}
    local function Part(region, x, y, w, h)
        parts[#parts + 1] = { region, Z.x + x, Z.y + y, w, h }
        return region
    end
    for i, s in ipairs(A.shadows) do
        Part(S.Shadow(S.Texture(tag, "ARTWORK", i, { SHADE[1], SHADE[2], SHADE[3], s[4] })),
            s[1] - s[3], s[2] - s[3], Z.w + 2 * s[3], Z.h + 2 * s[3])
    end
    Part(S.Texture(tag, "ARTWORK", 3, A.paper), 0, 0, Z.w, Z.h)
    Part(S.Texture(tag, "ARTWORK", 4, ink), o, o, Z.w - 2 * o, 1)
    Part(S.Texture(tag, "ARTWORK", 4, ink), o, Z.h - o - 1, Z.w - 2 * o, 1)
    Part(S.Texture(tag, "ARTWORK", 4, ink), o, o, 1, Z.h - 2 * o)
    Part(S.Texture(tag, "ARTWORK", 4, ink), Z.w - o - 1, o, 1, Z.h - 2 * o)
    local title, italic = Style.Text(tag, PF.tornTitle), Style.Text(tag, PF.tornItalic)
    title:SetText("ONE SOCIAL DIARY")
    italic:SetText("writes itself")
    host.tornLabel = { title = title, italic = italic, parts = parts }

    -- The diary's note, beside the book: a loose sheet of its own.
    local N = NOTE
    local holder = CreateFrame("Frame", nil, F)
    holder:SetSize(N.w + 40, N.h + 40)
    holder:SetPoint("CENTER", host, "TOPLEFT", N.x + N.w / 2 - SCENE.left, -(N.y + N.h / 2 - SCENE.top))
    local note, K = ns.UI.LooseSheet(holder, N.w, N.h, { crease = CREASE, quiet = true })
    -- Only the note takes clicks, not the game round it.
    note:EnableMouse(false)
    local sheet = note.sheet
    note.hellos = { Style.Text(sheet, FONT.pencilLede), Style.Text(sheet, FONT.pencilLede) }
    note.hello = note.hellos[1]
    note.lines = {}
    for i = 1, N.most do note.lines[i] = Style.Text(sheet, FONT.pencil) end
    note.count = Style.Text(sheet, FONT.pencil)
    note.open = K.Link(FONT.strong, function() ns.UI.ShowIntro() end)
    note.open:SetText("Open me")
    note.later = K.Link(FONT.body, function()
        later = true
        ns.UI.HideSlip(false)
    end)
    note.later:SetText("Later")
    note.aside = Style.Text(sheet, FONT.small)
    note.aside:SetText("or type /sd")
    note.rule = K.Texture("ARTWORK", 0)
    note.rule:SetColorTexture(Style.GRAPHITE[1], Style.GRAPHITE[2], Style.GRAPHITE[3], 0.25)
    note.keeps = Style.Text(sheet, FONT.pencilSmall)
    note.keeps:SetText(KEEPS)
    host.note, host.K = note, K
end

-- The torn label, turned as it lies (straight laid flat, or where text
-- cannot turn).
local function LayLabel(host, S, flat)
    local Z = TORN_LABEL
    local turn = (not flat and host.turnsText) and Rad(Z.turn) or 0
    local ox, oy = Z.x + Z.w / 2, Z.y + Z.h / 2
    for _, part in ipairs(host.tornLabel.parts) do
        S.Box(part[1], part[2], part[3], part[4], part[5], turn, ox, oy)
    end
    S.Line(host.tornLabel.title, ox, Z.y + Z.title, "CENTER", turn, ox, oy)
    S.Line(host.tornLabel.italic, ox, Z.y + Z.italic, "CENTER", turn, ox, oy)
end

-- The note: how it lies, the first line (the first time, or again), the
-- body a line at a time, the live count, the links and the plain line.
local function LayNote(host, flat, again)
    local note, K, N = host.note, host.K, NOTE
    K.Fall("parcel" .. (ns.ownGUID or ""), flat and 0 or Rad(N.turn))
    K.Lay()
    local M = N.margin
    local hello = K.Wrap(again and HELLO.again or HELLO.first, N.w - 2 * M, FONT.pencilLede)
    if #hello > #note.hellos then hello[#note.hellos] = table.concat(hello, " ", #note.hellos) end
    for i, text in ipairs(note.hellos) do
        text:SetText(hello[i] or "")
        text:SetShown(hello[i] ~= nil)
        if hello[i] then K.PlaceText(text, M, N.hello + (i - 1) * N.helloLine) end
    end
    local lines = K.Wrap(BODY, N.w - 2 * M, FONT.pencil)
    -- More lines than room: the last one takes the rest rather than lose
    -- words.
    if #lines > N.most then lines[N.most] = table.concat(lines, " ", N.most) end
    -- The body moves down by the greeting's second line, if any.
    local y = N.body + (math.min(#hello, #note.hellos) - 1) * N.helloLine
    for i, text in ipairs(note.lines) do
        local line = lines[i]
        text:SetText(line or "")
        text:SetShown(line ~= nil)
        if line then
            K.PlaceText(text, M, y)
            y = y + N.line
        end
    end
    note.count:SetText(Pencilled(ns.People.PencilledCount()))
    K.PlaceText(note.count, M, y - N.line + N.count)
    local links = N.h - N.links
    note.open:PlaceAt(M, links)
    note.later:PlaceAt(M + K.Width(note.open.label) + 16, links)
    K.PlaceText(note.aside, N.w - M, links, "RIGHT")
    K.Place(note.rule, M, N.h - N.rule, N.w - 2 * M, 1)
    K.PlaceText(note.keeps, M, N.h - N.keeps)
    note:Show()
end

--------------------------------------------------------------------------
-- The host
--------------------------------------------------------------------------

local function Build()
    local host = CreateFrame("Frame", "SocialDiaryIntroFrame", UIParent)
    host:SetSize(SCENE.w, SCENE.h)
    host:SetFrameStrata("HIGH")
    host:SetClampedToScreen(true)
    host:Hide()
    -- Escape puts it away, like Later.
    UISpecialFrames[#UISpecialFrames + 1] = "SocialDiaryIntroFrame"

    local probe = host:CreateFontString(nil, "OVERLAY")
    host.turnsText = probe.SetRotation ~= nil
    probe:Hide()

    local S = Kit(host)
    BuildWrapped(host, S)
    BuildTorn(host, S)
    host.counts = { teeth = S.teeth, textures = S.made }

    function host:Lay()
        local flat = ns.Setting("flatSheets") == true
        local state = ns.Setting("parcelOpened") and "torn" or "wrapped"
        local maker = UnitFactionGroup("player") == "Horde" and "goblin" or "gnome"
        self.state, self.maker = state, maker
        self:SetScale(SCENE.scale)
        self:ClearAllPoints()
        self:SetPoint("TOP", UIParent, "TOP", SCENE.w / 2 - (SCENE.middle[state] - SCENE.left), SCENE.y)
        for _, shadow in ipairs(S.shadows) do shadow:SetShown(not flat and not shadow.never) end
        for _, edge in ipairs(self.edges) do edge:Lay(flat) end
        self.wrapped:SetShown(state == "wrapped")
        self.torn:SetShown(state == "torn")
        if state == "wrapped" then
            LayWrapped(self, S, maker)
        else
            LayLabel(self, S, flat)
            LayNote(self, flat, not tornNow)
        end
    end

    -- Torn open: kept, with the paper's sound, and laid again.
    function host:Tear()
        if self.state ~= "wrapped" then return end
        ns.SetSetting("parcelOpened", true)
        tornNow = true
        Style.PlaySound("tear")
        self:Lay()
    end

    -- However it goes -- Later, Escape, the book opening -- the note goes
    -- with it.
    host:SetScript("OnHide", function() host.note:Hide(true) end)

    return host
end

-- Puts it away: with the paper's rustle, unless `quiet`.
function ns.UI.HideSlip(quiet)
    if not slip or not slip:IsShown() then return end
    if quiet ~= false then quiet = true end
    slip:Hide()
    if not quiet then Style.PlaySound("sheetClose") end
end

-- Lays it over the game, if it is still due: the front matter unread, not
-- put away this login, and no fight on.
function ns.UI.OfferSlip()
    if ns.Setting("frontRead") or later then return end
    if InCombatLockdown() then
        waiting = true
        return
    end
    waiting = false
    slip = slip or Build()
    if slip:IsShown() then return end
    slip:Show()
    slip:Raise()
    slip:Lay()
    Style.PlaySound("sheetOpen")
end

-- The introduction: the book turned to its first leaf, the frontispiece.
function ns.UI.ShowIntro()
    ns.UI.SetJournalView("frontispiece")
    ns.UI.ShowJournal()
end

-- For the tests: the parcel's host.
function ns.UI.Slip()
    return slip
end

ns.On("PLAYER_LOGIN", function()
    later, tornNow = false, false
    if ns.Setting("frontRead") then return end
    C_Timer.After(SHOW_DELAY, ns.UI.OfferSlip)
end)

ns.On("PLAYER_REGEN_DISABLED", function()
    if slip and slip:IsShown() then
        ns.UI.HideSlip(true)
        waiting = true
    end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    if waiting then ns.UI.OfferSlip() end
end)
