-- The campfire slip (Your Diary's plates; .claude/ui-proposal/campfire.md,
-- the user's decisions of 14 Oct): a campfire sat by on a plate, told in the
-- margin by one small cut slip of the strip family (UI/PaperStrip.lua) with
-- one line in the diary's hand, exactly "sat by a campfire"
-- (Text.CAMPFIRE_SLIP, the user's words), and a pencil leader to the fire's
-- mark (UI/JourneyPlate.lua's SHAPES.campfire).
--
-- It is the lucky card's S size (UI/LuckyCard.lua's tag): the hand at
-- 14 px, not a person's 16, so it fits the narrowest column (122 px); the
-- tag's small tape slanted over its top left corner, clear of the words. No
-- heading, icon, count or struck words: one slip a plate however many fires
-- (each keeps its own mark), and its tooltip lists every sitting there. It
-- opens nothing.
--
-- It is filler ("kind of unimportant, just filler if we don't have
-- anything better", the user, 14 Oct): last in the margin, so the first
-- left off, and it never grows smaller. Either it fits or it is left off
-- and the caption's words say it (Text.PlateCaption's `camped`).
--
-- Laid flat ("Flat paper only") it lies square, without shadows, as every
-- slip does.

local addonName, ns = ...

local CampfireSlip = {}
ns.UI.CampfireSlip = CampfireSlip

-- The slip: the hand's file and size (the lucky tag's 14 px, PRINT.hand),
-- the most it turns (degrees, the strip's), and its tape (LuckyCard's TAG:
-- `w` by `h`, its middle at `x`, `y` px of the slip from its top left, i.e.
-- on the corner, slanted between the two `slant`s, degrees, seeded), which
-- crosses the corner on the slip's margin (7 px left, 4 px top), so the
-- words start clear of it.
local SLIP = { file = "Interface\\AddOns\\" .. addonName .. "\\Fonts\\Neuton-Italic.ttf", size = 14, turn = 1.4,
    tape = { x = 1, y = 1, w = 22, h = 10, slant = { 39, 51 } } }
CampfireSlip.SLIP = SLIP

-- A number from a string, the same every time (PaperStrip's).
local function Seed(key)
    local seed = 0
    key = tostring(key or "")
    for i = 1, #key do seed = (seed + key:byte(i) * i) % 100003 end
    return seed
end

-- The plate's one slip, from its fires (plate.campfireMarks: { x, y on the
-- card, list of moments, at = { x, y } on the page }): every sitting on the
-- plate (`list`, oldest first, for the tooltip), the latest fire's mark on
-- the page (`mark`, which stands in for the slip's place in the margin's
-- order before it is laid), and every mark (`marks`, page points, for its
-- leader to go to the nearest). Nil without a fire.
function CampfireSlip.Choose(marks)
    local list, latest, at = {}, nil, nil
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            list[#list + 1] = m
            if not latest or (m.t or 0) >= (latest.t or 0) then latest, at = m, mark end
        end
    end
    if not latest then return nil end
    table.sort(list, function(a, b) return (a.t or 0) < (b.t or 0) end)
    local points = {}
    for i, mark in ipairs(marks) do points[i] = mark.at end
    return { list = list, mark = at.at, marks = points, x = at.x, y = at.y }
end

-- The mark its leader goes to: of the fires on the plate, the one nearest
-- the slip as laid (the fires are equals, as a person's marks are).
function CampfireSlip.Mark(chosen, slip)
    local best, gap
    for _, at in ipairs(chosen.marks or {}) do
        local sx, sy = slip:Nearest(at[1], at[2])
        local d = (sx - at[1]) ^ 2 + (sy - at[2]) ^ 2
        if not best or d < gap then best, gap = at, d end
    end
    return best or chosen.mark
end

-- A slip on `parent`. slip:SetCampfire(chosen, seed, now), then
-- slip:Layout(x, y, width) as a strip's; `overfull` where its line is wider
-- than `width` (it does not wrap or shrink, so the page leaves it off).
function CampfireSlip.New(parent)
    local slip = ns.UI.PaperStrip(parent)
    slip.name:SetFont(SLIP.file, SLIP.size, "")

    function slip:SetCampfire(chosen, seed, now)
        local Text = ns.UI.JourneyText
        self.chosen = chosen
        local function Tip()
            local tip = {}
            for _, m in ipairs(chosen.list) do
                local title, lines = Text.CampfireTip(m.campfire or m, now)
                tip[#tip + 1] = { title }
                for _, line in ipairs(lines or {}) do tip[#tip + 1] = { line, 1, 1, 1, true } end
            end
            return tip
        end
        local rand = ns.UI.InkTrail.Random(Seed(seed .. ":tape"))
        local T = SLIP.tape
        self:SetNote({ name = Text.CAMPFIRE_SLIP, strong = true, seed = seed, turn = SLIP.turn, tip = Tip,
            tapeAt = { x = T.x, y = T.y, w = T.w, h = T.h, slant = T.slant[1] + (T.slant[2] - T.slant[1]) * rand() } })
    end

    -- The words as written (for the tests).
    function slip:Words() return self.name:GetText() end

    local Lay = slip.Layout
    function slip:Layout(x, y, width)
        local pad = ns.UI.PAPER_STRIP.STRIP.pad
        local text = self.name
        local natural = (text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth() or 0)
            + 2 + pad[1] + pad[3]
        self.overfull = natural > width
        return Lay(self, x, y, width)
    end

    return slip
end
