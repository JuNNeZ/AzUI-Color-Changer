# Hunter Pet Coloring

AzUI Healthbar Color Changer includes a system for automatically coloring your health bar based on your active hunter pet. When **Pet Colour Overrides** is enabled, the health bar changes color whenever you summon or dismiss a pet, and returns to your own color when no pet is active.

---

## How It Works

1. When you summon a pet, the addon reacts to the `UNIT_PET` event.
2. It checks your saved presets for a preset **named after the pet** (exact match, case-sensitive).
3. If a named preset is found → that color is shown.
4. If no named preset exists → the pet's **family** is looked up in the built-in family color table. Families are matched by their game ID, so this works in every client language.
5. If neither matches → your own color is kept.
6. When the pet is dismissed (or dies and stays dismissed), your **own color comes back**, including any rainbow or pulse animation you had running.

The pet color is only shown on screen — it is never saved over your chosen color, so `/reload`ing or logging out with a pet out cannot lose your color.

---

## Enabling Pet Color Overrides

Open the options panel (`/ahui`) and toggle **Pet Colour Overrides** on.

> Settings are stored in the shared **Default** profile, so the toggle applies to all your characters. Non-hunters are unaffected because they have no pet.

---

## Saving a Color for a Specific Pet

1. Summon the pet you want to color.
2. Set your desired color with the color picker.
3. Click **Save to Current Pet**.

The color from the color picker is saved under the pet's exact name (e.g., `"Fluffy"`) and shown straight away. It also appears in the regular **Select Preset** dropdown and can be renamed or deleted there.

---

## Built-in Pet Family Colors

If no named preset exists for a pet, the addon falls back to a color based on the pet's family:

### Exotic Families
| Family | Color |
|--------|-------|
| Spirit Beast | Cyan aura `{0.00, 1.00, 1.00}` |
| Devilsaur | Blood-red scales `{0.90, 0.20, 0.10}` |
| Core Hound | Fiery magma `{1.00, 0.35, 0.25}` |
| Chimaera | Frost-blue breath `{0.25, 0.80, 1.00}` |
| Clefthoof | Earthen hide `{0.55, 0.35, 0.25}` |
| Direhorn | Muddy horn `{0.60, 0.40, 0.20}` |
| Scalehide | Mossy scales `{0.40, 0.70, 0.30}` |
| Shale Beast | Crystalline purple `{0.65, 0.50, 0.75}` |
| Stone Hound | Azure stone `{0.50, 0.70, 0.90}` |
| Water Strider | Teal water walker `{0.20, 0.60, 0.80}` |
| Hydra | Emerald scales `{0.25, 0.75, 0.55}` |
| Aqiri | Bronze carapace `{0.85, 0.45, 0.15}` |
| Riverbeast | Swamp green `{0.35, 0.65, 0.45}` |
| Worm | Sandy burrower `{0.70, 0.55, 0.25}` |
| Carapid | Purple chitin `{0.70, 0.30, 0.80}` |
| Pterrordax | Amber wing `{0.80, 0.60, 0.30}` |

### Mammal Families
| Family | Color |
|--------|-------|
| Bear | Brown fur `{0.45, 0.35, 0.25}` |
| Boar | Tusky brown `{0.60, 0.40, 0.30}` |
| Cat | Pale pink `{1.00, 0.50, 0.50}` |
| Fox | Orange fur `{0.95, 0.45, 0.20}` |
| Gorilla | Grey shadow `{0.40, 0.40, 0.40}` |
| Hyena | Savannah `{0.80, 0.60, 0.25}` |
| Monkey | Jungle brown `{0.65, 0.55, 0.40}` |
| Oxen | Taupe `{0.50, 0.45, 0.35}` |
| Rodent | Whiskered grey `{0.75, 0.65, 0.55}` |
| Tallstrider | Savannah yellow `{0.85, 0.70, 0.20}` |
| Camel | Desert beige `{0.75, 0.65, 0.45}` |
| Courser | Golden stallion `{0.90, 0.80, 0.60}` |
| Feathermane | Majestic plum `{0.75, 0.50, 0.85}` |
| Gruffhorn | Rough hide `{0.55, 0.45, 0.30}` |
| Hound | Loyal brown `{0.60, 0.50, 0.40}` |
| Mammoth | Tusked grey `{0.65, 0.55, 0.45}` |
| Stag | Forest green `{0.50, 0.70, 0.40}` |
| Wolf | Pack grey `{0.45, 0.50, 0.55}` |

