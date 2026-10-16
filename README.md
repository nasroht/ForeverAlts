<div align="center">
  <img src="https://raw.githubusercontent.com/nasroht/ForeverAlts/main/media/logo.jpg" alt="ForeverAlts Logo" width="220" style="border-radius: 16px;" />
  <h1>ForeverAlts</h1>
  <p><strong>Manage your alts. Make the most of your rested XP. Keep your army working together.</strong></p>
  <p>
    <a href="https://github.com/nasroht/ForeverAlts/actions/workflows/ci.yml"><img src="https://github.com/nasroht/ForeverAlts/actions/workflows/ci.yml/badge.svg" alt="CI &amp; Release" /></a>
    <a href="https://www.curseforge.com/wow/addons/foreveralts"><img src="https://img.shields.io/badge/CurseForge-1747176-orange.svg" alt="CurseForge" /></a>
    <a href="https://github.com/nasroht/ForeverAlts/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" /></a>
  </p>
</div>

---

ForeverAlts was created to solve a problem I had as a World of Warcraft player: managing an army of alts.

My goal in WoW has always been to have 3–4 main characters, supported by a bunch of alts. Characters to level, professions to maintain, materials to gather, and rested XP to make the most of. Before long, keeping track of everything becomes a job of its own.

ForeverAlts is my solution to that problem.

---

## What does it do?

### Rested XP and Levelling

ForeverAlts tracks your characters' levels, current XP, rested XP, and rested XP progression. It also remembers where each character logged out and whether they were resting in an inn or another location.

The idea is simple: know which character to play next and make the most of your available rested XP. Spend less time figuring out who to level and more time actually playing.

### Profession-Based Mailing Routes

Gathering materials on one character only to need them on another is part of the alt life. ForeverAlts helps keep that organised.

You can assign characters with crafting professions as recipients for the relevant reagents and materials. You can also designate a primary cook to receive meat and other cooking supplies.

The mailing route feature is deliberately straightforward: configure who should receive what, and let your characters work together instead of leaving useful materials scattered across your roster.

### Character and Progression Tracking

ForeverAlts keeps useful information about your characters in one place:

- **Character levels and XP progression**
- **Rested XP and rested location**
- **Last logged-out location**
- **Gold balances**
- **Professions and profession skill levels**
- **Dungeon lockouts** *(experimental; still needs testing)*
- **Legacy rested perks**, configurable from 0 to 5 points per character

### Combined Bags

There's also a small extra: ForeverAlts can sort your combined bags. Look for the little icon in the top-right corner.

---

## Why ForeverAlts?

I mainly made this addon for myself. I wanted something that did what I needed, without a pile of features I didn't.

ForeverAlts is about managing a roster, making efficient use of rested XP, and getting materials to the characters who need them.

Nothing more, nothing less.

If you're also playing WoW with a growing army of alts, I hope it helps you as much as it helps me.

---

## Dashboard Overview & Features

ForeverAlts provides a focused, retro-terminal dashboard with 8 dedicated tabs:

1. **Overview (`/fa 1`)**:
   - **Next Session / Play Next Cards**: Instant recommendations highlighting who to play next based on rested XP waste, current rested bonus, and time to cap.
   - **Dual Circular Gauges**: At-a-glance circular meters showing current level XP progress (`% of lvl`) and rested XP (`% of level` with precise decimal display and progress toward cap).
   - **Details Subline**: Accrual telemetry (`+... XP/h (Inn)` or `Wild · 4x in Inn`) and countdown time to cap.
   - **Urgency Highlights**: Capped and XP-wasting alts are highlighted with warning indicators so you never miss banked rested gains.
   - **Liquid Wealth**: Coin display with colored gold, silver, and copper tokens.

2. **Forever Route (`/fa 2`)**:
   - Strategic leveling priority ranking and rotation recommendations across cohort tiers (**`CORE`**, **`RESERVE`**, **`BANK`**).

3. **Rested XP Monitor (`/fa 3`)**:
   - 10 streamlined analysis columns with right-aligned numeric data: Current XP, Rested Pool, Perk Bonus, Rested Cap, Rest Location, and Time to Cap.
   - Progress bars calibrated to individual perk caps with standardized states (`Accruing`, `[CAPPED]`, `[+WASTED]`).

4. **Professions (`/fa 4`)**:
   - Primary and secondary profession ranks, skill caps (75/150/225/300), and recipe discovery tracking.

5. **Economy (`/fa 5`)**:
   - Total account treasury across all alts, individual gold balances, and wealth trends.

6. **Cooldowns & Locks (`/fa 6`)**:
   - Crafting trade cooldowns (Transmutes, Mooncloth, Salt Shaker) and raid/dungeon instance reset timers.

7. **Mail Routing (`/fa 7`)**:
   - Automated supply chain routing: 1-click `[ AUTO-FILL ]` button at mailboxes to attach matching crafting materials and set the correct alt recipient.
   - Includes cross-faction safety guards and a customizable `/fa mailignore` list.

8. **Settings & Preferences (`/fa 8` or `/fa config`)**:
   - Integrated configuration panel to adjust CRT themes, UI scaling, font sizes, chat layouts, and alert digests.

---

