-- The journal window (JNL-1, JNL-2, JNL-4, JNL-6).
--
-- An open book, with no window frame: a leather cover round two pages. The
-- People list on the left page (search, sort, filters), the selected
-- person's page on the right (portrait, who they are, your note, the story
-- so far, then the timeline). An index tab on the right edge lays the map
-- on the book as a loose sheet (UI/HeatMap.lua). Ribbons hanging out of the
-- bottom of the book switch between the journal's pages: green for Your
-- Diary (8.11), red for People, purple for Recently nearby (JNL-3), grey
-- for the settings. The lists are virtual
-- (ns.UI.VirtualList), so the frame count stays fixed no matter how big the
-- diary grows. The look lives in the Style files (UI/StyleTokens.lua on).
--
-- This file keeps the book: its geometry, the state its pages share, the
-- ribbons and the entry points. The pages are files of their own: Your
-- Diary, the user's own road (UI/JournalJourney.lua, with its map plates
-- in UI/JourneyPlate.lua), the People list (UI/JournalPeople.lua), the profile (UI/JournalProfile.lua)
-- with its timeline (UI/JournalTimeline.lua, in the words of
-- UI/TimelineText.lua), Recently nearby (UI/NearbyPage.lua) and the
-- settings (UI/Settings.lua). In front of them lies the introduction: the
-- frontispiece (UI/JournalFrontispiece.lua), pencil and ink, then the front
-- matter (UI/JournalFront.lua), bookplate and contents. The book opens on
-- the frontispiece until the front matter has been read, and on Your Diary
-- after that (JRN-16);
-- an empty diary's People page teaches how someone gets in
-- (UI/JournalEmpty.lua).
--
-- The journal only reads. Editing goes through the entry dialog, which already
-- routes every change through ns.Diary; the journal refreshes when it closes.
--
-- JNL-5 (load the archive on demand, with a loading indicator) waits on the
-- DAT-2 archive split, which does not exist yet and whose LoD behaviour is
-- untested (T-H2). When it lands, ShowJournal loads it before the first query.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local WIDTH, HEIGHT = 840, 600
local COVER = 16  -- how far the cover reaches past the pages
local BOOK_W, BOOK_H = WIDTH - 2 * COVER, HEIGHT - 2 * COVER
local LEFT_PAGE = 286
local LEFT_X, LEFT_W = 26, LEFT_PAGE - 50
local RIGHT_X = LEFT_PAGE + 30
local PROFILE_W = BOOK_W - RIGHT_X - 26
local PROFILE_TOP, PROFILE_BOTTOM = 20, 14
local PROFILE_H = BOOK_H - PROFILE_TOP - PROFILE_BOTTOM

local INK = Style.INK
local LIST_BAR = { { INK[1], INK[2], INK[3], 0.10 }, { 0.45, 0.31, 0.14, 0.75 } }

-- The book's geometry, for the pages that live in their own files
-- (UI/JournalPeople.lua, UI/JournalProfile.lua, UI/NearbyPage.lua).
ns.UI.JOURNAL = {
    BOOK_W = BOOK_W, BOOK_H = BOOK_H,
    LEFT_X = LEFT_X, LEFT_W = LEFT_W,
    RIGHT_X = RIGHT_X, RIGHT_W = PROFILE_W,
    TOP = PROFILE_TOP, RIGHT_H = PROFILE_H,
    LIST_BAR = LIST_BAR,
}

-- The heading of one of the journal's pages, on the left page, and the
-- count to its right ("3 in the diary", "2 days"). Returns the count, for
-- the page to fill.
function ns.UI.PageHeading(book, text)
    local title = Style.Text(book, FONT.page)
    title:SetPoint("TOPLEFT", LEFT_X, -20)
    title:SetText(text)

    local count = Style.Text(book, FONT.small)
    count:SetPoint("BOTTOMRIGHT", book, "TOPLEFT", LEFT_X + LEFT_W, -36)
    count:SetJustifyH("RIGHT")
    return count
end

-- What the journal's files share (UI/JournalPeople.lua, UI/JournalProfile.lua,
-- UI/JournalTimeline.lua): the state below, and the functions one of them
-- calls in another. Every file reads and writes the state through this table;
-- a local copy would go stale as soon as another file changed it.
local J = {}
ns.UI.Journal = J

