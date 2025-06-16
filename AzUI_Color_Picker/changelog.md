# Changelog

## [4.7.26] – 2025-06-15

### Added (4.7.26)

- **Complete TWW hunter pet family coverage**: Added all missing The War Within hunter pet families to `familyColours` table.
- New **Exotic families**: Carapid, Pterrordax, Shale Beast.
- New **Mammal families**: Courser, Feathermane, Gruffhorn, Hound, Mammoth, Stag, Wolf.
- New **Bird families**: Bat, Waterfowl.
- New **Reptile families**: Hopper, Ray, Wind Serpent.
- New **Insect families**: Scorpid.
- **Special skill-required families**: Blood Beast, Lesser Dragonkin, Warp Stalker.

### Changed (4.7.26)

- Updated hunter pet family fallback colors to include all current TWW pet families.
- Normalized some family naming (e.g., "Shale Spider" → "Shale Beast").
- Enhanced color variety across all pet family types with thematic color choices.

### Fixed (4.7.26)

- Missing fallback colors for newer hunter pet families introduced in The War Within expansion.

## [4.7.25] – 2025-06-15

### Added (4.7.25)

- **Lua 5.2 + 5.4 compatibility**: `local unpack = table.unpack or unpack` shim.
- Class-colour buttons now show both **male / female** localized names where they differ.
- Enhanced Blizzard health bar color override for Dragonflight/TWW+.

### Fixed (4.7.25)

- "attempt to call global 'SetHealthColor' (a nil value)" errors.
- "attempt to index a number value" on retail when `GetStatusBarTexture()` returned a fileID.
- Missing SetHealthColor function definition.

### Changed (4.7.25)

- Texture-detection logic finalised:  
  - Blizzard gradient → recoloured via VertexColor (keeps gloss, no tint).  
  - AzeriteUI / oUF numeric gradients → recoloured, not replaced.  
  - Unknown custom textures → fallback to `WHITE8X8`.
- Version bump to **4.7.25**.
- Improved code organization with proper sectioning and comments. Picker

All notable changes to this project will be documented in this file.  
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)  
Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## [4.7.20] – 2026-06-16

### Added (4.7.20 – Features)

- **Lua 5.2 + 5.4 compatibility**: `local unpack = table.unpack or unpack` shim.
- Class-colour buttons now show both **male / female** localized names where they differ.

### Changed (4.7.20 – Logic)

- Texture-detection logic finalised:  
  - Blizzard gradient → recoloured via VertexColor (keeps gloss, no tint).  
  - AzeriteUI / oUF numeric gradients → recoloured, not replaced.  
  - Unknown custom textures → fallback to `WHITE8X8`.
- Version bump to **4.7.20**.

### Fixed (4.7.20 – Compatibility)

- “attempt to index a number value” on retail when `GetStatusBarTexture()` returned a fileID.

## [4.7.19] – 2026-06-16

### Changed (4.7.19 – UI)

- Earlier texture swap (to flat `WHITE8X8`) reverted for Blizzard bars; now re-tint gradient instead.
- Option-panel label and header bumped to 4.7.19.

### Fixed (4.7.19 – Bugs)

- Unwanted flat-brown bar on AzeriteUI frames.

## [4.7.18] – 2026-06-16

### Added (4.7.18 – Features)

- Removed duplicate numeric-texture branch that forced all bars to flat white.
- Extra `end` in `PatchFrame` eliminated (syntax error in VS Code).

### Fixed (4.7.18 – Bugs)

- Stray `end` before Blizzard helper comment – stopped `<eof>` compile error.
- Deleted leftover duplicate `SetHealthColor` snippet.

## [4.7.17] – 2026-06-16

### Added (4.7.17 – Features)

- `PatchFrame` now tests `type(texPath)` before `:match()`, preventing
  “attempt to index a number value” on numeric fileIDs.
- Version strings bumped.

### Fixed (4.7.17 – Bugs)

- Missing `end` after `hooksecurefunc` block closed `PatchFrame` correctly.
- Duplicate `SetHealthColor` snippet removed (caused wrong colours / loader fail).

## [4.7.16] – 2026-06-16

### Added (4.7.16 – Features)

- Blizzard Dragonflight/TWW player-frame support** (`ForceBlizzardHealthBarColor`).
- Hook to keep bar coloured after Blizzard refreshes.

### Fixed (4.7.16 – Bugs)

- `PatchFrame` now tests `type(texPath)` before `:match()`, preventing
  “attempt to index a number value” on numeric fileIDs.
- Version strings bumped.

## [4.7.15] – 2026-06-16

### Added (4.7.15 – Features)

- Missing `end` after `hooksecurefunc` block closed `PatchFrame` correctly.
- Duplicate `SetHealthColor` snippet removed (caused wrong colours / loader fail).

### Fixed (4.7.15 – Bugs)

- Deleted redundant two-line snippet overriding colour logic.
- Version bump only.

