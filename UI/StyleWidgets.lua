-- The small pieces drawn on the pages (Style, from UI/StyleTokens.lua):
-- rules, links, index tabs, tags, writing lines, boxes to tick, number
-- fields, portraits, a dungeon's medallion and its boss marks.

local addonName, ns = ...

local Style = ns.Style
-- The cover's brass (UI/StyleBook.lua), for the medallions' rings.
local BRASS_LIGHT, BRASS_MID, BRASS_DARK = Style.BRASS_LIGHT, Style.BRASS_MID, Style.BRASS_DARK

--------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------

-- A thin ink rule that fades out at both ends.
function Style.Rule(parent, width)
    local rule = CreateFrame("Frame", nil, parent)
    rule:SetSize(width, 1)
    local INK = Style.INK
    for i, alpha in ipairs({ { 0, Style.HAIRLINE }, { Style.HAIRLINE, 0 } }) do
        local half = rule:CreateTexture(nil, "ARTWORK")
        half:SetSize(width / 2, 1)
        half:SetPoint(i == 1 and "LEFT" or "RIGHT")
        Style.Shade(half, "HORIZONTAL", INK[1], INK[2], INK[3], alpha[1], alpha[2])
    end
    return rule
end

-- Text that behaves like a link: underlined, darker on hover. For the
-- choices that used to be big red buttons (sort, filter, map, scope).
function Style.Link(parent, font, onClick)
    local link = CreateFrame("Button", nil, parent)
    link:SetHeight(18)

    link.label = Style.Text(link, font or Style.FONT.body)
    link.label:SetPoint("LEFT")

    link.line = link:CreateTexture(nil, "ARTWORK")
    link.line:SetHeight(1)
    link.line:SetPoint("TOPLEFT", link.label, "BOTTOMLEFT", 0, -1)
    link.line:SetPoint("TOPRIGHT", link.label, "BOTTOMRIGHT", 0, -1)
    link.line:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], Style.HAIRLINE)

    function link:SetText(text)
        self.label:SetText(text)
        self:SetWidth(math.max(self.label:GetStringWidth(), 8) + 2)
    end
    function link:GetText() return self.label:GetText() end

    -- Its own ink, for a link that should stand apart (Remove, in red).
    function link:SetColor(r, g, b)
        self.color = { r, g, b }
        self.label:SetTextColor(r, g, b)
        self.line:SetColorTexture(r, g, b, Style.HAIRLINE)
    end

    -- A link that is the current choice reads as plain text.
    function link:SetCurrent(current)
        self.current = current
        self.line:SetShown(not current)
        self.label:SetTextColor(unpack(current and Style.INK_STRONG or Style.INK))
    end

    link:SetScript("OnEnter", function(self)
        if self.current then return end
        self.label:SetTextColor(unpack(Style.INK_STRONG))
        self.line:SetColorTexture(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3], Style.HAIRLINE_HOT)
    end)
    link:SetScript("OnLeave", function(self)
        if self.current then return end
        local color = self.color or Style.INK
        self.label:SetTextColor(color[1], color[2], color[3])
        self.line:SetColorTexture(color[1], color[2], color[3], Style.HAIRLINE)
    end)
    link:SetScript("OnClick", onClick)

    return link
end

-- A row of a list grouped under headings (the People list, the days on
-- Recently nearby): a heading in small capitals with a rule after it, or an
-- item that lights up under the mouse and is shaded while selected.
-- `body(row)` builds the item's own parts and returns them, so a heading
-- can hide them. The caller sets OnClick.
function Style.GroupedRow(list, body)
    local row = CreateFrame("Button", nil, list)
    local INK = Style.INK

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(INK[1], INK[2], INK[3], Style.HOVER_ALPHA)

    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(unpack(Style.SELECTED))

    row.parts = body(row)

    row.header = Style.Text(row, Style.FONT.heading)
    row.header:SetPoint("BOTTOMLEFT", 2, 3)

    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    row.rule:SetPoint("LEFT", row.header, "RIGHT", 8, 0)
    row.rule:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.rule:SetColorTexture(INK[1], INK[2], INK[3], 0.25)

    -- Shows `item` as a heading (item.header) and returns true, or shows the
    -- item's parts and returns false, for the caller to fill them and mark
    -- the selection. A heading never lights up and is never selected.
    function row:SetHeading(item)
        local isHeader = item.header ~= nil
        self.header:SetShown(isHeader)
        self.rule:SetShown(isHeader)
        for _, part in ipairs(self.parts) do part:SetShown(not isHeader) end
        self.highlight:SetAlpha(isHeader and 0 or 1)
        if isHeader then
            self.header:SetText(item.header:upper())
            self.selected:Hide()
        end
        return isHeader
    end

    return row
end

