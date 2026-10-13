# Supported Frames

ABCS colours your own bars in these addons. Frames that appear after login are found when their addon loads, a few times after login and every 15 seconds after that.

| Addon | Health bar | Pet frame | Power bar | Cast bar | Class resources | Heal and absorb overlays |
|-------|:---:|:---:|:---:|:---:|:---:|:---:|
| AzeriteUI (5.x, JuNNeZ Edition, AzeriteUI6) | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| ElvUI | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Unhalted Unit Frames | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Shadowed Unit Frames | ✔ | ✔ | ✔ | ✔ | – | ✔ |
| Any layout on the shared oUF | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Z-Perl | ✔ | ✔ | ✔ | – | – | – |
| PitBull 4 | ✔ | ✔ | ✔ | – (it colours its own by the cast) | – | – |
| Blizzard's player and pet frames | ✔ | ✔ | ✔ | – | – | – |
| Blizzard's personal resource display | ✔ | – | ✔ | – | – | – |

The power bar, cast bar, class resources, overlays and personal resource display are switched on under **More Bars**. A rule set to show on the power bar, the cast bar or the class resources takes them while it shows, even when they are otherwise left alone.

Class resources are the points oUF draws as ClassPower and Runes: combo points, holy power, chi, arcane charges, soul shards, essence and runes. Monk stagger keeps its own colour, since it says how heavy the stagger is.

## When a bar is not coloured

Type `/ahui check` in chat. It lists:

* what each bar should show and why (your colour, a rule, your pet),
* every bar found, with the addon it comes from, and whether it is hidden right now,
* how long one repaint of every bar takes on your machine.

If your health bar is missing from the list, your unit frame addon is not one of the above, or it builds its frames in a way the addon does not know yet. Paste the lines from `/ahui check` into a bug report on GitHub or CurseForge, with the name and version of your unit frame addon.