## [4.7.14] – 2026-06-16

### Added (4.7.14 – Features)

- Second duplicate “Classic / pre-DF path” block removed.
- Stray `end (f.Health,"SetStatusBarColor"...` line deleted (line-213 crash).

### Fixed (4.7.14 – Bugs)

- Began clean-up: re-ordered `PatchFrame`, consolidated texture handling.

## [4.7.13] – 2026-06-16

### Added (4.7.13 – Features)

- Double equals typo (`colorClass=false=false`) corrected.
- Blizzard gradient now recolours via VertexColor not flat replace.

### Fixed (4.7.13 – Bugs)

- Forced `WHITE8X8` on all non-Blizzard bars (prevented green tint on retail).

## [4.7.12] – 2026-06-16

### Added (4.7.12 – Features)

- Retail player bar path updated (`HealthBarsContainer.HealthBar`).

### Fixed (4.7.12) – Bugs

- Blizzard helper added, but wrong path: resulted in nil test, quickly superseded.

## [4.7.6] - 2026-06-15

### Added (4.7.6) – Features

- `StopRainbow` nil error when hunter-pet events fired before rainbow functions were in scope.
- Duplicate `storedPlayerColor, storedRainbow` declaration removed.

### Fixed (4.7.6) – Bugs

- Rainbow toggle button now shows **“Stop Rainbow Effect”** while active.
- Ping-Pong mode re-implemented with true HSV hue sweep (0 → 1 → 0) for clearer contrast versus Cycle.

(No functional code changes to Pulse or presets.)

## [4.7.5] - 2026-06-15

### Added (4.7.5) – Features

- **Ping-Pong** pattern now sweeps half the HSV hue wheel and reverses, giving a visibly different effect from Cycle.
- Chaos pattern now picks a fresh random hue every tick (0.1 s) for maximum contrast.
- Rainbow toggle button text switches between **“Rainbow Effect”** and **“Stop Rainbow Effect”**.
- Version bump to **4.7.5**.

## [4.7.4] - 2026-06-15

### Added (4.7.4) – Features

- Single **toggle buttons** for both Rainbow and Pulse (start/stop in one).

### Fixed (4.7.4) – Bugs

- `StopRainbow` nil error in `UNIT_PET` handler by converting it to an up-value assignment.
-

## [4.7.3] - 2026-06-15

### Added (4.7.3) – Features

- **Pulse Colour** / **Stop Pulse** buttons that pulse the currently selected colour (independent of rainbow).

### Changed (4.7.3)

- Removed “Pulse” entry from Rainbow Pattern dropdown (now its own effect).
- Updated `.toc` library paths to match `Libs\…` structure.

## [4.7.2] - 2026-06-15

### Added (4.7.2) – Features

- Minimap launcher now toggles the options panel (click to open/close).

### Fixed (4.7.2) – Bugs

- Cleaned duplicate state blocks and stray `end` to clear Lua warnings.

## [4.7.1] - 2026-06-15

### Added (4.7.1) – Features

- Pulse Colour picker to define the base hue for Pulse pattern.

## [4.7.0] - 2026-06-15

### Added (4.7.0) – Features

- Advanced Rainbow patterns: **Cycle**, **Ping-Pong**, **Chaos** (Pulse split later).

### Changed (1.5.0)

- Rainbow Speed slider restarts animation live.

## [4.6.2] - 2026-06-15

### Added (4.6.2)

- Minimap/Titan launcher click now closes the panel if it’s already open.

## [4.6.1] - 2026-06-15

### Added (4.6.1)

- Descriptive tooltips for every control.

### Fixed (4.6.1)

- Removed duplicate tooltip lines and stray em-dashes.

## [4.6.0] - 2026-06-15

### Added (4.6.0)

- **LibDataBroker + LibDBIcon** minimap launcher with “Show Minimap Icon” toggle.

## [4.5.4] - 2026-06-15

### Added (4.5.4

- 40+ hunter-pet family fallback colours (with comments).

### Fixed (4.5.4)

- Nil reference in reset popup via forward declarations.

## [4.5.3] - 2025-06-15

### Added (4.5.3 – Features)

- Confirmation popup for “Reset to Defaults”.

## [4.5.2] - 2025-06-15

### Fixed (4.5.2 – Bugs)

- Rainbow buttons missing after header refactor.

## [4.5.1] - 2025-06-15

### Added (4.5.1 – Features)

- Section headers to group options visually.

## [4.5.0] - 2025-06-14

### Added (4.5.0 – Features)

- Alpha-channel support (RGBA).
- Rainbow speed slider (0.1 - 5 Hz).
- Quick “Class Colour” reset button.
- Colour-blind friendly presets seeded on first run.
- AceLocale scaffold for future translations.

## [4.0.0] - 2025-06-10

### Added (4.0.0 – Features)

- Ace3 rewrite: static colour picker, rainbow cycle, presets, save-to-pet, random colour, class buttons.

