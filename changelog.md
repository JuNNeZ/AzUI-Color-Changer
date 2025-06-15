# Changelog for AzUI Color Picker
All notable changes to this project will be documented in this file.  
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)  
Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

--------------------------------------------------------------------
## [4.7.3] - 2026-06-15
### Added
- **Pulse Colour** / **Stop Pulse** buttons that pulse the currently selected colour (independent of rainbow).
### Changed
- Removed “Pulse” entry from Rainbow Pattern dropdown (now its own effect).
- Updated `.toc` library paths to match `Libs\…` structure.

## [4.7.2] - 2026-06-15
### Fixed
- Minimap launcher now toggles the options panel (click to open/close).
- Cleaned duplicate state blocks and stray `end` to clear Lua warnings.

## [4.7.1] - 2026-06-15
### Added
- Pulse Colour picker to define the base hue for Pulse pattern.

## [4.7.0] - 2026-06-15
### Added
- Advanced Rainbow patterns: **Cycle**, **Ping-Pong**, **Chaos** (Pulse split later).
### Changed
- Rainbow Speed slider restarts animation live.

## [4.6.2] - 2026-06-15
### Added
- Minimap/Titan launcher click now closes the panel if it’s already open.

## [4.6.1] - 2026-06-15
### Added
- Descriptive tooltips for every control.
### Fixed
- Removed duplicate tooltip lines and stray em-dashes.

## [4.6.0] - 2026-06-15
### Added
- **LibDataBroker + LibDBIcon** minimap launcher with “Show Minimap Icon” toggle.

## [4.5.4] - 2026-06-15
### Added
- 40+ hunter-pet family fallback colours (with comments).
### Fixed
- Nil reference in reset popup via forward declarations.

## [4.5.3] - 2025-06-15
### Added
- Confirmation popup for “Reset to Defaults”.

## [4.5.2] - 2025-06-15
### Fixed
- Rainbow buttons missing after header refactor.

## [4.5.1] - 2025-06-15
### Added
- Section headers to group options visually.

## [4.5.0] - 2025-06-14
### Added
- Alpha-channel support (RGBA).
- Rainbow speed slider (0.1 - 5 Hz).
- Quick “Class Colour” reset button.
- Colour-blind friendly presets seeded on first run.
- AceLocale scaffold for future translations.

## [4.0.0] - 2025-06-10
### Added
- Ace3 rewrite: static colour picker, rainbow cycle, presets, save-to-pet, random colour, class buttons.

--------------------------------------------------------------------
## [3.1.103] - 2025-05-30
### Added
- Preset save now prompts for custom name.

## [3.1.102] - 2025-05-28
### Fixed
- Hunter-pet presets now revert to player colour when pet dismissed.

## [3.1.101] - 2025-05-25
### Added
- Automatic hunter-pet name presets applied on summon.

## [3.1.100] - 2025-05-21
### Added
- Initial Ace3 public release with rainbow cycle, presets, and debug logging.

--------------------------------------------------------------------
## [3.0.100] - 2025-06-13
### Added
- (Original note set – modular rewrite, rainbow cycle, class colours, presets, debug logging, etc.)
### Fixed
- DB nil during startup, double event registration.

## [2.9.2] - 2025-06-12
### Added
- Dynamic BuildPresetDropdown; combat-safe ApplyColor.

## [2.9.0] - 2025-06-11
### Added
- Rename input box and buttons.

## [2.8.0]
### Added
- Rainbow cycle toggler.

## [2.7.0]
### Added
- Blizzard PlayerFrame and oUF support.

## [2.6.0]
### Added
- AceDB profile system.

## [2.5.0]
### Fixed
- Rogue classColour resets on AzeriteUI frames.

## [2.0.0]
### Added
- Modular ApplyColor with recursive frame walk.

## [1.5.0]
### Changed
- Default colour to RGB {0.7, 0.1, 0.1}.

## [1.0.0]
### Added
- Health-bar override on login.

## [0.9.0]
### Added
- Hook SetStatusBarColor on Blizzard/oUF/AUI frames.

## [0.8.0]
### Fixed
- Removed unsupported DB:SaveProfile().

## [0.7.0]
### Added
- Class-colour buttons.

## [0.6.0]
### Added
- AceConfigDialog panel.

## [0.5.0]
### Fixed
- Slash command registration.

## [0.4.0]
### Fixed
- Load-order issues with Ace3.

## [0.3.0]
### Added
- .toc, AceDB, Interface Options swatch, /ahui.

## [0.2.0]
### Added
- Hooked into AzeriteUI colours.

## [0.1.0]
### Added
- Basic /hbcp command & PlayerFrame recolour.
