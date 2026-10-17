# Changelog

All notable changes to **ForeverAlts** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.2] - 2026-10-17

### Fixed & Improved
- **Overview Tab "TIME TO CAP" Sorting**: Resolved an issue where sorting by Time To Cap failed to order alts actively accumulating rested XP. Introduced continuous time-to-cap scoring where urgent/wasting alts sort first, followed by capped alts (0s), ascending time remaining until cap, with max-level characters cleanly grouped at the end.
- **Rested XP Sorting by Percentage**: Sorted characters by the normalized rested percentage (`r.currentRested / char.maxXP * 100`) matching the exact value displayed in the circular gauge, preventing higher-level alts with small percentages from superseding low-level alts at 150% cap.
- **Overview Tab "CHARACTER" Column Sort by Level**: Clicking the `CHARACTER` column header on the Overview dashboard now sorts by character level (highest level first: 60 → 1, tie-breaking alphabetically), providing immediate one-click progression ordering without cluttering the consolidated gauge layout.
- **Level Sort Direction Polish**: Clicking `level` or `CHARACTER` on Overview now defaults to descending (highest level 60 first) on first click, reversing to ascending on second click.

## [1.3.1] - 2026-10-17

### Added
- **Third-Party Bag Addon Auto-Detection**: Added instantaneous in-memory detection of third-party bag management and alt tracking addons (`Bagnon`, `Baganator`, `AdiBags`, `ArkInventory`, `BetterBags`, `Inventorian`, `Combuctor`, `LiteBag`, `tdBag2`, `cargBags_Nivaya`, and `Altoholic`).
- **Conflict Auto-Resolution for Bag Sort Button**: When a supported third-party bag addon is loaded, ForeverAlts automatically disables and hides its duplicate `[S]` sort button to eliminate interface clutter, issuing a single polite chat notice on first login.
- **Granular Tooltip Split & Mail Router Tag Retention**: Split cross-character item hover tooltips into independent controls (`showAltCountTooltips` and `showMailRouteTooltips`). When Bagnon, Baganator, or Altoholic is detected, duplicate alt item counts are suppressed while **Inter-Alt Mail Router destination tags remain fully active** (`[Mail Router] Send to: <Alt> (<Reason>)`).
- **Dynamic Auto-Restoration & Manual Overrides**: If third-party bag addons are uninstalled or disabled in the future, ForeverAlts automatically detects their removal on login and restores its default `[S]` button and alt item tooltips. Full manual control is supported via `/fa sortbtn`, `/fa tooltip`, and the Settings Dialog.

## [1.3.0] - 2026-10-17

### Added
- **Instant ESC Key Dismissal**: Pressing `ESC` anywhere while viewing the addon cleanly dismisses open dialogs, clears input focus, or closes the main panel immediately without opening the World of Warcraft game menu.
- **Overview Table View Toggle**: Added interactive `[ View: Gauges | View: Table ]` view toggle button to the filter bar and `/fa view` slash command, allowing instant switching between visual gauges and condensed analysis columns.
- **Pending Mail Tooltip Inspection**: Hovering over the pending mail counter on character cards now reveals a full itemized tooltip breakdown including item names, stack counts, and quality color borders.

### Improved & Fixed
- **UI Strata & HUD Elevation (`DIALOG`)**: Elevated the main window to the `DIALOG` frame strata, ensuring it renders strictly above action bars, custom HUDs, combat text, and unit frames; elevated all overlay modals to `FULLSCREEN_DIALOG`.
- **Rested Accumulation Rate Consistency**: Unified rested rate calculations across the entire interface. The character dossier now displays the exact offline resting accrual rate (`+146 XP/hr`) matching the gauge hover tooltips rather than active combat grinding rates.
- **Streamlined Time to Cap Column**: Replaced redundant numeric rested pool values in the Overview table with a single, vertically centered **TIME TO CAP** countdown (`Caps in ...`, `At Cap`, or `Level Cap Reached`).
- **Dossier Avatar & Identity Simplification**: Replaced the placeholder avatar initial with the character's level badge and simplified the identity subline to cleanly show race and class.
- **Engine Performance**: Added reusable scratch buffers and column metadata caching to eliminate table render allocations.

## [1.2.2] - 2026-10-16

### Added
- **`/fa version` Slash Command**: Instantly prints the installed ForeverAlts version (`v1.2.2`) and CurseForge project reference (`#1747176`) to the chat window (aliases: `/fa ver`, `/fa -v`, `/fa --version`).
- **Interactive Terminal Command Prompt Support**: Added `version` to the bottom command bar and autocomplete list, with live feedback on the current build.
- **`CLIAlts:PrintVersion()` API**: Programmatic helper for version inspection across modules and diagnostics.