-- The GameTooltip over `frame` while the mouse is on it, at `anchor`
-- (default ANCHOR_RIGHT). `lines` is the text, a list of lines, or a
-- function(frame) returning the list when the mouse arrives, or nil for no
-- tooltip this time. A line is the arguments SetText (the first line) and
-- AddLine (the rest) take: { text, r, g, b, ... }. `hover(frame, over)`,
-- if given, is the frame's own hover look, called before the tooltip shows
-- and before it hides. Sets OnEnter and OnLeave.
function Style.Tooltip(frame, lines, anchor, hover)
    frame:SetScript("OnEnter", function(self)
        if hover then hover(self, true) end
        local list = lines
        if type(list) == "function" then list = list(self) end
        if not list then return end
        if type(list) == "string" then list = { { list } } end
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(unpack(list[1]))
        for i = 2, #list do GameTooltip:AddLine(unpack(list[i])) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        if hover then hover(self, false) end
        GameTooltip:Hide()
    end)
end

-- Radio choices in a context menu (MenuUtil), one per `choices` entry,
-- each { label, key }: on where `get()` equals its key, and picking one
-- calls `set(key)`. A nil key is the "any" choice. Into `menu`, the root
-- or a submenu being built.
function Style.Choices(menu, choices, get, set)
    for _, choice in ipairs(choices) do
        menu:CreateRadio(choice.label, function() return get() == choice.key end,
            function() set(choice.key) end)
    end
end

-- A context menu of nothing but those choices, under `title` if given.
function Style.ChoiceMenu(owner, title, choices, get, set)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if title then root:CreateTitle(title) end
        Style.Choices(root, choices, get, set)
    end)
end

-- An index tab sticking out of the book's right edge: a paper tab with a
-- small picture on it. The open one is lighter and stands out further.
local TAB_OUT, TAB_IN = 40, 32

function Style.SideTab(parent, artKey, tip, onClick)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(TAB_IN, 36)
    local P, INK = Style.PAPER, Style.INK_STRONG

    -- Ink edge on the three sides that stick out, paper inside.
    local edge = tab:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(INK[1], INK[2], INK[3], 0.85)

    tab.paper = tab:CreateTexture(nil, "BACKGROUND", nil, 1)
    tab.paper:SetPoint("TOPLEFT", 0, -1)
    tab.paper:SetPoint("BOTTOMRIGHT", -1, 1)

    -- The fold where it comes out of the pages.
    local fold = tab:CreateTexture(nil, "BACKGROUND", nil, 2)
    fold:SetPoint("TOPLEFT", 0, -1)
    fold:SetPoint("BOTTOMLEFT", 0, 1)
    fold:SetWidth(8)
    Style.Shade(fold, "HORIZONTAL", INK[1], INK[2], INK[3], 0.35, 0)

    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(22, 22)
    tab.icon:SetPoint("RIGHT", -6, 0)
    Style.SetTexture(tab.icon, artKey, 0.3, 0.22, 0.12, 1)
    tab.icon:SetTexCoord(unpack(Style.ICON_CROP))

    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(tab.paper)
    hover:SetColorTexture(1, 0.95, 0.8, 0.18)

    function tab:SetSelected(selected)
        self.selected = selected
        local shade = selected and 1 or 0.80
        self.paper:SetColorTexture(P[1] * shade, P[2] * shade, P[3] * shade, 1)
        self:SetWidth(selected and TAB_OUT or TAB_IN)
        self.icon:SetDesaturated(not selected)
        self.icon:SetAlpha(selected and 1 or 0.7)
    end
    tab:SetSelected(false)

    Style.Tooltip(tab, tip)
    tab:SetScript("OnClick", onClick)
    return tab
end

-- A tag you can click: filled in its colour when on, an ink outline on
-- the paper when off. A removable (custom) tag carries a small cross, which
-- is its own button.
function Style.TagButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(18)

    button.edge = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    button.edge:SetAllPoints()
    button.fill = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    button.fill:SetPoint("TOPLEFT", 1, -1)
    button.fill:SetPoint("BOTTOMRIGHT", -1, 1)

    button.label = Style.Text(button, Style.FONT.tag)
    button.label:SetPoint("LEFT", 7, 0)

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.95, 0.8, 0.12)

    button.cross = CreateFrame("Button", nil, button)
    button.cross:SetSize(14, 18)
    button.cross:SetPoint("RIGHT", -2, 0)
    local cross = Style.Text(button.cross, Style.FONT.tag)
    cross:SetPoint("CENTER")
    cross:SetText("\195\151")  -- the multiplication sign, U+00D7
    cross:SetAlpha(0.75)
    button.cross:SetScript("OnEnter", function() cross:SetAlpha(1) end)
    button.cross:SetScript("OnLeave", function() cross:SetAlpha(0.75) end)

    function button:SetTag(tag, on, removable)
        self.tag, self.on = tag, on
        local color = Style.TAG_COLORS[tag] or Style.TAG_DEFAULT
        local INK, P = Style.INK, Style.PAPER
        if on then
            self.edge:SetColorTexture(0, 0, 0, 0.35)
            self.fill:SetColorTexture(color[1], color[2], color[3], 1)
            self.label:SetTextColor(unpack(Style.TAG_TEXT))
        else
            self.edge:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)
            self.fill:SetColorTexture(P[1], P[2], P[3], 1)
            self.label:SetTextColor(unpack(Style.INK_FADED))
        end
        self.label:SetText(tag)
        self.cross:SetShown(removable == true)
        self:SetWidth(self.label:GetStringWidth() + 14 + (removable and 12 or 0))
    end

    return button
end

