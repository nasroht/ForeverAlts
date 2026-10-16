# Developer & Agent Guidelines for ForeverAlts

This document outlines architectural rules, engine compatibility requirements, and error prevention guidelines for the **ForeverAlts** (formerly CLIAlts / NasAlts) World of Warcraft addon. All AI coding assistants (Antigravity, Cursor, Copilot, etc.) and human contributors must follow these rules to avoid regressions.

---

## 1. WoW Frame Backdrop & BackdropTemplate Rules

### The Rule
In modern World of Warcraft client engines (including Shadowlands+, Retail, Classic 1.14/1.15+, Classic Beta, and custom modern client forks like WoW Forever):
* Plain `Frame` objects **do not** inherit `SetBackdrop`, `SetBackdropColor`, or `SetBackdropBorderColor` by default.
* Any frame requiring a backdrop **must** explicitly pass `BackdropTemplateMixin and "BackdropTemplate" or nil` as its template parameter during `CreateFrame`:
  ```lua
  local frame = CreateFrame("Frame", "ForeverAltsMyFrame", parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ```
* Before calling `SetBackdropColor` or `SetBackdropBorderColor`, **always check for method existence**:
  ```lua
  if frame.SetBackdropColor then
      frame:SetBackdropColor(r, g, b, a)
  end
  if frame.SetBackdropBorderColor then
      frame:SetBackdropBorderColor(r, g, b, a)
  end
  ```
* **Do not set backdrops on transparent container frames**: If a frame is solely a layout container (such as `CLIAltsSummaryBar` inside `CLIAltsRecPanel`), do not call `SetBackdropColor` on it. The parent frame already manages the visual backdrop.

### Testing Gotcha
The headless test runner (`tests/stub.lua`) defines generic dummy frames. Do not assume that because a method succeeded in `tests/stub.lua`, it exists on all WoW frame types in live client builds.

---

## 2. Minimap & Button Click vs Drag Handling

### The Problem
Registering both `RegisterForClicks("LeftButtonUp")` and `RegisterForDrag("LeftButton")` on a button can cause WoW's engine to fire `OnDragStart` upon slight cursor drift or immediate mouse down. If a drag flag is set, normal clicks will be swallowed.

### The Standard Pattern
* **Distance Threshold**: Never set `isMoving = true` immediately in `OnDragStart`. Record the initial cursor position (`GetCursorPosition()`) and require at least a 5-pixel displacement in `OnUpdate`:
  ```lua
  local dx = curX - self.dragStartX
  local dy = curY - self.dragStartY
  if (dx * dx + dy * dy) > 25 then
      self.isMoving = true
  end
  ```
* **Never rely on delayed timers for reset**: Do not use `C_Timer.After(0.05, ...)` to reset drag flags in `OnDragStop`. In many client builds, `OnClick` executes immediately on the same frame as mouse release, so delayed timers cause clicks to be swallowed.
* **Cancel Clicks Cleanly**:
  ```lua
  minimapBtn:SetScript("OnClick", function(self, button)
      if self.wasDragged or self.isMoving then
          self.wasDragged = false
          self.isMoving = false
          return
      end
      -- Process click logic...
  end)
  ```
* **Drag Registration**: Only register `"LeftButton"` for drag unless right-button dragging is explicitly required.

---

## 3. UI Error Handling & Visibility Traps

### The Problem
WoW clients default to hiding Lua runtime exceptions when `scriptErrors` CVar is `0`. If an error occurs inside `CreateMainFrame()`, `ApplyTheme()`, or `Render()`, the UI will silently fail to appear with no error message displayed to the user.

### The Rule
* Wrap top-level UI entry points in `pcall`:
  * `CLIAlts:Toggle(show)` in `ui.lua`
  * `CLIAlts:Refresh()` in `ui.lua`
  * `minimapBtn:SetScript("OnClick", ...)` in `minimap.lua`
* Always report caught errors to `DEFAULT_CHAT_FRAME` with bright red formatting:
  ```lua
  local ok, err = pcall(function() ... end)
  if not ok then
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
          DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[ForeverAlts]|r UI Toggle error: %s", tostring(err)))
      end
  end
  ```

---

## 4. Window Position & SavedVariables Validation

When restoring window coordinates from `CLIAltsDB.settings.windowPos`:
* Always validate that `pos.x` and `pos.y` are numbers.
* Validate against `NaN` and extreme off-screen values (`pos.x == pos.x and math.abs(pos.x) < 5000`).
* Wrap `frame:SetPoint(...)` in `pcall`. Fall back to `frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)` if restoration fails or coordinates are corrupt.

