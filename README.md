# CLIAlts - Retro Terminal Alt & Rested XP Dashboard

[![CI & Release](https://github.com/nasroht/clialts/actions/workflows/ci.yml/badge.svg)](https://github.com/nasroht/clialts/actions/workflows/ci.yml)

A polished, retro terminal-inspired alt-management dashboard and Text User Interface (TUI) for **World of Warcraft** (engineered specifically for *World of Warcraft: Forever*, *Classic Era*, and modern Classic).

**CLIAlts** tracks your account's character roster, **Faction**, **Race/Class**, **Levels and Targets**, **Rested Experience & Accrual Rates**, **Phase Profession Milestones**, **Account Wealth & Deltas**, **Trade Cooldowns & Instance Lockouts**, and **Forever Route Prioritization** — all within an amber-on-black DEC VT220 monospace aesthetic designed for usability, high information density, and zero horizontal overflow.

---

## Architecture & Visual Hierarchy

The main dashboard is organized into **three streamlined visual regions** designed to eliminate clutter and horizontal overflow while maintaining high information density:

```text
+--------------------------------------------------------------------------------------------------------------------------+
| [#] CLIALTS :: ALT MONITOR    [OVERVIEW] [ROUTE] [RESTED] [PROFS] [GOLD] [CDS]                       [C] [T] [?] [X]     |
+--------------------------------------------------------------------------------------------------------------------------+
| NEXT UP: ▶ Morvath [CORE] Lvl 20/25 | Tailor 150/150 [TRAIN]          [ 12 ALTS ] [ 2 CAPPED ] [ 1 CD RDY ] [ 4,520g ]   |
| Rested: 180% Capped (+3,400 XP waste) — Play now to prevent waste!    [ OPEN DOSSIER ]                     [ PERK: R5 ]  |
+--------------------------------------------------------------------------------------------------------------------------+
| CHARACTER      ROLE    LVL     RESTED XP          PRIMARY PROF 1        GOLD        ETA       STATUS                         |
| ------------------------------------------------------------------------------------------------------------------------ |
| > Morvath      [CORE]  20/25*  180% [FULL]        Tailor 150/150        142g 50s    !2h WST   ! CAPPED (Overflowing)         |
|   Vane         [CORE]  22/25   112% (12.4k)       Leatherwork 140        85g 20s    Caps 8h   CORE PRIORITY (Accruing)       |
|   Thorne       [ALT]   18/25    85% ( 6.8k)       Herbalism 125          45g 10s    Caps 1d   RESERVE ALT (Accruing)         |
|   Maxcraft     [CORE]  35/35*  180% [FULL]        Blacksmith 150        120g 00s    ---       TARGET REACHED                 |
|   Goldmule     [BANK]   1/1    ---                ---                    58g 40s    ---       BANK MULE (Excluded)           |
+--------------------------------------------------------------------------------------------------------------------------+
| < Prev  Page 1/1  Next >                     [Enter: Dossier | Shift-Click: Role | Right-Click: Context Menu | Sort Col] |
| > filter tailor |                                                                                                        |
+--------------------------------------------------------------------------------------------------------------------------+
```

### 1. Unified Header & Navigation Bar
- **Header Line**: Integrates the window title (`[#] CLIALTS :: ALT MONITOR` or `:: FOREVER ROUTE`) directly alongside the 6 view tabs (`[OVERVIEW]`, `[ROUTE]`, `[RESTED]`, `[PROFS]`, `[GOLD]`, `[CDS]`).
- **Control Affordances**: Compact action pills docked on the right: `[C]` (Compact mode), `[T]` (CRT Phosphor Theme), `[?]` (Help manual), and `[X]` (Close).
- **Decluttered Layout**: Eliminates redundant ASCII divider bars to maximize vertical scanability and breathing room.

### 2. Unified Mission Briefing Card
- **Recommended Next Action**: Evaluates the live multi-variable **Forever Route** prioritization engine (cohort weight, rested pool, cap proximity, waste penalty) to recommend the optimal character to play next.
- **Actionable Subline**: Displays character level vs target, active profession milestone alerts (`[TRAIN]`), rested percentage, and explicit rationale (e.g. *Rested cap reached with XP overflow (+3,400 XP wasted) — play now to prevent XP waste*).
- **Docked Telemetry Chips**: Real-time account metric badges on the right: `[ %d ALTS ]`, `[ %d CAPPED ]`, `[ %d CD RDY ]`, and `[ %sg ]`.
- **Integrated Controls**: 1-click `[ OPEN DOSSIER ]` button to inspect character details, plus the docked `[ PERK: R%d ]` Well Rested rank indicator.

### 3. Clean Monospace Roster Table & Statusline
- **Blizzard Class Colors**: Character names are highlighted in authentic World of Warcraft class colors, paired with 4-letter muted class tags (`[WARL]`, `[MAGE]`, `[ROGU]`, etc.).
- **Active Row Cursor**: Visible selection cursor (`>`) on the active row with subtle alternating zebra row shading.
- **8 Standardized Columns**: Monospace alignment with right-aligned numeric data and click-to-sort indicators (`^` ascending, `v` descending).
- **Streamlined 2-Line Statusline**: Top line combines pagination (`< Prev`, `Next >`, `Page 1/1`) and mouse/keyboard shortcuts; bottom line docks the interactive terminal command prompt (`> `).

---

## 6 Dedicated Views

| Tab | View Name | Description | Key Columns |
| :---: | :--- | :--- | :--- |
| **`1`** | **`[ OVERVIEW ]`** | Main dashboard with high-level monitoring across all characters. | `CHARACTER`, `ROLE`, `LEVEL`, `RESTED XP`, `PRIMARY PROFESSION`, `GOLD`, `ETA`, `STATUS` |
| **`2`** | **`[ ROUTE ]`** | Detailed leveling rotation order and explicit priority rationales. | `ORDER`, `CHARACTER`, `ROLE`, `LEVEL`, `RESTED XP`, `PRIORITY`, `ETA`, `RECOMMENDATION REASON` |
| **`3`** | **`[ RESTED ]`** | Exhaustion monitor with capacity and level percentage distinction. | `FAC`, `CHARACTER`, `LVL`, `CURRENT XP`, `RESTED / CAP`, `RESTED PROGRESS`, `RATE`, `ETA TO CAP` |
| **`4`** | **`[ PROFS ]`** | Primary and secondary crafting tracking with phase milestones. | `FAC`, `CHARACTER`, `LVL`, `PRIMARY PROF 1`, `PRIMARY PROF 2`, `SECONDARY SKILLS` |
| **`5`** | **`[ GOLD ]`** | Wealth distribution, share percentages, and zone locations. | `FAC`, `CHARACTER`, `LVL`, `GOLD & SILVER`, `SHARE`, `LAST ZONE`, `HEARTHSTONE` |
| **`6`** | **`[ CDS ]`** | Trade skill timers and dungeon/raid lockouts sorted by readiness. | `FAC`, `CHARACTER`, `LVL`, `TRADE COOLDOWNS`, `SAVED INSTANCES / LOCKS` |

---

## Character Interactions & Dossier

CLIAlts provides predictable, non-destructive mouse and keyboard interactions:

- **Left-Click Row**: Selects the character row and opens the **Alt Dossier modal** without cluttering the main table.
- **Shift-Click Row**: Quickly cycles the character's cohort role (`CORE` $\to$ `RESERVE/ALT` $\to$ `BANK` $\to$ `UNASSIGNED`).
- **Right-Click Row**: Opens a retro-styled **Context Menu** anchored to your cursor:
  1. `1. Open Dossier` — View full character sheet, milestones, notes, and supply roles.
  2. `2. Set Role: Core (L35)` — Assign to primary leveling cohort.
  3. `3. Set Role: Alt (L25)` — Assign to secondary alt cohort.
  4. `4. Set Role: Bank Mule` — Exclude from leveling rotation and mark as inventory mule.
  5. `5. Toggle Watchlist` — Track bag & bank item counts for this alt.
  6. `6. Remove Alt...` — Opens an explicit confirmation modal dialog (`[ YES, PURGE ]` / `[ CANCEL ]`). *Characters are never deleted directly from a right-click.*
  7. `7. Cancel` — Close the context menu.
- **Escape Key Handling**: Context menus, dossier popups, confirmation dialogs, and the main window register with `UISpecialFrames` to dismiss on `Escape`.
- **Informative Tooltips**: Hovering over column headers or character rows displays explanations of calculations, abbreviations, and control shortcuts.

---

## Rested XP Engine & WoW Forever Integration

- **Real-Time Offline Accrual Model**: Computes rested accumulation across all alts (5.0% per 8h in sanctuaries/cities; 1.25% per 8h in wilderness).
- **WoW Forever Well Rested Perk Support**: Supports legacy perk ranks 0–5 (+4% accumulation rate and +6% cap increase per rank, up to 180% maximum rested).
- **Capacity vs Level Percentage**: Explicitly distinguishes between percentage of level XP (can reach 180%) and percentage of rested capacity (0% to 100%), preventing incorrect clamping.
- **Rested Waste Tracking**: Calculates the exact time an alt has spent sitting capped at maximum rested XP, plus total potential XP lost (e.g. `!2h WST`, `+3.4k XP waste`).
- **Profession Milestones & Training Alerts**:
  - Automatically identifies Phase 2 caps (e.g. `Tailor: 150/150 [TRAIN EXPERT]`).
  - Flags character level bottlenecks (e.g. `[Req Lvl 20]`) and completed caps (`[DONE]`).
- **1-Click Supply Role Configuration**: Assign supply roles (`Tailor/Bags`, `Alch/DE`, `Miner/Smelt`, `LW/Armor`, `Passive Bank`, `Auto`) directly from the Alt Dossier.

---

## Compact Mode & Scaling

- **Standard Mode (920 x 565 px)**: Full 8-column layout, detailed telemetry, and complete recommendation rationales.
- **Compact Mode (680 x 565 px)**: Toggle with `[ COMPACT ]` or `/clialts compact`. Intelligently suppresses secondary columns (`ETA` on Tabs 1/2, `CURRENT XP` on Tab 3), slims tab headers to 105px (`[ 1: MAIN ]`, `[ 2: ROUTE ]`, etc.), and condenses telemetry into concise tokens without micro-scaling text.
- **UI Scaling**: Smoothly scales from 70% to 180% (`/clialts scale <val>`) while preserving crisp pixel borders.
- **Monospace Typography**: Monospace font sizing adjustable from 12px to 22px (`/clialts font <size>`).
- **Settings Persistence**: Compact mode, scale, active theme, window position, and tab selection persist cleanly in `CLIAltsDB`.

---

## Retro Color Themes

Cycle through authentic CRT phosphor themes using `[ THEME ]` in the title bar, `/clialts theme <name>`, or `> theme <name>`:

1. **VT220 Amber (`AMBER`)**: Warm P4 amber phosphor terminal display (default).
2. **Phosphor Green (`GREEN`)**: Classic P1 green monochrome CRT display.
3. **Cyberdeck Cyan (`CYAN`)**: BBS / retro cyberdeck neon cyan.
4. **VT100 Monochrome (`MONO`)**: High-contrast white phosphor on deep black.
5. **Phosphor Safe (`SAFE` / `COLORBLIND`)**: Colorblind-safe cerulean/slate/amber palette.
6. **Synthwave (`SYNTHWAVE`)**: Retrowave magenta and purple phosphor glow.
7. **Dracula (`DRACULA`)**: Gothic purple and mint modern terminal palette.

---

## Interactive Command Prompt Reference

Inside the CLIAlts window, type directly into the `> ` prompt:

| Prompt Input | Action |
| :--- | :--- |
| `1` .. `6` | Switch directly to Tab 1 through 6 |
| `tab <1-6>` | Switch to specified tab |
| `sort <col>` | Sort table by column (`name`, `level`, `role`, `prof`, `gold`, `rested`, `waste`, `xp`, `cooldown`, `location`, `hearth`, `seen`, `note`) |
| `filter <query>` | Filter character rows (e.g. `filter horde <60`, `filter tailor`) |
| `find <query>` | Filter characters matching name or text |
| `clear` | Clear the active filter |
| `page <n>`, `goto <n>` | Navigate to page number |
| `next` | Print top rotation alts losing rested XP |
| `plan [hours]` | Generate an optimal leveling session schedule |
| `role [name] [cohort]` | View or assign character leveling cohort (`core`, `reserve`, `bank`, `none`) |
| `core <name>` | Assign alt to Core cohort (Target Level 35) |
| `alt <name>` | Assign alt to Reserve cohort (Target Level 25) |
| `bank <name>` | Designate alt as Bank Mule (excluded from leveling) |
| `unassign <name>` | Remove cohort assignment |
| `prof` | Print profession milestone status across all alts |
| `watch <item>` | Add item to bag & bank watchlist tracker (supports Shift-clicking item links) |
| `unwatch <item>` | Remove item from watchlist |
| `watchlist` | Display inventory totals for watched items |
| `note <name> <text>` | Set per-alt custom note (`note <name> clear` to remove) |
| `unlocked <instance>`| Search for alts eligible for raid/dungeon without a lockout |
| `prune <days>` | Bulk scan and prune characters unseen for N days |
| `compact`, `c` | Toggle compact mode |
| `forever`, `wf` | Toggle WoW Forever mode (cohort routing & phase caps) |
| `tooltips`, `inv` | Toggle inventory item count hover tooltips |
| `theme <name>` | Set phosphor theme (`amber`, `green`, `cyan`, `mono`, `safe`, `synthwave`, `dracula`) |
| `scale <val>` | Adjust UI scale (e.g. `scale 1.15`) |
| `perk [0-5]` | Set or cycle Well Rested legacy perk rank |
| `backup` / `restore` | Backup or restore character database snapshot |
| `export` | Open copyable CSV export modal dialog |
| `help` | Open Quick Guide manual |
| `exit`, `quit`, `close` | Close main window |

---

## Slash Commands Reference

| Command | Description |
| :--- | :--- |
| `/clialts`, `/cli`, `/ca` | Toggle the main TUI monitor dashboard |
| `/clialts [1-6]` | Switch directly to a specific tab (1: Overview, 2: Route, 3: Rested, 4: Profs, 5: Econ, 6: CDs) |
| `/clialts theme [name]` | Cycle or set phosphor theme (`amber`, `green`, `cyan`, `mono`, `safe`, `synthwave`, `dracula`) |
| `/clialts compact` | Toggle one-key compact mode (680px slim window) |
| `/clialts scale <0.7-1.8>` | Set UI scale (e.g. `1.2` or `120%`) |
| `/clialts font <12-22>` | Set monospace terminal font size (default `15`) |
| `/clialts sort <col>` | Sort table by column key (`role`, `prof`, `cd`, `name`, `level`, `gold`, `rested`, `waste`, `xp`, `location`, `hearth`) |
| `/clialts filter <query>` | Filter characters by faction, level range, class, or profession |
| `/clialts clear` | Clear active filter |
| `/clialts next` | Recommend top alts to log into (highest wasted rested XP) |
| `/clialts plan [hours]` | Generate an optimal leveling session schedule (default: 2h) |
| `/clialts role <name> [cohort]` | View or assign character cohort (`core`, `reserve`, `bank`, `none`) |
| `/clialts core <name> [lvl]` | Assign alt to Core cohort (default target level 35) |
| `/clialts alt <name> [lvl]` | Assign alt to Reserve cohort (default target level 25) |
| `/clialts bank <name>` | Designate alt as Bank Mule (excluded from leveling) |
| `/clialts unassign <name>` | Unassign alt cohort |
| `/clialts supply <name> [role]` | Assign profession supply role (e.g. `Tailor/Bags`, `Alch/DE`, `auto`) |
| `/clialts prof` | Print profession milestones & caps across all alts |
| `/clialts watch <item>` | Add an item to the bag & bank watchlist tracker |
| `/clialts unwatch <item>` | Remove an item from the watchlist tracker |
| `/clialts watchlist` | Print watchlist item totals across all characters |
| `/clialts note <name> [text]` | Set or view custom notes for an alt |
| `/clialts unlocked <instance>`| Gap finder: list alts eligible for an instance without a lockout |
| `/clialts prune <days>` | Scan and prompt to prune alts inactive for N days |
| `/clialts backup` | Create a snapshot backup of your character database |
| `/clialts restore` | Restore character database from the last saved backup |
| `/clialts alerts [category]` | Toggle login alerts (`cooldowns`, `rested`, `mail`, `lockouts`, `on`, `off`) |
| `/clialts digest` | Display boxed login summary digest on demand |
| `/clialts rested` | Print an ASCII summary of all alts' rested XP to chat |
| `/clialts perk <0-5>` | Set or cycle your Well Rested legacy perk rank (0–5) |
| `/clialts gold` | Print total account wealth summary across all alts |
| `/clialts forever` | Toggle WoW Forever mode (cohort routing & phase caps) |
| `/clialts tooltips` | Toggle inventory item count hover tooltips |
| `/clialts minimap` | Toggle the minimap icon on or off |
| `/clialts reset` | Reset main window position to screen center |
| `/clialts perf` | Print execution latency (Collect & Render) and memory usage |
| `/clialts selftest` | Run complete unit test assertions suite (21 feature areas) |
| `/clialts help`, `/clialts ?` | Open the in-game Quick Guide manual |

---

## Engineering, Architecture & Testing

CLIAlts is engineered as a high-performance, lightweight addon adhering to modern Lua 5.1 best practices:

- **Modular Architecture**:
  - `data.lua`: High-throughput character state storage, mathematical projection engine, offline rested accrual calculator, gold sparklines, and SavedVariables schema migration.
  - `ui.lua`: Modern 3-region TUI layout engine, virtual list row recycling, lazy modal creation (`Alt Dossier`, `Context Menu`, `Confirmation Dialogs`), and customizable CRT phosphor theme palette.
  - `core.lua`: Event router (`PLAYER_ENTERING_WORLD`, `PLAYER_LOGOUT`, `BAG_UPDATE`, `TRADE_SKILL_SHOW`), slash command dispatcher, keyboard traps, and terminal prompt parser.
  - `minimap.lua`: High-performance LDB & LibDBIcon minimap integration with live rested/cooldown status tooltips.
- **Lazy Initialization & Memory Optimization**:
  - Sub-panels and modals instantiate lazily on first access, ensuring cold login memory footprint remains under 1.2 MB.
  - Frame recycling in the main character table avoids runtime garbage creation during tab navigation, scrolling, and prompt filtering.
- **Headless Unit Verification (229 Assertions across 21 Suites)**:
  - Validated by an in-game self-test suite (`/clialts selftest`) and headless testing under vanilla Lua 5.1 (`tests/stub.lua` + `tests/selftest.lua`).
  - Covers offline rest accrual formulas, perk bonus scaling, cap clamping, priority scoring, prompt grammar, item watchlists, and SavedVariables migration integrity.
- **Continuous Integration Pipeline**:
  - Every commit is automatically verified against [GitHub Actions CI](https://github.com/nasroht/clialts/actions), enforcing strict **Luacheck** static analysis (0 errors, 0 warnings) and plain **Lua 5.1** headless execution.

---

## Installation

1. Copy the `clialts` folder into your World of Warcraft directory:
   ```text
   World of Warcraft\_classic_beta_\Interface\AddOns\clialts
   ```
   *(Or the corresponding `Interface\AddOns` folder for WoW Forever / Classic Era / Anniversary)*
2. Ensure the folder name is `clialts` and contains `clialts.toc`, `data.lua`, `minimap.lua`, `ui.lua`, and `core.lua`.
3. Launch World of Warcraft and enable **CLIAlts** in your AddOns list.
4. Log into any character and type `/clialts` or click the minimap button to open your dashboard!

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
