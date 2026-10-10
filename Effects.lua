-- Effects.lua - every effect is a small function of time applied to a colour just
-- before it is painted. They all follow the Animation Speed slider, and Reduce
-- Motion shows each as its static colour.
local _, ns = ...
local P = ns.P
local L = P.L

local PI, TWO_PI = math.pi, 2 * math.pi
local sin, cos, abs, floor, min, max, random = math.sin, math.cos, math.abs, math.floor, math.min, math.max, math.random

local PHASE_RATE       = 0.3  -- radians per second at speed 1.0 (one rainbow cycle ~21 s)
local CHAOS_INTERVAL   = 0.1  -- Chaos picks a new colour this often
local FLICKER_INTERVAL = 0.08 -- Flicker picks a new brightness this often

-- Shown in this order wherever an effect is picked.
P.EFFECTS = { "static", "pulse", "breathe", "heartbeat", "twotone", "flicker", "sweep", "rainbow" }
P.EFFECT_VALUES = {
  static    = L["None"],
  pulse     = L["Pulse"],
  breathe   = L["Breathe"],
  heartbeat = L["Heartbeat"],
  twotone   = L["Two-tone"],
  flicker   = L["Flicker"],
  sweep     = L["Sweep"],
  rainbow   = L["Rainbow"],
}
P.EFFECT_HELP = {
  static    = L["Your colour, as it is."],
  pulse     = L["Brightness dips to 30% and comes back."],
  breathe   = L["A slow, soft rise and fall; calmer than pulse."],
  heartbeat = L["Two quick beats and a rest."],
  twotone   = L["Blends between your colour and a second colour."],
  flicker   = L["Uneven, candle-like brightness."],
  sweep     = L["The bar dims and a bright band crosses it, left to right."],
  rainbow   = L["Cycles through every colour; ignores your colour but keeps its alpha."],
}

-- Flicker is uneven flashing, so picking it asks first.
function P.EffectConfirm(value)
  if value == "flicker" then
    return L["Flicker changes brightness quickly and unevenly. Turn it on?"]
  end
end

function P.IsEffect(value)
  return type(value) == "string" and P.EFFECT_VALUES[value] ~= nil
end

-- Animation state, shared by every bar so they stay in step.
local phase = 0
local chaos = { random(), random(), random() }
local flicker = 1
local chaosElapsed, flickerElapsed = 0, 0

function P.ResetPhase()
  phase, chaosElapsed, flickerElapsed = 0, 0, 0
end

function P.AdvanceEffects(elapsed)
  local speed = min(5, max(0.1, tonumber(P.DB.profile.rainbowSpeed) or 1))
  phase = phase + elapsed * speed * PHASE_RATE
  chaosElapsed = chaosElapsed + elapsed
  if chaosElapsed >= CHAOS_INTERVAL then
    chaosElapsed = 0
    chaos[1], chaos[2], chaos[3] = random(), random(), random()
  end
  flickerElapsed = flickerElapsed + elapsed
  if flickerElapsed >= FLICKER_INTERVAL / speed then
    flickerElapsed = 0
    -- mostly bright with the odd dip, like a candle
    flicker = 0.65 + 0.35 * random() ^ 0.5
  end
end

-- For tests and previews.
function P.SetPhase(value) phase = value end

-- 0-1 hue to RGB for the Ping-Pong pattern
local function HueToRGB(h)
  local i = floor(h * 6)
  local f = h * 6 - i
  local q = 1 - f
  i = i % 6
  if     i == 0 then return 1, f, 0
  elseif i == 1 then return q, 1, 0
  elseif i == 2 then return 0, 1, f
  elseif i == 3 then return 0, q, 1
  elseif i == 4 then return f, 0, 1
  else               return 1, 0, q end
end

