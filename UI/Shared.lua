-- Shared frame construction.
--
-- Hand-rolled rather than templated, for the reason REU-3 gives about toasts:
-- the less of Blizzard's own machinery the addon reaches into, the less it can
-- taint. These are plain frames with plain textures; only the widely-used
-- widget templates (buttons, edit boxes, the close button) are borrowed.

local addonName, ns = ...

ns.UI = ns.UI or {}

-- The dialog border, over an opaque background. The stock dialog background
-- draws nearly see-through in this client, and text over the game world is
-- hard to read.
local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- A movable, escape-closable dialog with a heading and a close button.
--
-- `opts.bare`: no border, background or heading, for a window that draws
-- its own (the journal's cover, the loose sheet). Its close button sits
-- `opts.closeOutset` out past the top right corner, where there is no
-- border to sit inside.
function ns.UI.Panel(globalName, width, height, title, opts)
    local bare = opts and opts.bare
    local panel = CreateFrame("Frame", globalName, UIParent, not bare and "BackdropTemplate" or nil)
    panel:SetSize(width, height)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    if not bare then
        panel:SetBackdrop(BACKDROP)
        panel:SetBackdropColor(0.07, 0.06, 0.05, 0.97)
    end
    panel:Hide()

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    if bare then
        close:SetPoint("TOPRIGHT", opts.closeOutset or 0, opts.closeOutset or 0)
    else
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    panel.close = close

    if not bare then
        panel.heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        panel.heading:SetPoint("TOPLEFT", 18, -20)
        panel.heading:SetPoint("RIGHT", -34, 0)
        panel.heading:SetJustifyH("LEFT")
        panel.heading:SetText(title or "")
    end

    -- Escape closes it, the way every other WoW window behaves.
    if globalName then
        UISpecialFrames[#UISpecialFrames + 1] = globalName
    end

    return panel
end

function ns.UI.Label(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

function ns.UI.Button(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

--------------------------------------------------------------------------
-- The virtual list (JNL-6)
--------------------------------------------------------------------------
--
-- A fixed pool of row frames over an array of any length: scrolling moves an
-- offset and rewrites the visible rows, so 10,000 timeline items cost the
-- same frames as ten. Hand-rolled rather than Blizzard's ScrollBox for the
-- reason at the top of this file, and because this build's templates are
-- unverified where plain widgets are not.
--
-- `build(list, index)` makes one row; `update(row, item)` fills it.

local SCROLLBAR_WIDTH = 12
ns.UI.SCROLLBAR_WIDTH = SCROLLBAR_WIDTH  -- for column headings that line up with rows

-- The scrollbar, as something of the book's rather than the screen's: a
-- line pencilled down the page's margin, and riding on it a thumb index,
-- a small tab of leather like the ones cut into a ledger's fore-edge,
-- lit from the top left as everything in the book is.
--
-- `track`: the pencil line, `width` px, centred in the bar's
-- SCROLLBAR_WIDTH (which stays the bar's whole width, to take the mouse);
-- its pressure uneven down its length, alpha `top`, `middle`, `bottom`,
-- as a hand rules a line, fading at both ends over `fade` px.
-- `tab`: the leather, `w` x `h` px, centred on the line; its hold on the
-- mouse is the bar's whole width and `grab` px taller. Its colour is the
-- one SetBarColors gives, `lit` lighter at the top and `shade` darker at
-- the bottom; a `light` px edge catches the light on its top and left
-- (alpha `lightAlpha`), a dark edge falls on its bottom and right
-- (`darkAlpha`); `grooves` tooled lines pressed across it, `groove` px
-- apart, each a dark lip over a light one, the grip. Under the mouse its
-- lit edge brightens to `hotAlpha`. It casts a shadow on the page `cast`
-- px down and to the right at `castAlpha`.
-- Flat paper only (the flatSheets setting): a plain tab, no shading,
-- edges, grooves or shadow.
local SCROLLBAR = {
    track = { width = 1, top = 0.22, middle = 0.42, bottom = 0.30, fade = 10 },
    tab = { w = 9, h = 26, grab = 4, lit = 1.25, shade = 0.70, light = 1, lightAlpha = 0.35, darkAlpha = 0.45,
        grooves = 2, groove = 4, hotAlpha = 0.6, cast = 1.5, castAlpha = 0.22 },
}
ns.UI.SCROLLBAR = SCROLLBAR

-- A colour scaled toward black or white by `k`, as { r, g, b, a }.
local function Tone(c, k, a)
    local function One(x) return math.max(0, math.min(1, x * k)) end
    return { One(c[1]), One(c[2]), One(c[3]), a }
end

-- A gradient down a texture, `top` to `bottom`; the Style files' where
-- they have loaded (they load after this one), else a flat average.
local function Down(texture, top, bottom)
    if ns.Style and ns.Style.Gradient then
        ns.Style.Gradient(texture, "VERTICAL", bottom, top)
    else
        texture:SetColorTexture((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2,
            (top[4] + bottom[4]) / 2)
    end
end

-- The pencil line and the leather tab on `bar`, coloured by `pencil` and
-- `leather` ({ r, g, b, a }; only their colour is taken, SCROLLBAR holds
-- the rest). Returns the thumb texture (the tab's hold on the mouse), a
-- function to colour it, one to paint it again (flat or not), and its
-- parts (for the tests).
local function BookScrollbar(bar)
    local T, B = SCROLLBAR.track, SCROLLBAR.tab
    local pencil, leather = { 0.24, 0.16, 0.07 }, { 0.45, 0.31, 0.14 }

    local upper = bar:CreateTexture(nil, "BACKGROUND")
    upper:SetWidth(T.width)
    upper:SetPoint("TOP", bar, "TOP", 0, 0)
    upper:SetPoint("BOTTOM", bar, "CENTER", 0, 0)
    local lower = bar:CreateTexture(nil, "BACKGROUND")
    lower:SetWidth(T.width)
    lower:SetPoint("TOP", bar, "CENTER", 0, 0)
    lower:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    local capTop = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    capTop:SetSize(T.width, T.fade)
    capTop:SetPoint("TOP", bar, "TOP", 0, 0)
    local capBottom = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    capBottom:SetSize(T.width, T.fade)
    capBottom:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)

    -- The thumb the slider moves: clear, the bar's width, the tab on it.
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0, 0, 0, 0)
    thumb:SetSize(SCROLLBAR_WIDTH, B.h + B.grab)
    bar:SetThumbTexture(thumb)

    local cast = bar:CreateTexture(nil, "ARTWORK", nil, 0)
    cast:SetSize(B.w, B.h)
    cast:SetPoint("CENTER", thumb, "CENTER", B.cast, -B.cast)
    local body = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    body:SetSize(B.w, B.h)
    body:SetPoint("CENTER", thumb, "CENTER", 0, 0)
    local function Edge(sublevel, a, b, w, h)
        local t = bar:CreateTexture(nil, "ARTWORK", nil, sublevel)
        t:SetPoint(a, body, a)
        t:SetPoint(b, body, b)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        return t
    end
    local lightTop = Edge(3, "TOPLEFT", "TOPRIGHT", nil, B.light)
    local lightLeft = Edge(3, "TOPLEFT", "BOTTOMLEFT", B.light, nil)
    local darkBottom = Edge(2, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    local darkRight = Edge(2, "TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    local grooves = {}
    for i = 1, B.grooves do
        local y = (i - (B.grooves + 1) / 2) * B.groove
        local dark = bar:CreateTexture(nil, "ARTWORK", nil, 4)
        dark:SetSize(B.w - 4, 1)
        dark:SetPoint("CENTER", body, "CENTER", 0, y + 0.5)
        local light = bar:CreateTexture(nil, "ARTWORK", nil, 4)
        light:SetSize(B.w - 4, 1)
        light:SetPoint("CENTER", body, "CENTER", 0, y - 0.5)
        grooves[#grooves + 1] = { dark, light }
    end

    local hot = false
    local function Paint()
        local flat = ns.Setting and ns.Setting("flatSheets") == true
        local p = pencil
        Down(upper, { p[1], p[2], p[3], T.top }, { p[1], p[2], p[3], T.middle })
        Down(lower, { p[1], p[2], p[3], T.middle }, { p[1], p[2], p[3], T.bottom })
        -- The line fades in and out at its ends, over the page's colour.
        Down(capTop, { p[1], p[2], p[3], 0 }, { p[1], p[2], p[3], T.top })
        Down(capBottom, { p[1], p[2], p[3], T.bottom }, { p[1], p[2], p[3], 0 })
        upper:SetPoint("TOP", bar, "TOP", 0, -T.fade)
        lower:SetPoint("BOTTOM", bar, "BOTTOM", 0, T.fade)

        local l = leather
        if flat then
            body:SetColorTexture(l[1], l[2], l[3], 1)
        else
            Down(body, Tone(l, B.lit, 1), Tone(l, B.shade, 1))
        end
        local lit = hot and B.hotAlpha or B.lightAlpha
        for _, t in ipairs({ lightTop, lightLeft }) do
            t:SetColorTexture(1, 0.93, 0.78, lit)
            t:SetShown(not flat)
        end
        for _, t in ipairs({ darkBottom, darkRight }) do
            t:SetColorTexture(0.08, 0.05, 0.02, B.darkAlpha)
            t:SetShown(not flat)
        end
        for _, g in ipairs(grooves) do
            g[1]:SetColorTexture(0.08, 0.05, 0.02, B.darkAlpha)
            g[2]:SetColorTexture(1, 0.93, 0.78, B.lightAlpha * 0.7)
            g[1]:SetShown(not flat)
            g[2]:SetShown(not flat)
        end
        cast:SetColorTexture(0.08, 0.05, 0.02, B.castAlpha)
        cast:SetShown(not flat)
    end

    -- Under the mouse, the tab's lit edge brightens: it is there to take.
    bar:SetScript("OnEnter", function() hot = true Paint() end)
    bar:SetScript("OnLeave", function() hot = false Paint() end)
    bar:SetScript("OnShow", Paint)

    local function Colour(track, tab)
        if track then pencil = track end
        if tab then leather = tab end
        Paint()
    end
    Paint()
    return thumb, Colour, Paint, { body = body, cast = cast, line = upper, lit = lightTop, grooves = grooves }
end

--
-- `numRows` rows are built up front; SetNumRows shows fewer of them, for a
-- list whose space depends on what sits above it.

function ns.UI.VirtualList(parent, rowHeight, numRows, build, update)
    local list = CreateFrame("Frame", nil, parent)
    list:SetHeight(rowHeight * numRows)
    list.rows, list.data, list.offset = {}, {}, 0
    local maxRows = numRows

    for i = 1, numRows do
        local row = build(list, i)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:SetPoint("RIGHT", list, "RIGHT", -SCROLLBAR_WIDTH - 2, 0)
        list.rows[i] = row
    end

    local bar = CreateFrame("Slider", nil, list)
    bar:SetWidth(SCROLLBAR_WIDTH)
    bar:SetPoint("TOPRIGHT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:EnableMouse(true)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local thumb, colour, paint, parts = BookScrollbar(bar)
    list.bar, list.thumb, list.barParts = bar, thumb, parts

    -- The pencil's and the leather's colours, each as { r, g, b, a } (the
    -- alpha is SCROLLBAR's own): the book's ink and a leather brown by
    -- default.
    function list:SetBarColors(trackColor, thumbColor)
        colour(trackColor, thumbColor)
    end

    -- An item may set its own height (`item.height`): shorter for spacing,
    -- taller for an entry that needs room. The list shows the items that fit
    -- in numRows rows' worth of height, so a tall one means fewer below it
    -- and a short one more, up to the rows built.
    local function HeightOf(item)
        return item.height or rowHeight
    end

    -- Scrolled all the way down, the last items fill the list: the offset
    -- is however many come before the ones that fit.
    local function MaxOffset()
        local room, used, i = rowHeight * numRows, 0, #list.data
        while i >= 1 and used + HeightOf(list.data[i]) <= room do
            used = used + HeightOf(list.data[i])
            i = i - 1
        end
        return math.max(i, 0)
    end

    function list:Refresh()
        local y, room, full = 0, rowHeight * numRows, false
        for i = 1, maxRows do
            local row = self.rows[i]
            local item = self.data[self.offset + i]
            if item and (full or y + HeightOf(item) > room) then
                full, item = true, nil
            end
            if item then
                local height = HeightOf(item)
                row:SetHeight(height)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetPoint("RIGHT", self, "RIGHT", -SCROLLBAR_WIDTH - 2, 0)
                y = y + height
                row.item = item
                update(row, item)
                row:Show()
            else
                row.item = nil
                row:Hide()
            end
        end
    end

    function list:SetOffset(offset)
        offset = math.max(0, math.min(math.floor(offset + 0.5), MaxOffset()))
        if offset == self.offset and self.shownOnce then return end
        self.offset, self.shownOnce = offset, true
        if bar:GetValue() ~= offset then bar:SetValue(offset) end
        self:Refresh()
    end

    -- `keep` holds the scroll position, for refreshes that are not a new list.
    function list:SetData(data, keep)
        self.data = data or {}
        paint()
        bar:SetMinMaxValues(0, MaxOffset())
        bar:SetShown(MaxOffset() > 0)
        self.shownOnce = false
        self:SetOffset(keep and self.offset or 0)
    end

    -- Call before SetData. Never more than were built.
    function list:SetNumRows(n)
        numRows = math.max(1, math.min(n, maxRows))
        self.numRows = numRows
        self:SetHeight(rowHeight * numRows)
    end
    list.numRows = numRows

    bar:SetScript("OnValueChanged", function(_, value)
        list:SetOffset(value)
    end)

    -- Rows take the mouse (clicks, tooltips), so they pass the wheel on rather
    -- than rely on it reaching the list underneath.
    local function Wheel(_, delta)
        list:SetOffset(list.offset - delta * 3)
    end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", Wheel)
    for i = 1, maxRows do
        list.rows[i]:EnableMouseWheel(true)
        list.rows[i]:SetScript("OnMouseWheel", Wheel)
    end

    return list
end

--------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------

function ns.UI.Duration(seconds)
    local minutes = math.floor((seconds or 0) / 60)
    if minutes < 60 then return minutes .. " min" end
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60
    if minutes == 0 then return hours .. " h" end
    return ("%d h %d min"):format(hours, minutes)
end

-- DAT-4: stored as server epoch, shown relative or in local time.
function ns.UI.Ago(time, now)
    if not time then return "never" end
    now = now or ns.Now()
    local days = math.floor((now - time) / ns.DAY)
    if days < 1 then return "today" end
    if days < 2 then return "yesterday" end
    if days < 14 then return days .. " days ago" end
    if days < 60 then return math.floor(days / 7) .. " weeks ago" end
    return date("%d %b %Y", time)
end

-- "1 time", "3 times".
function ns.UI.Count(n, one, many)
    return n .. " " .. (n == 1 and one or many)
end

-- "Mulgore", "Mulgore and Durotar", "Mulgore, Durotar and The Barrens".
--
-- `opts` (all optional):
--   max      past this many names, only `shown` of them and a count of the
--            rest: "Mulgore, Durotar and 2 more"
--   shown    how many to name then (default `max`)
--   more     the word for the rest (default "more"; "others" for people)
--   oxford   a comma before the last "and" once there are three or more,
--            for lists of clauses rather than names
--
-- nil for an empty list.
function ns.UI.List(names, opts)
    local n = #names
    if n == 0 then return nil end
    opts = opts or {}

    if opts.max and n > opts.max then
        local shown = opts.shown or opts.max
        return ("%s and %d %s"):format(table.concat(names, ", ", 1, shown), n - shown, opts.more or "more")
    end

    if n == 1 then return names[1] end
    if n == 2 then return names[1] .. " and " .. names[2] end
    return table.concat(names, ", ", 1, n - 1) .. (opts.oxford and ", and " or " and ") .. names[n]
end

--------------------------------------------------------------------------
-- Days
--------------------------------------------------------------------------
--
-- Calendar days in local time, not 24-hour blocks: 23:50 last night is
-- "yesterday", not "today".

-- 0 when `time` falls on `now`'s day, 1 on the day before, nil otherwise.
local function DaysBack(time, now)
    local day = date("%Y-%m-%d", time)
    if day == date("%Y-%m-%d", now) then return 0 end
    if day == date("%Y-%m-%d", now - ns.DAY) then return 1 end
    return nil
end

-- "6 October". Given `now`, the year too once it is not now's: "6 October
-- 2025". Without it, never -- for a page that only reaches back as far as
-- the buffer does.
function ns.UI.DayMonth(time, now)
    local text = tonumber(date("%d", time)) .. date(" %B", time)
    if now and date("%Y", time) ~= date("%Y", now) then text = text .. date(" %Y", time) end
    return text
end

-- A heading for the day `time` falls on: "Today", "Yesterday", else
-- "Monday, 6 October" (with the year once it is not now's).
function ns.UI.DayLabel(time, now)
    now = now or ns.Now()
    local back = DaysBack(time, now)
    if back == 0 then return "Today" end
    if back == 1 then return "Yesterday" end
    return date("%A, ", time) .. ns.UI.DayMonth(time, now)
end

-- "today at 21:43", "yesterday at 18:02", "on 12 Sep at 18:02"; the year is
-- added once it is not this one.
function ns.UI.At(time, now)
    now = now or ns.Now()
    local clock = date("%H:%M", time)
    local back = DaysBack(time, now)

    if back == 0 then return "today at " .. clock end
    if back == 1 then return "yesterday at " .. clock end
    if date("%Y", time) == date("%Y", now) then
        return date("on %d %b at ", time) .. clock
    end
    return date("on %d %b %Y at ", time) .. clock
end

-- The profile's "last seen" line, from a character record's `seen`.
function ns.UI.SeenText(seen, now)
    if not seen then return "Not seen nearby yet." end

    local place = seen.zone
    if place and seen.subZone and seen.subZone ~= seen.zone then
        place = place .. ", " .. seen.subZone
    end

    return "Last seen " .. ns.UI.At(seen.time, now) .. (place and (" in " .. place) or "")
end

-- "once", "twice", "5 times".
function ns.UI.Times(n)
    if n == 1 then return "once" end
    if n == 2 then return "twice" end
    return n .. " times"
end

-- The score with a foe, from Fights.With: "You've killed them twice and
-- they've killed you 5 times." A kill by the group counts, and the sentence
-- says whose it was: "Your group has killed them once", "You and your group
-- have killed them 3 times". `em` marks the numbers, if given. `short`,
-- for the reunion card's two lines: "You've killed them 3 times, they've
-- killed you twice", every kill counted as yours. nil for no fights.
function ns.UI.FightsText(fights, em, short)
    if not fights then return nil end
    em = em or tostring
    local kills
    if fights.kills > 0 then
        local who = (short or fights.yours == fights.kills) and "You've"
            or fights.yours == 0 and "Your group has" or "You and your group have"
        kills = who .. " killed them " .. em(ns.UI.Times(fights.kills))
    end
    local deaths = fights.deaths > 0 and ("killed you " .. em(ns.UI.Times(fights.deaths))) or nil

    if kills and deaths then return kills .. (short and ", they've " or " and they've ") .. deaths .. "." end
    if kills then return kills .. "." end
    if deaths then return "They've " .. deaths .. "." end
    return nil
end

function ns.UI.Money(copper)
    copper = copper or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local rest = copper % 100

    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. "c" end
    return table.concat(parts, " ")
end

function ns.UI.ClassColor(guid)
    local record = ns.Characters.Get(guid)
    local token = record and record.class
    local color = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if not color then return "|cffffffff" end
    return ("|cff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
end

--------------------------------------------------------------------------
-- Characters in words
--------------------------------------------------------------------------
--
-- The colours are the Style files', which load after this one: ns.Style is
-- read when a line is written, never at load.

local RACE_NAMES = { Scourge = "Undead", NightElf = "Night Elf" }

function ns.UI.RaceName(record)
    if record.raceID and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
        local info = C_CreatureInfo.GetRaceInfo(record.raceID)
        if info and type(info.raceName) == "string" then return info.raceName end
    end
    return record.race and (RACE_NAMES[record.race] or record.race)
end

function ns.UI.ClassName(record)
    local token = record.class
    if not token then return nil end
    local names = record.sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
    if names and names[token] then return names[token] end
    return token:sub(1, 1) .. token:sub(2):lower()
end

-- "Level 6 Tauren Druid  ·  Horde  <Guild>", inked for the page.
function ns.UI.WhoLine(record, guild)
    record = record or {}
    local parts = {}
    if record.level then parts[#parts + 1] = "Level " .. record.level end
    parts[#parts + 1] = ns.UI.RaceName(record)
    parts[#parts + 1] = ns.UI.ClassName(record)

    local text = table.concat(parts, " ")
    if record.faction == "Horde" or record.faction == "Alliance" then
        local hex = record.faction == "Horde" and ns.Style.HEX.horde or ns.Style.HEX.alliance
        text = text .. (text ~= "" and "  ·  " or "") .. "|cff" .. hex .. record.faction .. "|r"
    end

    if guild then text = text .. "  |cff" .. ns.Style.HEX.faded .. "<" .. guild .. ">|r" end
    return text
end
