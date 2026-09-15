# Frequently Asked Questions

---

## General

### What does this addon actually do?
It lets you choose any color for your player health bar, optionally animate it with a rainbow or pulse effect, save colors as presets, and automatically show different colors based on your hunter pet. It works with every retail edition of AzeriteUI and with the default Blizzard player frame.

### Is it compatible with the current version of WoW?
Yes. The addon targets Interface `120100` (Midnight, patch 12.1). Classic versions of WoW are **not** supported.

### Does it affect performance?
The addon is intentionally lightweight. Animation work only happens while a rainbow or pulse is running (up to 30 updates per second). Otherwise the addon only reacts when something recolors your health bar, plus a tiny check every 2 seconds for AzeriteUI frames created after login.

### Do I need AzeriteUI?
No. AzeriteUI is an *optional* dependency. Without it, the addon colors the default Blizzard player frame.

### Which versions of AzeriteUI are supported?
All retail editions:
- **AzeriteUI for Midnight** (`AzeriteUI6`) — player and pet frames
- **AzeriteUI5 – JuNNeZ Edition** — player, alternate player and pet frames
- **AzeriteUI 5.x** — player, alternate player and pet frames

### Does it work with other unit frame addons?
No. ElvUI, oUF layouts, ShadowedUnitFrames and similar addons manage their own colors and are not colored by this addon.

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

### The minimap icon isn't visible.
The icon may be hidden. Open the options panel with `/ahui` (or from the AddOn Compartment next to the minimap) and make sure **Show Minimap Icon** is enabled.

If you use a minimap addon like SexyMap, it may be repositioning or hiding the icon. Try right-clicking your minimap addon to reveal hidden icons.

---

## Color & Animation

### My health bar reverts to its original color when I take damage or zone in.
The addon hooks the health bar and puts your color back in the same frame whenever something else recolors it. If it still reverts, enable **Enable Debug** in the options panel, `/reload`, and check the chat for which frames the addon found. Report the issue on the [GitHub issue tracker](https://github.com/JuNNeZ/AzUI-Color-Changer/issues).

### The color doesn't apply to my AzeriteUI health bar.
Make sure you are running one of the supported AzeriteUI editions and that it loaded correctly. Frames are picked up automatically within about 2 seconds, including frames AzeriteUI enables later. With debug enabled, the chat shows `Colouring AzeriteUI frame …` when a frame is found.

### Can I run rainbow and pulse at the same time?
No. Starting one automatically stops the other.

### The rainbow stopped when I applied a class color / loaded a preset.
This is intentional. Applying any static color (color picker, class button, preset, random) stops the animation and applies the new color. You can restart the rainbow manually afterward.

### My color changed after a /reload.
Your chosen color is only changed when you pick a color yourself — rainbow, pulse and pet colors are never saved over it. If a hunter pet is out with **Pet Colour Overrides** enabled, you are seeing the pet's color. Also remember that all characters share one profile, so a color picked on another character applies here too.

---

## Presets

### I accidentally deleted a preset. Can I recover it?
No, deletion is immediate and permanent through the UI. However, if WoW has not been restarted since the deletion, your SavedVariables file (`AzUI_Color_PickerDB.lua`) may not have been written to disk yet — check your most recent backup if you have one.

### How many presets can I save?
There is no enforced limit. Presets are stored as a Lua table; you can save as many as needed. Very large numbers of presets may make the dropdown list long, but this does not affect performance.

### Are presets shared between characters?
Yes. The addon uses a single **Default** profile, so presets, colors and settings are the same on all your characters.

---

## Hunter Pet Coloring

### Pet Colour Overrides is enabled but nothing changes when I summon my pet.
- Make sure you have either a named preset (saved with **Save to Current Pet**) or that your pet's family appears in the built-in family color table on the [Hunter Pet Coloring](Hunter-Pet-Coloring) page.
- Family colors work in every game language, so the displayed family name does not need to be English.

### My pet's family isn't in the list.
The list covers the hunter pet families available in patch 12.1. If a new family is added, the fallback won't fire for it until the addon is updated. Please open an [issue](https://github.com/JuNNeZ/AzUI-Color-Changer/issues) with the family name and we'll add it.

### I'm not a hunter. Can I disable the pet section?
Simply leave **Pet Colour Overrides** disabled (the default). Without a pet the feature has no effect.

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
WTF\Account\<account>\SavedVariables\AzUI_Color_PickerDB.lua
```

---

## Contributing & Reporting Bugs

- **Bug reports / feature requests:** [GitHub Issues](https://github.com/JuNNeZ/AzUI-Color-Changer/issues)
- **CurseForge page:** [Project 1286164](https://www.curseforge.com/wow/addons/azui-color-changer)
- **Author:** JuNNeZ
