# Changelog

All notable changes to Peggle Redux. Versions follow [Semantic Versioning](https://semver.org/) and are independent of WoW client versions. The original addon's history (Peggle 1.0 to 1.02) is in `original/CHANGELOG`.

## [1.0.0] - 2026-10-22

- **Peggle Redux**: First release as its own addon (`PeggleRedux`). It can be installed alongside the original Peggle; `/pegredux` always opens this one.
- **All clients, one package**: Runs on Retail (Midnight), WoW Forever, Mists of Pandaria Classic, Titan Reforged, TBC Anniversary and Classic Era from a single download, with runtime checks where the APIs differ.
- **Rewrite**: The minified single `Peggle.lua` (Peggle 1.02 for WoW 3.3) was deobfuscated, then split into one file per system (`Core/`, `Data/`, `Game/`, `UI/`, `Features/`, `Config/`). The twelve levels, stored in the original as checksummed base-70 strings, are now readable tables in `Data/Levels.lua`.
- **Same game**: The physics, aim guide, scoring, Extreme Fever, style shots and talents are ported from the original code. A headless test (`tests/run.py fidelity`) replays the same shots on the original addon and on Peggle Redux and compares the pegs hit, oranges and score of every shot. Played in game on Retail; the Classic clients and WoW Forever have only been tested headlessly so far.
- **Libraries**: Built on Ace3 (AceAddon, AceEvent, AceTimer, AceConsole, AceDB, AceDBOptions, AceComm, AceSerializer, AceGUI, AceConfig), LibDataBroker-1.1 and LibDBIcon-1.0.
- **Fresh saved data**: Level scores, medals and talents start over in `PeggleReduxDB` (AceDB, with profiles). They stay shared by every character on the account, as in the original. The original's encoded `PeggleData` / `PeggleProfile` saves are not imported.
- **New network protocol**: Duels, battles and Peggle Loot use a versioned AceComm protocol with validated messages. It does not talk to the original addon. Messages wait while Midnight's chat lockdown is active.
- **Battles without a score server**: Every participant keeps the whole battle and whispers it to online participants, keeping each player's best score. The original elected one player to collect scores.
- **Peggle Loot on Retail**: Clients without Master Loot let the group leader or an assistant start it.
- **Options**: Built with AceConfig, shown in the Options tab and under Settings → AddOns, with a toggle key binding and profiles.
- **Minimap**: The minimap button now uses LibDBIcon, plus an addon compartment entry.
- **Auto open triggers** (login, death, flight start) are now opt-in and off by default. Closing on combat and ready checks is still on by default.
- **Modern widgets**: The talent tree, the Exhibit A achievement toast, the tab sparkles, dropdowns and the aim guide line are rebuilt on current APIs. The removed WotLK templates and globals they used are gone.

### Fixed from the original

- Unused balls during Extreme Fever showed "+10,000" each but were only added to the fever statistic; they now count toward the score too.
- More Cowbell and Unintended Awesome rolled one percent under the chance their tooltips state.
- "Auto-open on death" never worked (the setting and the event handler used different names).
- The "Requires 5 points" talent check tested for one point.
- In Quick Play, the second green peg was checked for spacing against the wrong peg.
- `/peggleloot` raised a Lua error while someone else's contest was running.
- A tied duel was recorded as a loss for both players, and two duel statistics were swapped between the players.
- New battles only notified invitees up to the first ended battle, and the 3-minute resend only reached the first battle in the list.
- An expired battle you hadn't played could still be started.