-- Two beats a cycle: a sharp one, a softer echo, then rest. 0..1.
local function Heartbeat()
  local t = (phase * 7 / PI) % 1 -- one cycle about every 1.5 s at speed 1.0
  if t < 0.08 then return t / 0.08 end
  if t < 0.18 then return 1 - (t - 0.08) / 0.10 end
  if t < 0.26 then return 0.7 * (t - 0.18) / 0.08 end
  if t < 0.38 then return 0.7 * (1 - (t - 0.26) / 0.12) end
  return 0
end

-- Sweep, measured off the Feature Plan's preview: the bar sits at 61% of your colour
-- (#6E0F0F against #B31B1B) and a soft band crosses it left to right every 2.4 s. The
-- band's peak is your colour with 0.24 added to each channel, which turns #B31B1B into
-- #F05858, next to the preview's #F0604F.
local SWEEP_BASE, SWEEP_LIFT, SWEEP_PERIOD = 0.615, 0.24, 2.4

-- A colour with an effect applied: r, g, b, a. Sweep adds where its band is (0..1, the
-- band's way across the bar) and the band's colour; the painter draws the band.
function P.EffectColour(effect, c, second)
  c = c or P.DB.profile.color
  local a = c[4] or 1
  if P.DB.profile.reduceMotion then effect = "static" end
  if effect == "rainbow" then
    local mode = P.DB.profile.rainbowMode
    if mode == "chaos" then
      return chaos[1], chaos[2], chaos[3], a
    elseif mode == "ping" then
      -- sweep hue 0 -> 1 -> 0
      local x = phase % TWO_PI
      if x > PI then x = TWO_PI - x end
      local r, g, b = HueToRGB(x / PI)
      return r, g, b, a
    end
    return 0.5 + 0.5 * sin(phase),
           0.5 + 0.5 * sin(phase + TWO_PI / 3),
           0.5 + 0.5 * sin(phase + 2 * TWO_PI / 3), a
  elseif effect == "pulse" then
    local s = 0.3 + 0.7 * abs(sin(phase))
    return c[1] * s, c[2] * s, c[3] * s, a
  elseif effect == "breathe" then
    -- slower than pulse (about 14 s at speed 1.0), eased at both ends
    local s = 0.5 + 0.25 * (1 - cos(phase * 1.5))
    return c[1] * s, c[2] * s, c[3] * s, a
  elseif effect == "heartbeat" then
    -- each beat lifts the colour towards white
    local k = 0.55 * Heartbeat()
    return c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k, a
  elseif effect == "twotone" then
    local o = second or P.DB.profile.secondColor
    local k = 0.5 - 0.5 * cos(phase * 1.5)
    return c[1] + (o[1] - c[1]) * k, c[2] + (o[2] - c[2]) * k, c[3] + (o[3] - c[3]) * k, a
  elseif effect == "flicker" then
    return c[1] * flicker, c[2] * flicker, c[3] * flicker, a
  elseif effect == "sweep" then
    local at = (phase / PHASE_RATE / SWEEP_PERIOD) % 1
    local function Peak(v) return min(1, v + SWEEP_LIFT) end
    return c[1] * SWEEP_BASE, c[2] * SWEEP_BASE, c[3] * SWEEP_BASE, a, at, Peak(c[1]), Peak(c[2]), Peak(c[3])
  end
  return c[1], c[2], c[3], a
end

-- An effect at a phase of your own, for previews that animate whether or not the
-- bars do (the Studio's effect cards).
function P.EffectColourAt(at, effect, c, second)
  local saved = phase
  phase = at
  local r, g, b, a, x, pr, pg, pb = P.EffectColour(effect, c, second)
  phase = saved
  return r, g, b, a, x, pr, pg, pb
end

-- Your own effect. Picking one shows it on your health bar now; a pet colour there
-- comes back when the pet changes.
function P.SetEffect(effect)
  if not P.IsEffect(effect) then return false end
  P.DB.profile.effect = effect
  P.ResetPhase()
  if effect ~= "static" then P.petSuppressed = true end
  P.UpdateAnimator()
  P.Repaint()
  P.RefreshOptions()
  return true
end

function P.ToggleEffect(effect)
  return P.SetEffect(P.DB.profile.effect == effect and "static" or effect)
end
