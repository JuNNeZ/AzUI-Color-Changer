# AzUI Healthbar Color Changer

**Current version:** 4.8.0

Lightweight Ace3-powered addon that lets you recolour and animate your player health-bar in **AzeriteUI, oUF layouts, or the default frames**.

Supports **World of Warcraft Retail 12.1.0** (`Interface: 120100`).

---

## ✨ Features

* **Static RGBA colour** picker (alpha supported)
* **Rainbow** (Cycle / Ping-Pong / Chaos) with speed slider & single-button toggle
* **Pulse** effect on any colour with its own toggle
* **Presets:** save, rename, delete, auto-apply by hunter-pet name or family
* **Hunter pet family coverage** with name presets and fallback colours
* **Colour-blind presets** seeded on first run
* **Class colour & random** one-click buttons
* **Minimap, AddOn Compartment & Titan Panel launcher** (LibDataBroker)
* **AceDB profiles**, debug mode, and defensive frame hooks

---

## 🗺️ Slash Commands
* `/ahui` – open the options panel

---

## 🛠️ Requirements & Libraries

| Category      | Library / Addon                                                   | Bundled? | Notes                                      |
|---------------|-------------------------------------------------------------------|----------|--------------------------------------------|
| **Core**      | AceAddon-3.0, AceDB-3.0, AceGUI-3.0, AceConfig-3.0                | ✔ | Ace3 Release-r1403 (Retail 12.1 compatible) |
| **Launcher**  | LibDataBroker-1.1, LibDBIcon-1.0, CallbackHandler-1.0             | ✔ | LibDBIcon v12.0.3                          |
| **Stub**      | LibStub                                                           | ✔ | Loaded before all embedded libraries       |
| **Optional**  | AzeriteUI                                                         | — | Colours its custom player frames            |

No external downloads needed — everything is embedded in `Libs\`.

---

## 📂 Installation
1. Download **AzUI_Color_Picker-4.8.0.zip**
2. Unzip to your AddOns folder; you should have:

```
AddOns\AzUI_Color_Picker\
    AzUI_Color_Picker.toc
    AzUI_Color_picker.lua
    icon.tga
    Libs\LibStub\LibStub.lua
    Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua
    Libs\LibDBIcon-1.0\LibDataBroker-1.1\LibDataBroker-1.1.lua
    Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
    Libs\AceGUI-3.0\AceGUI-3.0.lua
    Libs\AceAddon-3.0\AceAddon-3.0.lua
    … (other Ace3 files)
```

3. `/reload` in-game and type `/ahui` to configure.

---

### Change-Highlights (since 4.7.5)

* **4.8.0**  Retail 12.1 API • Correct embedded-library load order • Current Ace3/LibDBIcon • Safe status-bar hooks • Fixed animation and pet-state restoration
* **4.7.27**  Version bump for release
* **4.7.26**  Complete TWW hunter pet family coverage • Added 20+ missing families (Carapid, Pterrordax, Courser, Feathermane, etc.) • Normalized family naming
* **4.7.25**  Lua 5.4 unpack shim • Male / Female class-name buttons • Enhanced Blizzard health bar override • Fixed SetHealthColor errors
* **4.7.20**  Final texture logic (Blizzard gradient tinted, AzeriteUI gradient preserved)
* **4.7.19**  Re-tint Blizzard bars instead of flat white • Fixed flat-brown AzeriteUI bar
* **4.7.18**  Removed duplicate numeric-texture branch • Extra end in PatchFrame fixed
* **4.7.17**  Stray end before helper removed • Deleted duplicate SetHealthColor block
* **4.7.16**  type(texPath) guard stops numeric-index crash • Version bump
* **4.7.15**  Closed PatchFrame correctly • Removed colour-override duplicate lines
* **4.7.14**  Purged redundant two-line override snippet (logic cleanup)
* **4.7.13**  Deleted duplicate Classic path & stray end (f.Health…) (line-213 crash)
* **4.7.12**  Refactored PatchFrame order, consolidated texture handling
* **4.7.11**  Fixed colorClass=false=false typo • VertexColor tint for Blizzard gradient
* **4.7.10**  Dragonflight/TWW Blizzard player-frame support • Atlas vs custom texture detect
* **4.7.9**  Temporary WHITE8X8 fallback for non-Blizzard bars (prevented green tint)
* **4.7.8**  Retail player-frame path updated (HealthBarsContainer.HealthBar)
* **4.7.7**  First Blizzard helper (path mis-match hot-fixed in 4.7.8)
* **4.7.6**  Rainbow toggle shows Stop text • HSV Ping-Pong hue sweep • Hunter-pet StopRainbow nil fix
* **4.7.5**  Advanced Rainbow patterns: Cycle / Ping-Pong / Chaos with toggle button text swap

See full `CHANGELOG.md` for detailed history.

## 👨‍💻 Credits
Created with ❤️ by **JuNNeZ** — code assistance & refactor ideas by **ChatGPT**.  
Ace3, LibDataBroker, LibDBIcon © their respective authors.
