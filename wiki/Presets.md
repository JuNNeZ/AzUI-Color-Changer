# Presets

The preset system lets you save any color — with its full RGBA values — under a custom name and recall it instantly from a dropdown. Presets persist across sessions and are shared by all your characters (the addon uses one **Default** profile).

---

## Built-in Presets

When the profile is first created (or after a **Reset to Defaults**) the addon adds four colorblind-friendly presets:

| Name | Color | RGBA |
|------|-------|------|
| `CB-Blue` | Deep blue | `{0.20, 0.40, 0.90, 1}` |
| `CB-Orange` | Warm orange | `{0.90, 0.50, 0.10, 1}` |
| `CB-Yellow` | Bright yellow | `{0.90, 0.90, 0.20, 1}` |
| `CB-Purple` | Medium purple | `{0.60, 0.30, 0.80, 1}` |

These four are designed to be easily distinguishable for players with common forms of color blindness. They are only added once: if you delete one, it stays deleted.

---

## Creating a Preset

1. Set your desired color using the **Healthbar Colour** picker (or any class/random button).
2. Click **Save as Preset**.
3. A popup dialog appears — type a name and click **Save** (or press Enter).
4. The preset is immediately available in the **Select Preset** dropdown.

> **Tip:** Names are case-sensitive. `"My Red"` and `"my red"` are treated as different presets. Saving under a name that already exists replaces that preset.

---

## Loading a Preset

Open the **Select Preset** dropdown and click the preset you want. The color is applied immediately and any active rainbow or pulse animation is stopped.

---

## Renaming a Preset

1. Load the preset you want to rename via the **Select Preset** dropdown.
2. Type the new name in the **Rename To:** input box.
3. Click **Rename Preset**.

The preset data (color values) is moved to the new name; the old name is removed. The dropdown updates to reflect the change.

> The **Rename Preset** button is disabled when no preset is selected, when the input box is empty, or when the new name is the same as the current one. If another preset already uses the new name, the rename is refused and a chat message tells you why — no preset is overwritten.

---

## Deleting a Preset

1. Select the preset you want to delete from the **Select Preset** dropdown.
2. Click **Delete Preset**.

The preset is removed immediately and the dropdown is refreshed. Deleted presets cannot be recovered (unless you manually edit your SavedVariables file).

> The **Delete Preset** button is disabled when no preset is selected.

---

## Presets and Pets

Hunter pet colors live on the **Hunter Pets** page instead of in presets. **Save to Current Pet** gives your active hunter pet the color from the color picker as its own color; it does not create a preset.

- **Presets from older versions** named after a hunter pet (e.g., `"Fluffy"`) become that pet's own color the first time the addon sees the pet in your stable. The preset stays in the dropdown, and deleting it does not remove the pet's color.
- **Other classes' pets**, such as a warlock demon, still use a preset with the pet's exact name. For those pets, **Save to Current Pet** saves that preset.

See the [Hunter Pet Coloring](Hunter-Pet-Coloring) page for details.

---

## Tips

- Create presets for your frequently-played specs or characters (e.g., `"Tank Red"`, `"Healer Blue"`).
- Use the four built-in colorblind presets as a starting point if you are unsure which colors work well.
- The **Reset to Defaults** button deletes all presets. Make sure you have noted any important colors before resetting.

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
