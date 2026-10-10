# Configuration

This page describes every option available in the AzUI Healthbar Color Changer options panel. Open the panel with `/ahui` or by clicking the minimap icon.

The pages, listed on the left: **Health Bar** (your colour, effects and presets), **Rules**, **Hunter Pets**, **Pet Families**, **More Bars**, **Profiles** and **Share**. **Window** sets the window's theme, opacity and scale.

The window is drawn in the **Studio** theme by default. Its Health Bar page has a live preview of your bars, a colour wheel with Hex, R G B and Alpha, your recent colours, preset swatches (click to use, drag to reorder, right-click to rename, overwrite or delete), a card per effect, the speed, **Show on** chips, **Undo** and **Done**. Its Rules page writes each rule as a sentence you can drag into order. The other themes (Azerite, Dark, Light, Class Color) use AzeriteUI's or Blizzard's art; changing between them and Studio asks for a /reload.

The search box at the top finds any setting or pet by name; click a result to go to its page. `/ahui classic` opens the previous Ace3 window, which has the same settings.

---

## Color Settings

### Healthbar Colour
**Type:** RGBA color picker

The main color of your player health bar. Supports full RGB control plus an independent alpha (transparency) channel. The color is applied instantly and saved automatically — there is no Save button.

- **Alpha** controls the transparency of the bar fill (0 = invisible, 1 = fully opaque). Text, borders and other overlays are not affected.
- The chosen color is stored in `DB.profile.color` as `{R, G, B, A}`.
- Only you change this color. Rainbow, pulse and hunter pet colors are shown on screen but never saved over it, so stopping an effect or dismissing a pet always brings it back.
- Picking a color stops Rainbow, which ignores your color. Other effects keep running on the new color.

---

## Effects

See the **[Animations](Animations)** page for a detailed guide. Quick reference:

### Effect
**Type:** Dropdown
One effect at a time on your own color: **None**, **Pulse**, **Breathe**, **Heartbeat**, **Two-tone**, **Flicker**, **Sweep** or **Rainbow**. Flicker asks before it starts. Rules, pets and the power bar each pick their own effect from the same list.

### Second Colour
**Type:** Color picker
The color **Two-tone** blends towards. Shown while you, a rule, a pet or the power bar use Two-tone.

### Rainbow Pattern
**Type:** Dropdown  
Controls the visual style of the animation. It can be changed while the rainbow is running.

| Option | Description |
|--------|-------------|
| **Cycle** | Smooth continuous sine-wave cycling through R, G, B channels with 120° phase offset. |
| **Ping-Pong** | HSV hue sweep from 0 → 1 → 0 (alternates forward and back). Produces sharper color contrast than Cycle. |
| **Chaos** | Picks a completely random RGB value every 0.1 s. Maximum flicker/unpredictability. |

### Animation Speed
**Type:** Slider, range 0.1–5  
A speed multiplier for every effect. At **1.0** a rainbow cycle takes about 21 seconds and a pulse about 10 seconds; 2.0 is twice as fast. Chaos always changes every 0.1 s.

### Smooth Fades
**Type:** Toggle, on by default
Blends into a new color over a third of a second when a pet is called, a preset loads or a rule starts.

### Reduce Motion
**Type:** Toggle
Shows every effect as its static color, everywhere, without changing which effect is picked.

### Update Rate
**Type:** Dropdown, 15 / 30 / 60 per second
How often a moving effect repaints the bars.

### Colour by Health
**Type:** Toggle, with a **Low Health Colour**
Your health bar runs from your color when you are full to the low-health color when you are nearly dead. Midnight hides health values from addons, so the game works the color out with a color curve; effects do not apply to it. Rules and pet colors still come first. Hidden on clients without color curves.

---

## Rules

A rule shows its color and effect while its condition is true. Rules come before pet colors and your own color, and the first matching rule wins **for each bar**, so a health-bar rule and a pet-frame rule can show together.

- **Add Rule** adds one at the bottom of the list.
- **On**, **When** (In combat, Mounted, Resting, Stealthed, Dead or a ghost, Specialization, In an instance), the **Specialization** or **Instance** it needs, **Colour**, **Effect** and **Show On** (Health bar, Pet frame, or both).
- **Move Up** / **Move Down** change which rule wins; **Delete** asks first.
- A rule's heading says *showing now* while it is on screen.