-- The journal's frame, once built, and whose page is open.
J.journal = nil
J.selected = nil

-- "map" while the map sheet lies on the book, else "timeline".
J.tab = "timeline"

-- Writing mode: the right page shows the entry form (UI/Entry.lua) in place
-- of the note, story and timeline or map.
J.editing = false

-- The People list's query, kept across opens within a login. The sort is
-- saved too and read back when the page is built (UI/JournalPeople.lua).
J.query = { search = "", sort = "lastMet" }

-- Which of the journal's pages is open: "journey", "people", "nearby" or
-- "settings", or the introduction in front of them all: "frontispiece",
-- then "front", the front matter. Each but those two has a ribbon (VIEWS),
-- and everything on a page lives in that
-- page's container. `page` is where it lies in the book: Your Diary first
-- (JRN-16), People next, Recently nearby and the settings last (negative
-- counts from the back).
local view = "journey"

local VIEWS = {
    { key = "journey", colour = "green", label = "Your Diary", page = 1 },
    { key = "people", colour = "red", label = "People", page = 2 },
    { key = "nearby", colour = "purple", label = "Recently nearby", page = -2 },
    { key = "settings", colour = "gray", label = "Settings", page = -1 },
}
local IS_VIEW = { frontispiece = true, front = true }
for _, v in ipairs(VIEWS) do IS_VIEW[v.key] = true end
local RIBBON_W, RIBBON_GAP = 22, 8

-- The book grows with the diary: a page for each of its own (VIEWS) and
-- one per entry between People and the back, up to BOOK_PAGES, with
-- FLYLEAVES blank ones at the back. Your Diary's own page is the first:
-- nothing lies under the left page there. The entries' pages are leafed
-- through in the order they are read: the first person opened lies on the
-- page after People's, the next on the one after that, and someone read
-- again turns back to their page. So the book moves forward a page at a
-- time instead of jumping between front and back. A closed book starts
-- over; once every page has been read, the rest share the last.
local BOOK_PAGES, FLYLEAVES = 25, 2

-- With the setting off (bookStack), a full even stack whatever is open.
local STILL_STACK = 6

-- Which page each entry read since the book opened lies on, the first
-- being 1, and how many have been given one.
local leaves, leafCount = {}, 0

-- The page `guid`'s entry lies on, given the next one the first time it is
-- read; nil for someone not in the diary.
local function EntryLeaf(guid)
    if not (guid and ns.Diary.Get(guid)) then return nil end
    if not leaves[guid] then
        leafCount = leafCount + 1
        leaves[guid] = leafCount
    end
    return leaves[guid]
end