## [3.1.103] - 2025-05-30

### Added (3.1.103 – Features)

- Preset save now prompts for custom name.

## [3.1.102] - 2025-05-28

### Fixed (3.1.102 – Bugs)

- Hunter-pet presets now revert to player colour when pet dismissed.

## [3.1.101] - 2025-05-25

### Added (3.1.101 – Features)

- Automatic hunter-pet name presets applied on summon.

## [3.1.100] - 2025-05-21

### Added (3.1.100 – Features)

- Initial Ace3 public release with rainbow cycle, presets, and debug logging.

## [3.0.100] - 2025-06-13

### Added (3.0.100 – Features)

- (Original note set – modular rewrite, rainbow cycle, class colours, presets, debug logging, etc.)

### Fixed (3.0.100 – Bugs)

- DB nil during startup, double event registration.

## [2.9.2] - 2025-06-12

### Added (2.9.2 – Features)

- Dynamic BuildPresetDropdown; combat-safe ApplyColor.

## [2.9.0] - 2025-06-11

### Added (2.9.0 – Features)

- Rename input box and buttons.

## [2.8.0] - 2025-06-11

### Added (2.8.0 – Features)

- Rainbow cycle toggler.

## [2.7.0] - 2025-06-11

### Added (2.7.0 – Features)

- Blizzard PlayerFrame and oUF support.

## [2.6.0] - 2025-06-11

### Added (2.6.0 – Features)

- AceDB profile system.

## [2.5.0] - 2025-06-11

### Fixed (2.5.0 – Bugs)

- Rogue classColour resets on AzeriteUI frames.

## [2.0.0] - 2025-06-11

### Added (2.0.0 – Features)

- Modular ApplyColor with recursive frame walk.

## [1.5.0] - 2025-06-11

### Changed (1.5.0 – Updates)

- Default colour to RGB {0.7, 0.1, 0.1}.

## [1.0.0] - 2025-06-10

### Added (1.0 – Core)

- Health-bar override on login.
- Saved a fully working backup version as reference.

## [0.9.0] - 2025-06-10

### Added (0.9 – Hooks)

- Hook SetStatusBarColor on Blizzard/oUF/AUI frames.
- Hooked `SetStatusBarColor` on PlayerFrame, oUF_Player, and AzeriteUnitFramePlayer.
- Registered `UNIT_HEALTH` event to reapply on every health update.
- Added `C_Timer.NewTicker` fallback to catch edge-case updates.

## [0.8.0] - 2025-06-10

### Fixed (0.8.0)

- Removed unsupported DB:SaveProfile().
- Discovered AceDB saves only on logout/reload.
- Removed unsupported `DB:SaveProfile()` calls.
- Suggested manual `/reload ui` or explicit `ReloadUI()` for immediate persistence.

## [0.7.0] - 2025-06-10

### Added (0.7 – Classes)

- Class-colour buttons.
- Extended options with one execute button per `RAID_CLASS_COLORS` entry.
- Clicking a class button immediately applies that class's color.

## [0.6.0] - 2025-06-10

### Added (0.6 – Config)

- AceConfigDialog panel.
- Adopted AceConfig-3.0 & AceConfigDialog-3.0 for a polished options UI.
- `/ahui` now opens the Blizzard-style options panel.
- Exposed a single "Healthbar Color" picker.

## [0.5.0] - 2025-06-10

### Added (0.5 – Structure)

- Slash command registration.
- Replaced `def` with `local function`, fixed `end` mismatches.
- Re-registered slash commands inside `ADDON_LOADED` properly.
- Corrected file and TOC casing.

## [0.4.0] - 2025-06-10

### Fixed (0.4.0)

- Load-order issues with Ace3.
- Resolved missing Ace3 libraries and AzeriteUI folder name issues.
- Switched between `## Dependencies:` and `## X-EmbedLibraries:`.
- Ensured correct loading of Blizzard_InterfaceOptions APIs.

## [0.3.0] - 2025-06-10

### Added (0.3 – Skeleton)

- .toc, AceDB, Interface Options swatch, /ahui.
- Created `.toc` and main Lua file.
- Added AceDB-3.0 for saved settings.
- Built Interface Options panel with swatch button.
- Introduced slash `/ahui`.

## [0.2.0] - 2025-06-10

### Added (0.2 – Integration)

- Hooked into AzeriteUI colours.
- Integrated with AceAddon-3.0 to retrieve AzeriteUI addon.
- Overrode `AUI.Colors.health` and repainted all `AUI.units`.
- Provided table override and `hooksecurefunc` on `PostUpdateHealth`.

## [0.1.0] - 2025-06-10

### Added (0.1 – Prototype)

- Basic /hbcp command & PlayerFrame recolour.
- Basic Blizzard ColorPicker integration.
- Slash `/hbcp` to open picker.
- Applies color to Blizzard PlayerFrame health bar only.
