---
name: plates
description: Work on Your Diary's map plates and everything written round them — slot layouts (LAYOUT, light/full weights, F+L), captions, margin notes and cards (paper strips, killer, close call, hunt, find, ...), leaders, marks, the full zone page. Load in a subagent (together with frontend-design) before changing or proposing anything on the right page of Your Diary; it maps the code, the rules the user has already decided, and the render/test tooling.
argument-hint: "[what to change on the plates]"
---

# Your Diary's plates

The right page of *Your Diary* (`/sd` → the green ribbon) shows the open
level's places as **plates**: windows of the zone map printed on photo
stock and glued in, each with a hand-written **caption** and **margin
notes** (taped paper strips and cards) with pencil **leaders** to marks on
the map. This skill is everything a fresh agent needs to work there
without rediscovering it.

Also load `frontend-design` (UI work in this project always goes through
it). If you add or change words a player reads, hand the copy to the
`copywriter` skill (`.claude/skills/copywriter/`) and don't write it yourself.

## 0. Before touching anything

1. Read `AGENTS.md` and `.impeccable.md` (design context, brand voice).
2. **Other sessions may edit these files between your steps.** Re-read a
   file right before editing it, use Edit (never whole-file rewrites), and
   don't revert changes you didn't make. Never commit; don't touch
   `CHANGELOG.md` (releases own it).
3. Run the baseline: `luajit tests/run.lua` from the addon folder (all
   green is normal; note anything already failing so you don't chase it).
4. Run the render baseline: `.claude/skills/plates/tools/plates.sh` (see §6).
   It prints what every testdata page lays out today.
5. Comments in this codebase are long prose explaining *why*, with dated
   in-client notes ("(11 Oct, in the client: …)"). Match that. A constant
   table gets a comment saying what each field means and why its value.
   When you change a value because of a screenshot, add the dated note.

## 1. The pipeline (data → page)

```
Core/JourneyRecap.lua                       UI/JournalJourney.lua                     UI/JourneyPlate.lua
Recap.Build(j) → entries (levels, weeks)
Recap.Moments(j, e, ctx) → moments ───────► PlatesOf(e)
Recap.Plates(j, e, ctx, cover) → plates ◄──   groups at SMALLEST[1..3] windows,
  (≤3, each {mapID,x0..y1,cx,cy,t,rank,        accepts the first grouping LayoutFor
   moments, light})                            gives a page for → e.plates/e.layout/e.pattern
Recap.Holds(plate, w, h)  ◄────────────────  LayoutFor(plates) → layout, key ("FL", …)
                                             DrawPlates(e): per plate a slot
                                               Plated(ctx, slot, over) ───────────────► plate:SetSlot / plate:Draw
                                                 Heading / Text.PlateCaption              (art, trail, marks, crosses,
                                                 WriteMargin → MarginOrder → LayNotes      killer/foe/hunt/find picks:
                                                 leaders (Aim/Pencil/Follow)               plate.killer/.foe/.hunt,
                                             DrawFull(e): FULL page, zoom/pan             plate.where[m] = page xy)
```

- **Moment kinds** (all of them): `session fight note first find death
  close luck fortune finale skill arrive dungeon stay road level`.
  `Recap.RANK` orders which open plates; a pin (`level`) never opens a
  plate alone unless nothing else exists.
- **Grouping**: a moment joins the first plate whose window it fits
  (`Fits`: the box spans ≤ `PLATES.inset` = 0.8 of the window). Windows are
  the slot's art box at **1 screen px per px of map art** (Decision 3;
  `Plate.Cover`), so a smaller slot = a smaller window = more plates.
- **Weight**: `plate.light` when every moment is in `Recap.LIGHT`
  (`arrive dungeon stay road level finale skill fortune`). It's a whitelist,
  so a new kind counts as full until someone weighs it.

## 2. Layouts (`UI/JournalJourney.lua`, `LAYOUT` and the comment above it)

Right page: 466 × 534 px (`RIGHT_H`), coordinates from its top left, y down.
A slot is `{ x, y, w, h, t (turn °, clockwise), pad (card margin round the
art), pc (photo-corner size), corners, lift ("br"/"bl": the corner come
unstuck), cap = { x, y, w, limit, align }, notes = { x, y, w } }`. Variants:
`top` (caption over the plate, notes in a `row` of boxes), `tucked`.

