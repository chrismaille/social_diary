-- Settings (PRV-2, PRV-3, DAT-3): the journal's grey ribbon.
--
-- A page of the book like the others, in two panes: the left page lists the
-- sections (Recording, Interface, Sounds, Integrations, Memory, About), with Interface's
-- two subpages (Toasts, Keybinds & Shortcuts) hung under it, and the right
-- page shows the chosen one's settings. Written in the same ink as the
-- rest of the book: boxes to tick and numbers on a line (Style.Checkbox,
-- Style.NumberField) rather than Blizzard's controls.
--
-- Blizzard's AddOns settings keep a small page that sends you here, since
-- that is where players look first. It only needs RegisterCanvasLayoutCategory
-- and RegisterAddOnCategory; the declarative Settings API has changed
-- signature between client versions and is unverified in this build.
--
-- What PRV-2 lists that is not here yet: the city list and the sighting
-- sources, which sightings (M2) keep in slash commands for now (/sd sightings
-- city, /sd sightings on|off), and the post-session note prompt, which
-- arrives with SES-8 (M3).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local INK = Style.INK
local L = ns.UI.JOURNAL

local ROW_HEIGHT = Style.ROW_HEIGHT
local INDENT = 20               -- a setting that depends on the one above it
local FIELD_W, UNIT_W = 34, 34  -- a number's line, and the word after it
local SECTION_GAP = 14

local page
local category
local quietSearch = ""

--------------------------------------------------------------------------
-- Confirmation for everything that deletes (PRV-3), and for the one switch
-- that reloads the interface
--------------------------------------------------------------------------

StaticPopupDialogs["SOCIAL_DIARY_CONFIRM"] = {
    text = "%s",
    button1 = "Delete",
    button2 = CANCEL or "Cancel",
    OnAccept = function(self, action)
        if action then action() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

-- `accept`, if given, names the button that goes ahead in place of Delete,
-- for a question that deletes nothing; it comes without the alert sign.
-- The client reads both each time it shows the dialog.
function ns.UI.Confirm(text, action, accept)
    local dialog = StaticPopupDialogs["SOCIAL_DIARY_CONFIRM"]
    dialog.button1 = accept or "Delete"
    dialog.showAlert = accept == nil
    StaticPopup_Show("SOCIAL_DIARY_CONFIRM", text, nil, action)
end

-- CloseEntry announces SD_DIARY_CHANGED, which refreshes the journal and
-- this page with it.
local function AfterDelete()
    ns.UI.CloseEntry()
end

function ns.UI.ConfirmForget(guid)
    local name = ns.Characters.FullName(guid) or guid
    ns.UI.Confirm(("Delete everything Social Diary knows about %s?\n\nThis cannot be undone.")
        :format(name), function()
        ns.Characters.Forget(guid)
        ns.Print("deleted everything about |cffffffff%s|r.", name)
        AfterDelete()
    end)
end

--------------------------------------------------------------------------
-- Laying out a column
--------------------------------------------------------------------------
--
-- Each page is one column, filled top down: every piece goes under the last
-- and says how tall it came out, so a label that wraps pushes the rest down.

local function Column(parent, x, y, width)
    local column = { parent = parent, x = x, y = y, width = width, first = true }

    function column:Place(widget, height, indent, gap)
        widget:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x + (indent or 0), self.y)
        self.y = self.y - height - (gap or 6)
        return widget
    end

    -- A heading in small capitals with a rule running on after it, as the
    -- People list groups its rows.
    function column:Heading(text)
        if not self.first then self.y = self.y - SECTION_GAP end
        self.first = false

        local heading = Style.Text(self.parent, FONT.heading)
        heading:SetText(text:upper())
        self:Place(heading, 14, 0, 8)

        local rule = self.parent:CreateTexture(nil, "ARTWORK")
        rule:SetHeight(1)
        rule:SetPoint("LEFT", heading, "RIGHT", 8, 0)
        rule:SetWidth(math.max(0, self.width - heading:GetStringWidth() - 8))
        rule:SetColorTexture(INK[1], INK[2], INK[3], 0.25)
        return heading
    end

    -- Faded small print under a setting.
    function column:Hint(text, indent)
        local hint = Style.Text(self.parent, FONT.small)
        hint:SetWidth(self.width - (indent or 0))
        hint:SetText(text)
        return self:Place(hint, hint:GetStringHeight(), indent, 8)
    end

    function column:Checkbox(text, get, set, indent, hint)
        local box = Style.Checkbox(self.parent, self.width - (indent or 0), text, get, set, hint)
        return self:Place(box, box.height, indent, hint and 8)
    end

    -- "Forget people outside the diary after [30] days": the sentence on the
    -- left, wrapping, and the number and its unit in a column on the right,
    -- so the numbers line up. `.box` is the field.
    function column:Number(text, unit, min, max, get, set)
        local row = CreateFrame("Frame", nil, self.parent)

        row.label = Style.Text(row, FONT.body)
        row.label:SetPoint("TOPLEFT")
        row.label:SetWidth(self.width - FIELD_W - UNIT_W - 8)
        row.label:SetText(text)

        row.box = Style.NumberField(row, FIELD_W, min, max, get, set)
        row.box:SetPoint("TOPRIGHT", row, "TOPRIGHT", -UNIT_W, 1)

        row.unit = Style.Text(row, FONT.body)
        row.unit:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
        row.unit:SetText(unit)

        local height = math.max(18, row.label:GetStringHeight())
        row:SetSize(self.width, height)

        function row:Refresh() self.box:Refresh() end
        function row:SetAvailable(available)
            self:SetAlpha(available and 1 or 0.45)
            if available then self.box:Enable() else self.box:Disable() end
        end

        return self:Place(row, height)
    end

    return column
end

