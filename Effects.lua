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
P.EFFECTS = { "static", "gradient", "flow", "pulse", "breathe", "heartbeat", "twotone", "flicker", "sweep",
  "rainbow", "rainbowgradient" }
P.EFFECT_VALUES = {
  static    = L["None"],
  gradient  = L["Gradient"],
  flow      = L["Flow"],
  rainbowgradient = L["Spectrum"],
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
  gradient  = L["Runs from your colour at one end of the bar to the second colour at the other. It does not move."],
  flow      = L["Your colour and the second colour slowly trade ends along the bar."],
  rainbowgradient = L["Every colour along the bar at once, drifting slowly."],
  pulse     = L["Brightness dips to 30% and comes back."],
  breathe   = L["A slow, soft rise and fall; calmer than pulse."],
  heartbeat = L["Two quick beats and a rest."],
  twotone   = L["Blends between your colour and a second colour."],
  flicker   = L["Uneven, candle-like brightness."],
  sweep     = L["The bar dims and a bright band crosses it, left to right."],
  rainbow   = L["Cycles through every colour; ignores your colour but keeps its alpha."],
}

-- Rules can also be coloured by your health: from the rule's colour down to the
-- low-health colour. It is not an effect of its own, so it is only offered on rules.
P.RULE_EFFECTS = {}
P.RULE_EFFECT_VALUES = { health = L["By health"] }
for _, key in ipairs(P.EFFECTS) do
  P.RULE_EFFECTS[#P.RULE_EFFECTS + 1] = key
  P.RULE_EFFECT_VALUES[key] = P.EFFECT_VALUES[key]
end
P.RULE_EFFECTS[#P.RULE_EFFECTS + 1] = "health"

function P.IsRuleEffect(value)
  return value == "health" or P.IsEffect(value)
end

-- Flicker is uneven flashing, so picking it asks first.
function P.EffectConfirm(value)
  if value == "flicker" then
    return L["Flicker changes brightness quickly and unevenly. Turn it on?"]
  end
end

function P.IsEffect(value)
  return type(value) == "string" and P.EFFECT_VALUES[value] ~= nil
end

-- Does it move? None, Gradient and a colour by health are drawn once and need no repaints.
function P.IsAnimated(effect)
  return effect ~= nil and effect ~= "static" and effect ~= "gradient" and effect ~= "health"
end

-- Effects that use the second colour (Two-tone's other colour, the gradients' far end).
function P.UsesSecondColour(effect)
  return effect == "twotone" or effect == "gradient" or effect == "flow"
end

-- How dark Pulse gets (its lowest brightness) and how long Sweep's band takes.
local function PulseLow() return math.min(0.9, math.max(0.05, tonumber(P.DB.profile.pulseDepth) or 0.3)) end
local function SweepPeriod() return math.min(8, math.max(0.8, tonumber(P.DB.profile.sweepPeriod) or 2.4)) end

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
local SWEEP_BASE, SWEEP_LIFT = 0.615, 0.24
local function Peak(v) return min(1, v + SWEEP_LIFT) end

-- A colour with an effect applied: r, g, b, a. Sweep adds where its band is (0..1, the
-- band's way across the bar) and the band's colour; the painter draws the band.
-- Gradient adds no band (nil) but the colour at the bar's far end.
function P.EffectColour(effect, c, second)
  c = c or P.DB.profile.color
  local a = c[4] or 1
  if effect == "gradient" then
    -- it does not move, so Reduce Motion leaves it alone
    local o = second or P.DB.profile.secondColor
    return c[1], c[2], c[3], a, nil, o[1], o[2], o[3]
  end
  if P.DB.profile.reduceMotion then
    -- the moving gradients hold still as Gradient
    if effect == "flow" then return P.EffectColour("gradient", c, second) end
    effect = "static"
  end
  if effect == "flow" then
    -- the two ends trade colours and back, about every 14 s at speed 1.0
    local o = second or P.DB.profile.secondColor
    local k = 0.5 - 0.5 * cos(phase * 1.5)
    local r1, g1, b1 = c[1] + (o[1] - c[1]) * k, c[2] + (o[2] - c[2]) * k, c[3] + (o[3] - c[3]) * k
    local r2, g2, b2 = o[1] + (c[1] - o[1]) * k, o[2] + (c[2] - o[2]) * k, o[3] + (c[3] - o[3]) * k
    return r1, g1, b1, a, nil, r2, g2, b2
  elseif effect == "rainbowgradient" then
    -- a third of the spectrum apart, drifting with the phase
    local h = (phase / TWO_PI) % 1
    local r1, g1, b1 = HueToRGB(h)
    local r2, g2, b2 = HueToRGB((h + 1 / 3) % 1)
    return r1, g1, b1, a, nil, r2, g2, b2
  end
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
    local low = PulseLow()
    local s = low + (1 - low) * abs(sin(phase))
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
    local at = (phase / PHASE_RATE / SweepPeriod()) % 1
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
