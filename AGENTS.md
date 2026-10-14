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
| `Core/` | Data model and logic: DB, identity, people, diary, timeline, journey, sessions, reunions, slash commands, event wiring |
| `Core/Bridges/` | Optional integrations (Questie) |
| `Capture/` | Game-event listeners that record interactions (group, trade, whisper, combat, deaths, PvP, sightings, journey) |
| `Data/` | Static data tables (e.g. quest-chain finales) |
| `UI/` | Journal frames and pages, cards, toasts, heat map, settings; shared style in `Style*.lua` |
| `Features/<Name>/` | One detection each, whole (so far `Campfire/`): its row kind, route list, recap moment, mark, margin note, words, capture and test data, registered into `Core/` and `UI/`. Layout and checklist: `.claude/registry-refactor.md`, "A feature's folder" |
| `Dev/` | Debug tools and test data (not for release) |
| `tests/` | Offline test suite against a WoW API mock (`wowmock.lua`). Run: `luajit tests/run.lua` (`-v` verbose, or pass file names) — add new files to `FILES` in `run.lua` |
| `.claude/` | Skills (`skills/`) and project rules (`rules/`) are in the repo. The PRD, plans, research notes and UI proposals stay local and untracked (`.gitignore`); code comments cite them by name and requirement ID |
| `CHANGELOG.md` | Release notes |
| `README.md`, `CONTRIBUTING.md`, `.github/` | Public front door: install, privacy, credits; contributor guide; CI (`tests.yml`), release (`release.yml`), issue forms |

Never commit images (`*.png` is gitignored) or anything recorded from real players (names, GUIDs, chat). Tests and examples use invented names.

## Rules

When working on UI, invoke a subagent and supply it with the /frontend-design skill, as this agent has the expertise to design the UI.

Work on Your Diary's plates (layouts, captions, margin notes and cards, marks, the full zone page) goes to a subagent that loads /plates (`.claude/skills/plates/`) as well as /frontend-design.

If you work on more text a player reads, give it to the /copywriter skill (`.claude/skills/copywriter/`) using a subagent.

Releases go through /release-version (`.claude/skills/release-version/`).
