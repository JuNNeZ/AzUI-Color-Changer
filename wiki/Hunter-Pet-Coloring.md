# Hunter Pet Coloring

AzUI Healthbar Color Changer can color your bars based on the pet you have out. Every hunter pet can have its own color and effect, pets without one use a color for their family, and you choose whether pet colors go on your health bar, the AzeriteUI pet frame, or both. When the pet is dismissed, your own color and effects come back.

Pet colors are only shown on screen — they are never saved over your chosen color, so `/reload`ing or logging out with a pet out cannot lose your color.

---

## Where to Find It

Open the options panel (`/ahui`). The panel has three pages in the list on the left:

| Page | What it holds |
|------|---------------|
| **Health Bar** | Your own color, effects, presets and maintenance options |
| **Hunter Pets** | Pet colors on or off, where they go, and one entry per pet |
| **Pet Families** | The fallback color for every pet family |

---

## Turning Pet Colors On

On the **Hunter Pets** page, enable **Use Pet Colours**.

> Settings are stored in the shared **Default** profile, so the toggle and your pet colors apply to all your characters. The list of pets is kept per character.

### Show Pet Colours On

| Option | Health bar | AzeriteUI pet frame |
|--------|------------|---------------------|
| **Health bar and pet frame** (default) | Pet color | Pet color |
| **Health bar only** | Pet color | Your color |
| **Pet frame only** | Your color | Pet color |

The bar that does not show the pet color keeps your own color and any rainbow or pulse you have running. The pet frame is only colored with AzeriteUI; the default Blizzard pet frame is not colored.

---

## Your Pets

Below the settings, the **Hunter Pets** page lists your pets with their in-game icons:

- Pets in your five **Call Pet** slots, and in the Beast Mastery second-pet slot, come first in slot order.
- Pets in your stable are grouped under **Stabled Pets**, sorted by name.
- The pet that is out is shown in green, and its icon also appears next to **Hunter Pets** in the list.

The list is filled from the game's stable information when you log in, summon a pet or use the stable. If a stabled pet is missing, visit a stable master once. Pets you abandon disappear from the list the next time you visit a stable master.

### Pet settings

Click a pet to open its settings:

| Setting | Options |
|---------|---------|
| **Colour** | **Family colour** — the color for its family on the Pet Families page (default)<br>**Own colour** — the color picked below<br>**No pet colour** — this pet leaves your bars alone |
| **Own Colour** | RGBA color picker. Picking a color switches the pet to **Own colour**. |
| **Effect** | **None**, **Pulse** or **Rainbow** while the pet is out |
| **Reset** | Back to the family color with no effect |

Pet effects use the **Animation Speed** and **Rainbow Pattern** from the Health Bar page. A pet set to **Rainbow** shows a rainbow even when its family has no color.

### Save to Current Pet

The **Save to Current Pet** button on the Health Bar page gives the pet that is out the color from the main color picker as its own color. It is disabled when no pet is out.

---

## Pet Families

Pets set to **Family colour** use the color for their family. The **Pet Families** page lists every hunter pet family, grouped like the tables below, each with its own color picker:

- Change a family's color with its color picker. A **Reset** button appears next to changed colors.
- **Reset All Families** puts every family back to its built-in color.

Families are matched by their game ID, so this works in every client language.

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

All built-in family colors are fully opaque (alpha 1).

---

## How the Pet Is Recognized

1. When you summon or dismiss a pet (`UNIT_PET`), the addon checks which **Call Pet** spell is active and reads that pet from your stable. This also works where the game hides unit names from addons.
2. If that does not find the pet, it matches your pet's name against your call-pet slots. If the stable has not caught up right after a summon, the addon looks again one second later.
3. The pet's family comes from the game while the pet is out. When the game hides it, the addon uses the family it noted earlier, or the family name shown in the stable.
4. The color is picked in this order:
   1. **No pet colour** → no pet color.
   2. **Own colour** → that color.
   3. A pet that is not in your stable, such as a warlock demon, with a preset of its exact name → that preset.
   4. Otherwise → its family color, if the family is known.

### Upgrading from older versions

Older versions saved a pet's color as a preset named after the pet. The first time the addon sees that pet in your stable, the preset's color becomes the pet's **Own colour**. The preset itself stays, so you can still load, rename or delete it without changing the pet.

---

## Tips

- Give your favorite pets their own colors and let the rest use their family colors.
- A pulsing or rainbow pet set to **Pet frame only** keeps your health bar calm while the pet frame stands out.
- Picking a color or starting an effect on the Health Bar page while a pet is out shows your choice on your health bar right away; the pet color returns there the next time your pet changes. If pet colors also go on the pet frame, it keeps showing the pet color.
- Changing a pet's color, effect or family color while that pet is out shows the change immediately.

---

## Behavior Details

| Situation | Result |
|-----------|--------|
| Pet out, **Own colour** set | Its own color and effect are shown |
| Pet out, **Family colour**, family known | Family color and the pet's effect are shown |
| Pet out, **Family colour**, family unknown | Your color unchanged, unless the pet is set to **Rainbow** |
| Pet out, **No pet colour** | Your color unchanged |
| Pet dismissed | Your own color shown again |
| Rainbow or pulse running when a pet color is shown on your health bar | Your effect pauses there and resumes when the pet is dismissed |
| `/reload` or logout with pet out | Your saved color is untouched |
