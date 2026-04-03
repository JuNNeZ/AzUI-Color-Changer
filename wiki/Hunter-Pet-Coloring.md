# Hunter Pet Coloring

AzUI Healthbar Color Changer includes a system for automatically coloring your health bar based on your active hunter pet. When **Pet Colour Overrides** is enabled, the health bar changes color whenever you summon or dismiss a pet, and seamlessly reverts to your player color when no pet is active.

---

## How It Works

1. When you summon a pet, the addon fires on the `UNIT_PET` event.
2. It checks your saved presets for a preset **named after the pet** (exact match, case-sensitive).
3. If a named preset is found → that color is applied.
4. If no named preset exists → the pet's **family type** is looked up in the built-in family color table.
5. If neither matches → the player's current color is kept unchanged.
6. When the pet is dismissed (or dies and stays dismissed), the player's **original color is fully restored**, including any rainbow or pulse animation that was active before the pet was summoned.

---

## Enabling Pet Color Overrides

Open the options panel (`/ahui`) and toggle **Pet Colour Overrides** on.

> This setting is per-character. A hunter alt and a non-hunter character can have different settings.

---

## Saving a Color for a Specific Pet

1. Summon the pet you want to color.
2. Set your desired color with the color picker.
3. Click **Save to Current Pet**.

The color is saved under the pet's exact name (e.g., `"Fluffy"`). It will also appear in the regular **Select Preset** dropdown and can be renamed or deleted there.

---

## Built-in Pet Family Colors

If no named preset exists for a pet, the addon falls back to a color based on the pet's family. All The War Within hunter pet families are covered:

### Exotic Families
| Family | Color | Notes |
|--------|-------|-------|
| Spirit Beast | Cyan `{0, 1, 1, 1}` | |
| Devilsaur | Deep green `{0.20, 0.60, 0.20, 1}` | Exotic |
| Core Hound | Dark red `{0.70, 0.20, 0.15, 1}` | Exotic |
| Chimaera | Teal `{0.20, 0.70, 0.65, 1}` | Exotic |
| Clefthoof | Brown-tan `{0.55, 0.40, 0.25, 1}` | Exotic |
| Direhorn | Purple-grey `{0.55, 0.45, 0.65, 1}` | Exotic |
| Kodo | Sandy `{0.70, 0.55, 0.30, 1}` | Exotic |
| Scalehide | Olive `{0.50, 0.55, 0.25, 1}` | Exotic |
| Shale Beast | Stone `{0.60, 0.55, 0.50, 1}` | Exotic |
| Silithid | Acid yellow `{0.80, 0.80, 0.10, 1}` | Exotic |
| Stone Hound | Rock grey `{0.55, 0.50, 0.45, 1}` | Exotic |
| Water Strider | Ice blue `{0.50, 0.80, 0.90, 1}` | Exotic |
| Hydra | Deep teal `{0.15, 0.60, 0.55, 1}` | Exotic |
| Aqiri | Sand `{0.85, 0.75, 0.40, 1}` | Exotic |
| Riverbeast | Muddy brown `{0.50, 0.40, 0.20, 1}` | Exotic |
| Worm | Pale `{0.70, 0.65, 0.50, 1}` | Exotic |
| Carapid | Amber `{0.80, 0.60, 0.20, 1}` | Exotic (TWW) |
| Pterrordax | Sky blue `{0.40, 0.70, 0.90, 1}` | Exotic (TWW) |

### Mammal Families
| Family | Color |
|--------|-------|
| Bear | Brown `{0.45, 0.35, 0.25, 1}` |
| Boar | Pink-tan `{0.70, 0.50, 0.40, 1}` |
| Cat | Golden `{0.90, 0.75, 0.15, 1}` |
| Dog | Tan `{0.80, 0.65, 0.40, 1}` |
| Fox | Orange `{0.90, 0.50, 0.15, 1}` |
| Gorilla | Dark brown `{0.40, 0.30, 0.20, 1}` |
| Hyena | Spotted tan `{0.75, 0.65, 0.40, 1}` |
| Monkey | Warm brown `{0.65, 0.45, 0.30, 1}` |
| Wolf | Steel blue `{0.45, 0.50, 0.60, 1}` |
| Mammoth | Ivory `{0.75, 0.70, 0.60, 1}` |
| Stag | Forest green `{0.35, 0.55, 0.30, 1}` |
| Feathermane | Feather pink `{0.85, 0.60, 0.70, 1}` |
| Courser | Silver `{0.70, 0.72, 0.75, 1}` |
| Gruffhorn | Charcoal `{0.40, 0.38, 0.35, 1}` |
| Hound | Rust `{0.70, 0.40, 0.25, 1}` |
| Tallstrider | Pale yellow `{0.90, 0.85, 0.50, 1}` |