-- Faded text in an empty box, saying what goes there: `box.hint`, for the
-- caller to place. box:UpdateHint() shows it while the box is empty, and
-- with `hideOnFocus` not while it has the cursor either.
function Style.Placeholder(box, text, hideOnFocus)
    box.hint = Style.Text(box, Style.FONT.faded)
    box.hint:SetText(text or "")
    function box:UpdateHint()
        self.hint:SetShown((self:GetText() or "") == "" and not (hideOnFocus and self:HasFocus()))
    end
    return box.hint
end

-- A search field drawn on the page rather than the dark InputBox template.
-- `onChange(text)` on every keystroke, the text never nil. Returns the
-- EditBox; its `hint` is the placeholder text.
function Style.PageSearch(parent, x, y, width, hint, onChange)
    local INK, FONT = Style.INK, Style.FONT
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 24)
    holder:SetPoint("TOPLEFT", x, y)

    local fill = holder:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(INK[1], INK[2], INK[3], 0.10)

    Style.Hairline(holder, "BORDER", nil, { Style.HAIRLINE, 0.20, 0.30, 0.30 })

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 6, 0)
    if Style.SetTexture(icon, "search") then
        icon:SetVertexColor(INK[1], INK[2], INK[3], 0.8)
    else
        icon:Hide()
    end

    local box = CreateFrame("EditBox", nil, holder)
    -- The whole field, for a caller that places it itself (a loose sheet).
    box.holder = holder
    box:SetPoint("TOPLEFT", 26, 0)
    box:SetPoint("BOTTOMRIGHT", -6, 0)
    box:SetFontObject(FONT.strong)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Unlike a writing line's, this hint stays while the box has the
    -- cursor, until the first letter.
    Style.Placeholder(box, hint):SetPoint("LEFT", 0, 0)

    box:SetScript("OnTextChanged", function(self)
        self:UpdateHint()
        if onChange then onChange(self:GetText() or "") end
    end)

    return box
end

-- A single line to write on: an EditBox in ink over an ink underline, with
-- a faded hint while empty. `onCommit(text)` on Enter and on losing focus.
function Style.WritingLine(parent, width, font, hint, onCommit)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 20)
    box:SetFontObject(font or Style.FONT.strong)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)

    box.line = box:CreateTexture(nil, "BORDER")
    box.line:SetHeight(1)
    box.line:SetPoint("BOTTOMLEFT", 0, -1)
    box.line:SetPoint("BOTTOMRIGHT", 0, -1)
    box.line:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], Style.HAIRLINE)

    Style.Placeholder(box, hint, true):SetPoint("LEFT", 0, 0)

    box:SetScript("OnTextChanged", box.UpdateHint)
    box:SetScript("OnEditFocusGained", function(self)
        self:UpdateHint()
        self.line:SetColorTexture(Style.INK_STRONG[1], Style.INK_STRONG[2], Style.INK_STRONG[3], Style.HAIRLINE_HOT)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:UpdateHint()
        self.line:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], Style.HAIRLINE)
        if onCommit then onCommit(self:GetText()) end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Text set from code: refresh the hint without committing anything.
    function box:SetValue(text)
        self:SetText(text or "")
        self:UpdateHint()
    end

    return box
end

-- A box to tick, drawn in ink: a hairline square, and a tick written into
-- it in two strokes. Only the picture: Style.Checkbox, and the rows that
-- toggle around one, do the clicking.
local TICK_BOX = 13
local HINT_GAP = 2   -- between a switch's label and its hint

-- Each stroke is a thin bar turned about its centre: { x, y from the box's
-- centre (y up), length, angle anticlockwise }. Short down to the corner,
-- long up to the right, a pixel longer each so they meet without a notch.
local TICK_STROKES = { { -2.9, -1.5, 5.8, -math.pi / 4 }, { 2.2, 1.1, 12, 0.90 } }

function Style.Tick(parent)
    local tick = CreateFrame("Frame", nil, parent)
    tick:SetSize(TICK_BOX, TICK_BOX)
    local INK, STRONG = Style.INK, Style.INK_STRONG

    local fill = tick:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(INK[1], INK[2], INK[3], 0.06)

    local edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = tick:CreateTexture(nil, "BORDER")
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[i] = edge
    end

    local strokes = {}
    for i, s in ipairs(TICK_STROKES) do
        local stroke = tick:CreateTexture(nil, "ARTWORK")
        stroke:SetSize(s[3], 2)
        stroke:SetPoint("CENTER", s[1], s[2])
        stroke:SetColorTexture(STRONG[1], STRONG[2], STRONG[3], 0.92)
        stroke:SetRotation(s[4])
        strokes[i] = stroke
    end

    function tick:SetChecked(checked)
        for _, stroke in ipairs(strokes) do stroke:SetShown(checked) end
    end

    -- Darker while the mouse is on what it belongs to.
    function tick:SetHot(hot)
        local c = hot and STRONG or INK
        for _, edge in ipairs(edges) do
            edge:SetColorTexture(c[1], c[2], c[3], hot and Style.HAIRLINE_HOT or Style.HAIRLINE + 0.2)
        end
    end

    tick:SetChecked(false)
    tick:SetHot(false)
    return tick
