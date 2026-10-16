<div align="center">
  <img src="https://raw.githubusercontent.com/nasroht/ForeverAlts/main/media/logo.jpg" alt="ForeverAlts Logo" width="220" style="border-radius: 16px;" />
  <h1>ForeverAlts</h1>
  <p><strong>The dedicated alt progression and supply chain manager built exclusively for World of Warcraft: Forever.</strong></p>
  <p>
    <a href="https://github.com/nasroht/ForeverAlts/actions/workflows/ci.yml"><img src="https://github.com/nasroht/ForeverAlts/actions/workflows/ci.yml/badge.svg" alt="CI &amp; Release" /></a>
    <a href="https://www.curseforge.com/wow/addons/foreveralts"><img src="https://img.shields.io/badge/CurseForge-1747176-orange.svg" alt="CurseForge" /></a>
    <a href="https://github.com/nasroht/ForeverAlts/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" /></a>
  </p>
</div>

---

A high-density, retro-terminal alt management dashboard and operations suite purpose-built for **World of Warcraft: Forever**.

**ForeverAlts** tracks your account's character roster, **Faction**, **Race/Class**, **Levels and Cohort Milestones**, **Well Rested Perk Calculations**, **Phase Profession Milestones**, **Account Wealth & Deltas**, **Trade Cooldowns & Instance Lockouts**, **Dungeon Quest Pre-Chains**, and **Inter-Alt Mail & Supply Routing** — all within an authentic, high-contrast terminal interface designed for maximum information density, zero horizontal overflow, and rapid keyboard control.

---

## Purpose-Built for WoW Forever

ForeverAlts is designed around the custom progression systems and mechanics of **WoW Forever**:

- **Well Rested Legacy Perk Integration**:
  - Real-time offline rest accrual calculations calibrated for WoW Forever's **Well Rested** legacy perk (Ranks 0–5).
  - Accurately models accelerated accumulation (+4% rate per rank) and expanded rested pools (+6% capacity per rank, up to **180% maximum rested XP**).
  - Displays time sitting at cap with precise wasted XP tracking (`Capped 1h 46m ago (≈500 wasted)`), dropping generic and confusing status text.
- **Custom Legacy Point (LP) Progress Tracker**:
  - Automatically calculates account and individual character Legacy Point contributions toward account unlock tiers:
    - **Tier 1** (10 LP)
    - **Tier 2** (16 LP - Core Target)
    - **Tier 3** (18 LP)
  - Tracks rewards for level thresholds (L20 → 1.0 LP, L35 → 3.0 LP, L60 → 5.0 LP) and profession caps (75 → 0.5 LP, 150 → 1.0 LP, 300 → 2.0 LP).
  - Live `[ LP: %.1f/%d ]` telemetry progress chip displayed in the dashboard header.
- **Cohort Milestone Engine**:
  - Assign characters to strategic leveling cohorts: **`CORE`** (Target Level 35), **`RESERVE`** (Target Level 25), **`CAP`** (Target Level 60), or **`BANK`** (Mule storage).
  - Characters that meet their cohort goal are designated with the clear status label **"Target Level Reached"**.
- **Automated Dungeon Quest Tracker & Attunement Chains**:
  - In-depth readiness tracking for early instances: **Ragefire Chasm (RFC)**, **Wailing Caverns (WC)**, **Deadmines (DM)**, **Shadowfang Keep (SFK)**, and **Blackfathom Deeps (BFD)**.
  - Validates multi-step prerequisite quest chains (*Hidden Enemies*, *Leaders of the Fang*, *The Defias Brotherhood*) to pinpoint bottlenecks before forming a group.
- **WoW Forever Dual-Name Engine**:
  - Native recognition of WoW Forever's dual-name character system (First Name & Surname identity cache).

---

## Consolidated Overview & Rested Analytics Architecture

ForeverAlts provides a focused, streamlined **Two-Screen Architecture**:

### 1. Consolidated Overview Dashboard (`/fa 1`)
- **"Play Next" Recommendation Banner**: Instant top-of-dashboard intelligence surfacing which characters need attention first, complete with an optimal 2-hour leveling rotation schedule.
- **Class-Colored Level Squares**: 34px retro square displaying the character's level styled in their official class color.
- **Dual Circular Speedometer Gauges**:
  - **Level XP Meter**: Circular progress gauge showing progress through the current level (`% of lvl`).
  - **Rested XP Meter**: Circular speedometer gauge calibrated to the Well Rested perk cap (`% of cap`).