---

## More Bars

### Colour Blizzard's Pet Frame
**Type:** Toggle, on by default
Blizzard's pet frame gets the same color as AzeriteUI's pet frame. Switching it off hands the bar back to Blizzard.

### Power Bar
**Type:** Dropdown
**Leave it alone**, **Match my health bar** (your color, rules and pet colors), or **Its own colour** with its own **Power Bar Colour** and **Power Bar Effect**. Colors AzeriteUI's power bar and the one on Blizzard's player frame.

---

## Profiles

Every character starts on the **Default** profile. A profile holds your colors, effects, presets, rules and pet colors; your pet list stays with each character.

- **Current Profile**, **New Profile** (type a name and press Enter), **Copy From**, **Delete a Profile** and **Reset Profile**.
- **Switch Profile with Specialization**, then pick a profile for each of your specializations, or *Keep the current profile*.

---

## Share

Tick the parts to include (your color and effect, presets, pet colors, family and specialization colors, rules) and click **Make Share String**. Select the string and press Ctrl+C to copy it.

To import, paste a string: the page lists what it would change, for example *3 presets (1 replaces yours: Tank Red)*. **Import** asks first, then adds the presets, pet and family colors, and replaces your rules. Share strings start with `!AZUI1!`.

---

## Quick Palette, Slash Commands and Key Bindings

- **Minimap button:** left-click opens the AzUI window, right-click the quick palette, Shift-click loads your next preset.
- **Quick palette:** your color, up to eight presets as swatches, every effect, pet colors on or off, and *Open the AzUI window…*.
- **Slash commands:** `/ahui`, `/ahui classic`, `/ahui color #ff8800`, `/ahui preset <name>`, `/ahui next`, `/ahui effect <name>|off`, `/ahui pets on|off`, `/ahui share`, `/ahui help`.
- **Key bindings** (Key Bindings → AddOns): open the AzUI window, toggle rainbow, toggle pulse, next preset, toggle pet colors.

---

## Class Colors

### Class color buttons (one per class)
Instantly applies the official class color (`RAID_CLASS_COLORS`) for that class. Stops any active rainbow or pulse. The current alpha value is preserved.

Buttons show both male and female localized class names where they differ in the current game locale.

### Class Colour button
Applies your own character's class color with a single click. Same behavior as the individual class buttons — stops animations, preserves alpha.

---

## Quick Colors

### Random Colour button
Generates a random RGB color (alpha is preserved) and applies it immediately. Stops any active rainbow or pulse.

---

## Pet Coloring

See the **[Hunter Pet Coloring](Hunter-Pet-Coloring)** page for a full guide.

### Use Pet Colours toggle (Hunter Pets page)
**Type:** Toggle (checkbox)  
When **enabled**, a pet that is out shows its color: its own color or effect from the Hunter Pets page, or its family color. When the pet is dismissed, your own color and effect come back. If you pick a color or start an effect while a pet color is on your health bar, your choice is shown there until the next pet change.

When **disabled**, your chosen color is always displayed, regardless of which pet is active.

### Show Pet Colours On (Hunter Pets page)
**Type:** Dropdown  
**Health bar and pet frame**, **Health bar only** or **Pet frame only**. The bar that does not get the pet color keeps your own color and effect. The pet frame is AzeriteUI's.

### Pet gallery (Hunter Pets page)
One card per pet with its portrait, name, family and color: call-pet slots first, then stabled pets. The pet that is out has an **OUT** badge. **All**, **Call slots** (**Current pet** on Forever) and **Stabled** filter the cards, and the search box finds a pet by name, family or specialization.

Click a card to open its detail panel: the pet's 3D model (drag to turn it), **Colour** (Family colour / Own colour / No pet colour), an **Own Colour** picker, **Effect** (None / Pulse / Rainbow), **Reset**, and **Use for all** to make the pet's color its family's color. A pet the stable has not reported a model for shows its icon instead; visit a stable master to fill these in.

### Specializations (Pet Families page, Retail)
**Use Specialization Colours** gives pets set to their family color the color of their specialization instead: one each for Ferocity, Tenacity and Cunning. Pets with their own color keep it.