| Key | When | Shape |
|---|---|---|
| `LAYOUT[1]` | one plate | 444×364 plate, caption under-left, notes column right |
| `LAYOUT[1][1].top` | one plate, caption short | caption across the top, plate 444×343 at y37, notes in a row of 3 (x 10/160/310, w142, y400) |
| `LAYOUT[2]` | 2 plates: FF, LL | 260×236 top-left + 300×236 bottom-right |
| `LAYOUT[3]` | 3 plates: FFF, FLL, LLF, LLL | 242×176 TL, tall 192×234 right, 228×126 BL |
| `FL`, `LF` | full + light | full 260 wide and tall with a 176 px caption column the page's height; light = snapshot |
| `F+L` (`LAYOUT.FL.tucked`) | FL, tried first | full plate under a top caption, a 2-box row, a 140×100 print tucked bottom right |
| `FLF`, `FFL`, `LFF`, `LFL` | 3 plates | full slots 260 wide with 176 px captions, snapshots for L |
| `FULL` | a plate clicked | 446×484, fitted to the zone's height, scroll zoom / drag pan (`Plate.FULLZOOM`), click = back |

- **Snapshot** = `SNAPSHOT` / `Snap(x, y, t, corners, lift, cap)`: 176×124,
  pad 7 (art 162×110), pc 18. `LayoutFor` calls a plate `L` only if it is
  light **and** a snapshot holds it (`Holds`); otherwise it's `F`.
- **Picking** (`LayoutFor`): key from the weights in time order →
  `LAYOUT[key] or LAYOUT[#plates]`; returns nil if any plate doesn't hold in
  its own slot, so `PlatesOf` regroups at the next smaller window.
- **F+L rule** (`DrawPlates`): only for an FL pattern. Both plates must hold
  in the tucked slots; then `Plated(ctx, tucked[1], true)` keeps it only if
  the caption is short (heading 1 line, words ≤ 1 line, the `top` test)
  **and** the margin is whole (`tucked[1].whole`: nothing left off the
  2-box row). Otherwise FL, decided once per draw and never flipped back.
- `page.layout` = plate count, `page.pattern` = key or `"F+L"`.
- `SMALLEST[n]` is the smallest art box of `LAYOUT[n]` and drives grouping.
  **Changing a numeric layout's sizes changes how moments group.** Check
  testdata summaries before and after.

**Geometry rules (each one came from a screenshot):**
- Nothing touches the page edge. A lifted corner's shadow reaches
  `out + blur + (gain + spread) × LIFT.height` ≈ 9.9 px, so keep lifted
  corners ≥ 10 px inside the page. Known exceptions, left as is: the `top`
  variant (~1.6 px past the right edge), `LAYOUT[3]`'s bl lift (~4 px past
  the foot).
- One lifted corner per page; turns between about ±1° and ±2.2°,
  alternating; photo corners `FOUR` or `LOST` (one missing at the lift).
- Keep the lowest plate and its caption clear of the **not-kept line**
  (`OFF`: x 246, y 512, shown when "Keep my own route" is off). Notes stop
  at `CAPTION.offLimit` (506) then, else `CAPTION.limit` (528).
- A full plate's caption column is **≥ 176 px**: a close-call card names a
  long creature ("Razormane Battleguard") on one line with its level tag.
  At 136 px it was dropped (11 Oct). The 3-plate left column was widened for
  a strip plus a close-call card for the same reason.
- A caption left of its plate is `align = "RIGHT"` (it leans on its plate).
- The top plate may sit at y −2 (the paper runs 20 px above the page top).

## 3. Captions and the margin