- **Rested Details Subline**: Real-time pool and accrual telemetry (`+... XP/h (Wild · 4x in Inn) · ... to cap`), offering actionable park suggestions when characters log out in the wilderness.
- **In-Row Urgency Highlighting**: Capped and wasting alts are highlighted directly with glowing warning borders and alert backdrops—eliminating clutter from redundant chip columns.
- **Level 1 Dimming**: Fresh level 1 alts with 0% XP and 0% rested are dimmed automatically (`alpha = 0.55`) to prioritize characters with active progression.
- **Strict Faction Grouping**: Characters are organized cleanly by faction—Alliance first, followed by Horde—guaranteeing rosters are never mixed.
- **Retro Coin Wealth**: Formatted liquid gold, silver, and copper tokens (`FormatCoins`).

### 2. Rested XP Analysis Table (`/fa 3`)
- **9 Dedicated Analysis Columns**: Total width fitted within 820px ($\le 850$px row bounds):
  `FAC` · `CHARACTER` · `LVL` · `CURRENT XP` · `RESTED / CAP` · `RESTED PROGRESS` · `REST LOC` · `XP/H` · `STATUS`
- **Clickable Header Sorting**: Sort your entire roster by faction, character name, level, current XP, rested pool, rest location (`REST LOC` - Inn vs Wild), hourly rest rate (`XP/H`), or status.
- **Precise Status Telemetry**: Shows exact time-to-cap or waste duration (`Capped ... ago (≈N wasted)`).

---

## Inter-Alt Mail & Supply Chain Router

Keep your crafting alts fueled without manual inventory sorting:

- **Cross-Faction & Cross-Realm Isolation Guard**:
  - Strictly prevents attempting to route or auto-fill mail between opposing factions (Alliance vs Horde) or across realm boundaries.
  - Detects explicit faction tags as well as race-based inference to guarantee safe mail routing.
- **Self-Mailing Prevention Guard**:
  - Automatically excludes the currently logged-in character from recipient suggestion lists and auto-fill batches.
- **Automatic Material Routing**:
  - **Cloth** → Tailor alts (or designated First Aid alts)
  - **Herbs** → Alchemy alts
  - **Ore & Stone** → Blacksmithing & Engineering alts
  - **Leather** → Leatherworking alts
  - **Meat & Fish** → Designated Cooking alts *(Ignored by default unless explicitly toggled on)*
  - **BoE Green+ Gear & Reagents** → Enchanting / Disenchanting alts
  - **Unassigned Items** → Designated `BANK` mules
- **Recipe, Pattern & Schematic Auto-Routing**:
  - Detects all recipes (Patterns, Plans, Schematics, Formulas, Manuals, Designs) across all crafting trades.
  - **"Learn It Yourself" Safety Guard**: Automatically retains unlearned recipes in bags if the current character has the matching profession and needs it.
  - **Learner Priority Scoring**: Routes recipes to the alt best positioned to learn them, based on profession rank, known recipe cache, and cohort tier.
- **Secondary Profession Opt-In Routing**:
  - Cooking and First Aid are secondary professions that any alt can learn. To prevent unwanted mail spam, Meat/Fish and First Aid materials default to safely ignored (kept in player bags) unless you enable the `[Cook: ON]` or `[FA: ON]` toggle on an alt.
- **1-Click Mailbox Auto-Fill**:
  - At any mailbox, click the `[ AUTO-FILL ]` button to automatically populate the recipient name and attach up to 12 matching items in a single click.
  - Review attachments and manually click Send Mail.
- **Mail Ignore List**:
  - Keep specific materials in your active character's bags using `/fa mailignore <item>`.

---

## One-Click Bag Auto-Sort Engine

- **Integrated Bag Sorter**: A dedicated `[S]` button docked cleanly on the backpack window (`ContainerFrame1` / Combined Bags).
- **Safe Consolidation**: Combines partial item stacks across all bags and sorts inventory by quality and category alphabetically.
- **Zero Taint**: Operates through an unhooked background visibility watcher with self-healing re-anchoring, completely free of action bar or container taint.

---

## Cross-Character Inventory & Bank Tooltips

Hover over any item in the game world, bag inventory, or bank to immediately see how many units of that item are held across all your alts on WoW Forever, complete with bag vs bank breakdowns.

---

## Chat Layout Cloner

Configure your chat layout once on your main character, then replicate it across your entire roster:

- **1-Click Cloner**: Copy chat tabs, channel subscriptions, font sizes, window positions, and dimensions from any saved alt to the current character.
- **Settings Dialog Integration**: Select source character from the dropdown in `/fa config` and click `[Copy Layout]`.
- **Slash Shortcut**: Run `/fa copychat <character_name>` directly from chat.

---

## Dedicated Settings & 8 Integrated Tabs

Access settings via `[CONFIG]`, the sidebar/header tab, `/fa config`, or `/fa settings`:

