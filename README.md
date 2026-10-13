# CLIAlts - Retro ASCII / TUI Alt & Rested XP Tracker

A retro-styled Text User Interface (TUI) character and alt tracking addon for **World of Warcraft** (compatible with *World of Warcraft: Forever*, *Classic Era*, and modern Classic).

Track your characters' **Faction**, **Race**, **Level**, **Professions**, **Gold**, and **Saved Rested Experience** — including real-time offline accumulation and **exact countdowns and dates for when rested XP will reach 150% (capped)**.

---

## Features

- **Retro Monospace DEC VT220 Terminal TUI Aesthetic**: Styled like a classic CRT terminal or BBS dashboard, complete with ASCII borders, box headers, progress bars, and multiple retro color phosphor palettes.
- **Interactive Terminal Command Prompt (`>`)**:
  - Full interactive terminal EditBox at the bottom of the window.
  - Command history cycling with **Up/Down arrows** (up to 50 commands).
  - Auto-completion with **Tab key** for commands and sort column keys.
  - Quick keyboard navigation: `> 1` .. `> 5` to switch tabs.
  - Direct prompt commands: `> sort gold`, `> filter horde <60`, `> find mining`, `> goto 3`, `> watch Runecloth`, `> next`, `> export`, `> theme cyan`.
- **5 Monospace Dashboard Tabs**:
  - `[ 1: ALTS OVERVIEW ]`: Faction, Name, Level, Race/Class 3-letter codes, XP progress bar, Gold, Rested %, and ETA to cap.
  - `[ 2: RESTED XP MONITOR ]`: Pool vs Cap, ASCII Rested progress bar, accumulation rate, resting state, and ETA / Rested Waste timer.
  - `[ 3: PROFESSIONS ]`: Primary professions with ranks and secondary skills (Cooking, First Aid, Fishing).
  - `[ 4: ECONOMY / WEALTH ]`: Gold breakdown, account wealth share percentage and bar, last known location, plus a 14-character ASCII sparkline (`_.-=*#`) and 24h/7d/30d gold history deltas in the status bar.
  - `[ 5: COOLDOWNS & SAVED LOCKS ]`: Real-time trade skill cooldown timers (Transmutes, Mooncloth, Salt Shaker) and saved raid/dungeon instance lockouts with reset countdowns.
- **Self-Calibrating Rested Model**:
  - Compares live `GetXPExhaustion()` with predicted rested projections on login.
  - If drift > 2%, automatically calculates observed accumulation rate, detects resting state, and auto-calibrates the `Well Rested` legacy perk rank.
- **Rested XP Waste Tracker**:
  - Calculates exactly how long each character has been sitting at maximum rested cap and how much XP has been wasted without accruing (e.g. `capped for 3d 4h, ~52k XP wasted`).
  - Sort by `"waste"` column to prioritize characters losing the most potential XP.
  - `/clialts next` (or `> next`) instantly prints the top 3 alts you should log into right now to stop wasting rested XP.
  - Automatic login alert warning if any alts are currently rested capped.
- **Bank & Bag Item Watchlist**:
  - Lightweight inventory tracking: `/clialts watch <Item Name or ID>` monitors counts across bags and bank without scanning entire bag inventories.
  - View summary across all alts with `/clialts watchlist` (or `> watchlist`).
- **Gold History & ASCII Sparkline**:
  - Daily total-wealth snapshots capped at 90 days.
  - Calculates wealth changes over 24h, 7d, and 30d.
  - Renders a multi-level ASCII sparkline (`_.-=*#`) directly in the Economy tab status line.
- **Mail Expiry Tracker**:
  - Automatically records shortest mailbox expiration time on `MAIL_INBOX_UPDATE`.
  - Alerts you at login if any alt has mail expiring in $\le 3$ days.
- **CSV Data Export**:
  - `/clialts export` (or `> export`) opens an in-game copyable dialog formatted for easy import into spreadsheets (Excel, Google Sheets).
- **Customizable UI Scale & Fonts**:
  - Monospace font rendering with exact column width calculations.
  - `/clialts scale <0.7-1.8>` and title bar `[ SCALE ]` button for 1440p / 4K displays.

---

## Slash Commands

| Command | Description |
| :--- | :--- |
| `/clialts`, `/cli`, or `/ca` | Toggle the main TUI monitor window |
| `/clialts [1-5]` | Open directly to specific tab (1-5) |
| `/clialts next` | Recommend top 3 alts to log into (highest rested XP waste) |
| `/clialts watch <item>` | Add item to bag & bank watchlist tracker |
| `/clialts unwatch <item>` | Remove item from watchlist tracker |
| `/clialts watchlist` | Print watchlist summary across all characters |
| `/clialts export` | Open copyable CSV export modal dialog |
| `/clialts filter <query>` | Filter characters by faction, level range, class, or profession |
| `/clialts clear` | Clear active filter |
| `/clialts scale <0.7-1.8>` | Set UI scale (e.g. `1.2` or `120%`) for high resolution monitors |
| `/clialts font <12-22>` | Set terminal monospace font size (default `15`) |
| `/clialts minimap` | Toggle the minimap icon on or off |
| `/clialts rested` | Print an ASCII summary of all alts' rested XP to chat |
| `/clialts perk <0-5>` | Set or cycle your Well Rested legacy perk rank (0-5) |
| `/clialts gold` | Print total account wealth summary across all alts |
| `/clialts perf` | Print smoothed ms for Collect & Render plus memory usage |
| `/clialts selftest` | Run self-test unit assertions on Rested XP, Waste & Calibration |
| `/clialts alerts [cat]` | Toggle login alert categories (`cd`, `rested`, `mail`, `locks`, `on`, `off`) |
| `/clialts digest` | Display boxed login summary digest on demand |
| `/clialts reset` | Reset window position to the center of your screen |
| `/clialts help` | Open the in-game retro quick guide popup |

---

## Retro Color Themes

Cycle through authentic retro CRT color themes by clicking the `[ THEME ]` button in the title bar or typing `> theme <name>`:
1. **Phosphor Green (`GRN`)**: Classic green monochrome CRT monitor.
2. **VT220 Amber (`AMB`)**: Warm retro amber phosphor display.
3. **Cyberdeck Cyan (`CYN`)**: BBS / neon cyberspace cyan.
4. **VT100 Monochrome (`MON`)**: Classic white phosphor on black.
5. **Synthwave (`SYN`)**: Neon magenta and retro-wave styling.
6. **Dracula (`DRA`)**: Gothic purple and mint terminal palette.

---

## Installation

1. Copy the `clialts` folder into your World of Warcraft directory:
   ```
   World of Warcraft\_classic_beta_\Interface\AddOns\clialts
   ```
   *(Or the corresponding `Interface\AddOns` folder for WoW Forever / Classic Era)*
2. Ensure the folder name is `clialts` and contains `clialts.toc`, `data.lua`, `minimap.lua`, `ui.lua`, and `core.lua`.
3. Launch World of Warcraft and enable **CLIAlts** in your AddOns menu.
4. Log into any character and type `/clialts` or click the minimap button to start tracking!

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