### Bird Families
| Family | Color |
|--------|-------|
| Carrion Bird | Vulture red-brown `{0.75, 0.35, 0.20}` |
| Bird of Prey | Golden feather `{0.95, 0.85, 0.30}` |
| Dragonhawk | Fiery wings `{0.90, 0.30, 0.30}` |
| Ravager | Rust chitin `{0.80, 0.40, 0.20}` |
| Moth | Soft lilac `{0.80, 0.75, 0.85}` |
| Bat | Night wing `{0.30, 0.25, 0.35}` |
| Waterfowl | Lake blue `{0.40, 0.70, 0.90}` |

### Reptile & Amphibian Families
| Family | Color |
|--------|-------|
| Basilisk | Jade hide `{0.35, 0.75, 0.60}` |
| Crab | Scarlet shell `{0.90, 0.30, 0.30}` |
| Crocolisk | Swamp reptile `{0.30, 0.70, 0.35}` |
| Raptor | Rust scales `{0.80, 0.45, 0.20}` |
| Serpent | Emerald serpent `{0.15, 0.75, 0.40}` |
| Turtle | Jade shell `{0.20, 0.60, 0.30}` |
| Lizard | Lime scales `{0.55, 0.80, 0.35}` |
| Whiptail | Olive scales `{0.60, 0.75, 0.30}` |
| Sporebat | Cyan spores `{0.55, 0.80, 0.90}` |
| Hopper | Leap green `{0.60, 0.80, 0.50}` |
| Ray | Ethereal purple `{0.70, 0.60, 0.90}` |
| Wind Serpent | Airy teal `{0.50, 0.90, 0.70}` |

### Insect Families
| Family | Color |
|--------|-------|
| Spider | Web grey `{0.45, 0.45, 0.55}` |
| Wasp | Yellow stinger `{1.00, 0.85, 0.15}` |
| Beetle | Jade carapace `{0.30, 0.70, 0.55}` |
| Scorpid | Desert amber `{0.85, 0.70, 0.30}` |

### Mechanical & Special
| Family | Color |
|--------|-------|
| Mechanical | Arcane blue steel `{0.50, 0.80, 1.00}` |
| Blood Beast | Crimson blood `{0.80, 0.15, 0.20}` |
| Lesser Dragonkin | Dragon purple `{0.60, 0.40, 0.85}` |
| Warp Stalker | Void pink `{0.85, 0.50, 0.95}` |

All family colors are fully opaque (alpha 1).

---

## Tips

- You can create per-pet colors for multiple pets and switch between them naturally by summoning different pets.
- If you want all pets of a particular family to share a color without saving individual presets, just rely on the family fallback.
- The **Save to Current Pet** button is disabled when you have no active pet — make sure the pet is summoned before saving.
- Pet presets can be renamed via the regular **Rename Preset** UI if you want to tidy up the dropdown.
- Picking a color or starting an effect while a pet is out shows your choice right away; the pet color returns the next time your pet changes.

---

## Behavior Details

| Situation | Result |
|-----------|--------|
| Pet summoned, named preset exists | Named preset color shown |
| Pet summoned, no named preset, family known | Family fallback color shown |
| Pet summoned, no named preset, family unknown | Your color unchanged |
| Pet dismissed | Your own color shown again |
| Rainbow was active before summoning pet | Rainbow pauses, resumes after pet dismissed |
| Pulse was active before summoning pet | Pulse pauses, resumes after pet dismissed |
| `/reload` or logout with pet out | Your saved color is untouched |
