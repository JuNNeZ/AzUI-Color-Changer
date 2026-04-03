# Frequently Asked Questions

---

## General

### What does this addon actually do?
It lets you choose any color for your player health bar, optionally animate it with a rainbow or pulse effect, save colors as presets, and automatically apply different colors based on your hunter pet. It works with AzeriteUI, oUF layouts, and the default Blizzard frames.

### Is it compatible with the current version of WoW?
Yes. The addon targets Interface `120000` (The War Within and Dragonflight+). Classic versions of WoW are **not** supported.

### Does it affect performance?
The addon is intentionally lightweight. The animation ticker fires every 0.1 s only when an animation is actually running. A passive monitor frame re-applies the color every 1.5 s to catch any frame that Blizzard may have reset. The overhead is negligible even on low-end hardware.

### Do I need AzeriteUI?
No. AzeriteUI is an *optional* dependency. If it is installed, the addon will also color its custom unit frames. If it is not installed, the addon colors the default Blizzard frame (and any oUF layout you have active).

### Does it work with other unit frame addons?
The addon natively supports **AzeriteUI** and **oUF**-based layouts. For other frame addons (e.g., ElvUI, ShadowUF), the addon may not be able to color their frames — those addons typically manage colors internally and do not expose the standard oUF API.

---

## Installation & Setup

### Where do I find my AddOns folder?
The default path is:
```
C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\
```
On macOS:
```
/Applications/World of Warcraft/_retail_/Interface/AddOns/
```

### The addon isn't showing up in my AddOns list.
- Make sure the folder is named exactly `AzUI_Color_Picker` (underscores, no spaces).
- The `.toc` file must be directly inside that folder, not in a subfolder.
- Ensure you are on the **Retail** version of WoW, not Classic.
- Click **Load out of date AddOns** at the character select screen if the version check is flagging it.

### The minimap icon isn't visible.
The icon may be hidden. Open the options panel with `/ahui`, scroll to the **Interface** section, and make sure **Show Minimap Icon** is enabled.

If you use a minimap addon like SexyMap, it may be repositioning or hiding the icon. Try right-clicking your minimap addon to reveal hidden icons.

---

## Color & Animation

### My health bar reverts to its original color when I take damage or zone in.
The addon has defensive hooks and a monitor frame that reapply the color on health events and every 1.5 s. If it still reverts, enable **Debug Mode** (`/ahui` → Debug section) and watch the chat for any error messages. Report the issue on the [GitHub issue tracker](https://github.com/JuNNeZ/AzUI-Color-Changer/issues).

### The color doesn't apply to my AzeriteUI health bar.
Make sure AzeriteUI is listed as an enabled addon and that it loaded correctly. The addon detects AzeriteUI automatically; if AUI loaded after AzUI Color Changer, try a `/reload`. Also check that you are not in combat when you first zone in — the addon defers AUI color updates during combat.

### Can I run rainbow and pulse at the same time?
No. They are independent toggles but share the speed slider and would visually conflict. Start one at a time.

### The rainbow stopped when I applied a class color / loaded a preset.
This is intentional. Applying any static color (class button, preset, random) stops the animation and applies the new color. You can restart the rainbow manually afterward.

### My color resets after every /reload.
Your color *is* being saved — it just may not be the color you expect. Check that you are not inadvertently running `/ahui` → **Reset to Defaults** after each reload, or that another addon is not resetting `AzUI_Color_PickerDB.lua`.

---

## Presets

### I accidentally deleted a preset. Can I recover it?
No, deletion is immediate and permanent through the UI. However, if WoW has not been restarted since the deletion, your SavedVariables file (`AzUI_Color_PickerDB.lua`) may not have been written to disk yet — check your most recent backup if you have one.

### How many presets can I save?
There is no enforced limit. Presets are stored as a Lua table; you can save as many as needed. Very large numbers of presets may make the dropdown list long, but this does not affect performance.

### My presets are gone after switching characters.
Presets are stored per-character (AceDB profile). Presets saved on character A are not visible on character B by default. You can manually copy the `presets` table between character profiles in your `AzUI_Color_PickerDB.lua` file while WoW is closed.

---

## Hunter Pet Coloring

### Pet Colour Overrides is enabled but nothing changes when I summon my pet.
- Make sure you have either a named preset (saved with **Save to Current Pet**) or that your pet's family appears in the built-in family color table.
- Check the pet's family: open the Collections journal → Pets, or use the in-game tooltip. The family must match one of the families listed on the [Hunter Pet Coloring](Hunter-Pet-Coloring) page.
- Enable **Debug Mode** to see what the addon detects as the pet name and family.

### My pet's family isn't in the list.
The list covers all The War Within families. If you are running a beta or PTR build with a new family, the fallback won't fire. Please open an [issue](https://github.com/JuNNeZ/AzUI-Color-Changer/issues) with the family name and we'll add it.

### I'm not a hunter. Can I disable the pet section?
Simply leave **Pet Colour Overrides** disabled (the default). The `UNIT_PET` event handler only acts when the toggle is on, so there is no overhead for non-hunters.

---

## Errors & Troubleshooting

### I see a Lua error mentioning `AzUI_Color_Picker`.
1. Note the exact error message (screenshot or copy the text).
2. Check the [known issues](https://github.com/JuNNeZ/AzUI-Color-Changer/issues) list.
3. If it's not listed, open a new issue and include:
   - The full error text.
   - Your WoW version and Interface number.
   - Which other unit frame addons are active.
   - Steps to reproduce.

### The options panel is blank / empty.
Try a `/reload`. If it persists, delete `AzUI_Color_PickerDB.lua` from your SavedVariables folder to reset the database, then reload. If the panel is still blank, it is likely a conflict with another options-panel addon (e.g., a corrupted AceConfigDialog).

### How do I completely reset the addon?
Option A — use the in-game button: `/ahui` → **Reset to Defaults** (shows a confirmation popup).

Option B — delete the SavedVariables file while WoW is closed:
```
WTF\Account\<account>\<realm>\<character>\SavedVariables\AzUI_Color_PickerDB.lua
```

---

## Contributing & Reporting Bugs

- **Bug reports / feature requests:** [GitHub Issues](https://github.com/JuNNeZ/AzUI-Color-Changer/issues)
- **CurseForge page:** [Project 1286164](https://www.curseforge.com/wow/addons/azui-color-changer)
- **Author:** JuNNeZ