end

-- A setting to switch: the inked box and its label beside it, wrapping
-- inside `width`, and `hint`, if any, in small print close under the label,
-- on its left edge and as wide. Reads `get()` on Refresh and writes the
-- other value through `set` when clicked anywhere. Answers GetChecked and
-- SetChecked like the client's CheckButton; `height` is what it takes on
-- the page.
--
-- Without `set` it is a status, written in by the addon, not a switch: the
-- same box and tick at full ink, but deaf to the mouse, so it never darkens
-- under it and a click goes nowhere.
function Style.Checkbox(parent, width, text, get, set, hint)
    local button = CreateFrame("Button", nil, parent)
    local FONT = Style.FONT
    local labelW = width - TICK_BOX - 7

    button.tick = Style.Tick(button)
    button.tick:SetPoint("TOPLEFT", 0, -2)

    button.label = Style.Text(button, FONT.body)
    button.label:SetPoint("TOPLEFT", TICK_BOX + 7, 0)
    button.label:SetWidth(labelW)
    button.label:SetText(text)

    button.height = math.max(TICK_BOX + 4, button.label:GetStringHeight())
    if hint then
        button.hint = Style.Text(button, FONT.small)
        button.hint:SetPoint("TOPLEFT", button.label, "BOTTOMLEFT", 0, -HINT_GAP)
        button.hint:SetWidth(labelW)
        button.hint:SetText(hint)
        button.height = math.max(TICK_BOX + 4,
            button.label:GetStringHeight() + HINT_GAP + button.hint:GetStringHeight())
    end
    button:SetSize(width, button.height)

    function button:SetChecked(checked)
        self.checked = checked and true or false
        self.tick:SetChecked(self.checked)
    end
    function button:GetChecked() return self.checked == true end
    function button:Refresh() self:SetChecked(get()) end

    -- Faded and deaf while what it depends on is off.
    function button:SetAvailable(available)
        self.unavailable = not available
        self:SetAlpha(available and 1 or 0.45)
    end

    button:SetChecked(false)
    if not set then
        button.readOnly = true
        button:EnableMouse(false)
        return button
    end

    local function Hover(self, over)
        over = over and not self.unavailable
        self.label:SetFontObject(over and FONT.strong or FONT.body)
        self.tick:SetHot(over)
    end
    button:SetScript("OnEnter", function(self) Hover(self, true) end)
    button:SetScript("OnLeave", function(self) Hover(self, false) end)
    button:SetScript("OnClick", function(self)
        if self.unavailable then return end
        self:SetChecked(not self.checked)
        set(self.checked)
    end)

    return button
end

-- A whole number written on a short line, centred, clamped to [min, max]
-- on Enter and on losing focus. A box left empty or unreadable goes back to
-- `get()`. Refresh shows the current value.
function Style.NumberField(parent, width, min, max, get, set)
    local INK, STRONG = Style.INK, Style.INK_STRONG
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 18)
    box:SetFontObject(Style.FONT.strong)
    box:SetJustifyH("CENTER")
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)

    box.line = box:CreateTexture(nil, "BORDER")
    box.line:SetHeight(1)
    box.line:SetPoint("BOTTOMLEFT", 0, -1)
    box.line:SetPoint("BOTTOMRIGHT", 0, -1)
    box.line:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)

    function box:Refresh() self:SetText(tostring(get())) end

    -- Enter commits and lets go, and letting go commits again: only a
    -- changed number reaches `set`.
    local function Commit(self)
        local n = tonumber(self:GetText())
        if n then
            n = math.max(min, math.min(max, math.floor(n)))
            if n ~= get() then set(n) end
        end
        self:Refresh()
    end

    box:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:Refresh()
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        self.line:SetColorTexture(STRONG[1], STRONG[2], STRONG[3], Style.HAIRLINE_HOT)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self.line:SetColorTexture(INK[1], INK[2], INK[3], Style.HAIRLINE)
        Commit(self)
    end)

    return box
end

-- A tag as a small inked label: colour plus its text.
function Style.TagChip(parent)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetHeight(18)

    local edge = chip:CreateTexture(nil, "BACKGROUND", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0, 0.35)

    chip.fill = chip:CreateTexture(nil, "BACKGROUND", nil, 1)
    chip.fill:SetPoint("TOPLEFT", 1, -1)
    chip.fill:SetPoint("BOTTOMRIGHT", -1, 1)

    chip.label = Style.Text(chip, Style.FONT.tag)
    chip.label:SetPoint("LEFT", 7, 0)

    function chip:SetTag(tag)
        local color = Style.TAG_COLORS[tag] or Style.TAG_DEFAULT
        self.fill:SetColorTexture(color[1], color[2], color[3], 1)
        self.label:SetText(tag)
        self:SetWidth(self.label:GetStringWidth() + 14)
    end

    return chip
end

local PORTRAIT_ZOOM = 1.4

