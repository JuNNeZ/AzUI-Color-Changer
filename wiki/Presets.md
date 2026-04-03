# Presets

The preset system lets you save any color — with its full RGBA values — under a custom name and recall it instantly from a dropdown. Presets persist across sessions and are stored per character.

---

## Built-in Presets

On the very first run (new character, or after a **Reset to Defaults**) the addon seeds four colorblind-friendly presets:

| Name | Color | RGBA |
|------|-------|------|
| `CB-Blue` | Deep blue | `{0.20, 0.40, 0.90, 1}` |
| `CB-Orange` | Warm orange | `{0.90, 0.50, 0.10, 1}` |
| `CB-Yellow` | Bright yellow | `{0.90, 0.90, 0.20, 1}` |
| `CB-Purple` | Medium purple | `{0.60, 0.30, 0.80, 1}` |

These four are designed to be easily distinguishable for players with common forms of color blindness.

---

## Creating a Preset

1. Set your desired color using the **Healthbar Colour** picker (or any class/random button).
2. Click **Save as Preset**.
3. A popup dialog appears — type a name and click **Accept**.
4. The preset is immediately available in the **Select Preset** dropdown.

> **Tip:** Names are case-sensitive. `"My Red"` and `"my red"` are treated as different presets.

---

## Loading a Preset

Open the **Select Preset** dropdown and click the preset you want. The color is applied immediately and any active rainbow or pulse animation is stopped.

---

## Renaming a Preset

1. Load the preset you want to rename via the **Select Preset** dropdown.
2. Type the new name in the **Rename** input box.
3. Click **Rename**.

The preset data (color values) is moved to the new name; the old name is removed. The dropdown updates to reflect the change.

> The **Rename** button is disabled when no preset is selected, or when the input box is empty.

---

## Deleting a Preset

1. Select the preset you want to delete from the **Select Preset** dropdown.
2. Click **Delete Preset**.

The preset is removed immediately and the dropdown is refreshed. Deleted presets cannot be recovered (unless you manually edit your SavedVariables file).

> The **Delete Preset** button is disabled when no preset is selected.

---

## Pet Presets

When you click **Save to Current Pet**, the current color is saved as a preset under your pet's exact name (e.g., `"Fluffy"`). This preset functions identically to a manual preset — it appears in the dropdown, can be renamed or deleted, and can be loaded manually at any time.

When **Pet Colour Overrides** is enabled, the addon automatically loads the matching pet preset whenever that pet is summoned. See the [Hunter Pet Coloring](Hunter-Pet-Coloring) page for details.

---

## Tips

- Create presets for each of your frequently-played characters or specs (e.g., `"Tank Red"`, `"Healer Blue"`).
- Use the four built-in colorblind presets as a starting point if you are unsure which colors work well.
- The **Reset to Defaults** button deletes all presets. Make sure you have backed up any important names before resetting.
- Presets are stored per character (AceDB profile). They are not shared between characters by default.

---

## Storage Format

Presets are stored in your SavedVariables file (`AzUI_Color_PickerDB.lua`) under `DB.profile.presets` as a table of RGBA tables:

```lua
presets = {
    ["My Red"]   = { 0.9, 0.1, 0.1, 1.0 },
    ["CB-Blue"]  = { 0.2, 0.4, 0.9, 1.0 },
    ["Fluffy"]   = { 0.0, 1.0, 1.0, 1.0 },
}
```

You can manually edit this file (while WoW is closed) to add, remove, or modify presets if needed.
