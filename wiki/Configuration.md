# Configuration

This page describes every option available in the AzUI Healthbar Color Changer options panel. Open the panel with `/ahui` or by clicking the minimap icon.

The panel has three pages, listed on the left: **Health Bar** (everything below except pet coloring), **Hunter Pets** and **Pet Families**.

---

## Color Settings

### Healthbar Colour
**Type:** RGBA color picker

The main color of your player health bar. Supports full RGB control plus an independent alpha (transparency) channel. The color is applied instantly and saved automatically — there is no Save button.

- **Alpha** controls the transparency of the bar fill (0 = invisible, 1 = fully opaque). Text, borders and other overlays are not affected.
- The chosen color is stored in `DB.profile.color` as `{R, G, B, A}`.
- Only you change this color. Rainbow, pulse and hunter pet colors are shown on screen but never saved over it, so stopping an effect or dismissing a pet always brings it back.
- Picking a color stops any running rainbow or pulse.

---

## Rainbow Animation

See the **[Animations](Animations)** page for a detailed guide. Quick reference:

### Rainbow Effect button
Toggles the rainbow animation on/off.  
- Label shows **Rainbow Effect** when inactive, **Stop Rainbow Effect** when active.
- Starting the rainbow stops the pulse.

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
A speed multiplier for both the rainbow and the pulse. At **1.0** a rainbow cycle takes about 21 seconds and a pulse about 10 seconds; 2.0 is twice as fast. Chaos always changes every 0.1 s.

---

## Pulse Effect

See the **[Animations](Animations)** page for a detailed guide. Quick reference:

### Pulse Colour button
Toggles the pulse animation on/off.  
- Label shows **Pulse Colour** when inactive, **Stop Pulse** when active.
- Your color's brightness oscillates between 30% and 100% using a sine wave.
- Uses the same speed slider as the rainbow effect.
- Rainbow and pulse never run together — starting one stops the other.

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

### Pet entries (Hunter Pets page)
One entry per pet with its in-game icon: call-pet slots first, stabled pets under **Stabled Pets**. Each has **Colour** (Family colour / Own colour / No pet colour), an **Own Colour** picker, **Effect** (None / Pulse / Rainbow) and **Reset**.

### Family colors (Pet Families page)
One color picker per hunter pet family. Changed colors get a **Reset** button, and **Reset All Families** restores every built-in color.

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

The file uses AceDB-3.0 with a single **Default** profile that all your characters share. All changes are committed automatically on logout/reload — there is no manual save step.

### Profile Keys Reference

| Key | Type | Description |
|-----|------|-------------|
| `color` | table `{R, G, B, A}` | Your chosen health bar color |
| `rainbowActive` | boolean | Whether rainbow is running |
| `rainbowMode` | string | `"cycle"` / `"ping"` / `"chaos"` |
| `rainbowSpeed` | number | Animation speed multiplier (0.1–5) |
| `pulseActive` | boolean | Whether pulse is running |
| `petColouring` | boolean | Pet colors enabled |
| `petTarget` | string | `"both"` / `"player"` / `"pet"`: where pet colors are shown |
| `pets` | table | Per-pet settings by pet number `{mode = "family"/"custom"/"off", color = {R,G,B,A}, effect = "static"/"pulse"/"rainbow"}` |
| `familyColours` | table | Changed family colors by family ID `{R,G,B,A}` |
| `presets` | table | Named color presets `{name = {R,G,B,A}}` |
| `defaultPresetsSeeded` | boolean | Whether the colorblind presets were added |
| `debug` | boolean | Debug mode enabled |

The minimap icon settings (`minimap.hide`, `minimap.showInCompartment`) and the family names the addon has learned (`familyIDs`) are stored in the account-wide `global` section. The list of your pets (`knownPets`: name, icon, family and slot) is stored per character in the `char` section.
