# Animations

ABCS – Advanced Bar Coloring System supports two animation effects: **Rainbow** and **Pulse**. Both are controlled from the options panel (`/ahui`).

---

## Rainbow Effect

The rainbow effect continuously changes your health bar color using one of three patterns. A single **toggle button** starts and stops the animation; its label changes to reflect the current state:

- **Rainbow Effect** — animation is currently **off**; click to start.
- **Stop Rainbow Effect** — animation is currently **on**; click to stop.

When stopped, your health bar shows the color from the color picker again. The rainbow never changes that saved color.

### Rainbow Patterns

Choose a pattern from the **Rainbow Pattern** dropdown before (or while) the animation is running.

#### Cycle *(default)*
A smooth, continuous sine-wave that cycles through red, green, and blue simultaneously, each 120° out of phase with the others. The result is a classic, seamless rainbow loop.

```
R = 0.5 + 0.5 × sin(t)
G = 0.5 + 0.5 × sin(t + 2π/3)
B = 0.5 + 0.5 × sin(t + 4π/3)
```

Best for: a pleasant, eye-friendly ambient animation.

#### Ping-Pong
Sweeps the HSV hue from 0 → 1, then back from 1 → 0, creating a forward-and-back alternation. Colors are more saturated and the transitions are sharper than Cycle mode.

Best for: high-contrast color changes that are still smooth.

#### Chaos
Picks a completely random RGB triplet every 0.1 s, regardless of the speed slider. There is no pattern — colors jump unpredictably.

Best for: maximum visual noise / a fun "disco" style.

---

## Pulse Effect

The pulse effect gently oscillates your health bar's **brightness** between 30% and 100% using a sine wave, while keeping the same hue and saturation as your chosen color. It starts at 30%.

```
brightness = 0.3 + 0.7 × |sin(t)|
```

The toggle button works the same way as the rainbow button:

- **Pulse Colour** — pulse is **off**; click to start.
- **Stop Pulse** — pulse is **on**; click to stop.

When stopped, the health bar shows your chosen color at full brightness. The pulse never changes the saved color, even if you log out or `/reload` while it runs.

> **Note:** Rainbow and Pulse never run at the same time. Starting one automatically stops the other.

---

## Speed Slider

The **Animation Speed** slider (range **0.1 – 5**) is a speed multiplier for **both** the rainbow and pulse effects. `t` in the formulas above advances by 0.3 × speed per second.

| Setting | Rainbow cycle / Ping-Pong round trip | One pulse |
|---------|--------------------------------------|-----------|
| 0.1 | ~3.5 min | ~105 s |
| 0.5 | ~42 s | ~21 s |
| 1.0 *(default)* | ~21 s | ~10.5 s |
| 2.0 | ~10.5 s | ~5 s |
| 5.0 | ~4 s | ~2 s |

The speed can be changed while an animation is running; the effect speeds up or slows down smoothly without jumping.

---

## More Effects

| Effect | What it does |
|--------|--------------|
| **Breathe** | A slow, soft rise and fall, about 14 seconds at speed 1.0; calmer than Pulse. |
| **Heartbeat** | Two quick beats and a rest, about every 1.5 seconds; each beat lifts the color towards white. |
| **Two-tone** | Blends between your color and the **Second Colour**. |
| **Flicker** | Uneven, candle-like brightness. Asks before it starts, because of the flashing. |
| **Sweep** | The bar dims to about 60% and a bright band of your colour crosses it, left to right, every 2.4 seconds. |

**Reduce Motion** shows every effect as its static color. **Smooth Fades** blend into a new color when a pet is called, a preset loads or a rule starts.

## Behavior Notes

- Animations update 30 times per second by default (15, 30 or 60 under **Update Rate**) and **continue in combat** without restriction.
- Your effect, pattern and speed are saved and **automatically restarted** when you log in or reload the UI.
- Picking a color stops **Rainbow**, which ignores your color; other effects keep running on the new color.
- When a hunter pet color is shown on your health bar, your animation pauses there and resumes when the pet is dismissed. Pets can have their own pulse or rainbow — see [Hunter Pet Coloring](Hunter-Pet-Coloring).

---

## Tips

- Use **Cycle** at low speed (0.2–0.5) for a subtle, atmospheric glow effect.
- Use **Ping-Pong** at medium speed (1–2) for a distinctly different feel from Cycle.
- Use **Chaos** sparingly — it can be distracting during gameplay.
- **Pulse** pairs well with a vibrant class color for a "heartbeat" effect.
