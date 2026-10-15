# Changelog

All notable changes to **CLIAlts** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
