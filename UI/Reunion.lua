-- Reunion toasts (REU-1 to REU-3).
--
-- When a diary entry joins the user's group, a toast says who, with their
-- tags, when and where you last met, and how often. Core/Roster.lua fires
-- SD_REUNION *before* the join reaches Sessions, so "last met" is the
-- previous meeting rather than the one that is starting now.
--
-- REU-3: the addon's own frame, never Blizzard's alert system. The alert
-- system is shared, secure-adjacent machinery, and a taint there surfaces in
-- somebody else's code.
--
-- The toast is a card from the diary rather than a window: a loose sheet
-- (UI/LooseSheet.lua) laid over the game like the first-run slip
-- (UI/Intro.lua), with the timeline's rubricated heading, the profile's
-- portrait and name in capitals, and the last meeting in a sentence. It is
-- quiet: no sound and no motion, as it comes during play.
--
-- REU-2: nothing appears in combat. Toasts wait in a queue and the queue
-- moves on PLAYER_REGEN_ENABLED. One toast shows at a time; a raid full of
-- friends would otherwise bury the screen, so the queue is capped and the
-- overflow becomes one "and N more" toast at the end.
--
-- REU-5: the same toast when a diary entry comes into view (Capture/Nearby.lua),
-- never for someone already in the group.
--
-- Both kinds share one per-person cooldown. Whether a toast is due -- the
-- settings, the cooldown, the stamps it keeps -- is Core/Reunions.lua's.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local TOAST_SECONDS = 7
-- While the mouse is on it the card stays; once it leaves a card that is
-- past its time, the card goes this much later.
local LINGER_SECONDS = 1.5
local MAX_QUEUE = 5

-- The card: a slip kept between the diary's leaves, laid over the game near
-- the top of the screen, a little askew, the same way each time for the
-- same person (LooseSheet's Fall). In its own coordinates (x right, y down
-- from its top left): the margin; the middle of the heading's line, its
-- paraph's size and the darkness its rule starts at; the portrait's size
-- and top; how far in the name and the line under it start, beside the
-- portrait; the middle of the name, of that line and of the story's first
-- line, the step to the next and how many lines it may take. The story runs
-- the card's full measure, under the portrait. The margins leave a clear 11
-- pixels or more inside the warning's double rule (WARN_RULE ends 9 in), on
-- every card, so the warning only adds the rule and moves nothing.
local CARD = { w = 320, h = 135, top = -120, margin = 20,
    heading = 26, paraph = 6, rule = 0.40,
    portrait = 40, portraitTop = 36, indent = 70,
    name = 48, about = 67, story = 92, line = 16, lines = 2 }
-- Never folded: kept flat in the book, so no creases and no grime along
-- them, only paper a little uneven and corners curling up off the game.
local CREASE = {
    columns = { 0, 0.1, 0.5, 0.9, 1 }, rows = { 0, 0.5, 1 },
    folds = { columns = {}, rows = {} },
    crumple = 0.8, drift = 0.4, edge = 0.5, wander = 0.03,
    curl = { lift = 3, pull = 1.5 },
}

-- The heading, rubricated like a day on the timeline, by what brought them.
local HEADINGS = {
    group = "Joined your group",
    nearby = "Nearby",
    mixed = "Nearby and in your group",
}
-- The last card of a flood goes on from "AND 3 MORE".
local MORE = {
    group = "from your diary joined your group too.",
    nearby = "from your diary are nearby too.",
    mixed = "from your diary are about too.",
}
-- A warning: someone tagged foe or avoid. Their card says so in its
-- heading, its paraph is red (lapis on the others), and a double rule is
-- inked round it in red, like a notice: never colour alone. The tags in
-- the order they matter: in the group, the person to avoid; nearby, the foe.
local WARNINGS = {
    foe = { group = "A foe joined your group", nearby = "A foe, nearby" },
    avoid = { group = "Someone to avoid joined your group", nearby = "Someone to avoid, nearby" },
}
local WARNING_ORDER = { group = { "avoid", "foe" }, nearby = { "foe", "avoid" } }
-- The double rule, printed on the paper so it bends and takes the light
-- with it: how far in from the edge, the outer line's width, the gap, the
-- inner line's width, and how dark the red ink is.
local WARN_RULE = { inset = 4, outer = 2, gap = 2, inner = 1, alpha = 0.85 }

