# Contributing to Peggle Redux

Thank you for helping maintain *Peggle Redux*. This guide covers setup, how the code is organized, the headless tests, and the rules that keep the game faithful to the original.

---

## Getting Started

1. Clone the repository and run `scripts/fetch-libs.sh` (Git Bash works on Windows) to download the libraries into `Libs/`.
2. Make the checkout visible to the game. Either copy it to `<client folder>/Interface/AddOns/PeggleRedux`, or link it so edits apply on `/reload`. Linking the same checkout into several clients lets you test them all:
   - Windows: `mklink /J "<WoW>\_retail_\Interface\AddOns\PeggleRedux" "<path to checkout>"`
   - macOS/Linux: `ln -s <path to checkout> "<WoW>/_retail_/Interface/AddOns/PeggleRedux"`
3. Only the runtime files are needed in-game: `PeggleRedux.toc`, `embeds.xml`, the code folders, `Libs/`, `images/` and `sounds/`.

---

## Supported Clients

All clients are served from the `main` branch and a single package:

| Client | Interface | Status |
|---|---|---|
| **Retail** (Midnight) | `120100`, `120105` | Supported |
| **WoW Forever** | `16001` | Supported (beta client) |
| **Mists of Pandaria Classic** | `50504` | Supported |
| **Titan Reforged** (Wrath) | `38002` | Supported |
| **TBC Anniversary** | `20506` | Supported |
| **Classic Era** | `11509` | Supported |

Check every new API against all of them (the [wow-api MCP server](https://www.npmjs.com/package/@nighthawk42/wow-api-mcp) answers this per flavor) and add a fallback where one is missing.

---

## Code Layout

| Folder | Contents |
|---|---|
| `Core/` | Bootstrap (`Init.lua`), constants, English strings, AceDB saved variables, level progress and talents, utilities, slash commands, login glue |
| `Data/` | Static tables: the twelve levels, atlas regions (`Art.lua`), talents |
| `Game/` | Round state, level building and moving pegs, collisions, scoring and talents, aiming, the engine tick, round flow |
| `UI/` | Main window, board sprites, effects, HUD, ball and fever tubes, summary, game menu, character select, menu tabs, duel and battle tabs |
| `Features/` | Addon messages, sound, duels, battles, Peggle Loot, the Exhibit A achievement, open/close triggers, minimap/LDB launcher |
| `Config/` | AceConfig options (in-window and in the Blizzard Settings panel) |
| `tests/` | Headless tests on a stubbed WoW API (not part of the download) |
| `original/` | The original Peggle 1.02 addon, unmodified, for reference and the fidelity test (not part of the download) |
| `scripts/` | Developer tools |

Conventions:
- Files share state through the addon namespace (`local _, ns = ...`) and the AceAddon object `ns.addon`. Never create globals.
- Code that creates frames runs from `ns.RegisterBuilder(name, func)`; event registration and login logic run from `ns.RegisterEnabler(name, func)`. Both run at `OnEnable`, builders first, in TOC order.
- The round state is `ns.game` (`Game/State.lua`). Settings live in `ns.db.profile`, level progress and talents in `ns.db.global.progress`, duel history and battles in `ns.db.char`.
- Board coordinates have their origin at the board's bottom-left corner, with y pointing up, and angles are in degrees, as in the original. `ns.Util.Atan2` returns degrees like the old WoW `atan2` global.
- Image regions come from `Data/Art.lua` (`ns.Art.Apply`, `Coords`, `Size`) instead of hard-coded texture coordinates.
- Lua 5.1 allows at most 60 upvalues per function; large functions should read rarely used constants as `C.NAME`.
- Settings are booleans (`true`/`false`), never `1`/`nil`.

Game events for features: `PEGGLE_LEVEL_END` (with the result table), `PEGGLE_LEVEL_ABANDONED`, `PEGGLE_SUMMARY_CLOSED`, `PEGGLE_PROGRESS_CHANGED`, `PEGGLE_TALENTS_CHANGED` and `PEGGLE_SETTING_CHANGED`, all sent with AceEvent's `SendMessage`. `Game/Game.lua` documents the result fields.

### Keeping the game faithful
The physics, aiming, scoring and timing in `Game/` are ported from the original line by line. Small changes in arithmetic matter: at a shared polygon corner two edges can tie, and floating-point rounding decides which one the ball bounces off. Keep the original's formulas and evaluation order even where a simpler form is algebraically equal, and run the fidelity test after any change in `Game/`.

### Midnight Restrictions (Retail and WoW Forever)
- Unit names can be *secret values* in instances, encounters and PvP. Check with `ns.Util.IsSecret()` before comparing them.
- Addon messages and chat can be locked down (`C_ChatInfo.InChatMessagingLockdown()`). Send everything through `ns.Comm.Send` and `ns.Comm.Chat`; they hold messages until the lockdown lifts.

### Libraries
Ace3, LibDataBroker-1.1 and LibDBIcon-1.0 are not committed. Release builds pull them in through the `.pkgmeta` externals. For local testing, run `scripts/fetch-libs.sh`.

---

## Headless Tests

`tests/run.py` loads the addon in TOC order on a stubbed WoW API, with the real Ace3 core libraries, inside Lua 5.1 (`pip install lupa`). It catches Lua errors, bad widget arguments and protocol mistakes without starting the game:

```
python tests/run.py play            # one round on each level with random aim
python tests/run.py play 3 --balls 60   # play level 3 until it is cleared
python tests/run.py ui              # every click, hover and show handler on each screen
python tests/run.py duel            # two clients play a duel against each other
python tests/run.py loot            # three-player Peggle Loot
python tests/run.py battle          # three-player battle; all must see the same standings
python tests/run.py fidelity        # same shots on the original and on Peggle Redux
```

The fidelity test needs `original/Peggle.lua`. It fires the same angles on the same peg layout at the same moments on both addons and compares, shot by shot, the pegs hit in order, the oranges hit, the balls left and the score. Every shot must match.

The stub can't show what a frame looks like, so layout, art and anything client-specific still needs an in-game check.

---

## In-Game Testing

- Test in-game before opening a PR: on Retail, and on at least one Classic client for anything that touches client-specific code. BugSack and BugGrabber catch silent Lua errors.
- At minimum, check:
  - First login: the legal notice, then the splash.
  - A Quick Play round through to the summary, with a free ball from the bucket and from the coin flip.
  - Extreme Fever and the score buckets, and a full clear.
  - The Talents, How To Play, Options and About screens.
  - A duel with a second account, and Peggle Loot in a group if you changed either.
- Code that can only be confirmed in-game is marked `-- TODO(in-game):`. If you verify one, remove the marker in your PR.

## Licensing & Asset Attribution
- New community contributions, fixes and maintenance code are licensed under the **[MIT License](LICENSE)**.
- The original game design, art, sounds, levels, text and addon code remain copyright **PopCap Games, Inc. / Electronic Arts** (see [NOTICES.md](NOTICES.md)).
- Credit original ideas, patches or third-party tools in [ACKNOWLEDGEMENT.md](ACKNOWLEDGEMENT.md).

## AI-Assisted Contributions
- AI tools may be used, but you are responsible for the result: read the code, test it in-game and make sure it follows this guide.
- Say in the PR description when a substantial part of a change was AI-generated.
