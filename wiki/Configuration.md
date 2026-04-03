# Configuration

This page describes every option available in the AzUI Healthbar Color Changer options panel. Open the panel with `/ahui` or by clicking the minimap icon.

---

## Color Settings

### Healthbar Colour
**Type:** RGBA color picker

The main color of your player health bar. Supports full RGB control plus an independent alpha (transparency) channel. The color is applied instantly and saved automatically — there is no Save button.

- **Alpha** controls bar transparency (0 = invisible, 1 = fully opaque).
- The chosen color is stored in `DB.profile.color` as `{R, G, B, A}`.
- Any active rainbow or pulse animation overrides the display color while running, but the base color is preserved for when you stop the animation.

---

## Rainbow Animation

See the **[Animations](Animations)** page for a detailed guide. Quick reference:

### Rainbow Effect button
Toggles the rainbow animation on/off.  
- Label shows **Rainbow Effect** when inactive, **Stop Rainbow Effect** when active.

### Rainbow Pattern
**Type:** Dropdown  
Controls the visual style of the animation.

| Option | Description |
|--------|-------------|
| **Cycle** | Smooth continuous sine-wave cycling through R, G, B channels with 120° phase offset. |
| **Ping-Pong** | HSV hue sweep from 0 → 1 → 0 (alternates forward and back). Produces sharper color contrast than Cycle. |
| **Chaos** | Picks a completely random RGB value every 0.1 s. Maximum flicker/unpredictability. |

### Rainbow Speed (Hz)
**Type:** Slider, range 0.1–5 Hz  
Controls how fast the rainbow (and pulse) animation plays. Also affects the Pulse effect.

---

## Pulse Effect

See the **[Animations](Animations)** page for a detailed guide. Quick reference:

### Pulse Colour button
Toggles the pulse animation on/off.  
- Label shows **Pulse Colour** when inactive, **Stop Pulse** when active.
- The current color's brightness oscillates between 30% and 100% using a sine wave.
- Uses the same speed slider as the rainbow effect.
- Completely independent of rainbow — you cannot run both at once.

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

### Pet Colour Overrides toggle
**Type:** Toggle (checkbox)  
When **enabled**, the addon watches for pet summon/dismiss events (`UNIT_PET`) and automatically applies:
1. A color saved under the pet's exact name (if one exists).
2. A fallback color based on the pet's family type.

When the pet is dismissed, the player's previous color (including active rainbow/pulse state) is fully restored.

When **disabled**, the player's chosen color is always displayed, regardless of which pet is active.

### Save to Current Pet button
Saves the current RGBA color as a named preset under the active pet's name. Disabled when no pet is active. After saving, "Pet Colour Overrides" will use this color whenever that specific pet is summoned.

---

## Presets

See the **[Presets](Presets)** page for a full guide.

### Select Preset (dropdown)
Lists all saved presets. Selecting one loads it immediately (stops rainbow, applies color).

### Save as Preset button
Opens a popup dialog asking for a name. Saves the current RGBA color under that name.

### Rename Preset
**Type:** Text input + button  
Type a new name in the input box, then click **Rename** to rename the currently selected preset.

### Delete Preset button
Permanently removes the currently selected preset. Disabled when no preset is selected.

---

## Interface

### Show Minimap Icon toggle
**Type:** Toggle  
Shows or hides the AzUI icon on your minimap. When hidden, use `/ahui` to open the options panel instead. Compatible with Titan Panel.

---

## Maintenance

### Reset to Defaults button
Resets all settings and clears all presets back to factory defaults. A confirmation popup is shown before any data is deleted.

> ⚠️ This also deletes all saved presets, including pet presets. This action cannot be undone.

### Reload button
Runs `/reload ui`. Stops any active rainbow or pulse before reloading. All settings are saved automatically, so no data is lost.

---

## Debug Mode

### Enable Debug toggle
When enabled, the addon prints diagnostic messages to your chat window prefixed with `[AzUI_Color_Picker]`. Useful for troubleshooting frame detection issues or unexpected color resets.

---

## SavedVariables

All settings are stored in:

```
WTF\Account\<account>\<realm>\<character>\SavedVariables\AzUI_Color_PickerDB.lua
```

The file uses AceDB-3.0's profile system. All changes are committed automatically on logout/reload — there is no manual save step.

### Profile Keys Reference

| Key | Type | Description |
|-----|------|-------------|
| `color` | table `{R, G, B, A}` | Current health bar color |
| `rainbowActive` | boolean | Whether rainbow is running |
| `rainbowMode` | string | "Cycle" / "Ping-Pong" / "Chaos" |
| `rainbowSpeed` | number | Animation speed in Hz (0.1–5) |
| `pulseActive` | boolean | Whether pulse is running |
| `petColouring` | boolean | Pet color override enabled |
| `presets` | table | Named color presets `{name = {R,G,B,A}}` |
| `debug` | boolean | Debug mode enabled |
| `minimap.hide` | boolean | Minimap icon hidden |