---

## 5. Audio & API Flavor Differences

* `PlaySound` and `SOUNDKIT` vary between Vanilla 1.12, WotLK 3.3.5, Modern Classic, and Retail.
* Always wrap sound calls in `pcall` (e.g. `pcall(PlaySound, ...)`).

---

## 6. Modern WoW Forever & API Namespaces

* **Modern Engine Architecture**: WoW Forever uses modern engine rules, not legacy Vanilla. Do not use legacy global query functions.
* **Modern C_ Namespaces Required**:
  * Use `C_Spell.*` or `C_Item.*` instead of legacy queries like `GetSpellInfo` or `GetItemInfo`.
  * Use `C_Container.*` instead of legacy `GetContainerNumSlots`, `GetContainerItemLink`, etc.
* **Compatibility Guards**: Check for function existence before calling newer `C_` methods if targeting multiple client versions.
* **Combat Lockdown & Execution Safety**:
  * Never call `Show()`, `Hide()`, `SetPoint()`, or resize protected frames while `InCombatLockdown()` is true.
  * Defer UI renders or toggles requested during combat until the `PLAYER_REGEN_ENABLED` event fires.
* **Performance & Garbage Collection**:
  * Never allocate anonymous tables `{}` inside high-frequency handlers like `OnUpdate`.
  * Throttle `OnUpdate` loops with an elapsed accumulator (e.g., run logic only when `elapsed > 0.1`).

---

## 7. Tooltip Hooks & Recursive Scanning Prevention

* **Recursive Tooltip Danger**: Calling tooltip-populating methods (such as `scanTip:SetItemByID(itemID)`) from inside tooltip enhancement hooks (e.g. `TooltipDataProcessor.AddTooltipPostCall` or `OnTooltipSetItem`) can re-trigger tooltip data handlers and cause an unrecoverable `C stack overflow`.
* **Guard Recursion**: Maintain a module-level `isScanningTooltip` reentrancy guard flag:
  ```lua
  if isScanningTooltip then return end
  isScanningTooltip = true
  -- Perform isolated scan on dedicated hidden tooltip
  isScanningTooltip = false
  ```
* **Dedicated Scan Tooltip**: Use a dedicated, isolated hidden scanning frame (`CLIAltsScanTip`) rather than querying or modifying active game tooltips.

---

## 8. Circular Gauges & Cooldown Frame Progress

* **Hardware-Accelerated Radial Fills**: Blizzard's `StatusBar` only supports linear horizontal or vertical fills. For circular meters, speedometers, and rings, use Blizzard's `CooldownFrameTemplate`:
  ```lua
  local cd = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
  cd:SetSwipeTexture("Interface\\AddOns\\ForeverAlts\\media\\ring_swipe.tga")
  cd:SetSwipeColor(r, g, b, 1)
  cd:SetDrawEdge(false)
  cd:SetDrawBling(false)
  cd:SetHideCountdownNumbers(true)
  ```
* **Freeze Radial Angle**: Set static progress without ticking down by specifying a high base duration (e.g. 100,000s) and invoking `cd:Pause()`:
  ```lua
  local ratio = math.min(math.max(progressRatio, 0), 1)
  if ratio <= 0 then
      cd:Clear()
  else
      cd:SetCooldown(GetTime() - (ratio * 100000), 100000)
      if cd.Pause then cd:Pause() end
  end
  ```
* **Inner Cutout Disc**: Layer a dark circular disc texture or frame over the center of the ring to create a crisp speedometer/donut gauge and anchor numeric percentage text in the center.

---

## 9. TOC File & Interface Version Constraint

* **Exclusively 16001**: The `ForeverAlts.toc` interface version must be set exclusively to `16001` (WoW Forever). Do not add alternative client version numbers unless specifically instructed by the project maintainer.

---

## 10. Commit & Release Constraints

* **CurseForge Tag Guard**: NEVER push `v*` git release tags. Always push to branch `main`. Releases are triggered through tagged releases only when explicitly approved.
* **Exact UI Wording**: The UI status label for reaching cohort targets must be **"Target Level Reached"** (never "Parked").
* **Client Synchronization**: Whenever committing changes to repository files, synchronize modified files to the local WoW client test folder:
  `D:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverAlts\`
* **CI Quality Gate**: All commits to `main` must pass both `Luacheck` (0 errors, 0 warnings) and `Self-Test (Lua 5.1)` in GitHub Actions.