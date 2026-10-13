# Rules Cookbook

Rules show a colour and effect while something is true. Each recipe below says what to set on the **Rules** page of the ABCS window (`/ahui`, then Rules). Many are also in the **Add a ready-made rule…** list at the top of that page; they are added switched off, so press **Try** on the row to see the rule on your bars for five seconds, then switch it on.

The first rule that matches wins for each bar, so put the rules you care about most at the top (drag a row by its handle).

## Reminders

| Rule | When | Show | On |
|------|------|------|----|
| **Call your pet** | Pet: Not out | orange, Heartbeat | Health bar |
| **You are dead** | Dead or a ghost | grey, None | Health bar and pet frame |
| **Out of a group** | **When not** Group: In any group | soft blue, Breathe | Health bar |

Click **When** on a row to turn it into **When not**.

## Threat and casting

| Rule | When | Show | On |
|------|------|------|----|
| **About to pull aggro** | Threat: About to pull aggro **and not** Role: Tank | orange, Heartbeat, raid warning sound | Health bar |
| **A tank losing aggro** | Threat: Losing aggro **and** Role: Tank | red, Pulse, alarm sound | Health bar |
| **I have aggro** | Threat: I have aggro | your pick, None | Health bar |
| **Casting** | Casting: Casting or channelling | gold, Sweep | Health bar |

The first two are in the ready-made list. Midnight hides threat and casting from addons in some content; a rule on them then waits rather than guess.

## Sounds

The speaker on a rule's row picks a sound the rule plays when it starts showing: raid warning, ready check, alarm clock, boss whisper, whisper, friend online or quest complete. It plays on the Master channel, so you hear it with sound effects off. Picking a sound plays it once, and **Try** plays it too.

## Group content

| Rule | When | Show | On |
|------|------|------|----|
| **Healing a raid** | Role: Healer **and** Group: In a raid | green, None | Health bar |
| **Tanking** | Role: Tank **and** In combat | deep red, Pulse | Health bar |
| **Mythic+** | In a Mythic+ run | teal, None | Health bar |
| **Big raid** | Group: In a raid of 20 or more | gold, None | Every bar |
| **Delves** | In a delve | amber, Breathe | Health bar |

Press **+** on a row to add the second condition ("and").

## Buffs

| Rule | When | Show | On |
|------|------|------|----|
| **Bloodlust and the like** | Buff or debuff: `2825, 32182, 80353, 264667, 390386` | red, Pulse | Health bar |
| **A proc you watch** | Buff or debuff: its name or spell ID | your pick, Sweep | Power bar |

Several spells, separated by commas, match when any one of them is on you. While the game hides aura data from addons, as in some combat, a buff rule waits.

## Low health

Health is hidden from addons in Midnight, so a rule cannot say "below 35%". Instead:

* **Colour by Health** on the Health Bar page runs your own colour down to the low-health colour.
* A rule with the effect **By health** does the same from the rule's colour, so a raid rule can keep a health gradient of its own.

## Just for looks

| Rule | When | Show | On |
|------|------|------|----|
| **Night** | Time of day: Night (21 to 5) | moonlit blue, Breathe | Health bar and pet frame |
| **Flying** | Flying | sky blue, Flow | Health bar |
| **Resting** | Resting | calm green, Breathe | Health bar and pet frame |
| **War Mode** | War Mode | crimson, None | Health bar |

## Sharing a rule

On the **Share** page, tick only **Rules**, press **Make Share String** and paste the `!AZUI1!` line in Discord or a guide. Importing it replaces the rule list of the profile it goes into, after showing what changes.

In the game, **Share in Chat** does it without copying: it puts `[ABCS: name]` in your chat box, and anyone with the addon who clicks it gets the parts you ticked in their import preview.