## Command & Slash Reference

You can type commands into the in-game chat (`/fa` or `/foreveralts`) or directly into the dashboard terminal prompt (`> `):

| Command | Action |
| :--- | :--- |
| `/fa` | Toggle the main alt monitor dashboard |
| `/fa [1-8]` | Switch directly to a specific tab (Overview, Route, Rested, Profs, Economy, CDs, Mail, Settings) |
| `/fa config` | Open the integrated Settings & Preferences view (Tab 8) |
| `/fa tour` | Launch the interactive first-run onboarding tour |
| `/fa compact` | Toggle 680px compact mode |
| `/fa theme [name]` | Cycle or set phosphor theme (`AMBER`, `GREEN`, `CYAN`, `MONO`, `SAFE`, `SYNTHWAVE`, `DRACULA`) |
| `/fa scale <val>` | Adjust UI scale (`0.8` to `1.45`) |
| `/fa font <size>` | Set monospace font size (`12` to `24`) |
| `/fa copychat <alt>` | Copy chat window layout and channels from another character |
| `/fa sort <col>` | Sort table by column (`name`, `level`, `xp`, `rested`, `bonus`, `progress`, `cap`, `loc`, `waste`, `gold`) |
| `/fa filter <query>`| Filter characters by faction, level, class, or profession |
| `/fa clear` | Clear the active search filter |
| `/fa next` | Recommend top alts losing rested XP |
| `/fa plan [hours]` | Generate an optimal leveling session schedule (default: 2h) |
| `/fa role <alt> [role]` | View or assign cohort role (`core`, `reserve`, `bank`, `none`) |
| `/fa supply <alt> [role]` | Set supply chain role (`Cloth`, `Herbs`, `Ore`, `Leather`, `DE`, `auto`) |
| `/fa cook <alt>` | Toggle Cooking (Meat & Fish) opt-in routing for character |
| `/fa firstaid <alt>` | Toggle First Aid (Cloth) opt-in routing for character |
| `/fa dungeon [inst]`| Inspect dungeon quest readiness (RFC, WC, DM, SFK, BFD) |
| `/fa mail` | Print inter-alt mail routing summary for bag items |
| `/fa mailignore <item>` | Add an item to the mail ignore list |
| `/fa mailunignore <item>` | Remove an item from the mail ignore list |
| `/fa mailconsumables` | Toggle auto-routing of food/water/potions (safe by default) |
| `/fa perk [0-5] [alt]` | Set or cycle Well Rested legacy perk rank (0–5) for current or specified character |
| `/fa watch <item>` | Add item to bag & bank watchlist tracker |
| `/fa unwatch <item>` | Remove item from watchlist |
| `/fa watchlist` | Display inventory totals for watched items |
| `/fa note <alt> [text]` | Set custom per-character note |
| `/fa prune <days>` | Scan and prompt to prune alts unseen for N days |
| `/fa backup` / `restore` | Backup or restore character database snapshot |
| `/fa export` | Open copyable CSV roster export modal |
| `/fa reset` | Reset main window position to screen center |
| `/fa perf` | Run active benchmark of `Render()` with `debugprofilestop()` and print memory usage |
| `/fa selftest` | Run complete unit test assertions suite |
| `/fa help` | Open the in-game Quick Guide manual |

*(Note: Legacy aliases `/clialts` and `/ca` remain fully supported. Right-click any character row in the dashboard to open the quick context menu to adjust individual Well Rested perk ranks, delete records, or inspect full alt details).*

---

## Retro CRT Phosphor Themes

Choose your preferred retro visual aesthetic from `/fa config` or via `/fa theme <name>`:

| Theme Key | Name | Palette Description |
| :--- | :--- | :--- |
| **`AMBER`** | VT220 Amber | Classic warm P4 amber phosphor on deep terminal black (Default) |
| **`GREEN`** | Phosphor Green | Traditional P1 monochrome green CRT display |
| **`CYAN`** | Cyberdeck Cyan | High-tech BBS neon cyan on midnight blue |
| **`MONO`** | VT100 Monochrome | Crisp high-contrast white phosphor on jet black |
| **`SAFE`** | Phosphor Safe | Colorblind-accessible cerulean, slate, and amber palette |
| **`SYNTHWAVE`** | Synthwave Neon | Retrowave magenta, hot pink, and purple phosphor glow |
| **`DRACULA`** | Dracula Modern | Dark gothic purple and mint modern terminal theme |

---

## Installation

1. Download the latest release from [CurseForge](https://www.curseforge.com/wow/addons/foreveralts) or [GitHub Releases](https://github.com/nasroht/ForeverAlts/releases).
2. Extract the `ForeverAlts` folder into your World of Warcraft AddOns directory:
   ```text
   World of Warcraft\_classic_beta_\Interface\AddOns\ForeverAlts
   ```
3. Ensure the folder is named `ForeverAlts` and contains `ForeverAlts.toc`, `data.lua`, `theme.lua`, `minimap.lua`, `ui.lua`, and `core.lua`.
4. Launch World of Warcraft, enable **ForeverAlts** in your AddOns menu, and log into any character.
5. Type `/fa` or click the minimap button to launch your dashboard!

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