local queue = {}
local more, moreReason = 0, nil
local showing
local toast
-- The mouse on the card, and a card past its time waiting for it to leave.
local hovered, overdue = false, false
-- While the card is being placed: { onDone }. No toast shows meanwhile.
local placing

--------------------------------------------------------------------------
-- Content
--------------------------------------------------------------------------

-- Taken at the moment of the join, from the stats as they were before it.
local function Snapshot(guid, reason)
    local s = ns.People.Stats(guid)
    if not s then return nil end

    local tags = {}
    for i, tag in ipairs(s.entry.tags) do tags[i] = tag end

    return {
        guid = guid,
        reason = reason,
        name = s.name,
        record = s.record,
        guild = s.entry.guildAtAdd,
        tags = tags,
        relationship = s.entry.relationship,
        lastMet = s.lastMet,
        lastZone = s.lastZone,
        timesMet = s.timesMet,
        fights = ns.Interactions.Fights(guid),
    }
end

-- A word at a time: the story is wrapped by hand into separate lines, and
-- a colour opened on one line would not carry over to the next.
local function Em(text)
    return (tostring(text):gsub("%S+", function(word)
        return "|cff" .. Style.HEX.accent .. word .. "|r"
    end))
end

-- "3 days ago", but "on 12 Sep 2025".
local function When(time)
    local when = ns.UI.Ago(time)
    if when:match("^%d") and not when:find("ago$") then when = "on " .. when end
    return when
end

