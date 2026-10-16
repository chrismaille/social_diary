# Social Diary

A World of Warcraft addon that remembers the people you meet in the open world —
groups, trades, whispers, fights, deaths, sightings, reunions — and presents them,
plus your own journey (levels, firsts, zones, sessions), as a hand-written,
paper-styled journal. Open with `/sd`.

## Target game: WoW Forever

This is **WoW Forever** (currently in beta): a classic-era game (classic content,
rules and world) running on the **retail addon API**. Use retail API names and
patterns (`C_*` namespaces, Settings API, AddonCompartment, etc.), but expect
classic gameplay. Interface version is in `social_diary.toc`.

## Where to find what

| Path | Contents |
|---|---|
| `social_diary.toc` | Load order, SavedVariables (`SocialDiaryDB`, `SocialDiaryCharDB`) |
| `Core/` | Data model and logic: DB, identity, people, diary, timeline, journey, sessions, reunions, slash commands, event wiring; the registries features plug into (`Rows.lua`, `Journey.RegisterList`, `JourneyRecap.RegisterMoment`) |
| `Core/Bridges/` | Optional integrations (Questie) |
| `Capture/` | Game-event listeners for the diary's substrate (group, sessions, sightings, the journey route) |
| `UI/` | A folder per area: `Style/` (the design system: tokens, art, sounds, drawing, book, cover, widgets, a person's pieces), `Kit/` (shared frames, lists, keys, the confirm popups), `Paper/` (loose sheets, strips, note and link sheets), `Ink/` (trail, blots), `Map/` (map art, overlays, the heat-map sheet), `Words/` (timeline wording), `Journal/` (the book and its pages), `Journey/` (Your Diary: page, plates, words), `Settings/` (the page, its kit, the quiet list, macros, `Sections/` one file per section), `Windows/` (entry, picker, `Reunion/` the reunion toast, `Intro/` the login parcel), `Blizzard/` (tooltip and Social tab hooks, the AddOns settings signpost, key bindings). Namespaces, registries, the card contract and load order: `.claude/rules/ui.md` |
| `.impeccable.md` | The book's design context: audience, brand voice, aesthetic direction, the map sheet as the example to follow. The design skills say to read it before any UI work |
| `Features/<Name>/` | One detection each, whole (chat, trade, level-ups, World PvP, duels, rare kills, deaths, witnesses, close calls, hunts, firsts found, quest finales, profession caps, campfires): its row kind, route list, recap moment, mark, margin note, words, capture, static data and test data, registered into `Core/` and `UI/`. Core never names a feature. How to add one: the `/new-feature` skill (`.claude/skills/new-feature/`) |
| `Dev/` | Debug tools and test data (`/sd art`, `/sd journey`, `/sd testdata`), fenced out of releases |
| `tests/` | Offline test suite against a WoW API mock (`wowmock.lua`). Run: `luajit tests/run.lua` (`-v` verbose, or pass file names) — add new files to `FILES` in `run.lua`. `tests/golden/golden.sh <label>` and `compare.sh <before> <after>` prove a refactor changed nothing (`.claude/rules/ui.md`) |
| `docker-compose.yml`, `scripts/link-addon.sh` | The Retail simulator (wow-ui-sim) and the setup script: `make install ADDONS=<game root, _retail_ or Interface/AddOns>` links the clone into the game as `social_diary` (the path is remembered in the gitignored `.wow-addons`); without the client, `docker compose run --rm sim lua-errors` lists the startup errors and `... dump-tree --visible-only` dumps the frame tree. The simulator models Retail 12.0.7 |
| `Makefile`, `.luacheckrc`, `.pre-commit-config.yaml` | `make check` — the lint and the tests (`make lint`, `make tests` on their own). `make lint` runs the pre-commit hooks themselves, over every tracked file and the new ones not yet staged; `make tests` runs the suite offline. The lint config keeps the client's globals by hand, since the beta interface does not match the published WoW definitions; the hooks add file hygiene. First setup after a clone: `make install` (see the row above). |
| `.claude/` | Skills (`skills/`: copywriter, new-feature, plates, release-version) and project rules (`rules/`: `ui.md` — where UI code goes and how it plugs in; `settings.md` — per character or per account, schemas and migrations; `changelog.md` — changelog entries) are in the repo. The PRD, plans, research notes and UI proposals stay local and untracked (`.gitignore`); code comments cite them by name and requirement ID |
| `CHANGELOG.md` | Release notes |
| `README.md`, `CONTRIBUTING.md`, `.github/` | Public front door: install, privacy, credits; contributor guide; CI (`tests.yml`), release (`release.yml`), issue forms |
| `Fonts/`, `Bindings.xml`, `.pkgmeta`, `LICENSE` | The Neuton font (OFL); the journal and _Remember this_ keybinds; packaging — what a release leaves out (`.claude`, `Dev`, `scripts`, `docker-compose.yml`, `tests`, every `Features/*/Dev.lua`, the TOC's `#@do-not-package@` block); MIT |

Never commit images (`*.png` is gitignored) or anything recorded from real players (names, GUIDs, chat). Tests and examples use invented names.

## Rules

Run `make check` after every change, before calling it done, and report what it printed: luacheck with the suite, green. The lint is strict — fix what it finds instead of ignoring it. The only ignores in `.luacheckrc` are the implicit `self` of a colon method that does not use it, and, under `tests/`, what the mock must write and the fixture names it reuses.

The addon is live, so players' saved data has to survive every update. Never drop, move or reinterpret saved fields without a migration: bump the matching schema in `Core/DB.lua`, add a `STEPS` entry, and test it on an old-shaped table (`.claude/rules/settings.md`).

When working on UI, invoke a subagent and supply it with the /frontend-design skill, as this agent has the expertise to design the UI.

Work on Your Diary's plates (layouts, captions, margin notes and cards, marks, the full zone page) goes to a subagent that loads /plates (`.claude/skills/plates/`) as well as /frontend-design.

If you work on any text a player reads, give it to the /copywriter skill (`.claude/skills/copywriter/`) using a subagent. Anything a player notices gets one line in `CHANGELOG.md` under `## [Unreleased]` (`.claude/rules/changelog.md`).

New detections (`Features/<Name>/`) go through /new-feature (`.claude/skills/new-feature/`), from the first idea to the in-client rounds. It is the reference for what a feature touches; when a run teaches something new, update the skill.

Releases go through /release-version (`.claude/skills/release-version/`).