- **8 Dashboard Navigation Views**:
  1. **Overview** (`/fa 1`): Consolidated dashboard featuring the "Play next" recommendation banner, dual circular gauges (Level XP % of level and Rested XP % of cap), character level in class-colored square, details subline (rest pool & accrual rate), urgency row highlighting, and coin wealth.
  2. **Forever Route** (`/fa 2`): Smart rotation recommendations, usable rested ranking, cohort tiers (`CORE`, `RESERVE`, `BANK`).
  3. **Rested XP** (`/fa 3`): Real-time offline rest accrual analysis table with 9 sortable columns, including Inn/Wild location (`loc`), XP/h rate (`xph`), and time-to-cap/waste status.
  4. **Professions** (`/fa 4`): Phase profession milestones (75/150/225/300) and recipes.
  5. **Economy** (`/fa 5`): Total account wealth, liquid gold across alts, and transaction delta tracker.
  6. **Cooldowns & Locks** (`/fa 6`): Trade cooldowns (Transmutes, Mooncloth) and raid/dungeon instance reset timers.
  7. **Mail Routing** (`/fa 7`): Supply chain auto-routing for crafting trades with 1-click mailbox auto-fill and cross-faction isolation.
  8. **Settings & Preferences** (`/fa 8`): Full integrated configuration panel embedded directly in the main dashboard view.
- **Theme Palette**: Choose between 7 CRT phosphor themes (`Amber`, `Green`, `Cyan`, `Monochrome`, `Colorblind Safe`, `Synthwave`, `Dracula`).
- **Display Scaling & Font Size**: Adjust UI scale (80%–145%) and monospace font size (12px–24px) with live previews.
- **Audio & Visual Preferences**: Toggle sound effects, login alert digests, minimap button, and bag sort button.
- **Chat Layout Management**: Snapshot and clone chat settings between characters.

---

## Performance & Event Coalescing Engine

Built for zero perceptible frame drops and minimal memory overhead:

- **Active Render Benchmark (`/fa perf`)**: Real-time render profiling using WoW's `debugprofilestop()` hardware timer to display active `Render()` execution time (min, max, average) alongside addon memory consumption.
- **Smart Event Coalescing**:
  - `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, and `ZONE_CHANGED_NEW_AREA` events coalesce over a 0.75-second frame bucket.
  - `QUEST_LOG_UPDATE` events coalesce over a 1.25-second frame bucket.
  - Prevents burst events from triggering redundant full-dashboard re-renders.
- **Sub-Millisecond Execution**: Average full-table render takes under **0.5 ms**, eliminating the need for complex row-cache invalidation.

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

Type into the dashboard terminal prompt (`> `) or in standard chat (`/fa` or `/foreveralts`):

| Command | Action |
| :--- | :--- |
| `/fa` | Toggle the main alt monitor dashboard |
| `/fa [1-8]` | Switch directly to a specific tab (Overview, Route, Rested, Profs, Economy, CDs, Mail, Settings) |
| `/fa config` | Open the integrated Settings & Preferences view (Tab 8) |
| `/fa beta` / `/fa 8` | Overview alias (Beta dashboard integrated into Tab 1) |
| `/fa tour` | Launch the interactive first-run onboarding tour |
| `/fa compact` | Toggle 680px compact mode |
| `/fa theme [name]` | Cycle or set phosphor theme (`AMBER`, `GREEN`, `CYAN`, `MONO`, `SAFE`, `SYNTHWAVE`, `DRACULA`) |
| `/fa scale <val>` | Adjust UI scale (`0.8` to `1.45`) |
| `/fa font <size>` | Set monospace font size (`12` to `24`) |
| `/fa perf` | Run active benchmark of `Render()` with `debugprofilestop()` and print memory usage |
| `/fa copychat <alt>` | Copy chat window layout and channels from another character |
| `/fa sort <col>` | Sort table by column key (`role`, `prof`, `name`, `level`, `gold`, `rested`, `waste`, `xp`, `loc`, `xph`) |
| `/fa filter <query>`| Filter characters by faction, level, class, or profession |
| `/fa clear` | Clear the active filter |
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
| `/fa lp [pts\|auto]`| View account Legacy Point progress or set manual override |
| `/fa perk [0-5]` | Set or cycle Well Rested legacy perk rank (0–5) |
| `/fa watch <item>` | Add item to bag & bank watchlist tracker |
| `/fa unwatch <item>` | Remove item from watchlist |
| `/fa watchlist` | Display inventory totals for watched items |
| `/fa note <alt> [text]` | Set custom per-character note |
| `/fa prune <days>` | Scan and prompt to prune alts unseen for N days |
| `/fa backup` / `restore` | Backup or restore character database snapshot |
| `/fa export` | Open copyable CSV roster export modal |
| `/fa reset` | Reset main window position to screen center |
| `/fa selftest` | Run complete unit test assertions suite |
| `/fa help` | Open the in-game Quick Guide manual |

*(Note: Legacy aliases `/clialts` and `/ca` remain fully supported).*

---

## Installation

1. Download the latest release from [CurseForge](https://www.curseforge.com/wow/addons/foreveralts) or GitHub Releases.
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
