# AzUI Healthbar Color Changer – Wiki Home

**AzUI Healthbar Color Changer** is a lightweight, self-contained World of Warcraft addon that lets you fully customize the appearance of your player health bar. Set a static color, run animated rainbow or pulse effects, save unlimited presets, and automatically apply unique colors for your hunter pets — all from one clean options panel.

> **Current version:** 4.7.29 | **Interface:** 120000 (The War Within / Dragonflight+)

---

## 📖 Wiki Pages

| Page | Description |
|------|-------------|
| **[Installation](Installation)** | How to install the addon |
| **[Configuration](Configuration)** | Full reference for every option and setting |
| **[Animations](Animations)** | Rainbow and pulse animation guide |
| **[Presets](Presets)** | Save, load, rename, and delete color presets |
| **[Hunter Pet Coloring](Hunter-Pet-Coloring)** | Auto-coloring by pet name and family |
| **[FAQ](FAQ)** | Frequently asked questions and troubleshooting |
| **[Changelog](Changelog)** | Version history |

---

## ✨ Feature Overview

### Static Color Picker
Choose any RGBA color for your health bar — full RGB control plus independent alpha (transparency). Your color persists automatically across sessions and UI reloads.

### Rainbow Animations
Three distinct animated rainbow patterns with an adjustable speed slider (0.1–5 Hz). Toggle on and off with a single button — the button label flips between **Rainbow Effect** and **Stop Rainbow Effect** so you always know the current state.

### Pulse Effect
A gentle brightness pulse (30%–100%) applied to your chosen color. Independent of the rainbow effect; uses the same speed slider. Toggle with the **Pulse Colour** / **Stop Pulse** button.

### Preset System
Save unlimited named color presets, load them from a dropdown, rename or delete them at any time. Four colorblind-friendly presets (`CB-Blue`, `CB-Orange`, `CB-Yellow`, `CB-Purple`) are pre-loaded on first run.

### Hunter Pet Auto-Coloring
When a hunter summons a pet, the addon automatically applies a color based on the pet's saved name or, as a fallback, its family type. When the pet is dismissed the player's original color is fully restored — including any active rainbow or pulse.

### Class Color Buttons
One-click buttons for every playable class apply that class's official color immediately, stopping any active animations. A dedicated **Class Colour** button applies your *own* class color.

### Minimap / Titan Panel Icon
A draggable minimap button (LibDataBroker + LibDBIcon) gives quick access to the options panel. Can be hidden from the options panel itself if you prefer the slash command instead.

### Frame Compatibility
| Frame Type | Support |
|---|---|
| **AzeriteUI** | Full — detects and colors all unit frames |
| **oUF layouts** | Full — player frame detected automatically |
| **Blizzard Default (DF / TWW)** | Full — defensive hooks prevent overwrite |

All libraries are bundled — no external downloads required.

---

## 🗺️ Quick Start

1. Install the addon (see [Installation](Installation)).
2. Log in and type `/ahui` or click the minimap icon.
3. Use the **Healthbar Colour** picker to choose a color.
4. (Optional) Click **Save as Preset** to save it for later.
5. Done — the color applies instantly and persists automatically.

---

## 🗺️ Slash Commands

| Command | Effect |
|---------|--------|
| `/ahui` | Open / close the options panel |

---

## 👨‍💻 Credits
Created with ❤️ by **JuNNeZ**.  
Code assistance & refactor ideas by **ChatGPT**.  
Ace3, LibDataBroker, LibDBIcon © their respective authors.