- **Heading** (`Heading`): "The Barrens, yesterday" by hand
  (`FONT.noteWritten`, sizes `CAPTION.hand` 16 then 14, Neuton Italic). If
  it doesn't fit one line, the zone alone, and the day moves into the words.
  A plate on the same day as the one before counts on ("Twenty minutes
  later").
- **Words** (`Text.PlateCaption(p, began, named, killer, shown, foe,
  hunted)`): `FONT.body`. They name what the margin had no room for, so
  `Plated` writes the words, lays the margin, rewrites the words and lays
  again until they agree (`Mark`/`Undo` roll the pools back). Anyone a
  strip names is not named again in the words.
- **Margin order** (`MarginOrder`): tier-1 people (session, fight, note,
  added, find given) → firsts found (`FindCard.Items`) → witness (`UI/WitnessCard.lua`:
  someone who watched you die, tried to save you or saved you; it replaces the
  killer card, or a rescue the close call's) → killer → close call
  (`foe`) → lucky (good luck, `UI/LuckyCard.lua`; on a light plate's print
  it is the print's S instead, never in the margin) → hunt (bad luck, the
  first to go) → tier-2/3 people (first
  sightings, crossed). `WriteMargin` tries quoted notes at 3/2/1 lines
  (`QUOTES`) before dropping items; in a row, notes are re-sorted by their
  mark's x.
- **Notes** are laid by `LayNotes` into `boxes` (column under the caption,
  or `row` boxes, shared by `Shared`/`ROW.most`). Pools: `notePool`
  (`UI/PaperStrip.lua`), `findPool` (`UI/FindCard.lua`), `killerPool`
  (`UI/KillerCard.lua`, also the close-call card via `KillerCard.Foe`),
  `huntPool` (`UI/HuntCard.lua`), `witnessPool` (`UI/WitnessCard.lua`), `luckyPool` (`UI/LuckyCard.lua`: a card
  and its tag, a second slip, `card.tag`), `leaderPool`, `dotPool`.
- **S, good luck on a light print** (`LuckyCard.Print`, drawn by the plate in
  `DrawPrint` through its own toolkit, `PRINT_LAYERS` on the `over` frame,
  under the lift's shade): `plate.print` (form, polys, leader). F+L is not
  kept where S will not go on the tucked print (`LuckyCard.PrintFits`).
- **Leaders** (`LEADER`, `Aim`, `Pencil`, `Follow`): one per strip, graphite
  pen (not ink), leave the strip's nearest edge, enter over the plate edge
  nearest the strip, bow down slightly, end `stop` px short in a dot.
  `plate.where[m]` gives a mark's page position (through `plate:OnPage`).
- Copy lives in `UI/JourneyText.lua` (`PlateHeading`, `PlateCaption`,
  `MarginWhat`, `MarginQuote`, `KillerName`, `FoeTag`, `Hunt*`, `Find*`,
  `ZoneFoot`, tooltips). Changes there go through the copywriter skill.

## 4. The plate itself (`UI/JourneyPlate.lua`, header comment = spec)

The card is `ns.UI.LooseSheet(..., glued)`: everything is placed through its
toolkit (`K.Place`, `K.Quad`, `K.PlaceText`, `K.Pool`) so it turns with the
card. Look tables: `PLATE` (stock, desaturate, tint), `FRAME`, `VIGNETTE`,
`THICKNESS`, `SHADOW`, `MOUNT` (kraft photo corners), `GLUE`, `LIFT`,
`SHARE` (a smaller plate gets a share of the trail caps by area). Marks:
`MARK`, `PRIORITY`, `POUCH` (find), `CLOSE` (close call), `TALLY` (bad
luck), `FORTUNE` (good luck star), `FINALE`, `SKILL` (stairs), `DOOR`,
`DEATH`, `PIN`, `FLIGHT`; `SHAPES[kind]` draws them; `Radius`/`Apart` keep
them apart. The ink trail is `UI/InkTrail.lua`; map art and explored
overlays are `UI/MapArt.lua`. "Flat paper only" lays everything flat (no
turn, shadow, lift, glue, vignette). Drawing is pooled, deterministic
(seeded), once per open/turn, and nothing runs per frame.

## 5. Decisions already made (don't reopen without asking the user)

- **Only the open level** is drawn on plates and the full page. Other
  levels' roads and marks in pencil were removed as "graphic spam" (10 Oct).
- **No key/legend** on plates; tooltips explain ink and marks (Decision 7).
- **A first sighting shows only in hindsight**, and a person "matters" only
  through a diary add or an interaction row (group_join, trade, whisper,
  say), not by being seen again (11 Oct).
- **Killer card and close-call card both show** whenever possible, even for
  the same creature (12 Oct).
- **Light kinds** include finale, skill and fortune. A light plate a
  snapshot can't hold is drawn full. Plates are in strict time order, top
  to bottom (13 Oct).
- **Paper is the product**: depth, wear, shadows and material are wanted.
  When something reads badly, fix its shape, not its alpha. Never trade
  away text contrast.
- **Fixed scale** of 1 screen px per px of map art on close-ups. No
  stretching a window to fill a slot.
- A session gets one spot (`Recap.Settle`, the longest overlap). Per-stop
  session moments are an open proposal; don't build them unasked.
- No SavedVariables changes without asking. Plates are computed at view
  time.

## 6. Tooling

**Tests** (offline, against `tests/wowmock.lua`):
- `luajit tests/run.lua` (all) · `luajit tests/run.lua journey_ui` (one file)
  · `-v` (sections + addon output).
- Plate tests: `tests/journey_ui.lua` (sections "the open level's plates",
  "a zone's full page", "a page by its plates' weights …"),
  `tests/journey.lua` (Recap: grouping, weights, Holds),
  `tests/killer_card.lua`, `tests/combat_ui.lua` (close-call/foe cards on
  testdata pages), `tests/hunt_card.lua`, `tests/lucky_card.lua`,
  `tests/firsts.lua`.
- Useful handles: `ns.UI.JourneyPage()` (page: `.plates`, `.links`,
  `.recap.entries`, `.layout`, `.pattern`, pools), `ns.UI.RedrawJourneyPage()`,
  `ns.UI.JourneyLook` (LAYOUT, CAPTION, LEADER, ROW, FOOT, SNAPSHOT,
  LayoutFor…), `ns.UI.JourneyPlate` (Cover, Window, SHADOW, LIFT…). On a
  plate: `.slot`, `.window`, `.captionOver`, `.margin`, `.counts`,
  `.killer/.foe/.hunt`, `.where`.
- To open a page in a test: `page.open = i; page.mode = "plates";
  ns.UI.RedrawJourneyPage()`, or click the level's rubric row (see `Open`
  in journey_ui).
- **The mock measures every string at 14 px and ~6 px per character.** To
  test wrapping, patch `GetStringHeight` on the heading/caption pools'
  font strings (as the `top`/F+L tests and `plate_dump.lua` do).
- Use `luajit` only to run things. **Never `luajit -bl a b`**: the second
  argument is the output file and gets overwritten.
- Prove a new condition matters: break it in the source, watch its test
  fail, restore byte for byte.

**Geometry render** (no client needed): `.claude/skills/plates/tools/`
- `plates.sh [out-dir] [label-or-pattern …]` (default `/tmp/sd-plates`):
  - prints a `SUMMARY` per `/sd testdata` entry (pattern, each plate's
    weight and moment kinds, what made each margin);
  - forces every string key in `LAYOUT` (plus F+L) onto an entry with that
    many plates;
  - writes PNGs (plates, shadows, photo corners, caption and note boxes,
    leaders, the not-kept line in red, S on a print as `PRINTSLIP` slip/tag/
    icon) and prints checks (overlaps, shadows past the page, text past the
    foot or over the not-kept line, S's icon on its tag or off its print).
  - Look at the PNGs with Read. `SD_PLATES_FORCE=0` skips the forced pages.
- `plate_dump.lua` (runs in a symlink farm next to the real harness, so
  nothing is written in the addon), `plate_render.py` (pure Python +
  `pngio.py`; run with `python3 -I`).
- A clean render is not proof: text widths are estimates, there's no art,
  and real fonts differ. It catches overlaps and off-page geometry before
  you ask for screenshots.
- Testdata today (13 Oct): lv10 F+L, lv11 FL (lucky card L in the column),
  lv12 FF (light plate too wide → full; lucky card M2 in the 122 px column),
  lv13 FL (S on the print; F+L given up for it), lv14 one plate (lucky card
  XL in the row, L in the mock), lv15–16 one plate, week 1 LF, week 2 FFF. Witness cards (14 Oct): lv10 tried
  (M, F+L row), lv11 saved (L), lv13 watched (L), lv14 saw + two others (M),
  the cap's oasis mercilessly watched (XL on lv16's page, smaller on a week's),
  the crag on the last week tried (XL); the weeks fall by the calendar. None of FLF/FFL/LFF/LFL
  occur naturally; they're only seen forced. If a change needs them for
  real, add a testdata entry in `Dev/TestData.lua` (`TestData.WriteJourney`).

**Proposals**: mockups go to `.claude/ui-proposal/<name>-mockup.html` with a
`<name>-proposal.md`, drawn to the real 466×534 page. Reuse the
plate-weight mockup's page/slot drawing (`plate-weight-mockup.html`;
`#boxes` shows slot boxes, `#flat` lays everything flat). Older plate
mockups: `journey-moments-mockup.html`, `journey-plate-mockup.html`,
`hunt-card-mockup.html`, `killer-models-mockup.html`. Specs:
`.claude/journey-goal.md` (decisions D1–D11), `.claude/prd.md` (JRN-*),
`.claude/journey-revamp-plan.md`.

## 7. In the client

The user tests in WoW and sends screenshots. You can't see the client.
- `/sd testdata` writes the made-up diary and route (the real route is
  parked). `/sd journey stats | segments [n] | raw` (dev) shows the route.
  `/sd pen` tweaks the ink live.
- Stray or oversized textures don't show in the mock (it doesn't compute
  layout). To find them, the user runs a region-width scan: see the memory
  note `in-client-layout-diagnosis`.
- For data rather than looks, log to SavedVariables and read the file after
  a `/reload`. Don't ask for screenshots of long text output.

## 8. Finish with

1. `luajit tests/run.lua`: every file green (state any failure and whether
   it was there before you started).
2. `plates.sh`: summaries as intended, no new `!!` lines, and the PNGs
   looked at.
3. A report: files changed; behaviour and geometry changes with their
   reasons; any test expectation you changed and why; and a **numbered
   in-client checklist** (which `/sd testdata` level or week shows each
   change, and what to look for).