### Bird Families
| Family | Color |
|--------|-------|
| Bird of Prey | Amber `{0.90, 0.65, 0.10, 1}` |
| Carrion Bird | Bone white `{0.75, 0.70, 0.60, 1}` |
| Dragonhawk | Flame `{1, 0.40, 0.05, 1}` |
| Bat | Dark purple `{0.30, 0.25, 0.35, 1}` |
| Moth | Lavender `{0.75, 0.60, 0.85, 1}` |
| Ravager | Crimson-purple `{0.60, 0.20, 0.60, 1}` |
| Waterfowl | Lake blue `{0.40, 0.65, 0.80, 1}` |

### Reptile Families
| Family | Color |
|--------|-------|
| Serpent | Emerald `{0.15, 0.75, 0.40, 1}` |
| Raptor | Teal `{0.20, 0.65, 0.55, 1}` |
| Turtle | Moss `{0.40, 0.60, 0.25, 1}` |
| Crocolisk | Swamp green `{0.35, 0.50, 0.20, 1}` |
| Basilisk | Stone green `{0.50, 0.55, 0.35, 1}` |
| Crab | Coral `{0.85, 0.40, 0.30, 1}` |
| Lizard | Lime `{0.50, 0.80, 0.25, 1}` |
| Wind Serpent | Electric blue `{0.20, 0.60, 0.95, 1}` |
| Ray | Deep blue `{0.25, 0.40, 0.80, 1}` |
| Hopper | Grass green `{0.40, 0.70, 0.30, 1}` |

### Insect Families
| Family | Color |
|--------|-------|
| Spider | Midnight purple `{0.35, 0.20, 0.50, 1}` |
| Wasp | Yellow `{1, 0.85, 0.15, 1}` |
| Beetle | Bronze `{0.55, 0.45, 0.20, 1}` |
| Scorpid | Orange-red `{0.80, 0.35, 0.10, 1}` |

### Aquatic & Other
| Family | Color |
|--------|-------|
| Shark | Ocean blue `{0.40, 0.60, 0.80, 1}` |
| Fish | Aqua `{0.30, 0.70, 0.75, 1}` |
| Mechanical | Steel `{0.50, 0.80, 1, 1}` |
| Sporebat | Violet `{0.60, 0.40, 0.75, 1}` |

### Special / Skill-Required
| Family | Color |
|--------|-------|
| Blood Beast | Crimson `{0.80, 0.15, 0.20, 1}` |
| Lesser Dragonkin | Dragon gold `{0.80, 0.65, 0.10, 1}` |
| Warp Stalker | Void purple `{0.45, 0.20, 0.65, 1}` |

---

## Tips

- You can create per-pet colors for multiple pets and switch between them naturally by summoning different pets.
- If you want all pets of a particular family to share a color without saving individual presets, just rely on the family fallback.
- The **Save to Current Pet** button is disabled when you have no active pet — make sure the pet is summoned before saving.
- Pet presets can be renamed via the regular **Rename Preset** UI if you want to tidy up the dropdown.
- Non-hunter characters can simply leave **Pet Colour Overrides** disabled — the feature has no effect when no pet is present.

---

## Behavior Details

| Situation | Result |
|-----------|--------|
| Pet summoned, named preset exists | Named preset color applied |
| Pet summoned, no named preset, family known | Family fallback color applied |
| Pet summoned, no named preset, family unknown | Player color unchanged |
| Pet dismissed | Player's previous color fully restored |
| Rainbow was active before summoning pet | Rainbow resumes after pet dismissed |
| Pulse was active before summoning pet | Pulse resumes after pet dismissed |