### Fixed & Improved
- **Detail Panel Rested Card Boundaries**: Fixed unbounded FontStrings in the character detail dossier (`restedCard.perkLine` and `restedCard.rate`). Added strict right border anchors, disabled word wrap, and reduced secondary font size to 11pt, eliminating all text overflow past card borders across all addon UI scales (80%–145%).
- **Rested XP Gauge Level Accuracy**: Gauge percentage now displays exact character level rested percentage (e.g. `12.6%` / `454 XP`) rather than the normalized cap ratio.
- **Character Identity Isolation**: Resolved player identification collision where characters sharing a first name (e.g. "Nas Brother" vs "Nas Uncle") could cross-match live session rested data.
- **Early Login Zero Guard**: Prevented early login client zeroes and wilderness logout uninitialized flags from overwriting saved rested XP or money pools.
- **Sidebar Tab & Badge Explanations**: Added rich tooltips explaining each navigation tab and unassigned / alert badge counter.
- **Play Next Session Cards**: Redesigned recommendation engine into modern "Next Session" priority cards with actionable leveling targets.

## [1.2.1] - 2026-10-15

### Changed
- **Rebrand to ForeverAlts**: Dedicated exclusively to World of Warcraft: Forever.
- **CurseForge Integration**: Updated packaging for new CurseForge project ID `1747176`.
- **Slash Commands**: Registered primary commands `/foreveralts`, `/fa`, and `/forever` (with `/clialts` and `/ca` preserved as legacy aliases).
- **Dual SavedVariables**: Added seamless `ForeverAltsDB` and `CLIAltsDB` aliasing so existing character data and configurations carry forward automatically.
- **Media**: Added official ForeverAlts CRT terminal emblem and updated project documentation.

## [1.2.0] - 2026-10-15

### Added
- **Modern Executive Dashboard**: Complete UI overhaul featuring a high-resolution 1440px wide executive layout, large 18pt typography, class-colored avatar rings, and visual level XP and Rested XP progress bars.
- **"Play Next" Intelligence & Leveling Session Planner**: Intelligent rotation scoring banner with actionable alt cards, Rested XP burn rates, and automated session planning.
- **WoW Forever & Classic Suite (Components 1–6)**:
  - **Component 1 (Roster Categorization & Cohorts)**: Core, Alt, and Bank cohorts with dynamic target leveling goals ("Target Level Reached") and WoW Forever dual-name surname recognition.
  - **Component 2 (Smart Rotation Engine)**: Calibrated for WoW Forever's *Well Rested* legacy perk (Ranks 0–5) and offline rested calculations.
  - **Component 3 (Profession Milestones)**: Training thresholds, cooldown monitors, and recipe eligibility tracking.
  - **Component 4 (Automated Dungeon Quest Tracker)**: Pre-requisite quest chain tracking and dungeon readiness overview.
  - **Component 5 (Inter-Alt Mail & Supply Chain Router)**: Auto-fill button on `SendMailFrame`, intelligent material destination routing, and instant recipe recognition.
  - **Component 6 (Legacy Point Progress Tracker)**: In-game LP tracking for milestone rewards.
- **Secondary Profession Opt-In Routing**:
  - Dedicated character-level toggles for Cooking (Meat & Fish) and First Aid (Cloth / Bandages) in the Mail Route Dialog, modern detail card, and slash commands (`/ca cook`, `/ca firstaid`).
  - Cooking and First Aid materials default to safely ignored (kept in player bags) unless explicitly enabled on an alt.
- **Bag Management & Auto-Sort Engine**:
  - Built-in `[S]` auto-sort button anchored directly to the backpack (`ContainerFrame1` / `ContainerFrameCombinedBags`) with self-healing visibility monitoring.
  - Automated multi-bag stack consolidation and fallback sorting engine across Vanilla, Classic Era, and Retail clients.
- **Cross-Character Inventory & Bank Item Hover Tooltips**: Hover over any item in the world, bags, or bank to view exact item counts held across all tracked alts on the realm.
- **Dedicated Settings & Preferences Dialog (`/ca settings`)**: Theme picker (Dracula, Amber CRT, Green CRT, Cyberpunk, Classic Dark), font scaling, audio toggles, and feature controls.
- **Chat Layout Cloner Engine (`/ca clonechat`)**: Clone chat window dimensions, tabs, font sizes, colors, and channels across alts.
- **Account Liquid Wealth & Dynamic Trend Engine**: Real-time liquid gold calculation and weekly trend indicators.

### Fixed
- Fixed container item link scanning on Classic Era and WoW Forever 1.12 6-argument container APIs so items and recipes in bags are immediately recognized.
- Restored direct container frame parenting and frame level layering for the bag auto-sort button to eliminate visual occlusion under WoW's `toplevel="true"` bag windows.
- Fixed cross-faction mailing guards and self-mailing prevention checks.
- Eliminated all potential UI taint on Blizzard action bars and bag micro-buttons by decoupling container visibility inspection into an unhooked event watcher.

---

## [1.1.0] - 2026-10-13

