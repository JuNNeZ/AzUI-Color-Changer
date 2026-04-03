# Animations

AzUI Healthbar Color Changer supports two independent animation effects: **Rainbow** and **Pulse**. Both are controlled from the options panel (`/ahui`).

---

## Rainbow Effect

The rainbow effect continuously changes your health bar color using one of three patterns. A single **toggle button** starts and stops the animation; its label changes to reflect the current state:

- **Rainbow Effect** — animation is currently **off**; click to start.
- **Stop Rainbow Effect** — animation is currently **on**; click to stop.

When stopped, your health bar reverts to the color stored in the color picker.

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
Picks a completely random RGB triplet every 0.1 s. There is no pattern — colors jump unpredictably on every tick.

Best for: maximum visual noise / a fun "disco" style.

---

## Pulse Effect

The pulse effect gently oscillates your health bar's **brightness** between 30% and 100% using a sine wave, while keeping the same hue and saturation as your chosen color.

```
brightness = 0.3 + 0.7 × |sin(t)|
```

The toggle button works the same way as the rainbow button:

- **Pulse Colour** — pulse is **off**; click to start.
- **Stop Pulse** — pulse is **on**; click to stop.

When stopped, the health bar reverts to the exact color that was active when you started the pulse.

> **Note:** Rainbow and Pulse cannot run at the same time. Starting one will not automatically stop the other, but their shared speed slider means they would conflict visually. Use one at a time for best results.

---

## Speed Slider

The **Rainbow Speed (Hz)** slider (range **0.1 Hz – 5 Hz**) controls the animation speed for **both** the rainbow and pulse effects.

| Setting | Feel |
|---------|------|
| 0.1 Hz | Very slow, almost imperceptible drift |
| 0.5 Hz | Leisurely cycling (~2 s per full loop) |
| 1.0 Hz | Default moderate pace |
| 2.0 Hz | Fast, energetic animation |
| 5.0 Hz | Near-maximum flicker speed |

The speed can be changed while an animation is running; the effect updates immediately.

---

## Behavior Notes

- Both animations **continue in combat** without restriction.
- Rainbow state (`rainbowActive`, `rainbowMode`, `rainbowSpeed`) is saved to your SavedVariables and **automatically restarted** when you log in or reload the UI.
- Pulse state (`pulseActive`) is also persisted and restarted on login.
- Clicking any **class color button** or the **Random Colour** button stops the active animation and applies the selected color.
- Loading a **preset** stops the active animation and applies the preset color.
- When **hunter pet auto-coloring** is active and a pet is dismissed, any rainbow or pulse that was running before the pet was summoned is fully restored.

---

## Tips

- Use **Cycle** at low speed (0.2–0.5 Hz) for a subtle, atmospheric glow effect.
- Use **Ping-Pong** at medium speed (1–2 Hz) for a distinctly different feel from Cycle.
- Use **Chaos** sparingly — at high speeds it can be distracting during gameplay.
- **Pulse** pairs well with a vibrant class color for a "heartbeat" effect.
- Set speed to **5 Hz + Chaos** for a strobing effect (not recommended for extended play).