-- A foe's card tells the score instead (Interactions.Fights): "You've killed
-- them twice, they've killed you 5 times. Last fight 3 days ago in
-- Hillsbrad Foothills." Longest first, for the card to take the first that
-- fits.
local function FightStories(fights)
    local score = ns.UI.FightsText(fights, Em, true)
    if not score then return { "No blood between you yet." } end
    local last = "Last fight " .. Em(When(fights.last))
    local stories = {}
    if fights.zone then stories[1] = score .. " " .. last .. " in " .. Em(fights.zone) .. "." end
    stories[#stories + 1] = score .. " " .. last .. "."
    stories[#stories + 1] = score
    return stories
end

-- What there is to say about the last meeting, the way the profile says it
-- (UI/JournalProfile.lua), without the place when `place` is false.
local function Story(snap, place)
    if snap.timesMet == 0 then
        if snap.reason == "nearby" then
            local first = snap.name:match("^(%S+)") or snap.name
            return ("No interaction data yet."):format(first)
        end
        return "Your first time together since you wrote them in."
    end

    local when = When(snap.lastMet)
    local where = place and snap.lastZone and (" in " .. Em(snap.lastZone)) or ""

    if snap.timesMet == 1 then
        return ("You've met once, %s%s."):format(Em(when), where)
    end
    return ("You've crossed paths %s, last %s%s."):format(Em(snap.timesMet .. " times"), Em(when), where)
end

-- The record without some of what it says.
local function Without(record, ...)
    local copy = {}
    for key, value in pairs(record) do copy[key] = value end
    for _, key in ipairs({ ... }) do copy[key] = nil end
    return copy
end

-- Who they are, longest first: with the guild, without it, without the
-- race (the portrait shows it), then the class alone. A foe's faction
-- stays to the last: it matters more on a toast than any guild.
local function Whos(record, guild)
    record = record or {}
    local W = ns.UI.WhoLine
    return {
        W(record, guild, true),
        W(record, nil, true),
        W(Without(record, "race", "raceID"), nil, true),
        W(Without(record, "race", "raceID", "level"), nil, true),
    }
end

-- What the card says, as a table:
--   heading       why it came up
--   name          who, or "and 3 more" at the end of a flood
--   tags          the tags in small capitals, each in its own ink
--   relationship  as the user wrote it
--   who           who they are, for an entry with neither tags nor a
--                 relationship: "Level 12 Tauren Druid  <Guild>", the
--                 faction only when it is not the player's; longest
--                 first, for the card to take the first that fits
--   stories       what to say under them, longest first, for the card to
--                 take the first that fits: the last meeting with its
--                 place and without, or for a foe the score
--   warning       "foe" or "avoid", for the warning card, else nil
function ns.UI.ReunionText(snap)
    -- The sample laid out to be placed: the name line and the story read
    -- on as one sentence, the way "AND 3 MORE" does.
    if snap.place then
        return {
            heading = "Placing the toast",
            name = "Your toasts",
            stories = { "will appear where you leave this card." },
        }
    end
    if snap.more then
        return {
            heading = HEADINGS[snap.reason] or HEADINGS.mixed,
            name = ("and %d more"):format(snap.more),
            stories = { MORE[snap.reason] or MORE.mixed },
        }
    end

    local tags, has = {}, {}
    for i, tag in ipairs(snap.tags or {}) do
        local colour = Style.TAG_COLORS[tag] or Style.TAG_DEFAULT
        tags[i] = "|cff" .. Style.HexOf(colour) .. tag:upper() .. "|r"
        has[tag] = true
    end
    local reason = snap.reason == "nearby" and "nearby" or "group"
    local warning
    for _, tag in ipairs(WARNING_ORDER[reason]) do
        if has[tag] then
            warning = tag
            break
        end
    end

    local text = {
        heading = warning and WARNINGS[warning][reason] or HEADINGS[reason],
        name = snap.name,
        tags = tags[1] and table.concat(tags, "  ·  ") or nil,
        relationship = snap.relationship,
        stories = has.foe and FightStories(snap.fights) or { Story(snap, true), Story(snap, false) },
        warning = warning,
    }
    if not text.tags and not text.relationship then
        text.who = Whos(snap.record, snap.guild)
    end
    return text
end

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

local Pump

local function Dismiss()
    showing, overdue = nil, false
    if toast then toast:Hide() end
    Pump()
end

local function Hover(over)
    hovered = over
    if over or not overdue then return end
    local snap = showing
    C_Timer.After(LINGER_SECONDS, function()
        if showing == snap and not hovered then Dismiss() end
    end)
end

-- Where the card lies (settings.toastAt): its top's offset from the top
-- middle of the screen, so it stays put across resolutions the way the
-- default does. Nil for the default, CARD.top below the top.
local function Anchor(host)
    local at = ns.Setting("toastAt")
    local x, y = 0, CARD.top
    if type(at) == "table" and type(at.x) == "number" and type(at.y) == "number" then x, y = at.x, at.y end
    host:ClearAllPoints()
    host:SetPoint("TOP", UIParent, "TOP", x, y)
end

-- Reads back where it was dragged to, keeps that, and anchors it there
-- again. The frame is the screen's child at the same scale, so the two
-- measure alike. Not the client's own record of a frame moved by hand:
-- that one the addon could not move or reset.
local function Remember(host)
    local x, top = host:GetCenter(), host:GetTop()
    local screenX, screenTop = UIParent:GetCenter(), UIParent:GetTop()
    if x and top and screenX and screenTop then
        ns.db.settings.toastAt = { x = math.floor(x - screenX + 0.5), y = math.floor(top - screenTop + 0.5) }
    end
    host:SetUserPlaced(false)
    Anchor(host)
end

local function Build()
    local host = CreateFrame("Frame", "SocialDiaryToastFrame", UIParent)
    host:SetSize(CARD.w + 60, CARD.h + 60)
    host:SetFrameStrata("HIGH")
    -- Dragged, it stays on the screen: the card itself, not the margin
    -- left round it for its shadow and turn.
    host:SetMovable(true)
    host:SetClampedToScreen(true)
    host:SetClampRectInsets(30, -30, -30, 30)
    Anchor(host)
    host:Hide()

    -- Quiet: a card that comes by itself all evening should not rustle.
    local view, K = ns.UI.LooseSheet(host, CARD.w, CARD.h, { crease = CREASE, quiet = true })
    -- Only the card takes the mouse, not the game around it.
    view:EnableMouse(false)
    local S, M = view.sheet, CARD.margin
    host.view = view

    host.heading = Style.Text(S, FONT.headingRubric)
    host.paraph = K.Texture("ARTWORK", 2)
    host.rule = K.Texture("ARTWORK", 1)
    local R = Style.RUBRIC
    Style.Shade(host.rule, "HORIZONTAL", R[1], R[2], R[3], CARD.rule, 0)

    -- The warning's double rule, cut along the paper's mesh and lit with it.
    local rules = K.Pool("ARTWORK", 0)
    host.rules = rules
    local function Rule(x0, y0, x1, y1)
        local R = Style.RUBRIC
        K.Split(x0, y0, x1, y1, function(a, b, c, d, light)
            local texture = rules:Next()
            texture:SetColorTexture(R[1] * light, R[2] * light, R[3] * light, WARN_RULE.alpha)
            K.Bend(texture, a, b, c, d)
        end)
    end
    local function Box(inset, width)
        local x0, y0, x1, y1 = inset, inset, CARD.w - inset, CARD.h - inset
        Rule(x0, y0, x1, y0 + width)
        Rule(x0, y1 - width, x1, y1)
        Rule(x0, y0 + width, x0 + width, y1 - width)
        Rule(x1 - width, y0 + width, x1, y1 - width)
    end

    host.portrait = Style.Portrait(S, CARD.portrait)
    host.name = Style.Text(S, FONT.page)
    host.tags = Style.Text(S, FONT.heading)
    host.relationship = Style.Text(S, FONT.noteWritten)
    host.who = Style.Text(S, FONT.body)
    host.lines = {}
    for i = 1, CARD.lines do host.lines[i] = Style.Text(S, FONT.body) end

    -- The whole card is one button: left-click opens them in the journal,
    -- right-click puts it away, and either way the next one comes. While it
    -- is being placed, it is dragged instead.
    local button = CreateFrame("Button", nil, S)
    button:SetFrameLevel(S:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(_, which)
        if placing then return end
        local snap = showing
        Dismiss()
        if which ~= "RightButton" and snap then ns.UI.ShowJournal(snap.guid) end
    end)
    button:SetScript("OnDragStart", function()
        if placing then host:StartMoving() end
    end)
    button:SetScript("OnDragStop", function()
        host:StopMovingOrSizing()
        if placing then Remember(host) end
    end)
    Style.Tooltip(button, function()
        if placing then return { { "Drag to move it", 1, 1, 1 } } end
        if not showing then return nil end
        return {
            { showing.guid and "Click to open their page in the diary" or "Click to open the diary", 1, 1, 1 },
            { "Right-click to put it away", 0.75, 0.75, 0.75 },
        }
    end, "ANCHOR_BOTTOM", function(_, over) Hover(over) end)
    host.button = button

    -- Only while it is being placed, on the story's second line: done, or
    -- back where it started.
    host.done = K.Link(FONT.strong, function() ns.UI.StopPlacingToast() end)
    host.done:SetText("Done")
    host.reset = K.Link(FONT.body, function()
        ns.db.settings.toastAt = nil
        Anchor(host)
    end)
    host.reset:SetText("Put it back")
    for _, link in ipairs({ host.done, host.reset }) do
        link:SetFrameLevel(button:GetFrameLevel() + 1)
    end

    local function Show(text, ...)
        text:SetShown(... ~= nil)
        if ... ~= nil then K.PlaceText(text, ...) end
    end

    -- Escape hides the frame itself while it is being placed.
    host:SetScript("OnHide", function()
        if placing then ns.UI.StopPlacingToast() end
    end)

    function host:Fill(snap)
        local text = ns.UI.ReunionText(snap)
        self.text = text
        K.Fall("toast" .. (snap.guid or ""))
        K.Lay()
        K.PlaceButton(button, 0, 0, CARD.w, CARD.h)

        rules:Begin()
        if text.warning then
            local W = WARN_RULE
            Box(W.inset, W.outer)
            Box(W.inset + W.outer + W.gap, W.inner)
        end
        rules:Finish()

        -- The heading: a paraph, red capitals, and a red rule fading out to
        -- the margin.
        self.heading:SetText(text.heading:upper())
        local left, width = K.PlaceText(self.heading, M + 13, CARD.heading)
        local P = text.warning and Style.RUBRIC or Style.LAPIS
        self.paraph:SetColorTexture(P[1], P[2], P[3], 1)
        K.Place(self.paraph, M + 3, CARD.heading - CARD.paraph / 2, CARD.paraph, CARD.paraph, math.pi / 4)
        -- A heading that fills the line goes without its rule.
        local ruleX = left + width + 6
        local ruleW = CARD.w - M - ruleX
        self.rule:SetShown(ruleW >= 12)
        if ruleW >= 12 then K.Place(self.rule, ruleX, CARD.heading, ruleW, 1) end

        -- Their portrait, else the diary's own book.
        self.portrait:SetCharacter(snap.record)
        K.Place(self.portrait, M, CARD.portraitTop, CARD.portrait, CARD.portrait)

        -- The name in capitals; the first name alone where the whole is too
        -- wide.
        local room = CARD.w - CARD.indent - M
        self.name:SetText(text.name:upper())
        if K.Width(self.name) > room then
            self.name:SetText((text.name:match("^(%S+)") or text.name):upper())
        end
        K.PlaceText(self.name, CARD.indent, CARD.name)

        -- Under it the tags, then the relationship in the user's hand, if it
        -- fits; or who they are, for an entry with neither.
        local x = CARD.indent
        self.tags:SetText(text.tags or "")
        if text.tags then
            Show(self.tags, x, CARD.about)
            x = x + K.Width(self.tags) + 10
        else
            Show(self.tags)
        end
        self.relationship:SetText(text.relationship or "")
        local fits = text.relationship and x + K.Width(self.relationship) <= CARD.w - M
        if fits then Show(self.relationship, x, CARD.about) else Show(self.relationship) end
        -- Who they are: the longest that fits.
        for _, who in ipairs(text.who or { "" }) do
            self.who:SetText(who)
            if K.Width(self.who) <= room then break end
        end
        if text.who then Show(self.who, CARD.indent, CARD.about) else Show(self.who) end

        -- The story: the longest that fits. Being placed, it keeps its
        -- second line for the links.
        local most = snap.place and 1 or CARD.lines
        local measure, lines = CARD.w - 2 * M, nil
        for _, story in ipairs(text.stories) do
            lines = K.Wrap(story, measure, FONT.body)
            if #lines <= most then break end
        end
        for i, fs in ipairs(self.lines) do
            local line = i <= most and lines[i] or nil
            fs:SetText(line or "")
            if line then Show(fs, M, CARD.story + (i - 1) * CARD.line) else Show(fs) end
        end

        self.done:SetShown(snap.place == true)
        self.reset:SetShown(snap.place == true)
        if snap.place then
            local y = CARD.story + CARD.line
            self.done:PlaceAt(M, y)
            self.reset:PlaceAt(M + K.Width(self.done.label) + 16, y)
        end
    end

    return host
end

local function Display(snap)
    toast = toast or Build()
    showing, overdue = snap, false

    toast:Show()
    toast:Raise()
    toast:Fill(snap)
    toast.view:Show()

    C_Timer.After(TOAST_SECONDS, function()
        if showing ~= snap then return end
        if hovered then overdue = true else Dismiss() end
    end)
end

local function InCombat()
    return (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and ns.Plain(UnitAffectingCombat("player")))
end

Pump = function()
    if showing or placing or InCombat() then return end

    local snap = table.remove(queue, 1)
    if not snap and more > 0 then
        snap = { more = more, reason = moreReason }
        more, moreReason = 0, nil
    end
    if snap then Display(snap) end
end

ns.On("PLAYER_REGEN_ENABLED", function() Pump() end)

--------------------------------------------------------------------------
-- Placing the card
--------------------------------------------------------------------------
--
-- A sample card laid where toasts appear, to be dragged somewhere else:
-- from Settings (Move the toast) and whenever Blizzard's Edit Mode is open,
-- so it can be placed along with the rest of the screen. Edit Mode is only
-- listened to (EventRegistry's EditMode.Enter and EditMode.Exit), never
-- hooked, for REU-3's reason. A toast due meanwhile waits, the one showing
-- included; Done, Escape, Edit Mode closing or a fight starting ends it.

local SPECIAL = "SocialDiaryToastFrame"

local function Escapable(on)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == SPECIAL then table.remove(UISpecialFrames, i) end
    end
    -- Only while placing: a toast during play must not eat an Escape.
    if on then UISpecialFrames[#UISpecialFrames + 1] = SPECIAL end
end

-- `onDone` runs once it is placed: Settings opens the book again.
function ns.UI.PlaceToast(onDone)
    if InCombat() then
        ns.Print("the toast can be moved once the fight is over.")
        return false
    end
    toast = toast or Build()
    if placing then
        placing.onDone = onDone or placing.onDone
        return true
    end

    -- The toast showing comes back after, first in line.
    if showing then
        table.insert(queue, 1, showing)
        showing = nil
    end
    placing, overdue = { onDone = onDone }, false
    Escapable(true)
    toast:Show()
    toast:Raise()
    toast:Fill({ place = true })
    toast.view:Show()
    return true
end

function ns.UI.StopPlacingToast()
    if not placing then return end
    local onDone = placing.onDone
    placing = nil
    Escapable(false)
    toast:StopMovingOrSizing()
    toast:Hide()
    if onDone then onDone() end
    Pump()
end

function ns.UI.PlacingToast()
    return placing ~= nil
end

ns.On("PLAYER_REGEN_DISABLED", function() ns.UI.StopPlacingToast() end)

if EventRegistry and EventRegistry.RegisterCallback then
    local owner = {}
    EventRegistry:RegisterCallback("EditMode.Enter", function() ns.UI.PlaceToast() end, owner)
    EventRegistry:RegisterCallback("EditMode.Exit", function() ns.UI.StopPlacingToast() end, owner)
end

--------------------------------------------------------------------------
-- Forgetting
--------------------------------------------------------------------------

-- PRV-3: a toast still waiting to show a forgotten person goes, and so does
-- one showing them now. Their cooldown stamp is Core/Reunions.lua's store.
ns.RegisterStore("toasts", function(guid)
    if guid == nil then more, moreReason = 0, nil end

    for i = #queue, 1, -1 do
        if guid == nil or queue[i].guid == guid then table.remove(queue, i) end
    end
    if showing and (guid == nil or showing.guid == guid) then Dismiss() end
end)

--------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------

-- REU-1 and REU-5. `reason` is "group" (the default) or "nearby".
function ns.UI.Reunion(guid, reason)
    reason = reason or "group"
    local now = ns.Now()
    guid = ns.Reunions.Due(guid, reason, now)
    if not guid then return end

    -- Without a cooldown (a foe, settings.foeToastsUncooled) a nameplate
    -- at the edge of range comes and goes: one toast per person in line.
    if showing and showing.guid == guid then return end
    for i = 1, #queue do
        if queue[i].guid == guid then return end
    end

    local snap = Snapshot(guid, reason)
    if not snap then return end
    ns.Reunions.Greet(guid, now)

    if #queue >= MAX_QUEUE then
        more = more + 1
        moreReason = (moreReason == nil or moreReason == reason) and reason or "mixed"
    else
        queue[#queue + 1] = snap
    end
    Pump()
end

-- The foe alert's sound, for the Sounds settings to play as a sample too.
function ns.UI.PlayFoeAlert()
    ns.Style.PlaySound("foeAlert", "Master")
end

-- Capture says who; this file decides whether that is worth a toast, and
-- Core/Reunions.lua whether it is a foe worth a warning.
ns.On("SD_REUNION", function(_, guid, reason)
    if reason == "nearby" and ns.Reunions.FoeAlert(guid) then ns.UI.PlayFoeAlert() end
    ns.UI.Reunion(guid, reason)
end)

-- For the smoke test.
function ns.UI.ReunionShowing()
    return showing
end