-- Discs inside each other, outermost first, each { inset, { r, g, b } }, and
-- an icon in the last, cropped round by a mask. The icon is drawn `zoom`
-- times that disc, so art with its own border and padding overhangs and
-- loses them; without a mask it cannot overhang.
local function RoundFrame(frame, size, rings, zoom)
    local circle = Style.Art("circle")
    for i, ring in ipairs(rings) do
        local inset, color = ring[1], ring[2]
        local disc = frame:CreateTexture(nil, "BACKGROUND", nil, i - 1)
        disc:SetPoint("TOPLEFT", inset, -inset)
        disc:SetPoint("BOTTOMRIGHT", -inset, inset)
        Style.Disc(disc, color[1], color[2], color[3], 1)
    end

    local pad = rings[#rings][1] + 1
    local inner = size - 2 * pad
    local icon = frame:CreateTexture(nil, "ARTWORK")
    if circle and frame.CreateMaskTexture then
        local overhang = (inner * zoom - inner) / 2
        icon:SetPoint("TOPLEFT", pad - overhang, -pad + overhang)
        icon:SetPoint("BOTTOMRIGHT", -pad + overhang, pad - overhang)

        local mask = frame:CreateMaskTexture()
        mask:SetTexture(circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetPoint("TOPLEFT", pad, -pad)
        mask:SetPoint("BOTTOMRIGHT", -pad, pad)
        icon:AddMaskTexture(mask)
    else
        icon:SetPoint("TOPLEFT", pad, -pad)
        icon:SetPoint("BOTTOMRIGHT", -pad, pad)
    end
    return icon
end

-- A round, gold-trimmed portrait: the person's race icon, else class icon.
-- The race icons carry their own rounded frame and padding, hence the zoom.
function Style.Portrait(parent, size)
    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetSize(size, size)
    portrait.icon = RoundFrame(portrait, size, {
        { 0, { 0, 0, 0 } }, { 2, { 0.72, 0.58, 0.33 } }, { 4, { 0, 0, 0 } }, { 5, { 0.22, 0.15, 0.08 } },
    }, PORTRAIT_ZOOM)

    function portrait:SetCharacter(record)
        if Style.SetRaceIcon(self.icon, record) then return end
        if Style.SetClassIcon(self.icon, record and record.class) then return end
        Style.SetTexture(self.icon, "book", 0.3, 0.22, 0.12, 1)
        self.icon:SetTexCoord(unpack(Style.ICON_CROP))
    end

    return portrait
end

-- A person's heading, on their page in the journal and on the loose sheet:
-- the round portrait, their name in capitals beside it, and the "who" line
-- under the name. HEADING is its measure: the portrait, how far in the name
-- and who line start, the name line's height and the gap under it.
local HEADING_PORTRAIT = 56
Style.HEADING = { portrait = HEADING_PORTRAIT, indent = HEADING_PORTRAIT + 12, name = 28, gap = 4 }

-- Builds it on `parent`, `width` wide, keeping `right` free at the end of
-- the name line (for Edit, or the close button). The pieces go on `owner`
-- as owner.portrait, owner.name and owner.who: the sheet keeps them on its
-- panel, above the content frame they sit in.
function Style.PersonHeading(owner, parent, width, right)
    local H = Style.HEADING
    owner.portrait = Style.Portrait(parent, H.portrait)
    owner.portrait:SetPoint("TOPLEFT", -4, 4)

    owner.name = Style.Text(parent, Style.FONT.title)
    owner.name:SetPoint("TOPLEFT", H.indent, 0)
    owner.name:SetPoint("RIGHT", parent, "RIGHT", -right, 0)
    owner.name:SetHeight(H.name)
    owner.name:SetWordWrap(false)
    owner.nameRoom = width - right - H.indent

    owner.who = Style.Text(parent, Style.FONT.body)
    owner.who:SetPoint("TOPLEFT", owner.name, "BOTTOMLEFT", 0, -H.gap)
    owner.who:SetPoint("RIGHT", parent, "RIGHT")
    owner.who:SetWordWrap(false)
end

-- Fills the heading Style.PersonHeading put on `owner`. The name is set in
-- Morpheus capitals: its lowercase is hard to read ("Eatmorchikin"). A long
-- name steps down a size rather than lose its end.
function Style.SetPersonHeading(owner, record, name, who)
    owner.portrait:SetCharacter(record)
    owner.name:SetFontObject(Style.FONT.title)
    owner.name:SetText(name:upper())
    if owner.name:GetUnboundedStringWidth() > owner.nameRoom then
        owner.name:SetFontObject(Style.FONT.titleSmall)
    end
    owner.who:SetText(who)
end

-- A dungeon run's medallion: the instance's own picture in a brass ring (gilt
-- for a raid), standing a little proud of the page, so it casts a small
-- shadow down and to the right. Without the picture, the name's initial as
-- a drop cap in red.
local MEDALLION_RINGS = {
    party = { { 0, BRASS_DARK }, { 1, BRASS_MID }, { 3, BRASS_DARK } },
    raid = { { 0, BRASS_DARK }, { 1, { 0.86, 0.68, 0.36 } }, { 2, BRASS_LIGHT }, { 3, BRASS_DARK } },
}

function Style.Medallion(parent, size)
    local medallion = CreateFrame("Frame", nil, parent)
    medallion:SetSize(size, size)

    local circle = Style.Art("circle")
    local shadow = medallion:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetSize(size, size)
    shadow:SetPoint("CENTER", 1.5, -1.5)
    if circle then
        Style.Disc(shadow, Style.INK[1], Style.INK[2], Style.INK[3], 0.35)
    else
        shadow:Hide()
    end

    local faces = {}
    for kind, rings in pairs(MEDALLION_RINGS) do
        local face = CreateFrame("Frame", nil, medallion)
        face:SetAllPoints()
        face.icon = RoundFrame(face, size, rings, 1)
        face:Hide()
        faces[kind] = face
    end

    medallion.initial = Style.Text(medallion, Style.FONT.title)
    medallion.initial:SetPoint("CENTER", 0, -1)
    medallion.initial:SetJustifyH("CENTER")
    medallion.initial:SetTextColor(Style.RUBRIC[1], Style.RUBRIC[2], Style.RUBRIC[3])

    function medallion:SetVisit(visit)
        local kind = visit.instanceType == "raid" and "raid" or "party"
        for k, face in pairs(faces) do face:SetShown(k == kind) end
        local icon, path = faces[kind].icon, Style.InstanceArt(visit)
        if path then
            icon:SetTexture(path)
            icon:SetTexCoord(0, 1, 0, 1)
            self.initial:Hide()
        else
            icon:SetColorTexture(Style.PAPER[1] * 0.92, Style.PAPER[2] * 0.92, Style.PAPER[3] * 0.92, 1)
            local name = (visit.name or "?"):gsub("^The ", "")
            self.initial:SetText(name:sub(1, 1):upper())
            self.initial:Show()
        end
    end

    return medallion
end

-- Bosses as marks: a small turned square each, filled in red for a kill and
-- left as an outline for the rest. At most `max`; the tooltip counts past
-- that. Returns how wide the marks came out.
local PIP, PIP_STEP = 7, 11

function Style.Pips(parent, max)
    local pips = CreateFrame("Frame", nil, parent)
    pips:SetHeight(PIP + 4)
    local marks = {}
    for i = 1, max do
        local outer = pips:CreateTexture(nil, "ARTWORK", nil, 0)
        outer:SetSize(PIP, PIP)
        outer:SetPoint("CENTER", pips, "LEFT", PIP / 2 + 1 + (i - 1) * PIP_STEP, 0)
        outer:SetRotation(math.pi / 4)
        local inner = pips:CreateTexture(nil, "ARTWORK", nil, 1)
        inner:SetSize(PIP - 3, PIP - 3)
        inner:SetPoint("CENTER", outer)
        inner:SetRotation(math.pi / 4)
        inner:SetColorTexture(Style.PAPER[1], Style.PAPER[2], Style.PAPER[3], 1)
        marks[i] = { outer = outer, inner = inner }
    end

    function pips:Set(killed, total)
        local n = math.min(math.max(total or 0, killed), max)
        for i, mark in ipairs(marks) do
            local shown, kill = i <= n, i <= killed
            mark.outer:SetShown(shown)
            mark.inner:SetShown(shown and not kill)
            if kill then
                mark.outer:SetColorTexture(Style.RUBRIC[1], Style.RUBRIC[2], Style.RUBRIC[3], 1)
            else
                mark.outer:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], 0.55)
            end
        end
        local width = n > 0 and (n - 1) * PIP_STEP + PIP + 2 or 0
        self:SetWidth(math.max(width, 1))
        return width
    end

    return pips
