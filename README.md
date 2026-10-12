# CLIAlts - Retro ASCII / TUI Alt & Rested XP Tracker

A retro-styled Text User Interface (TUI) character and alt tracking addon for **World of Warcraft** (compatible with *World of Warcraft: Forever*, *Classic Era*, and modern Classic).

Track your characters' **Faction**, **Race**, **Level**, **Professions**, **Gold**, and **Saved Rested Experience** — including real-time offline accumulation and **exact countdowns and dates for when rested XP will reach 150% (capped)**.

---

## Features

- **Retro ASCII / TUI Aesthetic**: Styled like a classic CRT terminal or BBS dashboard, complete with ASCII borders, box headers, progress bars, and multiple retro color phosphor palettes.
- **Full Mouse & Window Controls**:
  - Drag the window anywhere on screen.
  - Clickable tabs: `[ 1: ALTS OVERVIEW ]`, `[ 2: RESTED XP MONITOR ]`, `[ 3: PROFESSIONS ]`, `[ 4: ECONOMY / WEALTH ]`.
  - Clickable column headers to sort by **Level**, **Name**, **Gold**, or **Rested XP** (toggle Ascending / Descending with arrow indicators `^` and `v`).
  - Hover highlight on rows with terminal prompt arrow `>`.
  - Click any row to view a detailed **Character Dossier** popup.
  - Delete alt records with a retro confirmation modal.
  - Mouse wheel scrolling for unlimited characters.
- **Rested XP Projection & Full Cap Countdown**:
  - Tracks whether characters logged off in an **Inn/City** (+5% every 8 hours) or in the **Wilderness** (+1.25% every 8 hours).
  - Real-time offline estimation: Calculates current rested percentage even when logged on other characters.
  - Displays remaining time until 150% cap (`2d 14h`, `5h 30m`, or `FULL (150%)`).
  - Predicts the exact calendar date and time when rested XP reaches cap (e.g. `Oct 16, 14:30`).
  - Max level characters automatically marked as `[ MAX LEVEL ]`.
- **Professions Tracker**:
  - Tracks primary professions (Mining, Herbalism, Alchemy, Tailoring, etc.) and secondary skills (Cooking, First Aid, Fishing).
  - Shows current skill level and tier cap (e.g. `225/225`).
- **Economy & Wealth Dashboard**:
  - Formats gold, silver, and copper.
  - ASCII bar chart depicting wealth share per character.
  - Calculates total account wealth and average per alt.
- **Interactive Minimap Button**:
  - Sleek circular minimap icon with retro `[A]` display.
  - Left-click to toggle the monitor.
  - Right-click to refresh timers.
  - Drag to reposition along the minimap circumference.
  - Hover tooltip displaying an ASCII quick summary of alts and next rested character.
- **Primary Name & Secondary Name Support (WoW Forever)**:
  - Full native support for World of Warcraft Forever's two-part naming convention (First Name & Surname).
  - Captures and displays both names cleanly in the overview tables, Character Dossier, and chat reports.
  - Characters with the same first name but different surnames are preserved as distinct alts without colliding.
- **First-Load Auto Registration**:
  - Automatically records and updates the logged-in player on first load and subsequent logins.
  - Keeps stats fresh on logout, zone change, and skill rank ups.

---

## Slash Commands

| Command | Description |
| :--- | :--- |
| `/clialts`, `/cli`, or `/ca` | Toggle the main TUI monitor window |
| `/clialts show` | Open the window |
| `/clialts hide` | Close the window |
| `/clialts minimap` | Toggle the minimap icon on or off |
| `/clialts rested` | Print an ASCII summary of all alts' rested XP to chat |
| `/clialts perk <0-5>` | Set your Well Rested legacy perk rank (0-5) |
| `/clialts gold` | Print total account wealth summary across all alts |
| `/clialts reset` | Reset the window position to the center of your screen |
| `/clialts help` | Open the in-game retro quick guide popup |

---

## Retro Color Themes

Cycle through 4 authentic retro CRT themes by clicking the `[ THEME ]` button in the top-right corner of the window:
1. **Phosphor CRT (`GRN`)**: Classic green monochrome monitor.
2. **VT220 Amber (`AMB`)**: Warm retro amber terminal display.
3. **Cyberdeck Cyan (`CYN`)**: Futuristic BBS / neon cyan style.
4. **VT100 Monochrome (`MON`)**: Classic white-on-black terminal.

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
