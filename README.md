# Peggle Redux for World of Warcraft

Peggle is back in Azeroth. This is PopCap's 2009 Peggle addon, rebuilt for modern World of Warcraft clients: the same twelve levels, physics, scoring, talents, duels, battles and Peggle Loot.

Peggle Redux installs as its own addon (`PeggleRedux`) with its own saved data, so it can sit next to the original Peggle folder without either one touching the other. The original addon's code is kept, unmodified, in `original/` for reference and for the fidelity tests.

## Supported Clients

One download works on every supported client.

| Client | Interface | Status |
|---|---|---|
| **Retail** (Midnight) | `120100`, `120105` | Supported |
| **WoW Forever** | `16001` | Supported (beta client) |
| **Mists of Pandaria Classic** | `50504` | Supported |
| **Titan Reforged** (Wrath) | `38002` | Supported |
| **TBC Anniversary** | `20506` | Supported |
| **Classic Era** | `11509` | Supported |

Retail and WoW Forever no longer have Master Loot, so on those clients the group leader or an assistant starts Peggle Loot instead of the master looter.

## Installation

1. Download the latest release zip from the [Releases](https://github.com/Nighthawk42/wow_peggle_redux/releases) page.
2. Extract the `PeggleRedux` folder into your client's `Interface/AddOns/` folder, for example `World of Warcraft/_retail_/Interface/AddOns/` or `World of Warcraft/_classic_era_/Interface/AddOns/`.

Release archives include everything. If you install straight from a git checkout instead, run `scripts/fetch-libs.sh` first: the libraries (Ace3, LibDataBroker, LibDBIcon) are downloaded, not committed.

## Usage

- `/peggle` toggles the game window. Subcommands: `show`, `hide`, `options`, `resetwindow` (back to the middle of the screen at its normal size), `achievement` and `help`. `/peg` works too; if the original Peggle addon is also installed, use `/pegredux`, which always reaches this one.
- `/peggleloot [item]` starts a Peggle Loot challenge in your group: everyone with the addon gets one shot on the same board, and the highest score wins the item.
- Click the minimap button or the addon compartment entry to toggle the window; right-click the minimap button for options.
- Options are also under **Settings → AddOns → Peggle Redux**, including a key binding to toggle the window.

Duels and battles only work between players who both run Peggle Redux. The network protocol is new, so the original addon and Peggle Redux can't play each other.

## Feedback & Contributions

- If you run into a bug, please report it with the full error message.
- Contributions and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the code layout, the headless tests and the workflow.

## Documentation & License

- [Contributing Guide](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
- [Acknowledgements](ACKNOWLEDGEMENT.md)
- [License (MIT)](LICENSE) and [the original addon's notices](NOTICES.md)