end

-- A heading rubricated like a day on the timeline: a paraph (lapis or red),
-- the words in red capitals, and a red rule out to `width`, fading as it
-- goes. For the onboarding pages' sections (UI/JournalFront.lua,
-- UI/JournalEmpty.lua). :SetText(text, lapis) sets the words and the
-- paraph's colour.
local RUBRIC = { height = 16, paraph = 6, indent = 13, gap = 6, ruleAlpha = 0.40 }

function Style.Rubric(parent, width)
    local heading = CreateFrame("Frame", nil, parent)
    heading:SetSize(width, RUBRIC.height)

    heading.text = Style.Text(heading, Style.FONT.headingRubric)
    heading.text:SetPoint("LEFT", RUBRIC.indent, 0)

    heading.paraph = heading:CreateTexture(nil, "ARTWORK")
    heading.paraph:SetSize(RUBRIC.paraph, RUBRIC.paraph)
    heading.paraph:SetRotation(math.pi / 4)
    heading.paraph:SetPoint("CENTER", heading.text, "LEFT", -RUBRIC.indent / 2 - 1, 0)

    local rule = heading:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", heading.text, "RIGHT", RUBRIC.gap, 0)
    rule:SetPoint("RIGHT", heading, "RIGHT")
    local R = Style.RUBRIC
    Style.Shade(rule, "HORIZONTAL", R[1], R[2], R[3], RUBRIC.ruleAlpha, 0)

    function heading:SetText(text, lapis)
        self.text:SetText(text:upper())
        local colour = lapis and Style.LAPIS or Style.RUBRIC
        self.paraph:SetColorTexture(colour[1], colour[2], colour[3], 1)
    end

    return heading
end