--------------------------------------------------------------------------
-- Quiet nearby
--------------------------------------------------------------------------
--
-- The people from the diary who get no toast when they come into view
-- (ns.Diary.IsQuietNearby). With the search empty the list is everyone
-- marked; typing searches the whole diary by name and tag, to mark more.
-- A row unticked stays where it is until the list is next built, so a slip
-- can be ticked back.

local function Lower(text)
    return (text or ""):lower()
end

local function QuietQuery(search)
    search = Lower(search):gsub("^%s+", ""):gsub("%s+$", "")
    local list = {}

    for guid, entry in ns.Diary.Each() do
        local name = ns.Characters.FullName(guid) or guid
        local match
        if search == "" then
            match = entry.quietNearby == true
        else
            match = Lower(name):find(search, 1, true) ~= nil
            for i = 1, #entry.tags do
                if match then break end
                match = entry.tags[i]:find(search, 1, true) ~= nil
            end
        end
        if match then
            list[#list + 1] = {
                guid = guid,
                name = name,
                record = ns.Characters.Get(guid),
                tags = table.concat(entry.tags, ", "),
            }
        end
    end

    table.sort(list, function(a, b)
        if a.name ~= b.name then return Lower(a.name) < Lower(b.name) end
        return a.guid < b.guid
    end)
    return list
end

local function QuietCount()
    local n = 0
    for guid in ns.Diary.Each() do
        if ns.Diary.IsQuietNearby(guid) then n = n + 1 end
    end
    return n
end

local function RefreshQuietCount()
    page.quietCount:SetText(QuietCount() .. " quiet")
end

local function UpdateQuietRow(row, item)
    local quiet = ns.Diary.IsQuietNearby(item.guid)
    row.tick:SetChecked(quiet)
    row.name:SetText(item.name)
    row.name:SetFontObject(quiet and FONT.strong or FONT.body)
    row.tags:SetText(item.tags)
    Style.ClassIconOrInk(row.icon, item.record and item.record.class)
end

local function BuildQuietRow(list)
    local row = CreateFrame("Button", nil, list)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(INK[1], INK[2], INK[3], Style.HOVER_ALPHA)

    row.tick = Style.Tick(row)
    row.tick:SetPoint("LEFT", 6, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row.tick, "RIGHT", 9, 0)

    row.name = Style.Text(row, FONT.body)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -150, 0)
    row.name:SetWordWrap(false)

    row.tags = Style.Text(row, FONT.small)
    row.tags:SetPoint("RIGHT", -6, 0)
    row.tags:SetWidth(140)
    row.tags:SetJustifyH("RIGHT")
    row.tags:SetWordWrap(false)

    row:SetScript("OnEnter", function(self) self.tick:SetHot(true) end)
    row:SetScript("OnLeave", function(self) self.tick:SetHot(false) end)
    row:SetScript("OnClick", function(self)
        if not self.item then return end
        ns.Diary.SetQuietNearby(self.item.guid, not ns.Diary.IsQuietNearby(self.item.guid))
        UpdateQuietRow(self, self.item)
        RefreshQuietCount()
    end)

    return row
end

local function RefreshQuiet(keepScroll)
    local list = QuietQuery(quietSearch)
    page.quiet:SetData(list, keepScroll)
    RefreshQuietCount()

    local empty = ""
    if #list == 0 then
        if ns.Diary.Count() == 0 then
            empty = "Nobody in the diary yet."
        elseif quietSearch:find("%S") then
            empty = "Nobody in the diary matches."
        else
            empty = "Nobody yet. Search your diary above to choose who."
        end
    end
    page.quietEmpty:SetText(empty)
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------
--
-- Two panes, as the book's other pages: the left page lists the sections,
-- the right page shows the chosen one's settings under its name.

-- In the order the left page lists them. A subpage names its `parent` and
-- follows it; it is a section like the others, with its own pane, and only
-- its row on the left is smaller.
local SECTIONS = {
    { key = "recording", label = "Recording", about = "Chat, together sessions, sightings" },
    { key = "interface", label = "Interface", about = "Tooltips, and how the book looks" },
    { key = "toasts", label = "Toasts", about = "Who gets one, how often, and where", parent = "interface" },
    { key = "shortcuts", label = "Keybinds & Shortcuts", about = "Keys, a button, and /sd",
        parent = "interface" },
    { key = "sounds", label = "Sounds", about = "A warning when a foe comes into view" },
    { key = "integrations", label = "Integrations", about = "Other addons it can read" },
    { key = "memory", label = "Memory", about = "How long it keeps things, and deleting" },
    { key = "about", label = "About", about = "Thanks to those who helped" },
}

-- The About page's thanks, in the order they were given.
local TESTERS = { "Gunther Guntherino", "Mooguy Mooperson", "Koko Skybluff" }
-- The left page: where the rows start, a section's row (its name and what
-- it covers), a subpage's (its name alone), how far in a subpage hangs, and
-- the ink bracket it hangs off: how far in from the section's row, the
-- foot's length, and its ink, darker while one of its subpages is open.
-- SUB_AFTER is the room left under the last subpage, so the next section
-- stands clear of the group.
local NAV_TOP, NAV_ROW, SUB_ROW, SUB_INDENT, SUB_AFTER = 58, 42, 24, 18, 6
local BRACKET = { x = 10, foot = 6, ink = 0.30, open = 0.65 }
local MIN_QUIET_ROWS = 4
local MAX_CHAT_LINES = 5000  -- above it, "No maximum" says it better

-- The open section, kept across opens within a login.
local section = SECTIONS[1].key

local function SizeText(bytes)
    local rows = ns.Interactions.Totals()

    return ("%d in the diary  ·  %d characters known  ·  %d sessions  ·  %d interactions"
        .. "  ·  %d sightings.  About %d KB on disk.")
        :format(ns.Diary.Count(), ns.Characters.Count(), ns.CountKeys(ns.db.sessions), rows,
            ns.CountKeys(ns.db.sightings), math.ceil(bytes / 1024))