-- Lays the stack beneath the open pages out for the page that is open:
-- what lies before it under the left page, what follows under the right.
-- People opens on the selected person's page, or on its own with nobody
-- selected.
local function TurnStack()
    if not ns.Setting("bookStack") then
        J.journal:FitPages(J.journal.book:SetStack(STILL_STACK, STILL_STACK))
        return
    end
    local entries = ns.Diary.Count()
    local pages = math.min(BOOK_PAGES, #VIEWS + entries)
    -- The frontispiece is the first leaf and the front matter the second:
    -- the whole book lies under the right page, Your Diary's with it.
    if view == "frontispiece" or view == "front" then
        local turned = view == "front" and 1 or 0
        J.journal:FitPages(J.journal.book:SetStack(turned, FLYLEAVES + pages + 1 - turned))
        return
    end
    local at, people
    for _, v in ipairs(VIEWS) do
        local page = v.page > 0 and v.page or pages + 1 + v.page
        if v.key == view then at = page end
        if v.key == "people" then people = page end
    end
    local leaf = view == "people" and EntryLeaf(J.selected)
    if leaf then
        at = people + math.min(leaf, pages - #VIEWS)
    end
    J.journal:FitPages(J.journal.book:SetStack(at - 1, FLYLEAVES + pages - at))
end

-- Shows one of the journal's pages, marks its ribbon and turns the stack
-- beneath to it. The pages that are not People read live data, so they are
-- brought up to date as they open.
local function ShowView()
    for key, container in pairs(J.journal.views) do
        container:SetShown(key == view)
        if J.journal.ribbons[key] then J.journal.ribbons[key]:SetActive(key == view) end
    end
    TurnStack()
    if view == "frontispiece" then
        ns.UI.RefreshFrontispiece()
    elseif view == "front" then
        ns.UI.RefreshFrontMatter()
    elseif view == "journey" then
        ns.UI.RefreshJourneyPage()
    elseif view == "nearby" then
        ns.UI.RefreshNearbyPage()
    elseif view == "settings" then
        ns.UI.RefreshSettingsPage()
    end
    -- Left before its end, the introduction asks to be gone back to
    -- (UI/JournalFrontispiece.lua).
    ns.UI.RefreshIntroLabel()
end

local function Build()
    -- The cover is the frame: no dialog border, no title bar.
    local panel = ns.UI.Panel("SocialDiaryJournalFrame", WIDTH, HEIGHT, nil, { bare = true, closeOutset = 8 })
    -- Below the entry dialog, which opens on top of it from the Edit button.
    panel:SetFrameStrata("HIGH")
    Style.Cover(panel, COVER, COVER + LEFT_PAGE)

    panel.book = Style.Book(panel, LEFT_PAGE, BOOK_W, BOOK_H)
    panel.book:SetPoint("TOPLEFT", COVER, -COVER)
    panel.book:SetPoint("BOTTOMRIGHT", -COVER, COVER)
    -- Closing the book ends writing mode; what was typed is kept.
    panel:HookScript("OnHide", function() ns.UI.EndJournalEdit() end)

    ns.On("SD_PAPER_CHANGED", function()
        panel.book:ApplyPaper()
        panel.book:ApplyGrain()
    end)

    -- One container per page of the journal, each covering the whole book.
    panel.views = {}
    for key in pairs(IS_VIEW) do
        local container = CreateFrame("Frame", nil, panel.book)
        container:SetAllPoints(panel.book)
        panel.views[key] = container
    end

    local people = panel.views.people
    J.BuildLeftPage(panel, people)
    panel.profile = J.BuildProfile(panel, people)

    panel.emptyProfile = Style.Text(people, FONT.faded)
    panel.emptyProfile:SetPoint("TOPLEFT", RIGHT_X, -PROFILE_TOP - 8)
    panel.emptyProfile:SetText("Choose someone from the list to read their page.")

    -- An empty diary's People page: how someone gets in, and what their
    -- page will be (UI/JournalEmpty.lua).
    J.BuildWelcome(panel, people)

    ns.UI.BuildFrontispiece(panel.views.frontispiece)
    ns.UI.BuildFrontMatter(panel.views.front)
    ns.UI.BuildJourneyPage(panel.views.journey)
    ns.UI.BuildNearbyPage(panel.views.nearby)
    ns.UI.BuildSettingsPage(panel.views.settings)

    -- The ribbons, left to right in VIEWS order, on the left page: they turn
    -- the journal's main pages, while the right page's index tabs belong to
    -- whatever page is open. Mirrors where the ornamental one hung on the
    -- right.
    panel.ribbons = {}
    local x = 112 - RIBBON_W
    for _, v in ipairs(VIEWS) do
        -- A ribbon pulled turns the book to its page, with the sound of it:
        -- from the introduction too, which playtesters asked for.
        panel.ribbons[v.key] = Style.BookRibbon(panel.book, x, RIBBON_W, COVER, v.colour, v.label, function()
            if view ~= v.key then Style.PlaySound("pageTurn") end
            ns.UI.SetJournalView(v.key)
        end)
        x = x + RIBBON_W + RIBBON_GAP
    end

    return panel
end

--------------------------------------------------------------------------
-- Entry points (JNL-4)
--------------------------------------------------------------------------

-- Turns the right page to writing mode on `guid`. False when the journal is
-- closed, so the caller opens the loose sheet instead.
function ns.UI.EditInJournal(guid, focusNote)
    if not J.journal or not J.journal:IsShown() then return false end
    J.selected = ns.SafeGUID(guid)
    J.editing = true
    view = "people"
    ShowView()
    J.journal.people:Refresh()
    J.RefreshProfile()
    if focusNote then J.journal.profile.form.note:SetFocus() end
    return true
end

-- Back from writing mode to the page.
function ns.UI.EndJournalEdit()
    if not J.editing then return end
    J.journal.profile.form:Commit()
    J.editing = false
    J.RefreshProfile()
end

function ns.UI.SelectPerson(guid)
    if J.editing then ns.UI.EndJournalEdit() end
    J.selected = ns.SafeGUID(guid)
    if not J.journal then return end
    TurnStack()
    J.journal.people:Refresh()
    J.RefreshProfile()
end

-- Turns to one of the journal's pages: "frontispiece", "front", "journey",
-- "people", "nearby" or "settings".
function ns.UI.SetJournalView(key)
    if not IS_VIEW[key] then return end
    if key ~= "people" and J.editing then ns.UI.EndJournalEdit() end
    view = key
    if not J.journal then return end
    ShowView()

    -- The Recently nearby page adds people; the list has to know. Diary.Add
    -- moved the data version, so the list's query sees them.
    if key == "people" then
        J.RefreshList(true)
        J.RefreshProfile()
    end
end

-- After the bookStack setting changed.
function ns.UI.TurnJournalStack()
    if J.journal then TurnStack() end
end

function ns.UI.JournalView()
    return view
end

-- Whether the journal is open, and with `key`, on that page. Every refresh
-- below asks this first: a closed book is brought up to date when it opens
-- (ShowJournal), so repainting it in the meantime is wasted work.
function ns.UI.JournalShowing(key)
    if not J.journal or not J.journal:IsShown() then return false end
    return key == nil or view == key
end

-- After anything that may have changed what the journal shows: on
-- SD_DIARY_CHANGED, or called directly. It re-queries the People index, which
-- has already noticed the write (ns.Touch), so it is for edits, not for
-- keystrokes.
--
-- The loose entry sheet follows the same edits, journal open or not: an
-- entry edited on the journal's page, or deleted by /sd testdata remove,
-- would otherwise stay on the sheet as it was.
function ns.UI.RefreshJournal()
    ns.UI.RefreshEntry()
    if not ns.UI.JournalShowing() then return end
    TurnStack()
    J.RefreshList(true)
    J.RefreshProfile()
end
ns.On("SD_DIARY_CHANGED", function() ns.UI.RefreshJournal() end)

-- The timeline alone, where it scrolled to: an episode opened or folded.
function ns.UI.RefreshTimeline()
    if not ns.UI.JournalShowing() or not J.selected or J.editing or J.tab ~= "timeline" then return end
    J.RefreshTimelineList()
end

-- Opened on nobody in particular before the front matter has been read
-- (PRV-4), it opens on the introduction, at the frontispiece; after, on whichever page was open last, Your
-- Diary to begin with (JRN-16). Opened on someone, it opens on them: the
-- slip keeps asking for the front matter until it has been read.
function ns.UI.ShowJournal(guid)
    J.journal = J.journal or Build()
    -- A book opened afresh is leafed through from the start again.
    if not J.journal:IsShown() then leaves, leafCount = {}, 0 end
    if guid then
        J.selected = ns.SafeGUID(guid)
        view = "people"
    elseif not ns.Setting("frontRead") then
        view = "frontispiece"
    end

    -- Shown before the page is chosen: the Recently nearby page only
    -- refreshes into an open book.
    J.journal:Show()
    J.journal:Raise()
    ShowView()

    -- People.Index rebuilds by itself when the data moved on (ns.Touch), so
    -- opening an unchanged diary twice builds it once.
    J.RefreshList()
    J.RefreshProfile()
end

-- The book, built if it was not yet, without opening it: for the settings
-- page's accessor (UI/Settings.lua), which tests reach for closed.
function ns.UI.JournalFrame()
    J.journal = J.journal or Build()
    return J.journal
end

function ns.UI.CloseJournal()
    if J.journal then J.journal:Hide() end
end

function ns.UI.ToggleJournal()
    if J.journal and J.journal:IsShown() then
        ns.UI.CloseJournal()
    else
        ns.UI.ShowJournal()
    end
end

BINDING_NAME_SOCIALDIARY_JOURNAL = "Open the journal"

function SocialDiary_ToggleJournal()
    ns.UI.ToggleJournal()
end

function SocialDiary_OnCompartmentClick()
    ns.UI.ToggleJournal()
end