### Added
- **Colorblind-Safe Phosphor Theme (`SAFE`)**: Added high-contrast cerulean blue, sky blue, slate, and vivid amber/gold CRT palette (`COLORBLIND` / `SAFE`) accessible via title bar theme cycle, prompt command (`> theme safe`, `> theme colorblind`), or slash command (`/ca theme safe`).
- **One-Key Compact Mode (`C`)**: Added one-key toggle with `C` key and `[ C: COMPACT ]` title bar button. Hides the XP bar column in Tab 1 and rest bar in Tab 2 (reducing line width from 85 to 68 characters) and automatically shrinks the main window from 780px to 630px for narrow windows and high UI scaling (130%–145%). Keypress is focus-aware, preserving full functionality of the terminal prompt.
- **Monochrome-Safe Capped Indicators**: Replaced reliance on red/green colors with unambiguous textual glyphs and alert markers:
  - Capped rested percentage marked with an explicit asterisk (`150%*`).
  - Rested ETA displays `[CAP]` when full and `!1d 2h` with amber styling when actively wasting.
  - Rested visual bar displays solid hash glyphs `[##########] 150%*` for capped alts vs step blocks `[========..]` for accruing alts.
  - Minimap and LibDataBroker tooltips display `[!]` and `[*]` tags with amber warning colors instead of red vs green.
- **Optional LibDataBroker-1.1 Integration**: Added LDB data source object (`CLIAlts`) for Titan Panel, Bazooka, ChocolateBar, and other broker displays. Shows capped alt count, total rested XP waste, and quick summary with zero memory overhead when LDB is absent.
- **Hearthstone Location & Inactivity Pruner**:
  - Added bind location tracking (`HEARTH` column in Tab 1) via `GetBindLocation()`.
  - Added stale alt flag (`STALE`) for characters not visited in N days.
  - Added bulk prune command (`/ca prune <days> [confirm]` and `> prune <days>`) with a retro ASCII confirmation modal dialog.
- **Interactive Item Watchlist & Chat Linking**:
  - Hooked `ChatEdit_InsertLink` so Shift-clicking any item in bags, bank, or chat pastes directly into the terminal prompt.
  - Parsed item IDs (`|Hitem:(%d+)`) to ensure resilience against localized clients and duplicate item names.
  - Dropped watchlist counts automatically cleaned up upon item removal.
- **Raid & Dungeon Lockout Gap Finder**: Added `> unlocked <instance>` / `/ca unlocked <instance>` to find characters eligible for raids or dungeons with no active lockout for the reset cycle, complete with raid aliases and auto-complete suggestions.
- **Per-Alt Notes System**: Added `> note <name> <text>` / `/ca note <name> <text>` for customizable character notes (e.g. `farm mooncloth`, `banker`), integrated into character tooltips, Dossier modal, search filters, and table sorting.
- **Leveling Session Planner**: Added `> plan [hours]` / `/ca plan [hours]` to calculate session schedules based on live session XP/hour tracking and calibrated rested pool burn rates.
- **Unified Login Digest**: Added consolidated boxed ASCII login banner (<= 5 lines) showing capped alts, ready cooldowns, expiring mail, and reset timers, with category toggles via `/ca alerts`.
- **Performance Profiling & Automated Self-Test**:
  - Added `/ca perf` displaying exponential moving averages (EMA) for Collect and Render runtimes in milliseconds, plus addon memory usage.
  - Added `/ca selftest` suite containing 11 assertion sections covering rested projections, waste calculations, calibration, compact mode, and phosphor themes.

### Changed
- Standardized slash command aliases to `/clialts`, `/cli`, and `/ca`.
- Optimized watchlist event updates to drop redundant iterations.
- Dynamically resized border lines to match table width across normal and compact layouts.

---

## [1.0.0] - 2026-10-12

### Added
- **Retro Monospace CRT Terminal TUI**: DEC VT220 style ASCII interface with green, amber, cyan, and monochrome phosphor palettes.
- **Interactive Terminal Prompt (`>`)**: Full command prompt with up/down command history, tab auto-completion, and direct commands.
- **5 Dashboard Tabs**: Overview, Rested XP Monitor, Professions & Recipes, Economy / Bags / Bank, and Cooldowns & Instance Lockouts.
- **Rested XP Engine & Projection**: Accurate offline accumulation formulas for inns/cities (10 days) vs wilderness (40 days).
- **WoW Forever Custom Perks**: Native support for Well Rested legacy perk ranks (0–5).
- **Rested XP Waste Tracker**: Monitors time sitting at rested cap and accrued wasted XP.
- **Item Watchlist**: Bag and bank tracking for specific items.
- **Gold History & ASCII Sparklines**: 90-day snapshot history and status bar sparkline rendering.
- **Mail Expiry Tracking**: Inbox scan and login warnings for mail expiring in <= 3 days.
- **In-Game CSV Export**: Spreadsheets-ready CSV exporter.
- **Minimap Orbiting Button**: Movable circular ASCII button with quick-look tooltip.