end

-- Past ns.SIZE_WARNING: what it costs, and what to turn down. Empty below.
local function SizeWarning(bytes)
    if bytes <= ns.SIZE_WARNING then return "" end
    return ("Over %d MB: a lot to read at every login and /reload. Your diary keeps"
        .. " its history for good, so lowering the maximum chat lines (Recording) or"
        .. " deleting sightings is what brings it down.")
        :format(ns.SIZE_WARNING / (1024 * 1024))
end

-- DAT-1: which diary is in use, and so which file it is in, read from the
-- mode loaded this session (ns.diaryShared), not from the choice saved for
-- the next load.
local DIARY_FILE = {
    shared = "WTF\\Account\\<account>\\SavedVariables\\social_diary.lua",
    own = "WTF\\Account\\<account>\\<realm>\\<character>\\SavedVariables\\social_diary.lua",
}

-- PRV-1: said plainly, where the user will look for it.
local function DataText()
    if ns.diaryShared then
        return ("The shared diary is stored only on this computer, in %s. Nothing is sent to"
            .. " other players or to any server."):format(DIARY_FILE.shared)
    end
    return ("This character's diary is stored only on this computer, in %s. Nothing is sent"
        .. " to other players or to any server."):format(DIARY_FILE.own)
end

-- PRV-3: "delete everything" is the diary in use, so it says whose.
local function WipeText()
    if ns.diaryShared then
        return "Delete the shared diary?\n\nEvery diary entry, note, session and interaction"
            .. " your characters wrote in it goes, and every character's road in it. Your"
            .. " settings, and any diary a character keeps of its own, are kept. This cannot"
            .. " be undone."
    end
    return "Delete this character's diary?\n\nEvery diary entry, note, session and interaction"
        .. " it recorded goes, and its road. Your settings, and your other characters'"
        .. " diaries, are kept. This cannot be undone."
end

-- The switch's question, asked before the interface reloads: what the
-- character will see after it, and that nothing moves.
local function ShareText(on)
    if on then
        return "Share one diary between all your characters?\n\nThe interface reloads, and"
            .. " every character then uses the shared diary (empty if they never shared one)."
            .. " Nothing is copied or deleted: each character's own diary stays as it"
            .. " is, for if you switch back."
    end
    return "Give every character its own diary again?\n\nThe interface reloads, and this"
        .. " character then uses its own diary, empty if it never had one. Nothing is"
        .. " copied or deleted: the shared diary stays as it is, for if you share again."
end

local function Saved() return ns.db.settings end

-- The section a key names, or nil.
local function Find(key)
    for _, s in ipairs(SECTIONS) do
        if s.key == key then return s end
    end
end

-- Everything the page shows, read again: which section is open, the
-- switches, the numbers, which of them are available, the quiet list and
-- the size. The closed sections too, so none is stale when it opens.
-- A subpage open is shaded on the left like a section; its section's name
-- goes dark with it, unshaded, and so does the bracket it hangs off.
local function RefreshPage(keepScroll)
    if not page then return end
    page.version:SetText("v" .. ns.version)
    local open = Find(section)
    local parent = open and open.parent
    for _, s in ipairs(SECTIONS) do
        local row = page.nav[s.key]
        local isOpen = s.key == section
        page.panes[s.key]:SetShown(isOpen)
        row.selected:SetShown(isOpen)
        row.label:SetFontObject((isOpen or s.key == parent) and FONT.strong or FONT.body)
    end
    for key, bracket in pairs(page.brackets) do
        bracket:SetInk(key == parent)
    end
    for _, control in ipairs(page.controls) do control:Refresh() end
    for _, dependent in ipairs(page.dependents) do
        dependent.control:SetAvailable(dependent.on())
    end
    local bytes = ns.EstimateSize()
    page.size:SetText(SizeText(bytes))
    page.sizeWarning:SetText(SizeWarning(bytes))
    page.dataHint:SetText(DataText())
    RefreshQuiet(keepScroll)
end

function ns.UI.RefreshSettingsPage()
    RefreshPage(true)
end

-- Turns to one of SECTIONS by key, a subpage's included.
local function ShowSection(key)
    if not Find(key) then return end
    section = key
    RefreshPage(true)
end

-- Removing or forgetting someone changes the quiet list and the size.
ns.On("SD_DIARY_CHANGED", function()
    if ns.UI.JournalShowing("settings") then RefreshPage(true) end
end)

--------------------------------------------------------------------------
-- Left page: the sections
--------------------------------------------------------------------------

