# Changelog

All notable changes to this project are documented in this file.  
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · Versioning: [Semantic Versioning](https://semver.org/)

---

## [4.7.29] – 2026-04-03

### Changed
- Version bump for release.

---

## [4.7.27] – 2026-02-18

### Changed
- Version bump for release.

---

## [4.7.26] – 2025-06-15

### Added
- **Complete TWW hunter pet family coverage** — all missing The War Within hunter pet families added to the `familyColours` table.
- New **Exotic** families: Carapid, Pterrordax, Shale Beast.
- New **Mammal** families: Courser, Feathermane, Gruffhorn, Hound, Mammoth, Stag, Wolf.
- New **Bird** families: Bat, Waterfowl.
- New **Reptile** families: Hopper, Ray, Wind Serpent.
- New **Insect** families: Scorpid.
- **Special / skill-required** families: Blood Beast, Lesser Dragonkin, Warp Stalker.

### Changed
- Updated hunter pet family fallback colors to cover all current TWW pet families.
- Normalized some family naming (e.g., "Shale Spider" → "Shale Beast").
- Enhanced color variety across all pet family types with thematic color choices.

### Fixed
- Missing fallback colors for newer hunter pet families introduced in The War Within expansion.

---

## [4.7.25] – 2025-06-15

### Added
- **Lua 5.2 + 5.4 compatibility**: `local unpack = table.unpack or unpack` shim.
- Class-colour buttons now show both **male / female** localized names where they differ.
- Enhanced Blizzard health bar color override for Dragonflight/TWW+.

### Fixed
- `"attempt to call global 'SetHealthColor' (a nil value)"` error.
- `"attempt to index a number value"` on retail when `GetStatusBarTexture()` returned a fileID.
- Missing `SetHealthColor` function definition.

### Changed
- Texture-detection logic finalized:
  - Blizzard gradient → recoloured via `VertexColor` (keeps gloss, no tint).
  - AzeriteUI / oUF numeric gradients → recoloured, not replaced.
  - Unknown custom textures → fallback to `WHITE8X8`.
- Improved code organization with proper sectioning and comments.

---

## [4.7.20] – 2025-06-15

### Added
- Lua 5.2 + 5.4 compatibility shim.
- Class-colour buttons show male/female localized names.

### Changed
- Texture-detection logic finalized (same as 4.7.25).

### Fixed
- `"attempt to index a number value"` on retail when `GetStatusBarTexture()` returned a fileID.

---

## [4.7.19] – 2025-06-15

### Changed
- Reverted earlier texture swap (to flat `WHITE8X8`) for Blizzard bars; now re-tint gradient instead.

### Fixed
- Unwanted flat-brown bar on AzeriteUI frames.

---

## [4.7.18] – 2025-06-15

### Fixed
- Removed duplicate numeric-texture branch that forced all bars to flat white.
- Extra `end` in `PatchFrame` eliminated (syntax error).
- Deleted leftover duplicate `SetHealthColor` snippet.

---

## [4.7.17] – 2025-06-15

### Fixed
- `PatchFrame` now tests `type(texPath)` before `:match()`, preventing "attempt to index a number value" on numeric fileIDs.
- Missing `end` after `hooksecurefunc` block.
- Duplicate `SetHealthColor` snippet removed.

---

## [4.7.16] – 2025-06-15

### Added
- **Blizzard Dragonflight/TWW player-frame support** (`ForceBlizzardHealthBarColor`).
- Hook to keep bar colored after Blizzard refreshes it.

---

## [4.7.6] – 2025-06-15

### Added
- Rainbow toggle button now shows **"Stop Rainbow Effect"** while active.
- Ping-Pong mode re-implemented with true HSV hue sweep (0 → 1 → 0) for clearer contrast vs Cycle.

### Fixed
- `StopRainbow` nil error when hunter-pet events fired before rainbow functions were in scope.
- Duplicate `storedPlayerColor, storedRainbow` declaration removed.

---

## [4.7.5] – 2025-06-15

### Added
- **Advanced Rainbow patterns**: Cycle, Ping-Pong, Chaos with single toggle button.
- Ping-Pong sweeps the HSV hue wheel and reverses.
- Chaos picks a fresh random hue every tick (0.1 s).
- Rainbow toggle button text switches between **"Rainbow Effect"** and **"Stop Rainbow Effect"**.

---

## [4.7.4] – 2025-06-15

### Added
- Single **toggle buttons** for both Rainbow and Pulse (start/stop in one button).

### Fixed
- `StopRainbow` nil error in `UNIT_PET` handler.

---

## [4.7.3] – 2025-06-15

### Added
- **Pulse Colour** / **Stop Pulse** buttons — pulse the currently selected colour independently of rainbow.

### Changed
- Removed "Pulse" entry from Rainbow Pattern dropdown (now its own effect).
- Updated `.toc` library paths to match `Libs\…` structure.

---

## [4.7.2] – 2025-06-15

### Added
- Minimap launcher now toggles the options panel (click to open/close).

### Fixed
- Cleaned duplicate state blocks and stray `end` to clear Lua warnings.

---

## [4.7.1] – 2025-06-15

### Added
- Pulse color picker to define the base hue for the Pulse pattern.

---

## [4.7.0] – 2025-06-15

### Added
- Advanced Rainbow patterns: **Cycle**, **Ping-Pong**, **Chaos**.

### Changed
- Rainbow Speed slider restarts animation live.

---

## [4.6.2] – 2025-06-15

### Added
- Minimap / Titan launcher click closes the panel if it is already open.

---

## [4.6.1] – 2025-06-15

### Added
- Descriptive tooltips for every control.

### Fixed
- Removed duplicate tooltip lines and stray em-dashes.

---

## [4.6.0] – 2025-06-15

### Added
- **LibDataBroker + LibDBIcon** minimap launcher with "Show Minimap Icon" toggle.

---

## [4.5.4] – 2025-06-15

### Added
- 40+ hunter-pet family fallback colours.

### Fixed
- Nil reference in reset popup via forward declarations.

---

## [4.5.3] – 2025-06-15

### Added
- Confirmation popup for **Reset to Defaults**.

---

## [4.5.2] – 2025-06-15

### Fixed
- Rainbow buttons missing after header refactor.

---

## [4.5.1] – 2025-06-15

### Added
- Section headers to group options visually.

---

## [4.5.0] – 2025-06-14

### Added
- Alpha-channel support (RGBA).
- Rainbow speed slider (0.1–5 Hz).
- Quick **Class Colour** reset button.
- Colour-blind friendly presets seeded on first run.

---

## [4.0.0] – 2025-06-10

### Added
- **Ace3 complete rewrite**: static colour picker, rainbow cycle, presets, save-to-pet, random colour, class buttons.

---

## [3.1.x] – 2025-05-25 to 2025-05-30

### Notable changes in the 3.1 series
- **3.1.103**: Preset save now prompts for a custom name.
- **3.1.102**: Hunter-pet presets now revert to player colour when pet is dismissed.
- **3.1.101**: Automatic hunter-pet name presets applied on summon.
- **3.1.100**: Initial Ace3 public release with rainbow cycle, presets, and debug logging.

---

## [2.x] – 2025-06-11 to 2025-06-12

### Notable changes in the 2.x series
- **2.9.2**: Dynamic `BuildPresetDropdown`; combat-safe `ApplyColor`.
- **2.9.0**: Rename input box and buttons.
- **2.8.0**: Rainbow cycle toggler.
- **2.7.0**: Blizzard PlayerFrame and oUF support.
- **2.6.0**: AceDB profile system.
- **2.5.0**: Fixed rogue `classColour` resets on AzeriteUI frames.
- **2.0.0**: Modular `ApplyColor` with recursive frame walk.

---

## [1.x] – 2025-06-10 to 2025-06-11

### Notable changes in the 1.x series
- **1.5.0**: Default colour changed to `{0.7, 0.1, 0.1}`.
- **1.0.0**: Health-bar override on login; saved working backup.

---

## [0.x] – 2025-06-10 (Prototype)

- **0.9.0**: Hooked `SetStatusBarColor` on Blizzard/oUF/AUI frames; registered `UNIT_HEALTH`.
- **0.8.0**: Removed unsupported `DB:SaveProfile()`.
- **0.7.0**: Class-colour buttons.
- **0.6.0**: AceConfigDialog panel; `/ahui` opens options.
- **0.5.0**: Slash command registration; fixed `end` mismatches.
- **0.4.0**: Resolved Ace3 load-order and library issues.
- **0.3.0**: `.toc`, AceDB, Interface Options swatch, `/ahui`.
- **0.2.0**: Integrated AzeriteUI colour hooks.
- **0.1.0**: Basic `/hbcp` command; Blizzard PlayerFrame recolor prototype.
