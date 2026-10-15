# CLIAlts - WoW Forever & Classic Alt Manager

[![CI & Release](https://github.com/nasroht/clialts/actions/workflows/ci.yml/badge.svg)](https://github.com/nasroht/clialts/actions/workflows/ci.yml)
[![CurseForge](https://img.shields.io/badge/CurseForge-1742004-orange.svg)](https://www.curseforge.com/wow/addons/clialts)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A high-density, retro-terminal alt management dashboard and Text User Interface (TUI) for **World of Warcraft**, engineered primarily for **World of Warcraft: Forever** and **Classic Era** (with secondary compatibility for modern Retail).

**CLIAlts** tracks your account's character roster, **Faction**, **Race/Class**, **Levels and Cohort Milestones**, **Rested Experience & Accrual Rates**, **Phase Profession Milestones**, **Account Wealth & Deltas**, **Trade Cooldowns & Instance Lockouts**, **Dungeon Quest Pre-Chains**, and **Inter-Alt Mail & Supply Routing** — all within an authentic amber-on-black DEC VT220 monospace aesthetic designed for maximum information density, zero horizontal overflow, and rapid keyboard control.

---

## Primary Platform Focus: WoW Forever & Classic

CLIAlts is purpose-built around the progression mechanics and quality-of-life needs of **WoW Forever** and **Classic Era**:

- **Cohort Milestone Engine**:
  - Assign characters to strategic leveling cohorts: **`CORE`** (Target Level 35), **`RESERVE`** (Target Level 25), **`CAP`** (Target Level 60), or **`BANK`** (Mule storage).
  - Characters that meet their cohort goal are designated with the clear status label **"Target Level Reached"**.
- **Well Rested Legacy Perk Integration**:
  - Real-time offline rest accrual calculations calibrated for WoW Forever's **Well Rested** legacy perk (Ranks 0–5).
  - Supports accelerated accumulation (+4% rate per rank) and expanded rested pools (+6% capacity per rank, up to **180% maximum rested XP**).
- **Custom Legacy Point (LP) Progress Tracker**:
  - Automatically calculates account and individual character Legacy Point contributions toward account unlock tiers:
    - **Tier 1** (10 LP)
    - **Tier 2** (16 LP - Core Target)
    - **Tier 3** (18 LP)
  - Tracks rewards for level thresholds (L20 $\to$ 1.0 LP, L35 $\to$ 3.0 LP, L60 $\to$ 5.0 LP) and profession caps (75 $\to$ 0.5 LP, 150 $\to$ 1.0 LP, 300 $\to$ 2.0 LP).
  - Live `[ LP: %.1f/%d ]` telemetry progress chip displayed in the dashboard header.
- **Automated Dungeon Quest Tracker & Attunement Chains**:
  - In-depth readiness tracking for early instances: **Ragefire Chasm (RFC)**, **Wailing Caverns (WC)**, **Deadmines (DM)**, **Shadowfang Keep (SFK)**, and **Blackfathom Deeps (BFD)**.
  - Validates multi-step prerequisite quest chains (*Hidden Enemies*, *Leaders of the Fang*, *The Defias Brotherhood*) to pinpoint bottlenecks before forming a group.
- **WoW Forever Dual-Name Engine**:
  - Native recognition of WoW Forever's dual-name character system (First Name & Surname identity cache).
- **Secondary Retail Support**:
  - Modern client compatibility (The War Within / Retail) with fallback to standard 150% rested mechanics and unified UI scaling.

---

## Modern High-Density UI Architecture (1440px Display)

The main dashboard is organized into three streamlined visual regions designed to eliminate horizontal scrollbars and maximize vertical scanability:

```text
+-----------------------------------------------------------------------------------------------------------------------------------------+
| [#] CLIALTS :: ALT MONITOR    [OVERVIEW] [ROUTE] [RESTED] [PROFS] [GOLD] [CDS] [MAIL]       [COMPACT] [THEME] [CONFIG] [TOUR] [?] [X]   |
+-----------------------------------------------------------------------------------------------------------------------------------------+
| PLAY NEXT: ▶ Morvath [CORE] Lvl 20/35 | Tailor 150/150 [TRAIN EXPERT]     [ 12 ALTS ] [ 2 CAPPED ] [ 1 CD RDY ] [ 4,520g ] [ LP: 15.5 ] |
| Rested: 180% Capped (+3,400 XP waste) — Play now to prevent waste!        [ OPEN DOSSIER ]                          [ PERK: R5 ]        |
+-----------------------------------------------------------------------------------------------------------------------------------------+
| [ ALL ] [ CORE (4) ] [ RESERVE (5) ] [ MAX (2) ] [ CAPPED (2) ] [ HORDE (8) ] [ ALLY (4) ]                  [ Search: tailor________ ] |
| --------------------------------------------------------------------------------------------------------------------------------------- |
| > [O] Morvath   [WARL]  20/35  [==== 65% ====]  Tailor 150/150  142g 50s  !2h WST  [ CAPPED (Waste) ]   |  DOSSIER: Morvath-Forever  |
|   [O] Vane      [ROGU]  22/25  [======== 82% ]  Skin/LW 140      85g 20s  Caps 8h  [ CORE PRIORITY  ]   |  Level 20/35 | Rested: 180%|
|   [O] Thorne    [MAGE]  18/25  [=== 45% =====]  Herb/Alch 125    45g 10s  Caps 1d  [ RESERVE ALT    ]   |  Tailor 150/150 [TRAIN]    |
|   [O] Maxcraft  [WARR]  35/35  [=============]  Mining/BS 150   120g 00s  ---      [ TARGET REACHED ]   |  Mail Stream: Cloth [AUTO] |
|   [O] Goldmule  [PRIE]   1/1   [-------------]  ---              58g 40s  ---      [ BANK MULE      ]   |  0 items pending in bags   |
+-----------------------------------------------------------------------------------------------------------------------------------------+
| < Prev  Page 1/1  Next >   [Up/Down: Select | Enter: Toggle Dossier | Shift-Click: Role | Right-Click: Menu]   (1440x880 | Scale: 100%) |
| > sort level |                                                                                                                          |
+-----------------------------------------------------------------------------------------------------------------------------------------+
```

### 1. Unified Navigation & Control Bar
- **7 Dedicated Views**: `[OVERVIEW]`, `[ROUTE]`, `[RESTED]`, `[PROFS]`, `[GOLD]`, `[CDS]`, and `[MAIL]`.
- **Docked Action Pills**: `[COMPACT]` (slim 680px mode), `[THEME]` (CRT Phosphor palette), `[CONFIG]` (Settings dialog), `[TOUR]` (Interactive walkthrough), `[?]` (Help manual), and `[X]` (Close).

### 2. Play Next Mission Briefing Card
- **Optimal Character Recommendation**: Evaluates cohort rank, cap proximity, available rested XP, and waste penalty to recommend the next character to log into.
- **Level & Rested Diagnostics**: Displays exact level progress, milestone training alerts (`[TRAIN EXPERT]`), and time spent capped at maximum rested XP.
- **Live Account Telemetry**: Docked badges for Total Alts, Capped Alts, Ready Cooldowns, Total Liquid Gold, and Account Legacy Points.

### 3. Split Character Roster & Right Detail Panel
- **Modern Left Roster**:
  - Blizzard class-colored avatar rings.
  - Graphical XP progress bars illustrating progress toward the next level.
  - High-contrast status pills (`TARGET LEVEL REACHED`, `CORE PRIORITY`, `RESERVE ALT`, `CAPPED`, `ACCRUING`).
  - Active selection cursor (`>`) with smooth zebra row highlights.
- **Interactive Right Detail Panel**:
  - **Leveling & Rested Card**: Rested XP pool bar, accrual rate, time to cap, and estimated leveling session duration.
  - **Professions & Lockouts Card**: Primary/secondary ranks, training milestones, and dungeon/raid lockout timers.
  - **Mail & Supply Stream Card**: Active supply role (`[AUTO]` or `[OVERRIDE]`), pending materials in bags, and 1-click stream cycling.
- **Filter Chips & Instant Search**: 1-click filter pills (`All`, `Core`, `Reserve`, `Max Level`, `Capped`, `Horde`, `Alliance`) with instant text filtering.
- **Full Keyboard Navigation**: Arrow keys (`Up`/`Down`), `Page Up`/`Page Down`, `Home`/`End`, `Enter` to inspect dossier, and `Escape` to dismiss.

---

## Inter-Alt Mail & Supply Chain Router

Keep your crafting alts fueled without manual inventory sorting:

- **Automatic Material Routing**:
  - **Cloth** $\to$ Tailor alts
  - **Herbs** $\to$ Alchemy alts
  - **Ore & Stone** $\to$ Blacksmithing & Engineering alts
  - **Leather** $\to$ Leatherworking alts
  - **Meat & Fish** $\to$ Cooking alts
  - **BoE Green+ Gear & Reagents** $\to$ Enchanting / Disenchanting alts
  - **Unassigned Items** $\to$ Designated `BANK` mules
- **Recipe, Pattern & Schematic Auto-Routing**:
  - Detects all Class 9 recipes (Patterns, Plans, Schematics, Formulas, Manuals, Designs, Techniques) across all 11 crafting subclasses.
  - **"Learn It Yourself" Safety Guard**: Automatically retains unlearned recipes in bags if the current character has the matching profession and needs it.
  - **Learner Priority Scoring**: Routes recipes to the alt best positioned to learn them, based on profession rank, known recipe cache, and cohort tier.
- **1-Click Mailbox Auto-Fill**:
  - At any mailbox, click the retro `[Auto-Fill Mail]` button to automatically populate the recipient name and attach up to 12 matching items in a single click.
  - Built-in `pcall` guards and self-mailing prevention prevent UI taint and accidental self-delivery.
- **Mail Ignore List**:
  - Keep specific materials in your active character's bags using `/clialts mailignore <item>` or `> mailignore <item>`.
- **Consumable Safety**:
  - Food, drink, potions, and bandages are protected from auto-mailing by default (`/clialts mailconsumables` to toggle).

---

## One-Click Bag Auto-Sort Engine

- **Integrated Bag Sorter**: A dedicated `[Sort]` button docked cleanly inside Blizzard's combined bag frame and container frames.
- **Safe Consolidation**: Combines partial item stacks and sorts inventory by quality and category alphabetically.
- **Zero Taint**: Operates strictly out of combat with container validation to eliminate secure action button conflicts.

---

## Chat Layout Cloner

Configure your chat layout once on your main character, then replicate it across your entire roster:

- **1-Click Cloner**: Copy chat tabs, channel subscriptions, font sizes, window positions, and dimensions from any saved alt to the current character.
- **Settings Dialog Integration**: Select source character from the dropdown in `/clialts config` and click `[Copy Layout]`.
- **Slash Shortcut**: Run `/clialts copychat <character_name>` directly from chat.

---

## Dedicated Settings Dialog

Access the settings modal via `[CONFIG]`, `/clialts config`, or `/clialts settings`:

- **Theme Palette**: Choose between 7 CRT phosphor themes (`Amber`, `Green`, `Cyan`, `Monochrome`, `Colorblind Safe`, `Synthwave`, `Dracula`).
- **Display Scaling & Font Size**: Adjust UI scale (70%–180%) and monospace font size (12px–22px) with live previews.
- **Audio & Visual Preferences**: Toggle sound effects, login alert digests, minimap button, and bag sort button.
- **Chat Layout Management**: Snapshot and clone chat settings between characters.

---

## Retro CRT Phosphor Themes

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

## Command & Slash Reference

Type into the dashboard terminal prompt (`> `) or in standard chat (`/clialts` or `/ca`):

| Command | Action |
| :--- | :--- |
| `/clialts` | Toggle the main alt monitor dashboard |
| `/clialts [1-7]` | Switch directly to a specific tab (Overview, Route, Rested, Profs, Gold, CDs, Mail) |
| `/clialts config` | Open the dedicated Settings & Preferences Dialog |
| `/clialts tour` | Launch the interactive first-run onboarding tour |
| `/clialts compact` | Toggle 680px compact mode |
| `/clialts theme [name]` | Cycle or set phosphor theme |
| `/clialts scale <val>` | Adjust UI scale (`0.7` to `1.8`) |
| `/clialts font <size>` | Set monospace font size (`12` to `22`) |
| `/clialts copychat <alt>` | Copy chat window layout and channels from another character |
| `/clialts sort <col>` | Sort table by column key (`role`, `prof`, `name`, `level`, `gold`, `rested`, `waste`, `xp`) |
| `/clialts filter <query>`| Filter characters by faction, level, class, or profession |
| `/clialts clear` | Clear the active filter |
| `/clialts next` | Recommend top alts losing rested XP |
| `/clialts plan [hours]` | Generate an optimal leveling session schedule (default: 2h) |
| `/clialts role <alt> [role]` | View or assign cohort role (`core`, `reserve`, `bank`, `none`) |
| `/clialts supply <alt> [role]` | Set supply chain role (`Cloth`, `Herbs`, `Ore`, `Leather`, `DE`, `auto`) |
| `/clialts dungeon [inst]`| Inspect dungeon quest readiness (RFC, WC, DM, SFK, BFD) |
| `/clialts mail` | Print inter-alt mail routing summary for bag items |
| `/clialts mailignore <item>` | Add an item to the mail ignore list |
| `/clialts mailunignore <item>` | Remove an item from the mail ignore list |
| `/clialts mailconsumables` | Toggle auto-routing of food/water/potions (safe by default) |
| `/clialts lp [pts\|auto]`| View account Legacy Point progress or set manual override |
| `/clialts perk [0-5]` | Set or cycle Well Rested legacy perk rank (0–5) |
| `/clialts watch <item>` | Add item to bag & bank watchlist tracker |
| `/clialts unwatch <item>` | Remove item from watchlist |
| `/clialts watchlist` | Display inventory totals for watched items |
| `/clialts note <alt> [text]` | Set custom per-character note |
| `/clialts prune <days>` | Scan and prompt to prune alts unseen for N days |
| `/clialts backup` / `restore` | Backup or restore character database snapshot |
| `/clialts export` | Open copyable CSV roster export modal |
| `/clialts reset` | Reset main window position to screen center |
| `/clialts selftest` | Run complete unit test assertions suite (799 assertions) |
| `/clialts help` | Open the in-game Quick Guide manual |

---

## Engineering, Headless Verification & CI

CLIAlts is engineered for rock-solid stability, zero memory bloat, and cross-client compatibility:

- **Zero Runtime Garbage & Taint Isolation**:
  - Virtual row recycling in the character list prevents memory allocations during scrolling and filtering.
  - Mail auto-fill and bag sort hooks are wrapped in secure `pcall` boundaries to guard against action button lockouts.
- **Headless Unit Verification (799 Assertions across 34 Suites)**:
  - Validated by an in-game self-test engine (`/clialts selftest`) and headless execution under plain Lua 5.1 (`tests/stub.lua` + `tests/selftest.lua`).
  - Covers offline rest accrual formulas, perk bonus scaling, cap clamping, priority scoring, item watchlists, dungeon pre-chains, supply chain routing, recipe learning priorities, Legacy Point tiers, and database migration integrity.
- **Continuous Integration Pipeline**:
  - Every commit is verified against [GitHub Actions CI](https://github.com/nasroht/clialts/actions), enforcing strict **Luacheck** static analysis (0 errors, 0 warnings) and plain **Lua 5.1** headless execution.
- **CurseForge Multi-Flavor Packaging**:
  - Configured via `.pkgmeta` (`enable-toc-creation: yes`) and multi-flavor TOC headers to package clean distributions for WoW Forever, Classic Era, and Retail clients.

---

## Installation

1. Download the latest release from [CurseForge](https://www.curseforge.com/wow/addons/clialts) or GitHub Releases.
2. Extract the `clialts` folder into your World of Warcraft AddOns directory:
   - **WoW Forever / Classic Era**:
     ```text
     World of Warcraft\_classic_era_\Interface\AddOns\clialts
     ```
   - **Retail**:
     ```text
     World of Warcraft\_retail_\Interface\AddOns\clialts
     ```
3. Ensure the folder is named `clialts` and contains `clialts.toc`, `data.lua`, `theme.lua`, `minimap.lua`, `ui.lua`, and `core.lua`.
4. Launch World of Warcraft, enable **CLIAlts** in your AddOns menu, and log into any character.
5. Type `/clialts` or click the minimap button to launch your dashboard!

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