-- A section's subpages hang off an ink bracket, as an episode's rows do on
-- the timeline: down the margin from the foot of the section's row, under
-- its name, with a short foot out to each subpage. Drawn on the page, left
-- of the rows, so a subpage's shading never covers it. SetInk(open)
-- darkens it while one of its subpages is open.
local function Bracket(parent, x, top, feet)
    local INK = Style.INK
    local bracket = { pieces = {} }
    local function Piece(px, py, w, h)
        local piece = parent:CreateTexture(nil, "ARTWORK")
        piece:SetSize(w, h)
        piece:SetPoint("TOPLEFT", px, -py)
        bracket.pieces[#bracket.pieces + 1] = piece
    end
    Piece(x, top, 1, feet[#feet] - top + 1)
    for _, y in ipairs(feet) do Piece(x + 1, y, BRACKET.foot, 1) end

    function bracket:SetInk(open)
        for _, piece in ipairs(self.pieces) do
            piece:SetColorTexture(INK[1], INK[2], INK[3], open and BRACKET.open or BRACKET.ink)
        end
    end
    bracket:SetInk(false)
    return bracket
end

-- Sections in full (the name, and what it covers in small print under it);
-- subpages smaller, the name alone, indented under their section.
local function BuildNav(parent)
    page.version = ns.UI.PageHeading(parent, "Settings")
    page.nav, page.brackets = {}, {}

    local x, y = L.LEFT_X - 6, NAV_TOP
    local feet, bottoms = {}, {}
    for i, s in ipairs(SECTIONS) do
        local sub = s.parent ~= nil
        if not sub and i > 1 and SECTIONS[i - 1].parent then y = y + SUB_AFTER end
        local row = Style.GroupedRow(parent, function(row)
            row.label = Style.Text(row, FONT.body)
            if sub then
                row.label:SetPoint("LEFT", 8, 0)
                row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.label:SetWordWrap(false)
                return { row.label }
            end
            row.label:SetPoint("TOPLEFT", 8, -6)
            row.about = Style.Text(row, FONT.small)
            row.about:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
            row.about:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.about:SetWordWrap(false)
            return { row.label, row.about }
        end)
        local height = sub and SUB_ROW or NAV_ROW
        local indent = sub and SUB_INDENT or 0
        row:SetSize(L.LEFT_W + 12 - indent, height)
        row:SetPoint("TOPLEFT", x + indent, -y)
        row:SetHeading(s)
        row.label:SetText(s.label)
        if row.about then row.about:SetText(s.about) end
        row:SetScript("OnClick", function() ShowSection(s.key) end)
        page.nav[s.key] = row

        if sub then
            feet[s.parent] = feet[s.parent] or {}
            table.insert(feet[s.parent], y + height / 2)
        end
        bottoms[s.key] = y + height
        y = y + height + 2
    end
    page.navBottom = y

    -- From the foot of the section's row down to its last subpage.
    for key, ys in pairs(feet) do
        page.brackets[key] = Bracket(parent, x + BRACKET.x, bottoms[key], ys)
    end

    -- The way back to the introduction (the frontispiece, then the front
    -- matter, which says what is kept), at the foot of the page, clear of
    -- the ribbons.
    page.intro = Style.Link(parent, FONT.body, function()
        Style.PlaySound("pageTurn")
        ns.UI.ShowIntro()
    end)
    page.intro:SetText("The introduction")
    page.intro:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", L.LEFT_X + L.LEFT_W, -L.BOOK_H + 22)
end

--------------------------------------------------------------------------
-- Right page: one pane per section
--------------------------------------------------------------------------

-- A pane on the right page, headed with the section's name in capitals and
-- what it covers beside it, as the Recently nearby page heads a day. A
-- subpage's name is a size smaller, as its row is on the left.
-- Returns the pane and a column to fill, below the heading.
local function Pane(s)
    local pane = CreateFrame("Frame", nil, page)
    pane:SetPoint("TOPLEFT", L.RIGHT_X, -L.TOP)
    pane:SetSize(L.RIGHT_W, L.RIGHT_H)
    page.panes[s.key] = pane

    pane.title = Style.Text(pane, s.parent and FONT.titleSmall or FONT.title)
    pane.title:SetPoint("TOPLEFT", 0, 0)
    pane.title:SetHeight(28)
    pane.title:SetText(s.label:upper())

    pane.about = Style.Text(pane, FONT.faded)
    pane.about:SetPoint("BOTTOMLEFT", pane.title, "BOTTOMRIGHT", 10, 5)
    pane.about:SetText(s.about)

    return pane, Column(pane, 0, -48, L.RIGHT_W)
end

-- A setting from the saved table, in column `c`, refreshed with the page.
-- `after` runs once it is written. Every switch refreshes the page, so the
-- settings that depend on it fade or come back.
-- `hint` is the switch's small print, hung under its label.
local function Switch(c, text, key, indent, after, hint)
    local box = c:Checkbox(text, function() return Saved()[key] end, function(v)
        Saved()[key] = v
        if after then after(v) end
        RefreshPage(true)
    end, indent, hint)
    page.controls[#page.controls + 1] = box
    return box
end

local function Number(c, text, unit, key, min, max, after)
    local row = c:Number(text, unit, min, max, function() return Saved()[key] end, function(v)
        Saved()[key] = v
        if after then after(v) end
    end)
    page.controls[#page.controls + 1] = row
    return row
end

-- `on` is the key of the setting it depends on, or a function saying
-- whether it is available.
local function DependsOn(control, on)
    if type(on) ~= "function" then
        local key = on
        on = function() return Saved()[key] end
    end
    page.dependents[#page.dependents + 1] = { control = control, on = on }
end

local function BuildRecording(s)
    local _, c = Pane(s)

    -- JRN-17, through the same call as the front matter's links, so the
    -- timer starts and stops at once.
    c:Heading("Your Diary")
    page.keepRoute = Switch(c, "Keep my own route", "keepRoute", nil,
        function(on) ns.JourneyCapture.SetEnabled(on) end,
        "Where this character goes, every few seconds: only your own position, kept for good."
            .. " Off stops it; the road kept so far stays until you delete it under Memory.")

    c:Heading("Chat")
    -- INT-4 asks for the hint to be said in the settings.
    page.storeChat = Switch(c, "Keep whisper, /say and party text", "storeChat", nil, nil,
        "some text in dungeons cannot be accessed, fyi.")

    -- A lower limit applies now, to everyone's chat.
    page.chatLines = Number(c, "Maximum chat lines kept per person", "lines", "chatLines",
        1, MAX_CHAT_LINES, function() ns.Interactions.TrimChat() end)
    DependsOn(page.chatLines, function() return Saved().storeChat and not Saved().chatUnlimited end)
    page.chatUnlimited = Switch(c, "Unlimited", "chatUnlimited", INDENT,
        function(on) if not on then ns.Interactions.TrimChat() end end)
    DependsOn(page.chatUnlimited, "storeChat")
    c:Hint("Lines can still be lost if they exceed file size limits.")

    c:Heading("Together sessions")
    page.sessionGap = Number(c, "End a together session after this long apart", "min",
        "sessionGapMinutes", 5, 120)
    c:Hint("While you stay grouped, a session runs indefinitely. Imagine leaving"
        .. " a friend's group to finish a quest alone and inviting them again a quarter of an hour"
        .. " later. Back within this time, it stays one session in your diary; any longer, and it"
        .. " is written down as two. Low values could spam the Diary Timeline.")

    -- SIG-1 and SIG-5, through the same calls as /sd sightings on|off and
    -- /sd sightings city, so they take effect at once.
    c:Heading("Sightings")
    local Capture = ns.SightingCapture
    page.detectSightings = Switch(c, "Notice who passes you in the open world", "detectSightings", nil,
        function(on) Capture.SetEnabled(on) end,
        "Only works if nameplates are on. Doesn't work in dungeons, raids or battlegrounds.")

    -- The cities on SIG-5's list, two to a line. Saved, a city on means it
    -- pauses there; ticked here means it notices people there, so that a
    -- tick never stands for something that is not being recorded. The list
    -- is the one saved when the page was built; a city added by command
    -- shows after a reload.
    c:Hint("Enable sightings in cities - performance warning:", INDENT)
    local cities = Capture.Cities()
    for _, city in ipairs(cities) do
        city.name = type(city.key) == "number" and (ns.MapName(city.key) or ("map " .. city.key)) or city.key
    end
    table.sort(cities, function(a, b) return a.name < b.name end)

    local half = (c.width - INDENT) / 2
    local left
    page.cities = {}
    for i, city in ipairs(cities) do
        local box = Style.Checkbox(c.parent, half - 8, city.name,
            function() return Saved().cities[city.key] ~= true end,
            function(on) Capture.SetCity(city.key, not on) end)
        if i % 2 == 1 then
            left = c:Place(box, box.height, INDENT, 4)
        else
            box:SetPoint("TOPLEFT", left, "TOPLEFT", half, 0)
        end
        DependsOn(box, "detectSightings")
        page.controls[#page.controls + 1] = box
        page.cities[city.key] = box
    end
end

local function BuildInterface(s)
    local pane, c = Pane(s)

    c:Heading("Tooltips")
    page.tooltips = Switch(c, "Add diary lines to player tooltips", "tooltips")
    page.tooltipSeen = Switch(c, "For everyone else, how often you have seen them", "tooltipSeen", INDENT)
    DependsOn(page.tooltipSeen, "tooltips")

    c:Heading("Look and Feel")
    page.bookStack = Switch(c, "Simulate Page Turns", "bookStack", nil,
        function() ns.UI.TurnJournalStack() end,
        "New Diary entries add pages, and the book turns to the new page.")
    page.flatSheets = Switch(c, "Flat paper only", "flatSheets", nil, nil,
        "Disable folded & bent look of Heatmap & other sheets")
    page.revealMap = Switch(c, "Use fully discovered map for map sheets", "revealMap", nil, nil,
        nil)
end

-- Interface's first subpage: the toasts, moved out of Interface when it
-- grew too busy, the blacklist with them.
local function BuildToasts(s)
    local pane, c = Pane(s)

    -- Two switches, neither under the other: nearby toasts without the
    -- group ones is a fair thing to want. The cooldown is both kinds'.
    c:Heading("When they show")
    page.toasts = Switch(c, "Show a toast when someone from your diary joins your group", "toasts")
    page.nearbyToasts = Switch(c, "Show a toast when someone from your diary comes into view",
        "nearbyToasts")
    page.toastCooldown = Number(c, "At most one toast per person every", "min",
        "toastCooldownMinutes", 1, 720)
    DependsOn(page.toastCooldown, function() return Saved().toasts or Saved().nearbyToasts end)
    page.foeToastsUncooled = Switch(c, "Ignore toast cooldown for foes", "foeToastsUncooled", INDENT,
        nil, "For World PVP e.g.")
    DependsOn(page.foeToastsUncooled, function() return Saved().toasts or Saved().nearbyToasts end)

    -- The book closes so the card can be seen where it lies, and opens
    -- on this page again once it is placed (UI/Reunion.lua).
    local function Back() ns.UI.ShowSettings("toasts") end
    page.moveToast = Style.Link(pane, FONT.body, function()
        ns.UI.CloseJournal()
        if not ns.UI.PlaceToast(Back) then Back() end
    end)
    page.moveToast:SetText("Move the toast")
    c:Place(page.moveToast, 18)

    -- Last, so its list can take whatever room is left.
    c:Heading("Nearby Toast Blacklist")
    c:Hint("Toasts can get annoying for people you play with all the time.")

    page.quietSearch = Style.PageSearch(pane, 0, c.y, 236, "Search your diary", function(text)
        if text ~= quietSearch then
            quietSearch = text
            RefreshQuiet()
        end
    end)
    page.quietCount = Style.Text(pane, FONT.small)
    page.quietCount:SetPoint("RIGHT", pane, "TOPRIGHT", 0, c.y - 12)
    page.quietCount:SetJustifyH("RIGHT")
    c.y = c.y - 24 - 8

    local rows = math.max(MIN_QUIET_ROWS, math.floor((L.RIGHT_H + c.y) / ROW_HEIGHT))
    page.quiet = ns.UI.VirtualList(pane, ROW_HEIGHT, rows, BuildQuietRow, UpdateQuietRow)
    page.quiet:SetWidth(L.RIGHT_W)
    page.quiet:SetBarColors(L.LIST_BAR[1], L.LIST_BAR[2])
    c:Place(page.quiet, ROW_HEIGHT * rows)

    page.quietEmpty = Style.Text(pane, FONT.faded)
    page.quietEmpty:SetPoint("TOPLEFT", page.quiet, "TOPLEFT", 4, -6)
    page.quietEmpty:SetWidth(L.RIGHT_W - 8)
end

--------------------------------------------------------------------------
-- The book for an action bar
--------------------------------------------------------------------------
--
-- Two macros, one per book on the Keybinds & Shortcuts page: the journal
-- (/sd) and Remember this (/sd remember). Each is made the first time its
-- book is dragged or clicked, never before: the macro book is the user's,
-- and an addon that writes in it at login has no business there.
-- Account-wide, so every character finds them. They go onto the cursor
-- (PickupMacro) for the user to drop on a slot; the addon never places
-- them itself (PlaceAction).

-- Icons by their file name without the folder, the form the macro API
-- takes in this era of client. Unverified in this build: should a macro
-- show a question mark, its file ID is the other form CreateMacro accepts.
local MACROS = {
    journal = { name = "Social Diary", body = "/sd", icon = "INV_Misc_Book_09",
        art = "book", label = "Open Social Diary" },
    remember = { name = "Remember This", body = "/sd remember", icon = "INV_Misc_Note_01",
        art = "note", label = "Remember this" },
}
local MACRO_ORDER = { "journal", "remember" }
-- How many account macros there is room for, when the client does not say
-- (MAX_ACCOUNT_MACROS lives with Blizzard's macro window, which loads on
-- demand).
local ACCOUNT_MACROS = 120

-- Puts one of the diary's macros on the cursor ("journal", the default, or
-- "remember"), making it first if there is none. Returns true and its
-- index, or false and why not: "combat" (the client refuses macros and
-- action bars in a fight) or "full" (no room left in the account's macros,
-- or the client would not make it).
function ns.UI.PickupDiaryMacro(which)
    local macro = MACROS[which or "journal"]
    if InCombatLockdown() then return false, "combat" end
    local index = GetMacroIndexByName(macro.name)
    if not index or index == 0 then
        local account = GetNumMacros()
        if (account or 0) >= (MAX_ACCOUNT_MACROS or ACCOUNT_MACROS) then return false, "full" end
        local ok, made = pcall(CreateMacro, macro.name, macro.icon, macro.body, nil)
        if not ok or not made or made == 0 then return false, "full" end
        index = made
    end
    PickupMacro(index)
    return true, index
end

local MACRO_SAID = {
    combat = ns.UI.Keys.COMBAT,
    full = "Your macros are full, so there is no room for it. %s works anywhere, typed in chat.",
    click = "It is on your cursor: click a slot on an action bar to put it there.",
}

-- A book: the macro's icon, lying on the page with a hairline
-- round it and a shadow under it, lit from the top left like the rest, to
-- be picked up. Faded and deaf in a fight; SetFight says so, as the
-- client is not in lockdown yet when PLAYER_REGEN_DISABLED arrives.
local BOOK_ICON = 36

local function BookButton(parent, status, which)
    local macro = MACROS[which]
    local INK = Style.INK
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BOOK_ICON, BOOK_ICON)
    button:RegisterForDrag("LeftButton")

    local shadow = button:CreateTexture(nil, "BACKGROUND")
    shadow:SetSize(BOOK_ICON, BOOK_ICON)
    shadow:SetPoint("TOPLEFT", 2, -2)
    shadow:SetColorTexture(INK[1], INK[2], INK[3], 0.30)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    Style.SetTexture(button.icon, macro.art, 0.3, 0.22, 0.12, 1)
    button.icon:SetTexCoord(unpack(Style.ICON_CROP))
    Style.Hairline(button, "OVERLAY", 0, 0.65)

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.95, 0.8, 0.18)

    function button:SetFight(fight)
        self.unavailable = fight
        self:SetAlpha(fight and 0.45 or 1)
        self.icon:SetDesaturated(fight)
        if fight then self:Disable() else self:Enable() end
        if fight then
            status:SetText(MACRO_SAID.combat)
        elseif status:GetText() == MACRO_SAID.combat then
            status:SetText("")
        end
    end
    function button:Refresh() self:SetFight(InCombatLockdown()) end

    -- Dragged, it is in the hand already; clicked, it says where to put it.
    local function Pickup(self, clicked)
        if self.unavailable then return end
        local ok, why = ns.UI.PickupDiaryMacro(which)
        if ok then
            status:SetText(clicked and MACRO_SAID.click or "")
        elseif why == "combat" then
            self:SetFight(true)
        else
            status:SetText(MACRO_SAID.full:format(macro.body))
        end
    end
    button:SetScript("OnDragStart", function(self) Pickup(self, false) end)
    button:SetScript("OnClick", function(self) Pickup(self, true) end)

    Style.Tooltip(button, { { macro.label }, { "Drag onto an action bar.", 1, 1, 1 } })
    ns.On("PLAYER_REGEN_DISABLED", function() button:SetFight(true) end)
    ns.On("PLAYER_REGEN_ENABLED", function() button:SetFight(false) end)
    return button
end

-- The keys, in Bindings.xml's terms.
local BINDINGS = {
    { action = "SOCIALDIARY_JOURNAL", label = "Open the journal" },
    { action = "SOCIALDIARY_REMEMBER", label = "Remember this" },
}
local KEY_LABEL_W = 160

-- The /sd commands worth knowing (Core/Slash.lua has them all; /sd help
-- lists them in chat). In the order they would be wanted.
local COMMANDS = {
    { "/sd", "Opens the journal" },
    { "/sd add <name>", "Adds your target, or whoever you name" },
    { "/sd remember", "Remember this, from who you met lately" },
    { "/sd settings", "These pages" },
    { "/sd about", "What the diary keeps, and where" },
    { "/sd forget <name>", "Deletes everything about someone" },
    { "/sd help", "Every command, in chat" },
}
local COMMAND_W = 150

-- Interface's second subpage: both keys, the book to drag onto a bar, and
-- the slash commands.
local function BuildShortcuts(s)
    local pane, c = Pane(s)

    -- One status line for both keys, under them: what the key did before,
    -- or why it was refused. Room kept, so nothing below moves.
    c:Heading("Keys")
    page.keyStatus = Style.Text(pane, FONT.small)
    page.keyStatus:SetWidth(L.RIGHT_W)
    page.keys = {}
    for _, b in ipairs(BINDINGS) do
        local row = CreateFrame("Frame", nil, pane)
        row:SetSize(L.RIGHT_W, ns.UI.Keys.KEYCAP.h)
        row.label = Style.Text(row, FONT.body)
        row.label:SetPoint("LEFT")
        row.label:SetWidth(KEY_LABEL_W - 8)
        row.label:SetText(b.label)
        local setter = ns.UI.Keys.Setter(row, b.action, page.keyStatus)
        setter:SetPoint("LEFT", KEY_LABEL_W, 0)
        setter:SetWidth(L.RIGHT_W - KEY_LABEL_W)
        -- A key bound may have been the other's: both read again.
        setter.onBound = function() RefreshPage(true) end
        page.keys[b.action] = setter
        page.controls[#page.controls + 1] = setter
        c:Place(row, ns.UI.Keys.KEYCAP.h, 0, 8)
    end
    c:Place(page.keyStatus, 28, 0, 0)

    -- One status line for both books, under them, as for the keys.
    c:Heading("On your action bar")
    page.macroStatus = Style.Text(pane, FONT.small)
    page.macroStatus:SetWidth(L.RIGHT_W)
    page.macroBooks = {}
    for _, which in ipairs(MACRO_ORDER) do
        local book = BookButton(pane, page.macroStatus, which)
        book.label = Style.Text(pane, FONT.body)
        book.label:SetPoint("LEFT", book, "RIGHT", 14, 0)
        book.label:SetText(MACROS[which].label)
        page.macroBooks[which] = book
        page.controls[#page.controls + 1] = book
        c:Place(book, BOOK_ICON + 2, 0, 6)
    end
    c:Place(page.macroStatus, 28, 0, 0)

    c:Heading("Slash commands")
    page.commands = {}
    for i, command in ipairs(COMMANDS) do
        local line = Style.Text(pane, FONT.strong)
        line:SetText(command[1])
        local said = Style.Text(pane, FONT.body)
        said:SetPoint("TOPLEFT", line, "TOPLEFT", COMMAND_W, 0)
        said:SetWidth(L.RIGHT_W - COMMAND_W)
        said:SetText(command[2])
        page.commands[i] = c:Place(line, math.max(16, said:GetStringHeight()), 0, 5)
    end
end

-- The foe alert (Core/Reunions.lua), with a sample to hear what it sounds
-- like before switching it on.
local function BuildSounds(s)
    local pane, c = Pane(s)

    c:Heading("World PvP")
    page.foeAlert = Switch(c, "Sound a raid warning when a foe comes into view", "foeAlert", nil, nil,
        "Tag someone foe in your diary, e.g. for World PVP.")

    page.foeSample = Style.Link(pane, FONT.body, function() ns.UI.PlayFoeAlert() end)
    page.foeSample:SetText("Hear it")
    c:Place(page.foeSample, 18, INDENT)
end

-- An addon it will read from one day, not yet: never ticked, never looked
-- for, and always unavailable. Only the box and its label fade, as an
-- unavailable setting does; the small print stays at full hint ink, since
-- it is the part that says why.
local function Placeholder(c, heading, text, hint)
    local title = c:Heading(heading)
    local box = c:Checkbox(text, function() return false end, nil, nil, hint)
    box.heading = title
    function box:SetAvailable(available)
        self.unavailable = not available
        local alpha = available and 1 or 0.45
        self.tick:SetAlpha(alpha)
        self.label:SetAlpha(alpha)
    end
    page.controls[#page.controls + 1] = box
    DependsOn(box, function() return false end)
    box:SetAvailable(false)
    return box
end

-- Addons it reads from (Core/Bridges), each a status the user cannot
-- change: ticked where it is there and answers.
local function BuildIntegrations(s)
    local _, c = Pane(s)

    c:Heading("Questie")
    page.questie = c:Checkbox("Questie installed",
        function() return ns.QuestieBridge.Status() == "on" end, nil, nil,
        "Mobs get their real names and quest drops are checked against real drop rates."
            .. " Social Diary only reads from it.")
    page.controls[#page.controls + 1] = page.questie

    page.questieOld = c:Hint("Found, but this version isn't supported.")
    function page.questieOld:Refresh()
        self:SetShown(ns.QuestieBridge.Status() == "old")
    end
    page.controls[#page.controls + 1] = page.questieOld

    page.deathlog = Placeholder(c, "Deathlog", "Deathlog installed",
        "Adds permadeath notes in Hardcore. Not available until Hardcore is released.")
    page.trp3 = Placeholder(c, "Total RP 3", "Total RP 3 installed",
        "Adds RP profile data to diary entries. Not available until it's ported to Forever.")
end

local function BuildMemory(s)
    local pane, c = Pane(s)

    c:Heading("Forgetting")
    page.bufferDays = Number(c, "Forget people outside the diary after", "days", "bufferDays", 1, 365,
        function()
            -- A shorter window applies now, to both.
            ns.Interactions.Prune()
            ns.Sightings.Rollup()
            ns.Characters.Prune()
        end)
    c:Hint("Imagine adding a stranger to your diary after you've met them many times already."
        .. " This setting pre-saves stranger's data for this so interaction data is available even though they were always strangers. Data for people in your diary are kept indefinitely.")

    c:Heading("Your data")
    -- DAT-1: the page's one account setting, so it says so. Ticked is the
    -- diary loaded this session: a click puts the box back and asks, and
    -- only Reload saves the choice, which a load must read (ns.ShareDiary).
    page.shareDiary = c:Checkbox("Share one diary between all my characters",
        function() return ns.diaryShared end,
        function()
            local on = not ns.diaryShared
            page.shareDiary:SetChecked(ns.diaryShared)
            ns.UI.Confirm(ShareText(on), function()
                ns.ShareDiary(on)
                if ReloadUI then ReloadUI() end
            end, "Reload")
        end, nil, "Applies to every character. Switching reloads the interface.")
    page.controls[#page.controls + 1] = page.shareDiary

    -- Its text is the mode's; the mode stays until the next load.
    page.dataHint = c:Hint(DataText())

    page.size = Style.Text(pane, FONT.small)
    page.size:SetWidth(L.RIGHT_W)
    c:Place(page.size, 28, 0, 8)  -- two lines, whatever the numbers

    local ACCENT = Style.ACCENT
    page.sizeWarning = Style.Text(pane, FONT.small)
    page.sizeWarning:SetWidth(L.RIGHT_W)
    page.sizeWarning:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    c:Place(page.sizeWarning, 28, 0, 8)  -- room kept, so nothing below moves

    c:Heading("Deleting")
    c:Hint(("One person: Remove on their page, or type |cff%s/sd forget <name>|r for anyone"
        .. " else."):format(Style.HEX.strong))

    page.wipeSightings = Style.Link(pane, FONT.body, function()
        ns.UI.Confirm("Delete all sightings?\n\nDiary entries, sessions and interactions"
            .. " are kept.", function()
            ns.Sightings.DeleteAll()
            ns.Print("all sightings deleted.")
            AfterDelete()
        end)
    end)
    page.wipeSightings:SetText("Delete all sightings...")
    page.wipeSightings:SetColor(ACCENT[1], ACCENT[2], ACCENT[3])
    c:Place(page.wipeSightings, 18)

    page.wipeAll = Style.Link(pane, FONT.body, function()
        local shared = ns.diaryShared
        ns.UI.Confirm(WipeText(), function()
            ns.WipeData()
            ns.Print(shared and "the shared diary deleted." or "this character's diary deleted.")
            AfterDelete()
        end)
    end)
    page.wipeAll:SetText("Delete everything...")
    page.wipeAll:SetColor(ACCENT[1], ACCENT[2], ACCENT[3])
    page.wipeAll:SetPoint("LEFT", page.wipeSightings, "RIGHT", 18, 0)

    -- PRV-7: this character's road alone. Kept on, it begins again from
    -- here, with a prologue at today's level.
    page.wipeRoute = Style.Link(pane, FONT.body, function()
        ns.UI.Confirm("Delete this character's road?\n\nEvery stop, road, flight and level"
            .. " Your Diary kept for them goes. Diary entries, notes and sessions are kept.", function()
            ns.Journey.Delete(ns.ownGUID)
            if ns.JourneyCapture.On() then ns.JourneyCapture.SetEnabled(true) end
            ns.Print("this character's road deleted.")
            AfterDelete()
        end)
    end)
    page.wipeRoute:SetText("Delete this character's road...")
    page.wipeRoute:SetColor(ACCENT[1], ACCENT[2], ACCENT[3])
    c:Place(page.wipeRoute, 18, 0, 8)
end

local function BuildAbout(s)
    local pane, c = Pane(s)

    c:Heading("Thanks")
    local intro = Style.Text(pane, FONT.body)
    intro:SetWidth(L.RIGHT_W)
    intro:SetText("Willing impromptu Beta Testers:")
    c:Place(intro, intro:GetStringHeight(), 0, 8)

    page.testers = {}
    for i, name in ipairs(TESTERS) do
        local line = Style.Text(pane, FONT.strong)
        line:SetText(name)
        page.testers[i] = c:Place(line, line:GetStringHeight(), INDENT, 4)
    end
end

-- Called by the book as it is built (UI/Journal.lua), into the grey
-- ribbon's container.
function ns.UI.BuildSettingsPage(parent)
    page = parent
    page.controls, page.dependents, page.panes = {}, {}, {}
    BuildNav(parent)
    local build = { recording = BuildRecording, interface = BuildInterface, toasts = BuildToasts,
        shortcuts = BuildShortcuts, sounds = BuildSounds, integrations = BuildIntegrations,
        memory = BuildMemory, about = BuildAbout }
    for _, s in ipairs(SECTIONS) do build[s.key](s) end
    function page:Refresh() RefreshPage(true) end
    function page:ShowSection(key) ShowSection(key) end
    function page:Section() return section end
    return page
end

--------------------------------------------------------------------------
-- Blizzard's AddOns settings: a signpost
--------------------------------------------------------------------------

local function CloseBlizzardSettings()
    if SettingsPanel and SettingsPanel:IsShown() then
        if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
    end
end

local function Register()
    if category then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end

    local sign = CreateFrame("Frame")
    local title = ns.UI.Label(sign, "Social Diary", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local text = ns.UI.Label(sign, "The settings live in your journal now, behind the grey"
        .. " ribbon at the bottom of the book.", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    text:SetPoint("RIGHT", sign, "RIGHT", -16, 0)

    sign.open = ns.UI.Button(sign, "Open the settings", 170, function()
        CloseBlizzardSettings()
        ns.UI.ShowSettings()
    end)
    sign.open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)

    category = Settings.RegisterCanvasLayoutCategory(sign, "Social Diary")
    Settings.RegisterAddOnCategory(category)
end

ns.On("PLAYER_LOGIN", Register)

--------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------

-- `key`, if given, is the section or subpage to open on; else the one
-- open last this login.
function ns.UI.ShowSettings(key)
    ns.UI.ShowJournal()
    ns.UI.SetJournalView("settings")
    if key and page then ShowSection(key) end
end

-- The page, built with the book if it was not yet and brought up to date,
-- open or not. For the tests.
function ns.UI.SettingsPage()
    ns.UI.JournalFrame()
    RefreshPage(true)
    return page
end
