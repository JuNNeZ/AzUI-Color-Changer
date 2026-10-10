# AzUI Healthbar Color Changer

**Current version:** 5.2.0

Lightweight Ace3-powered addon that lets you recolour and animate your own player health bar in **AzeriteUI** or on the **default Blizzard player frame**.

Supports **World of Warcraft Retail 12.1** (`Interface: 120100, 120105`) and **WoW Forever / Camelot 1.60.1** (`Interface: 16001`). Forever uses its own TOC and current-pet/stabled-pet layout. On Forever, AzeriteUI5 – JuNNeZ Edition and AzeriteUI6 (1.0.7 and later) both colour their player and pet frames.

---

## ✨ Features

* **Static RGBA colour** picker (alpha supported)
* **Effects:** Pulse, Breathe, Heartbeat, Two-tone, Flicker, Sweep and Rainbow (Cycle / Ping-Pong / Chaos), with a shared speed slider, smooth fades and Reduce Motion
* **Rules:** a colour and effect while you are in combat, mounted, resting, stealthed, dead, in a specialization or in an instance
* **Colour by Health:** your bar runs from your colour to a low-health colour
* **Quick palette** on the minimap button's right-click, **slash commands** and **key bindings**
* **Share strings:** export your setup as one line of text and import someone else's
* **Profiles,** per character or per specialization
* **More bars:** Blizzard's pet frame and your power bar
* **Your colour is always kept:** effects and pet colours are only applied on screen, never saved over your chosen colour
* **Presets:** save, rename, delete
* **AzUI Studio:** the options window, with a live preview of your bars, a colour wheel, recent colours, preset swatches you drag into order, playing effect cards, rules written as sentences, Undo, and search across every setting and pet
* **Pet gallery:** every pet as a card with its portrait, plus a turning 3D model of the selected pet, its own colour and a pulse or rainbow effect
* **Filters and search** for call slots and stabled pets, and **Use for all** to give a pet's colour to its whole family
* **Specialization colours** for Ferocity, Tenacity and Cunning (Retail)
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
| **AzeriteUI for Midnight** (`AzeriteUI6`) | Player and pet frames, on Retail and Forever |
| **AzeriteUI5 – JuNNeZ Edition** (`AzeriteUI5_JuNNeZ_Edition`) | Player, alternate player and pet frames under every theme: Azerite, Hunter, Mage, Paladin and the Legacy HUD |
| **AzeriteUI 5.x** (`AzeriteUI`) | Player, alternate player and pet frames |
| **Blizzard default player frame** | The bar art is desaturated so your colour shows true |

Frames that AzeriteUI creates or enables after login are picked up automatically within a couple of seconds. Other unit frame addons (ElvUI, oUF layouts, ShadowedUF, …) are not coloured.

---

## 🗺️ Slash Commands
* `/ahui` – open or close the AzUI window
* `/ahui classic` – open the previous Ace3 options window, with the same settings
* `/ahui color #ff8800` – set your colour (also `1 0.5 0` or `255 128 0`)
* `/ahui preset <name>` / `/ahui next` – load a preset, or the next one
* `/ahui effect pulse|breathe|heartbeat|twotone|flicker|sweep|rainbow|off`
* `/ahui pets on|off` – pet colours on or off
* `/ahui share` – open the Share page; `/ahui help` lists every command

Key bindings for the window, rainbow, pulse, next preset and pet colours are under **Key Bindings → AddOns**. On the minimap button, left-click opens the window, right-click the quick palette and Shift-click loads the next preset.

---

## 🛠️ Requirements & Libraries

| Category      | Library / Addon                                                   | Bundled? | Notes                                      |
|---------------|-------------------------------------------------------------------|----------|--------------------------------------------|
| **Core**      | AceAddon-3.0, AceDB-3.0, AceGUI-3.0, AceConfig-3.0                | ✔ | Ace3 Release-r1403 |
| **Launcher**  | LibDataBroker-1.1, LibDBIcon-1.0, CallbackHandler-1.0             | ✔ | LibDBIcon v12.0.3                          |
| **Stub**      | LibStub                                                           | ✔ | Loaded before all embedded libraries       |
| **Optional**  | AzeriteUI (any edition above)                                     | — | Colours its player and pet frames          |

No external downloads needed — everything is embedded in `Libs\`.

---

## 📂 Installation
1. Download **AzUI_Color_Picker-5.2.0.zip**
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

* **5.2.0**  AzUI Studio and AzUI Azerite windows • Live preview, colour wheel, recent colours and preset swatches • Rules (with five examples) • New effects: Breathe, Heartbeat, Two-tone, Flicker, Sweep • Quick palette, slash commands and key bindings • Share strings • Profiles per spec • Pet gallery with models • Power bar and Blizzard pet frame • Colour by Health • WoW Forever support
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

* Fonts: **Marcellus** by Astigmatic and **Source Sans 3** by Adobe, both under the SIL Open Font License (see `Media/Fonts`).
Created with ❤️ by **JuNNeZ** — code assistance & refactor ideas by **ChatGPT**.  
Ace3, LibDataBroker, LibDBIcon © their respective authors.
