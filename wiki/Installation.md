# Installation

## Requirements

| Requirement | Details |
|-------------|---------|
| **Game version** | World of Warcraft: The War Within / Dragonflight (Interface 120000+) |
| **External addons** | None — all libraries are bundled |
| **Optional** | [AzeriteUI](https://www.curseforge.com/wow/addons/azeriteui) — if installed, the addon will also color its custom unit frames |

---

## Method 1 — CurseForge App (recommended)

1. Open the **CurseForge** desktop app and search for **AzUI Healthbar Color Changer** (Project ID `1286164`).
2. Click **Install**.
3. Launch WoW — the addon is ready.

---

## Method 2 — Manual Installation

1. Download the latest release ZIP from the [Releases](https://github.com/JuNNeZ/AzUI-Color-Changer/releases) page.
2. Unzip the archive. You should end up with a single folder called `AzUI_Color_Picker`.
3. Move that folder into your WoW AddOns directory:

```
World of Warcraft\_retail_\Interface\AddOns\AzUI_Color_Picker\
```

The final structure inside the folder should look like this:

```
AzUI_Color_Picker\
├── AzUI_Color_Picker.toc
├── AzUI_Color_Picker.lua
├── icon.tga
└── Libs\
    ├── LibStub\
    │   └── LibStub.lua
    ├── LibDBIcon-1.0\
    │   ├── LibDBIcon-1.0.lua
    │   ├── LibDataBroker-1.1\
    │   │   └── LibDataBroker-1.1.lua
    │   └── CallbackHandler-1.0\
    │       └── CallbackHandler-1.0.lua
    ├── AceAddon-3.0\
    │   └── AceAddon-3.0.lua
    ├── AceDB-3.0\
    │   └── AceDB-3.0.lua
    ├── AceHook-3.0\
    │   └── AceHook-3.0.lua
    └── AceConfig-3.0\
        ├── AceConfig-3.0.lua
        ├── AceConfigDialog-3.0\
        └── ...
```

4. Start (or `/reload`) WoW and enable the addon in the **AddOns** list at the character select screen.
5. Type `/ahui` in-game to open the options panel.

---

## Verifying the Installation

After logging in:

- A small **AzUI icon** should appear on your minimap (unless you have hidden it in another session).
- Type `/ahui` — the options panel should open immediately.
- If neither of these happen, check that the addon is enabled in the AddOns list and that there are no Lua errors in your chat.

---

## Updating

### CurseForge App
The app handles updates automatically. You can also click **Check for Updates** manually.

### Manual
1. Delete the old `AzUI_Color_Picker` folder from your AddOns directory.
2. Download the new ZIP from [Releases](https://github.com/JuNNeZ/AzUI-Color-Changer/releases) and repeat the steps above.

Your saved colors and presets are stored in `WTF\Account\<account>\<realm>\<character>\SavedVariables\AzUI_Color_PickerDB.lua` and are **not** deleted when you update the addon.

---

## Uninstalling

1. Delete the `AzUI_Color_Picker` folder from your AddOns directory.
2. (Optional) Delete `AzUI_Color_PickerDB.lua` from your SavedVariables folder to remove all saved data.

---

## Bundled Libraries

All dependencies ship inside the `Libs\` folder — you do not need to install anything else.

| Library | Purpose |
|---------|---------|
| LibStub | Library stub loader used by all Ace libs |
| AceAddon-3.0 | Core addon framework |
| AceDB-3.0 | Per-character saved variables manager |
| AceHook-3.0 | Safe function hooking |
| AceConfig-3.0 | Options table definition system |
| AceConfigDialog-3.0 | Blizzard-style options panel renderer |
| LibDataBroker-1.1 | Data broker for minimap / Titan Panel |
| CallbackHandler-1.0 | Event callback system (used by LDB) |
| LibDBIcon-1.0 | Minimap icon and Titan Panel launcher |
