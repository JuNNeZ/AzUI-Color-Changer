All notable changes to this project will be documented in this file.  
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)  
Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
----------------------------------------------------------------------
# Changelog

## [5.2.0] - 2026-10-10

- Simplified the Rules and Hunter Pets empty states into compact coloured icons with soft gradients; replaced the ghost condition icon with a clear death/skull symbol.

- Completed the original AzUI Studio art pack in a Warcraft cartoon fantasy style with sculpted bronze, faceted gold and stone: prism-and-health-bar logo (beside the title in both AzUI Studio and AzUI Azerite), bronze corner fittings, seven rule-condition icons, and rules/pets empty-state illustrations. All eleven alpha TGA assets are enabled; high-resolution PNG masters, SVG placement wrappers and the offline fitting preview are in `Tools/AssetBrief/`.

Everything planned for 5.1 and 5.2 in the AzUI Feature Plan, the AzUI window with its pet gallery, and Forever support.

### Added: 5.1, polish and sharing

- Quick palette: right-click the minimap button (or its AddOn Compartment entry) for your colour, your presets as swatches, every effect, pet colours on or off, and a way into the AzUI window. Shift-click loads your next preset; the tooltip shows your colour, effect and the pet that is out.
- Slash commands: `/ahui color #ff8800` (also `1 0.5 0` or `255 128 0`), `/ahui preset <name>`, `/ahui next`, `/ahui effect <name>|off`, `/ahui pets on|off`, `/ahui share`, `/ahui help`.
- Key bindings under AddOns: open the AzUI window, toggle rainbow, toggle pulse, next preset, toggle pet colours.
- Smooth fades: the bars blend into a new colour over a third of a second when a pet is called, a preset loads or a rule starts. Can be switched off.
- Share page: turn your colour and effect, presets, pet colours, family and specialization colours and rules into one `!AZUI1!` line of text, and import one with a preview of what it changes. Uses Blizzard's own encoder; everything imported is checked and capped.
- Blizzard's pet frame is coloured like AzeriteUI's, and can be switched off on the More Bars page.
- Tests run on GitHub on every push, with luacheck for accidental globals.

### Added: 5.2, rules and effects

- Rules page: show a colour and effect while you are in combat, mounted, resting, stealthed, dead, in a specialization or in a kind of instance. Rules come before pet colours and your own colour; the first matching rule wins for each bar. Rules can be switched off, moved and deleted.
- New effects: Breathe, Heartbeat, Two-tone (with a second colour) and Flicker, which asks before it starts. Sweep dims the bar and sends a bright band across it, left to right, as in the Feature Plan's preview.
- Reduce Motion shows every effect as its static colour; Update Rate sets 15, 30 or 60 repaints a second.
- Profiles page: make, switch, copy, reset and delete profiles, and switch profile with your specialization.
- Power bar on the More Bars page: leave it alone, match your health bar, or give it its own colour and effect. Colours AzeriteUI's power bar and Blizzard's.
- Colour by Health: your health bar runs from your colour to a low-health colour as your health drops. The game works the colour out with a colour curve, so it works with Midnight's hidden health values.

### Fixed

- `TextStatusBar.lua: attempt to compare a secret number value (execution tainted by 'AzUI_Color_Picker')`. The addon wrote `lockColor` onto Blizzard's player, pet and mana bars and called Blizzard's own bar updates when handing a bar back; both tainted Blizzard's code, which may not compare Midnight's secret health values while tainted. Nothing is written onto or run in Blizzard's frames any more; the colour is kept by the existing hook instead. The tests now fail if anything is.

### Added: AzUI Studio and AzUI Azerite