### Family colors (Pet Families page)
One color picker per hunter pet family. Changed colors get a reset arrow (a **Reset** button in the classic window), and **Reset All Families** restores every built-in color.

### Save to Current Pet button (Health Bar page)
Gives the active pet the color from the color picker as its own color. Disabled when no pet is active. For a pet that is not in your stable, such as a warlock demon, it saves a preset named after the pet instead.

---

## Presets

See the **[Presets](Presets)** page for a full guide.

### Select Preset (dropdown)
Lists all saved presets. Selecting one loads it immediately (stops animations, applies color).

### Save as Preset button
Opens a popup dialog asking for a name. Saves the current RGBA color under that name. Saving under an existing name replaces that preset.

### Rename Preset
**Type:** Text input + button  
Type a new name in the input box, then click **Rename Preset** to rename the currently selected preset. Names that are already in use are refused.

### Delete Preset button
Permanently removes the currently selected preset. Disabled when no preset is selected.

---

## Interface

### Show Minimap Icon toggle
**Type:** Toggle  
Shows or hides the AzUI icon on your minimap. When hidden, use `/ahui` or the AddOn Compartment to open the options panel instead. Compatible with Titan Panel.

---

## Maintenance

### Reset to Defaults button
Resets all settings in the current profile back to factory defaults and restores the four colorblind presets. A confirmation popup is shown first.

> ⚠️ This also deletes all saved presets, pet colors and changed family colors in the profile. This action cannot be undone.

### Reload button
Runs `/reload`. All settings are saved automatically, and a running rainbow or pulse continues after the reload.

---

## Debug Mode

### Enable Debug toggle
When enabled, the addon prints diagnostic messages to your chat window prefixed with `[AzUI Color Picker]`, such as which AzeriteUI frames it found. Useful for troubleshooting frame detection issues.

---

## SavedVariables

All settings are stored in:

```
WTF\Account\<account>\SavedVariables\AzUI_Color_PickerDB.lua
```

The file uses AceDB-3.0. Characters share the **Default** profile unless you pick another on the Profiles page. All changes are committed automatically on logout/reload — there is no manual save step.

### Profile Keys Reference

| Key | Type | Description |
|-----|------|-------------|
| `color` | table `{R, G, B, A}` | Your chosen health bar color |
| `effect` | string | `"static"`, `"pulse"`, `"breathe"`, `"heartbeat"`, `"twotone"`, `"flicker"`, `"sweep"` or `"rainbow"` |
| `secondColor` | table `{R, G, B, A}` | Two-tone's second color |
| `rainbowMode` | string | `"cycle"` / `"ping"` / `"chaos"` |
| `rainbowSpeed` | number | Speed multiplier for every effect (0.1–5) |
| `fade` / `reduceMotion` / `updateRate` | boolean / boolean / number | Smooth fades, Reduce Motion, repaints per second |
| `healthColour` / `lowHealthColour` | boolean / table | Colour by Health and its low-health color |
| `rules` | table | `{enabled, condition, value, color, effect, target}`, in order |
| `blizzardPetFrame` | boolean | Color Blizzard's pet frame |
| `power` | table | `{mode = "off"/"health"/"custom", color, effect}` |
| `useSpecColours` / `specColours` | boolean / table | Specialization colors by spec ID |
| `schema` | number | Which saved-data upgrades have run |
| `petColouring` | boolean | Pet colors enabled |
| `petTarget` | string | `"both"` / `"player"` / `"pet"`: where pet colors are shown |
| `pets` | table | Per-pet settings by pet number `{mode = "family"/"custom"/"off", color = {R,G,B,A}, effect}` |
| `familyColours` | table | Changed family colors by family ID `{R,G,B,A}` |
| `presets` | table | Named color presets `{name = {R,G,B,A}}` |
| `defaultPresetsSeeded` | boolean | Whether the colorblind presets were added |
| `debug` | boolean | Debug mode enabled |

The minimap icon settings (`minimap.hide`, `minimap.showInCompartment`) and the family names the addon has learned (`familyIDs`) are stored in the account-wide `global` section. The list of your pets (`knownPets`: name, icon, display, family, specialization and slot) and the per-specialization profiles (`specProfiles`) are stored per character in the `char` section. The AzUI window's own settings are in `global.panel`.