-- A straight stroke of ink or pencil on `parent`, from x1, y1 to x2, y2 (x
-- right and y down from its top left), `thickness` wide: a texture turned
-- along it. Where textures cannot turn, nothing is drawn: a stroke is
-- ornament (a margin note's leader, an arrow), never the only signal.
-- `sublevel` orders it within its layer.
function Style.Stroke(parent, layer, x1, y1, x2, y2, colour, alpha, thickness, sublevel)
    local stroke = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
    if not stroke.SetRotation then
        stroke:Hide()
        return stroke
    end
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    stroke:SetSize(length + 0.5, thickness or 1)
    stroke:SetPoint("CENTER", parent, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    stroke:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
    -- Turned on the screen, where y runs up.
    stroke:SetRotation(math.atan2(-dy, dx))
    if stroke.SetSnapToPixelGrid then
        stroke:SetSnapToPixelGrid(false)
        stroke:SetTexelSnappingBias(0)
    end
    return stroke
end

-- A curve drawn as short strokes: the quadratic from x1, y1 to x2, y2 that
-- bends toward the control point cx, cy, in `steps` pieces.
function Style.Curve(parent, layer, x1, y1, cx, cy, x2, y2, colour, alpha, thickness, steps)
    steps = steps or 10
    local strokes = {}
    local px, py = x1, y1
    for i = 1, steps do
        local t = i / steps
        local u = 1 - t
        local x = u * u * x1 + 2 * u * t * cx + t * t * x2
        local y = u * u * y1 + 2 * u * t * cy + t * t * y2
        strokes[i] = Style.Stroke(parent, layer, px, py, x, y, colour, alpha, thickness)
        px, py = x, y
    end
    return strokes
end

-- A pencilled arrow on `parent` (x right, y down from its top left): a
-- curve from `from` bending toward `bend`, ending in a head at `to`, two
-- strokes `head` long back from the point, either side of the way it came
-- in. For the onboarding pages' pointers down to the ribbons.
function Style.Arrow(parent, layer, from, bend, to, alpha, head)
    local G = Style.GRAPHITE
    Style.Curve(parent, layer, from[1], from[2], bend[1], bend[2], to[1], to[2], G, alpha, 1.2, 9)
    local back = math.atan2(bend[2] - to[2], bend[1] - to[1])
    for _, side in ipairs({ -0.5, 0.5 }) do
        local t = back + side
        Style.Stroke(parent, layer, to[1], to[2], to[1] + head * math.cos(t), to[2] + head * math.sin(t),
            G, alpha, 1.2)
    end
end

-- A lozenge: a square of flat colour turned on its point, `size` across.
function Style.Lozenge(parent, layer, size, colour, sublevel)
    local l = parent:CreateTexture(nil, layer, nil, sublevel)
    l:SetSize(size, size)
    l:SetRotation(math.pi / 4)
    l:SetColorTexture(colour[1], colour[2], colour[3], 1)
    return l
end

-- A ring drawn by hand round a centre (x, y on `parent`, y down): an
-- ellipse in rubric red that does not quite close, a little uneven. R is
-- its measure: w, h, how far it overshoots where it began, how unevenly it
-- was drawn, its ink's alpha and its strokes, and `colour` for any ink but
-- rubric. Round "Remember this" on the empty
-- People page (UI/JournalEmpty.lua) and on the frontispiece's figure.
function Style.HandRing(parent, layer, x, y, R)
    local a0 = math.rad(200)
    local sweep = 2 * math.pi * (1 + R.overshoot)
    local px, py
    for i = 0, R.steps do
        local t = a0 + sweep * i / R.steps
        local grow = 1 + R.wobble * math.sin(3 * t) + R.wobble * i / R.steps
        local qx, qy = x + R.w / 2 * grow * math.cos(t), y + R.h / 2 * grow * math.sin(t)
        if px then Style.Stroke(parent, layer, px, py, qx, qy, R.colour or Style.RUBRIC, R.alpha, 1.3) end
        px, py = qx, qy
    end
end

-- A plate pasted onto the page, `w` by `h` at x, y (y down): a sheet of
-- paper a shade lighter than the page, with its grain; its shadow, down and
-- to the right; the glue soaked through at its corners, unevenly; and an
-- engraved frame, a hairline per pixel of each rule, with a lozenge in each
-- corner over it, red and lapis by turns. The bookplate (UI/JournalFront.lua)
-- and the frontispiece's figure (UI/JournalFrontispiece.lua). P is its look:
-- paper, grain, rules ({ inset, width, alpha }), lozenge, lozengeInset,
-- glue ({ size, alpha }), shadows ({ drop, alpha }).
function Style.PastedPlate(parent, x, y, w, h, P)
    local INK = Style.INK
    local plate = CreateFrame("Frame", nil, parent)
    plate:SetSize(w, h)
    plate:SetPoint("TOPLEFT", x, -y)

    for i, shadow in ipairs(P.shadows) do
        local s = plate:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
        s:SetPoint("TOPLEFT", shadow.drop, -shadow.drop)
        s:SetPoint("BOTTOMRIGHT", shadow.drop, -shadow.drop)
        s:SetColorTexture(INK[1], INK[2], INK[3], shadow.alpha)
    end
    local paper = plate:CreateTexture(nil, "BACKGROUND", nil, -4)
    paper:SetAllPoints()
    paper:SetColorTexture(P.paper[1], P.paper[2], P.paper[3], 1)
    local grainPath = Style.Art("grain")
    if grainPath then
        local grain = plate:CreateTexture(nil, "BACKGROUND", nil, -3)
        grain:SetAllPoints()
        grain:SetTexture(grainPath)
        grain:SetTexCoord(0.31, 0.58, 0.12, 0.47)
        grain:SetAlpha(P.grain)
    end

    local glue = { 1, 0.7, 0.85, 1.25 }
    for i, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local g = plate:CreateTexture(nil, "BACKGROUND", nil, -2)
        g:SetSize(P.glue.size, P.glue.size)
        g:SetPoint("CENTER", plate, corner)
        Style.Disc(g, INK[1], INK[2], INK[3], P.glue.alpha * glue[i])
    end

    -- The frames only give each hairline its place; the lines are drawn on
    -- the plate itself, so the lozenges lie over them.
    for _, rule in ipairs(P.rules) do
        for step = 0, rule.width - 1 do
            local inset = rule.inset + step
            local place = CreateFrame("Frame", nil, plate)
            place:SetPoint("TOPLEFT", inset, -inset)
            place:SetPoint("BOTTOMRIGHT", -inset, inset)
            Style.Hairline(plate, "BORDER", 0, rule.alpha, place)
        end
    end
    for i, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMLEFT" }) do
        local l = Style.Lozenge(plate, "ARTWORK", P.lozenge, i % 2 == 1 and Style.RUBRIC or Style.LAPIS)
        local dx = corner:find("LEFT") and P.lozengeInset or -P.lozengeInset
        local dy = corner:find("TOP") and -P.lozengeInset or P.lozengeInset
        l:SetPoint("CENTER", plate, corner, dx, dy)
    end
    return plate
end

-- A texture on `parent` over any four points (x right, y down from its top
-- left), in the order upper left, upper right, lower right, lower left: a
-- square with its corners moved onto them (SetVertexOffset). A triangle
-- gives one point twice. Where the client cannot move corners it covers
-- the points' box instead, and this returns false, for the caller to hide
-- it or draw something plainer.
local VERTEX = Enum and Enum.VertexIndex or {}
local UL, LL, UR, LR = VERTEX.UpperLeft or 1, VERTEX.LowerLeft or 2, VERTEX.UpperRight or 3, VERTEX.LowerRight or 4

function Style.Quad(texture, parent, x1, y1, x2, y2, x3, y3, x4, y4)
    local left, top = math.min(x1, x2, x3, x4), math.min(y1, y2, y3, y4)
    local w = math.max(math.max(x1, x2, x3, x4) - left, 1)
    local h = math.max(math.max(y1, y2, y3, y4) - top, 1)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)
    texture:SetSize(w, h)
    if texture.SetRotation then texture:SetRotation(0) end
    if not texture.SetVertexOffset then return false end
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
    -- Offsets from where each corner of the box would be, y up.
    texture:SetVertexOffset(UL, x1 - left, top - y1)
    texture:SetVertexOffset(UR, x2 - (left + w), top - y2)
    texture:SetVertexOffset(LR, x3 - (left + w), top + h - y3)
    texture:SetVertexOffset(LL, x4 - left, top + h - y4)
    return true
end

-- A torn edge of paper on `parent` (x right, y down from its top left): the
-- line from x1, y1 to x2, y2 as `teeth` small triangles of `colour`
-- sticking out to the left of its direction, which is outward when a sheet
-- is gone round clockwise. Each stands up to `depth` px, every other one
-- lower, uneven by `seed`, so the same edge tears the same way every time.
-- Drawn in `layer` and `sublevel`. Returns the edge, its teeth in order;
-- edge:Lay(flat) lays them, evenly when `flat` ("Flat paper only"). Where
-- the client cannot move corners there are no teeth: the paper stays a
-- plain edge.
function Style.TornEdge(parent, layer, sublevel, x1, y1, x2, y2, teeth, depth, seed, colour)
    local Noise = Style.Noise
    local edge = {}
    for i = 1, teeth do
        local tooth = parent:CreateTexture(nil, layer, nil, sublevel)
        tooth:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1)
        edge[i] = tooth
    end
    local dx, dy = x2 - x1, y2 - y1
    local length = math.max(math.sqrt(dx * dx + dy * dy), 1)
    local nx, ny = dy / length, -dx / length
    function edge:Lay(flat)
        for i, tooth in ipairs(self) do
            local a, b = (i - 1) / teeth, i / teeth
            -- Its point leans a little along the edge, and stands as high
            -- as it tore.
            local lean = flat and 0 or (Noise(seed + i * 3.1) - 0.5) * 0.7 / teeth
            local high = depth * (i % 2 == 1 and 1 or 0.45) * (flat and 0.7 or (0.3 + 0.7 * Noise(seed + i)))
            local m = (a + b) / 2 + lean
            tooth:SetShown(Style.Quad(tooth, parent,
                x1 + dx * a, y1 + dy * a,
                x1 + dx * m + nx * high, y1 + dy * m + ny * high,
                x1 + dx * b, y1 + dy * b,
                x1 + dx * b, y1 + dy * b))
        end
    end
    return edge
end