- The AzUI window's new look, from the Feature Plan's mock-ups and now its default theme: a rounded dark window with a bronze edge and soft shadow, gold for what is selected, and the Marcellus and Source Sans 3 fonts (both SIL Open Font License, in `Media/Fonts`). The shapes are the addon's own, drawn by `Tools/MakeStudioArt.py`; no AzeriteUI art is copied. The Azerite, Dark, Light and Class Color themes are still there; changing between Studio and them asks for a /reload.
- Health Bar page: a live preview of your health bar, power bar and pet's bar; a colour wheel with Hex, R G B and Alpha; your last eight colours; presets as swatches you can drag into order and right-click to rename, overwrite or delete; a card per effect that plays it; the speed; "Show on" chips for the pet frames and the power bar; Undo for the changes made since the window opened; and Done.
- Rules page: each rule is one sentence (when, show, on) with a switch, a colour swatch and a drag handle to reorder; the rule showing now wears a gold dot.
- Five example rules, switched off, for every profile that has no rules of its own: grey while dead, a red pulse in combat, violet in stealth, gold in raids and green while resting. "Add example rules" adds them again.
- With Colour by Health on, an effect you pick now shows instead of it (it cannot carry an effect); None brings colouring by health back. Before, effects picked on the Health Bar page seemed to do nothing.
- Sweep follows the shape of the bar it crosses: the band is cut by a mask made from the bar's own fill texture, so it keeps to the angled ends of AzeriteUI's health bar and the facets of its power crystal (JuNNeZ Edition's FakeFill), instead of a rectangle swiping across the bar's box. It crosses horizontal bars left to right and climbs vertical ones, like the crystal, from the bottom. A bar with no fill texture to follow, such as the mana orb, shimmers as the band passes.
- Sweep's band adds light on top of the bar instead of painting over it, so the bar's texture (the crystal's facets) shows through. It is at 60% by default and softer still on vertical bars such as the crystal. "Sweep Strength" on the Health Bar page sets it from 10% to 100%.
- JuNNeZ Edition's mana orb is coloured with the power bar.
- AzUI Azerite's live preview is sized from AzeriteUI's own cases (measured off the textures), so the health bar's stone and the pet bar's case stay inside the card, with the names under the portraits and the power bar under the health bar.
- "Colour the Pet Frames" (More Bars, or "Show on: Pet frame") leaves AzeriteUI's and Blizzard's pet frames to their own colours.
- **AzUI Azerite**, AzUI's second look (the Azerite theme): the same window and pages dressed in AzeriteUI's own art, read from the installed AzeriteUI and never copied: its sculpted borders on cards and buttons, and its health bar in its case in the live preview. Used with the permission of Blakmane and Goldpaw.

### Added: the AzUI window and pet gallery

- New AzUI window, opened with `/ahui` or the minimap button. It is the options window from AzeriteUI – JuNNeZ Edition: a rail of pages, one search across every setting and pet, and a heading on each page. It uses AzeriteUI's own art and themes (Azerite, Dark, Light, Class Color) when JuNNeZ Edition is loaded, and Blizzard's art otherwise.
- The window has a page of its own for its theme, opacity and scale. It can be moved and resized, and remembers where it was.
- Pet gallery on the Hunter Pets page: every pet as a card with its portrait, name, family and colour. The pet that is out has a badge.
- The selected pet gets a detail panel with its 3D model, slowly turning (drag it to turn it yourself), next to its colour, own colour, effect and Reset.
- Filters for All, Call slots (Current pet on Forever) and Stabled, plus a search by name, family or specialization.
- "Use for all" on a pet copies its colour to its whole family.
- Specialization colours (Retail): one colour each for Ferocity, Tenacity and Cunning. When switched on, pets set to their family colour show their specialization's colour instead.
- Class colour buttons are shown in their class colours, as a grid in the new window.
- Changed family and specialization colours have a reset arrow beside them in the new window.

### Changed

- One Effect setting replaces the Rainbow and Pulse buttons. A running rainbow or pulse carries over once, the first time you log in.
- Picking a colour now only stops Rainbow, which ignores your colour; other effects keep running on the new colour.
- Pets and rules can use every effect.
- The addon is split into files by job (Core, Effects, Pets, Rules, Paint, Share, Profiles, Options, QuickPalette) as the Feature Plan laid out. `AzUI_Color_picker.lua` is gone; when installing by hand, replace the whole folder.
- `/ahui classic` opens the previous Ace3 window, which has the same settings. The Window page can make it the default again.
- Pets are now remembered with their display, specialization and level from the stable, for the gallery. Pets remembered by an older version use their icon until their slot or the stable is read again.

### Forever and AzeriteUI

- Added a Forever / Camelot TOC for Interface 16001, alongside Retail support.
- Forever is also recognised from the game's build number, so pet slots stay right even if the client loads the Retail TOC.
- Retail TOC also lists Interface 120105, so the addon is not flagged as out of date on the next 12.1 patch.
- Checked against AzeriteUI5 – JuNNeZ Edition 5.19.3 and every theme (Azerite, Hunter, Mage, Paladin, Legacy HUD): each one keeps the native health bar, so your colour and effects apply under all of them, including after a theme switch without a reload.
- Checked against AzeriteUI6 1.0.7-Alpha, which now runs on Forever as well as Retail.
- Hunter pet colours on Forever now use its current-pet slot; stored pets appear under Stabled Pets instead of Retail's Call Pet slots.
- Incomplete stable reads no longer remove previously discovered pets from the list.
- Checked against Blizzard's Camelot stable source and a Lua client regression harness. In-game validation is still required.

## [5.0.0] - 2026-09-15

### Added (5.0.0)

- Hunter Pets page in the options panel: your call-pet slots and stabled pets are listed with their in-game icons.
- Each pet can use its family colour, its own colour or no pet colour, with no effect, a pulse or a rainbow.
- Pet Families page to change the colour of every pet family, with per-family and full resets.
- "Show Pet Colours On" setting: health bar and pet frame, health bar only, or pet frame only.

### Changed (5.0.0)

- The options panel is split into Health Bar, Hunter Pets and Pet Families pages. "Pet Colour Overrides" is now "Use Pet Colours" on the Hunter Pets page.
- Hunter pets are recognised through the stable and their Call Pet spell, so their colour also works when the game hides unit names.
- "Save to Current Pet" sets the pet's own colour instead of creating a preset. Presets named after a hunter pet become that pet's own colour once; other classes' pets still use a preset named after them.
- Picking your colour or starting an effect while a pet is out only replaces the pet colour on your health bar; the pet frame keeps it.

## [4.9.1] - 2026-09-15

### Fixed (4.9.1)

- The AzeriteUI pet frame stayed red in 4.9.0. It shows your colour, effects and pet colours again, like the player frame, and the AzeriteUI6 pet frame is coloured as well.

## [4.9.0] - 2026-09-15

### Added (4.9.0)

- Support for every retail AzeriteUI edition: AzeriteUI 5.x, AzeriteUI5 JuNNeZ Edition and the official AzeriteUI for Midnight (`AzeriteUI6`), including player frames enabled after login.
- Hunter pet family colours now work in every game language (matched by creature family ID).
- Whiptail pet family colour.

### Changed (4.9.0)

- Rainbow, pulse and pet colours are only applied on screen; your saved colour is never changed by them.
- Animations update up to 30 times per second and no longer trigger AzeriteUI frame updates.
- "Rainbow Speed (Hz)" is now "Animation Speed". Speeds are unchanged: at 1.0 a rainbow cycle takes about 21 seconds.
- Alpha is applied to the health bar texture instead of the whole bar frame.
- The Blizzard player health bar art is desaturated so colours show true.
- Picking a colour or starting an effect while a pet colour is shown takes effect immediately; the pet colour returns on the next pet change.
- `/ahui` now opens and closes the options panel.
- Colour-blind presets are added once per profile.
- The TOC lists all AzeriteUI editions as optional dependencies, and release packages no longer include the wiki.

### Removed (4.9.0)

- The addon no longer replaces the global oUF health colour or AzeriteUI's colour table.
- Pet family entries that are not real families (Kodo, Dog, Goat, Mouse, Skunk, Hawk, Shark, Fish, Shale Spider, Silithid). The current names Hound, Aqiri and Shale Beast keep their colours.

### Fixed (4.9.0)

- Pulse made the saved colour darker after every `/reload` or logout while it was running.
- A pet colour replaced the saved player colour after a `/reload` with the pet out.
- Stopping the rainbow did not bring back the chosen colour.
- Renaming a preset to its own name deleted it, and renaming onto an existing name overwrote that preset.
- Lua errors in oUF layouts caused by replacing `oUF.colors.health`.
- One-frame colour flicker when AzeriteUI or oUF recoloured the bar, and full AzeriteUI player-frame updates running 10 times per second during animations.
- Colours could be replaced on JuNNeZ Edition frames, whose oUF colours the bar texture directly.
- The options panel did not refresh after saving a preset from the popup, resetting, or a pet change.
- Deleted colour-blind presets came back on every login.
- Possible taint from writing `lockColor` on the Blizzard player health bar.
- The reset dialog claimed all profiles would be deleted.

## [4.8.0] - 2026-08-27

### Added (4.8.0)

- World of Warcraft Retail 12.1.0 support (`Interface: 120100`).
- Native `PlayerFrame_GetHealthBar()` lookup with structural fallbacks.
- Retail secret-value guards for hunter-pet name and family lookups.
- AddOn Compartment registration through LibDBIcon.

### Changed (4.8.0)

- Updated embedded Ace3 to Release-r1403 and LibDBIcon to v12.0.3.
- Corrected dependency order and now load complete AceGUI/AceConfig XML manifests.
- Replaced direct status-bar method overrides with guarded secure post-hooks.
- Reduced health-bar polling and event churn while retaining late AzeriteUI frame discovery.

### Fixed (4.8.0)

- Addon startup failures caused by loading LibStub, CallbackHandler, AceConfig dependencies, and AceGUI in the wrong order or not at all.
- An endless zero-delay timer loop caused by re-entering the Blizzard `SetStatusBarColor` hook.
- Pulse and rainbow effects running simultaneously or surviving manual colour changes.
- Pulse/rainbow state restoration after hunter-pet overrides.
- Pulse state not resuming after reload and reset not fully stopping active effects.
- Alpha being applied twice to status-bar textures.

### Validated (4.8.0)

- Confirmed working in the World of Warcraft Retail 12.1 client after the API and library update.

## [4.7.27] - 2026-02-18

### Changed (4.7.27)

- Version bump for release.
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
