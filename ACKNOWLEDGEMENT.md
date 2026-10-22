# Acknowledgements

*Peggle Redux* is built on PopCap's Peggle addon for World of Warcraft.

## Original Game & Assets

- **PopCap Games, Inc.** (now Electronic Arts)
  Creator of *Peggle* and of the original World of Warcraft addon (2009).
  *(c) 2007, 2009 PopCap Games, Inc. All rights reserved.*
  The original addon team is credited in the in-game Credits screen: Michael Fromwiller (programmer), T. Carl Kwoh (producer), Tysen Henderson and Noah Maas (artists), Stephen Notley (level design), and Ed Miller and Eric Olson (quality assurance).

## Community Contributors

- **Nighthawk ([`Nighthawk42`](https://github.com/Nighthawk42))**
  - Project maintenance and Peggle Redux (deobfuscation and modular rewrite).

## Third-Party Libraries

- **[Ace3](https://www.wowace.com/projects/ace3)** (AceAddon, AceDB, AceDBOptions, AceEvent, AceTimer, AceConsole, AceComm, AceSerializer, AceGUI, AceConfig), with LibStub, CallbackHandler and ChatThrottleLib
  Copyright (c) 2007, Ace3 Development Team. See the license bundled with the library.
- **[LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1)** by Tekkub.
- **[LibDBIcon-1.0](https://www.curseforge.com/wow/addons/libdbicon-1-0)** by the WowAce community.

The libraries are fetched at build time (see `.pkgmeta`) and are not part of this repository.

## AI Assistance Disclaimer

Parts of Peggle Redux were produced with **Claude Opus 5.5**, a large language model by Anthropic, under the direction and review of the maintainer. This includes deobfuscating the original code, the modular rewrite, the modern API updates, the headless tests and this documentation. PopCap's original game design, levels, sounds and art (`images/`, `sounds/`) were not generated or altered by AI.
