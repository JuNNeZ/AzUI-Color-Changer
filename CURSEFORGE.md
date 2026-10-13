# ABCS – Advanced Bar Coloring System

**The ABCs of your bars.** Your own colours, effects and rules for your health bar, power bar, cast bar and class resources, on the unit frames you already use.

*Formerly AzUI Color Picker. Your settings, profiles and share strings carry over, and `/ahui` still works next to the new `/abcs`.*

## What does this addon do?

Most unit frames give your health bar one colour: green, or your class. ABCS lets you pick it yourself, set it moving with an effect, and change it when something happens: red while you hold aggro, gold in a raid, grey while dead, a pulse when Bloodlust goes up. Your hunter pets each get a colour of their own, and the same colours can reach your power bar, cast bar and combo points or runes.

It works on AzeriteUI, ElvUI, Shadowed and Unhalted Unit Frames, Z-Perl, PitBull 4, any oUF layout and the Blizzard frames, on Retail and on WoW Forever.

## New in 7.0

- **A new name.** AzUI Color Picker is now ABCS, since it colours far more than AzeriteUI's health bar.
- **Class resources:** combo points, holy power, chi, arcane charges, soul shards, essence and runes take your colour, or one of their own.
- **More unit frames:** Z-Perl, PitBull 4 and any layout on the shared oUF. Heal and absorb overlays and Blizzard's personal resource display can be coloured too.
- **Smarter rules:** two conditions in one rule ("in a raid and in combat"), turn a condition around ("not in a group"), **Try** a rule for five seconds, a **sound** when it starts, and ready-made rules to pick from.
- **New conditions:** threat (have aggro, losing it, about to pull it), casting, role, group, pet, zone, Mythic+, delve, flying, War Mode, vehicle and time of day. A buff rule can watch several spells and finds them by name in any game language.
- **Share in Chat:** put `[ABCS: name]` in chat, and anyone with the addon can click it to import your setup.
- **New effects:** Flow, Spectrum and Gradient.
- **Colour vision preview:** see your bars as they look with each common kind of colour blindness.
- **A clearer window:** new switches and sliders, icons for every page, heading and button, and a scrollbar on every long page.
- **Lighter on the game:** only what changes is repainted, and hidden bars are skipped.

## Supported unit frames

| Addon | Health | Pet | Power | Cast | Class resources | Overlays |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| AzeriteUI (5.x, JuNNeZ Edition, AzeriteUI6) | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| ElvUI | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Unhalted Unit Frames | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Shadowed Unit Frames | ✔ | ✔ | ✔ | ✔ | – | ✔ |
| Any oUF layout | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Z-Perl | ✔ | ✔ | ✔ | – | – | – |
| PitBull 4 | ✔ | ✔ | ✔ | – | – | – |
| Blizzard frames | ✔ | ✔ | ✔ | – | – | – |
| Personal resource display | ✔ | – | ✔ | – | – | – |

`/abcs check` lists every bar found, with the addon it comes from. If your bar is missing, paste what it says into a bug report.

## Features

### Colours and effects

- Any colour, with alpha, from a colour wheel with Hex and RGB, recent colours and preset swatches
- Effects: Gradient, Flow, Spectrum, Pulse, Breathe, Heartbeat, Two-tone, Flicker, Sweep and Rainbow, with speed, depth and Reduce Motion
- Colour by Health: your bar runs from your colour to a low-health colour
- Presets you save and name, plus ready-made packs: Class Fantasy, Elements, Pastel, High Contrast, Midnight and Class Colours
- A preset per specialization, or full profiles per character or specialization
- Your chosen colour is never overwritten by an effect, a rule or a pet colour

### Rules

- A colour and effect while something is true: in combat, mounted, resting, stealthed, dead, in a role, group, specialization, instance, Mythic+, delve or zone, flying, in War Mode or a vehicle, at a time of day, with or without your pet, with aggro, while casting, or while a buff or debuff is on you
- Two conditions in one rule, and any condition turned around
- On your health bar, pet frame, power bar, cast bar, class resources or every bar
- A sound when a rule starts, heard even with sound effects off
- Try a rule anywhere: raid and Mythic+ rules can be set up in town
- Ready-made rules: Bloodlust, healing a raid, Mythic+, delves, a pet reminder, aggro warnings for tanks and damage dealers, and more

### Hunter pets

- A gallery of every pet you have tamed, with portraits and a turning 3D model
- Each pet's own colour and effect, or a colour for its whole family
- Specialization colours for Ferocity, Tenacity and Cunning
- Choose where pet colours go: your health bar, the pet frame, or both

### Sharing

- Copy your whole setup, or the parts you pick, as one line of text
- Share in Chat as a link other players with ABCS can click
- See what an import would change before anything is changed

### The ABCS window

- Two looks: ABCS Studio, and ABCS Azerite in the art of whichever AzeriteUI you have
- A live preview of your bars, search across every setting and every pet, and Undo
- A mark on every setting you have changed, with one click to put it back
- Keyboard navigation, a quick palette on the minimap button, key bindings and slash commands

## Commands

- `/abcs` or `/ahui` – open the window
- `/abcs color #ff8800` – set your colour
- `/abcs preset <name>` and `/abcs next` – load a preset
- `/abcs effect pulse` – choose an effect (`off` to stop)
- `/abcs pets on|off` – pet colours on or off
- `/abcs check` – what each bar shows and why, for bug reports
- `/abcs help` – every command

## Languages

English, Deutsch, Français, Español, Português, Italiano, Русский, 한국어, 简体中文 and 繁體中文. Translations live on this project's **Localization** page, where anyone can correct or add one.

## Links

- Source, issues and wiki: [GitHub](https://github.com/JuNNeZ/ABCS-Advanced-Bar-Coloring-System)
- Rules Cookbook: [ready-made ideas for rules](https://github.com/JuNNeZ/ABCS-Advanced-Bar-Coloring-System/wiki/Rules-Cookbook)
- By the author of [Advanced Hotkey Overlay System (AHOS)](https://www.curseforge.com/wow/addons/advanced-hotkey-overlay-system)
