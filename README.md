# AzUI Healthbar Color Changer

**Current version:** 4.7.5  
Lightweight Ace3-powered addon that lets you recolour and animate your player health-bar in **AzeriteUI, oUF layouts, or the default frames**.

---

## ✨ Features
* **Static RGBA colour** picker (alpha supported)
* **Rainbow** (Cycle / Ping-Pong / Chaos) with speed slider & single-button toggle
* **Pulse** effect on any colour with its own toggle
* **Presets:** save, rename, delete, auto-apply by hunter-pet name or family
* **Colour-blind presets** seeded on first run
* **Class colour & random** one-click buttons
* **Minimap / Titan Panel icon** (LibDataBroker) — click to toggle options
* **AceDB profiles**, debug mode, and defensive frame hooks

---

## 🗺️ Slash Commands
* `/ahui` – open the options panel

---

## 🛠️ Requirements & Libraries

| Category      | Library / Addon                                                          | Bundled? | Notes                                   |
|---------------|--------------------------------------------------------------------------|----------|-----------------------------------------|
| **Core**      | AceAddon-3.0, AceDB-3.0, AceHook-3.0, AceConfig-3.0, AceConfigDialog-3.0 | ✔ | Shipped in *Libs\\AceXXX-3.0\\* |
| **Minimap**   | LibDataBroker-1.1 (+ CallbackHandler-1.0)                                | ✔ | Included under *Libs\\LibDBIcon-1.0\\* |
| **Icon**      | LibDBIcon-1.0                                                            | ✔ | Handles minimap & Titan launcher        |
| **Stub**      | LibStub                                                                  | ✔ | Embedded                                |
| **Optional**  | AzeriteUI                                                                | ⬇ | If installed, colours its custom frames |

No external downloads needed — everything is embedded in `Libs\`.

---

## 📂 Installation
1. Download **AzUI_Color_Picker-4.7.5.zip**  
2. Unzip to your AddOns folder; you should have:
AddOns\AzUI_Color_Picker
AzUI_Color_Picker.toc
AzUI_Color_Picker.lua
icon.tga
Libs\LibStub\LibStub.lua
Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua
Libs\LibDBIcon-1.0\LibDataBroker-1.1\LibDataBroker-1.1.lua
Libs\LibDBIcon-1.0\CallbackHandler-1.0\CallbackHandler-1.0.lua
Libs\AceAddon-3.0\AceAddon-3.0.lua
… (other Ace3 files)

3. `/reload` in-game and type `/ahui` to configure.

---

### Change-Highlights (since 4.6)

* **4.7.5** – HSV Ping-Pong & Chaos overhaul, smarter toggle labels.  
* **4.7.4** – Single-button toggles for Rainbow & Pulse, nil-safe StopRainbow.  
* **4.7.0** – Advanced Rainbow patterns, speed slider, pulse base colour.  
* **4.6.x** – Minimap/Titan launcher, full tooltips, colour-blind preset seeds.

See full `CHANGELOG.md` for detailed history.

## 👨‍💻 Credits
Created with ❤️ by **JuNNeZ** — code assistance & refactor ideas by **ChatGPT**.  
Ace3, LibDataBroker, LibDBIcon © their respective authors.
