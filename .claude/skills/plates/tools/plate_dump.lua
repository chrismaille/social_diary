-- Your Diary's right page, dumped from the mock for plate_render.py.
-- Run through plates.sh (it builds the harness farm this needs); not a test.
--
-- For every /sd testdata entry: one SUMMARY line on stdout (pattern, each
-- plate's weight and moment kinds, what made the margin) and its geometry
-- in $SD_PLATES_OUT/out.txt. With $SD_PLATES_FORCE=1 (the default) each
-- weighted page (FL, LF, FFL, FLF, LFF, LFL, F+L) is also forced onto an
-- entry with that many plates, whatever their weights, so pages testdata
-- never produces still get drawn.
--
-- The mock measures text at a flat 14 px; captions are patched to wrap
-- roughly as the client does (body 6.6 px a letter, 15 px a line; the
-- hand 7 px a letter, 18 px a line). Real widths differ: screenshots win.
local T = ...
local ns = T.Boot()
local dir = os.getenv("SD_PLATES_OUT") or "/tmp/sd-plates"
local out = assert(io.open(dir .. "/out.txt", "w"))

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local LAYOUT = ns.UI.JourneyLook.LAYOUT
local Plate = ns.UI.JourneyPlate

out:write(("CONST %g %g %g %g %g %g\n"):format(Plate.SHADOW.out, Plate.SHADOW.blur, Plate.SHADOW.gain,
    Plate.SHADOW.spread, Plate.LIFT.height, Plate.LIFT.reach))

local function Patch(fs, per, line)
    if fs.patched then return end
    fs.patched = true
    fs.GetStringHeight = function(self)
        local width = (self.width or 0) > 0 and self.width or 1e9
        if not self.text or self.text == "" then return 0 end
        return line * math.max(1, math.ceil(#self.text * per / width))
    end
    fs.GetUnboundedStringWidth = function(self) return #(self.text or "") * per end
end
for _, pair in ipairs({ { "headingPool", 7, 18 }, { "captionPool", 6.6, 15 } }) do
    local pool = page[pair[1]]
    local next = pool.Next
    pool.Next = function(self)
        local fs = next(self)
        Patch(fs, pair[2], pair[3])
        return fs
    end
end

local function Summary(label, e)
    local kinds = {}
    for k, p in ipairs(e.plates or {}) do
        local ks = {}
        for _, m in ipairs(p.moments or {}) do ks[#ks + 1] = m.kind end
        kinds[k] = (p.light and "L" or "F") .. "(" .. table.concat(ks, ",") .. ")"
    end
    local margins = {}
    for i, plate in ipairs(page.plates) do
        if plate:IsShown() then
            local ks = {}
            for _, it in ipairs(plate.margin or {}) do ks[#ks + 1] = it.kind end
            margins[#margins + 1] = i .. ":" .. table.concat(ks, ",") .. (plate.print and ("+S(" .. plate.print.form .. ")") or "")
        end
    end
    print(("SUMMARY %-22s %-4s %s | margin %s"):format(label, tostring(page.pattern), table.concat(kinds, " "),
        table.concat(margins, " ")))
end

local function Dump(label)
    out:write(("PAGE %s %s\n"):format(label, tostring(page.pattern)))
    for i, p in ipairs(page.plates) do
        if p:IsShown() then
            local s = p.slot
            out:write(("PLATE %d %g %g %g %g %g %g %s %s %s\n"):format(i, s.x, s.y, s.w, s.h, s.t or 0, s.pad,
                s.pc or 0, table.concat(s.corners or {}, ","), s.lift or "-"))
        end
    end
    for _, key in ipairs({ "headingPool", "captionPool" }) do
        local pool = page[key]
        for k = 1, pool.used do
            local fs = pool[k]
            if fs:IsShown() and fs.text and fs.text ~= "" then
                local a = fs.recorded.points[#fs.recorded.points].args
                local calls = fs.recorded.calls.SetJustifyH
                out:write(("TEXT %s %g %g %g %g %s|%s\n"):format(key, a[3], -a[4], fs.width or 0,
                    fs:GetStringHeight(), fs.justifyH or calls and calls[1] or "LEFT", fs.text:gsub("\n", " ")))
            end
        end
    end
    -- Good luck told on a print (UI/LuckyCard.lua's S): its slip, its tag
    -- and its icon, each four corners on the page.
    for i, p in ipairs(page.plates) do
        if p:IsShown() and p.print then
            for _, part in ipairs({ "label", "tag", "icon" }) do
                local pts = {}
                for _, pt in ipairs(p.print.polys[part]) do pts[#pts + 1] = ("%g %g"):format(pt[1], pt[2]) end
                out:write(("PRINTSLIP %d %s %s\n"):format(i, part, table.concat(pts, " ")))
            end
        end
    end
    for _, link in ipairs(page.links) do
        local b = link.strip.box
        -- (S's own leader leaves the print: S is drawn above, PRINTSLIP.)
        if b and link.strip:IsShown() and not link.strip.polys then
            out:write(("NOTE %g %g %g %g %g %g\n"):format(b[1], b[2], b[3], b[4], link.mark[1], link.mark[2]))
        end
    end
end

local function Draw(i)
    page.open = i
    page.mode = "plates"
    ns.UI.RedrawJourneyPage()
end

for i, e in ipairs(page.recap.entries) do
    Draw(i)
    local label = "entry" .. i .. "_" .. tostring(e.level or "week")
    Dump(label)
    Summary(label, e)
end

if (os.getenv("SD_PLATES_FORCE") or "1") ~= "0" then
    -- Each weighted page on the first entry with that many plates (the
    -- tucked page kept off, so FL is FL).
    local function Force(key, n)
        for i, e in ipairs(page.recap.entries) do
            if e.plates and #e.plates == n then
                local layout, pattern = e.layout, e.pattern
                e.layout, e.pattern = LAYOUT[key], key
                Draw(i)
                Dump("forced_" .. key .. "_entry" .. i)
                e.layout, e.pattern = layout, pattern
                return
            end
        end
        print("NONE: no testdata entry has " .. n .. " plates to force " .. key .. " onto")
    end
    local tucked = LAYOUT.FL.tucked
    LAYOUT.FL.tucked = nil
    for key, slots in pairs(LAYOUT) do
        if type(key) == "string" and key ~= "F+L" then Force(key, #slots) end
    end
    LAYOUT.FL.tucked = tucked
    -- F+L as if FL's rule kept it (its `whole` test off), on every
    -- two-plate entry.
    if tucked then
        local whole = tucked[1].whole
        tucked[1].whole = nil
        for i, e in ipairs(page.recap.entries) do
            if e.plates and #e.plates == 2 then
                local layout, pattern = e.layout, e.pattern
                e.layout, e.pattern = LAYOUT.FL, "FL"
                Draw(i)
                Dump("forced_FpL_entry" .. i)
                e.layout, e.pattern = layout, pattern
            end
        end
        tucked[1].whole = whole
    end
end
out:close()
