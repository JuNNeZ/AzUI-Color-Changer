# AzUI Studio art pack: brief for Codex

Paste the prompt below into Codex from the addon folder
(`World of Warcraft\_retail_\Interface\AddOns\AzUI_Color_Picker`). Open
`Tools/AssetBrief/mockups.html` in a browser alongside it: it shows where every piece
sits in the window, at its real size.

---

## Prompt

You are drawing the optional art pack for **AzUI Studio**, the options window of the
World of Warcraft addon AzUI Color Picker. The window is already built and works
without this pack. The pack adds hand-made art where the window currently uses
generated shapes or nothing at all.

**Read first**

- `Tools/AssetBrief/mockups.html`: every asset in place, at real size, with its
  slot and file name.
- `Options/StudioPack.lua`: the list of files and the switches that turn each piece on.
- `Options/Studio.lua`: the palette (`Studio.C`) and the generated shapes the art must
  sit beside (`Media/Studio/*.tga`, made by `Tools/MakeStudioArt.py`).

**Look**

Flat and dark, with rounded surfaces, a thin bronze window edge, and gold for whatever
is selected. Titles are set in Marcellus, everything else in Source Sans 3. The art
should feel like the bronze and gold fittings of a well-made instrument case: fine
engraved lines and restrained ornament, not glossy or painterly. It should echo the
spirit of AzeriteUI. AzUI has two looks: **AzUI Studio**, its own design, which this
pack is for, and **AzUI Azerite**, which already dresses the same window in AzeriteUI's
own art, read at runtime from the installed AzeriteUI. Blakmane and Goldpaw, AzeriteUI's
designer and developer, have given permission to use their art, but **never copy
AzeriteUI's files into AzUI**: reference them from AzeriteUI's folder instead. This pack
is AzUI's own, so draw it new; matching AzeriteUI's bronze-and-stone feel is welcome.

Palette (from `Studio.C`):

| Token  | Hex      | Use                                        |
|--------|----------|--------------------------------------------|
| window | `#15141B`| window background                          |
| surface| `#1D1C24`| cards and rows                             |
| raised | `#2B2733`| selected rail entry, chips that are on     |
| line   | `#2E2B36`| hairlines                                  |
| bronze | `#6E5B2A`| window edge, portrait rings                |
| gold   | `#FFD100`| selection, headings, the main button       |
| goldDim| `#5A4513`| fill behind gold                           |
| text   | `#E8E2D0`| text                                       |
| muted  | `#9C95A8`| secondary text                             |

**Files to make** (all 32-bit TGA with alpha, into `Media/StudioPack/`)

1. `logo.tga`, 64×64. The mark shown left of the "AzUI Studio" title (drawn at 28×28).
   A small emblem: a health-bar sliver crossing a gem or prism, in gold `#FFD100` and
   bronze `#6E5B2A` on transparent. It must read at 28 px: two or three shapes at most.
2. `corner.tga`, 64×64. Bronze filigree for the **top-left** corner of the window, drawn
   at 40×40 and mirrored by code for the other three corners. The outer curve follows
   the window's 10 px corner radius, sitting 3 px outside it. Bronze `#6E5B2A`, with
   highlights no brighter than `#A08A4E`. Keep the inner two thirds transparent so it
   never covers content.
3. `condition-<key>.tga`, 64×64 each, **white on transparent** (the code tints them
   gold): `combat` (crossed blades), `mounted` (horse head or saddle), `resting` (moon
   over an inn roof), `stealth` (eye with a slash), `dead` (skull, or a soft ghost),
   `spec` (three stacked talent diamonds), `instance` (stone doorway). They are drawn at
   20×20, so use 2 px strokes at that size (about 6 px at 64), a consistent line style
   and no fine detail.
4. `empty-rules.tga`, 256×128. Shown above "No rules yet" on the Rules page. A quiet
   line illustration: a health bar changing colour as it passes a gate or banner. Gold
   and muted lines on transparent, no background box.
5. `empty-pets.tga`, 256×128. Shown above "No pets known yet" on the Hunter Pets page.
   A line illustration of an empty stable stall with a paw print. Same style as
   `empty-rules`.

**Then**

- Set each finished piece to `true` in `Studio.Pack` in `Options/StudioPack.lua`.
- Run `python Tools/MakeStudioArt.py` only if you change the generated shapes (you
  should not need to).
- Run the tests from the addon folder with Lua 5.1, all of which must pass:
  `lua Tools/TestStudio.lua`, `lua Tools/TestPanel.lua`, `lua Tools/TestPanel.lua art`,
  `lua Tools/TestPanel.lua plain`, `lua Tools/TestFeatures.lua`, `lua Tools/TestClients.lua`.
- Add a short note under `## [Unreleased]` in `changelog.md` naming the art you added.
- Put the source files you drew from (SVG or layered files) in `Tools/AssetBrief/source/`,
  so the art can be changed later. `Tools/` is not packaged.

**Checks before you finish**

- Each TGA opens with alpha and has the exact size above.
- `condition-*.tga` are pure white where opaque, so tinting gives a clean gold.
- Look at each piece at the size it is drawn in game (28, 40, 20 and 256×128 px) on
  `#15141B`; it must still read.
