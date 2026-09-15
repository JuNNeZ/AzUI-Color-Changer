# AzUI Healthbar Color Changer

**Current version:** 5.0.0

Lightweight Ace3-powered addon that lets you recolour and animate your own player health bar in **AzeriteUI** or on the **default Blizzard player frame**.

Supports **World of Warcraft Retail 12.1** (`Interface: 120100`).

---

## ✨ Features

* **Static RGBA colour** picker (alpha supported)
* **Rainbow** (Cycle / Ping-Pong / Chaos) and **Pulse** effects with a shared speed slider
* **Your colour is always kept:** effects and pet colours are only applied on screen, never saved over your chosen colour
* **Presets:** save, rename, delete
* **Hunter Pets page:** every pet listed with its icon, each with its own colour and a pulse or rainbow effect
* **Editable pet family colours** that work in every game language
* **Choose where pet colours go:** your health bar, the AzeriteUI pet frame, or both
* **Colour-blind presets** added once per profile
* **Class colour & random** one-click buttons
* **Minimap, AddOn Compartment & Titan Panel launcher** (LibDataBroker)
* Debug mode for troubleshooting frame detection

---

## 🖼️ Supported Frames

| Frame | Notes |
|-------|-------|
| **AzeriteUI for Midnight** (`AzeriteUI6`) | Player and pet frames |
| **AzeriteUI5 – JuNNeZ Edition** (`AzeriteUI5_JuNNeZ_Edition`) | Player, alternate player and pet frames |
| **AzeriteUI 5.x** (`AzeriteUI`) | Player, alternate player and pet frames |
| **Blizzard default player frame** | The bar art is desaturated so your colour shows true |

Frames that AzeriteUI creates or enables after login are picked up automatically within a couple of seconds. Other unit frame addons (ElvUI, oUF layouts, ShadowedUF, …) are not coloured.

---

## 🗺️ Slash Commands
* `/ahui` – open or close the options panel

---

## 🛠️ Requirements & Libraries

| Category      | Library / Addon                                                   | Bundled? | Notes                                      |
|---------------|-------------------------------------------------------------------|----------|--------------------------------------------|
| **Core**      | AceAddon-3.0, AceDB-3.0, AceGUI-3.0, AceConfig-3.0                | ✔ | Ace3 Release-r1403 |
| **Launcher**  | LibDataBroker-1.1, LibDBIcon-1.0, CallbackHandler-1.0             | ✔ | LibDBIcon v12.0.3                          |
| **Stub**      | LibStub                                                           | ✔ | Loaded before all embedded libraries       |
| **Optional**  | AzeriteUI (any retail edition above)                              | — | Colours its player and pet frames          |

No external downloads needed — everything is embedded in `Libs\`.

---

## 📂 Installation
1. Download **AzUI_Color_Picker-5.0.0.zip**
2. Unzip to your AddOns folder; you should have:

```
AddOns\AzUI_Color_Picker\
    AzUI_Color_Picker.toc
    AzUI_Color_picker.lua
    icon.tga
    Libs\LibStub\LibStub.lua
    Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
    Libs\LibDBIcon-1.0\LibDBIcon-1.0\LibDBIcon-1.0.lua
    Libs\LibDBIcon-1.0\LibDataBroker-1.1\LibDataBroker-1.1.lua
    Libs\AceAddon-3.0\AceAddon-3.0.lua
    Libs\AceGUI-3.0\AceGUI-3.0.lua
    … (other Ace3 files)
```

3. `/reload` in-game and type `/ahui` to configure.

---

### Change-Highlights (since 4.7.5)

* **5.0.0**  Hunter Pets page with pet icons • Own colour and pulse or rainbow per pet • Editable pet family colours • Choose where pet colours go • Pets recognised even when unit names are hidden
* **4.9.1**  AzeriteUI pet frame shows your colour, effects and pet colours again • AzeriteUI6 pet frame coloured too
* **4.9.0**  All retail AzeriteUI editions incl. AzeriteUI6 • Saved colour never overwritten by pulse, rainbow or pet colours • Pet family colours in every language • Flicker-free, smoother animations • No more oUF colour overrides • Preset rename fixes
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

See full `changelog.md` for detailed history.

## 👨‍💻 Credits
Created with ❤️ by **JuNNeZ** — code assistance & refactor ideas by **ChatGPT**.  
Ace3, LibDataBroker, LibDBIcon © their respective authors.
