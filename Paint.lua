-- Paint.lua - the channels bars belong to, the mixer that picks each channel's colour,
-- fades, and the painter that puts it on screen. Frames.lua finds the bars.
--
-- Channels: "player" (your health bar), "pet" (the pet frames), "power", "cast" and
-- "classpower" (your power bar, cast bar and class resources, while switched on or taken
-- by a rule) and "absorb" (the heal and absorb overlays, while switched on). For each channel the mixer takes, in order: the
-- first matching rule, the pet's colour, your health (if Colour by Health is on, your
-- health bar only), and finally your own colour and effect.
local _, ns = ...
local P = ns.P
local L = P.L

local min, max = math.min, math.max
local pairs, pcall, type = pairs, pcall, type

local FADE_TIME     = 0.3 -- seconds to blend into a new colour

-- Which bars exist is Frames.lua's business; it hands them over with P.Painter.addTarget.
local targets       = setmetatable({}, { __mode = "k" }) -- bar -> brightness factor
local channels      = setmetatable({}, { __mode = "k" }) -- bar -> "player" | "pet" | "power" | "cast" | "classpower" | "absorb"
local blizzardBars  = setmetatable({}, { __mode = "k" }) -- bar -> how to hand it back to Blizzard
local optionalBars  = setmetatable({}, { __mode = "k" }) -- bar -> the setting that can take it away (Frames.lua)
local textureOwners = setmetatable({}, { __mode = "k" }) -- bar texture -> bar
local labels        = setmetatable({}, { __mode = "k" }) -- bar -> where it comes from, for /ahui check
local previews      = setmetatable({}, { __mode = "k" }) -- the addon's own preview bars
local ownerColour   = setmetatable({}, { __mode = "k" }) -- overlay -> { r, g, b, a } its owner gave it
local hooked        = setmetatable({}, { __mode = "k" })
local painting      = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------
-- COLOUR BY HEALTH
---------------------------------------------------------------------
-- Midnight keeps health secret from addons, so no Lua maths on it. A colour curve
-- runs inside the game instead: UnitHealthPercent evaluates it and hands back a
-- colour the bar can take as it is (SetStatusBarColor accepts secret values). The
-- preview bar's 90% is baked into a curve of its own, as nothing may be multiplied.
-- A curve runs from the low-health colour to a full-health colour: yours, or a rule's
-- when the rule is coloured by health. Curves are kept per full-health colour and factor.
local curves = setmetatable({}, { __mode = "k" }) -- colour -> { [factor] = curve }
local healthHigh = {}                              -- channel -> its full-health colour this repaint

function P.HealthColourAvailable()
  return C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent and CreateColor and true or false
end

function P.HealthColourOn()
  return P.DB.profile.healthColour and P.HealthColourAvailable()
end

function P.ResetHealthCurves()
  for key in pairs(curves) do curves[key] = nil end
end

local function HealthCurve(factor, high)
  local byFactor = curves[high]
  if not byFactor then byFactor = {}; curves[high] = byFactor end
  local curve = byFactor[factor]
  if curve then return curve end
  local low = P.DB.profile.lowHealthColour
  curve = C_CurveUtil.CreateColorCurve()
  curve:AddPoint(0, CreateColor(low[1] * factor, low[2] * factor, low[3] * factor, low[4] or 1))
  curve:AddPoint(1, CreateColor(high[1] * factor, high[2] * factor, high[3] * factor, high[4] or 1))
  byFactor[factor] = curve
  return curve
end

local function UnpackColour(colour) return colour:GetRGBA() end

-- The colour for your health right now, untouched, or nothing if the game would not say.
local function HealthColour(factor, high)
  local ok, colour = pcall(UnitHealthPercent, "player", true, HealthCurve(factor, high))
  if not ok or colour == nil then return end
  local unpacked, r, g, b, a = pcall(UnpackColour, colour)
  if unpacked then return r, g, b, a end
end

---------------------------------------------------------------------
-- THE MIXER
---------------------------------------------------------------------
-- Does the pet colour belong on this channel right now?
local function ShowsPetColour(channel)
  if not P.activePet or (channel == "player" and P.petSuppressed) then return false end
  local target = P.DB.profile.petTarget
  return target == "both" or target == channel
end

-- A rule's colour and effect. A rule coloured by health ("By health") runs from its
-- colour down to the low-health colour, on every bar but the pet frame (whose health
-- is not yours); there it shows its colour as it is.
local function FromRule(rule, channel)
  if rule.effect == "health" then
    if channel ~= "pet" and P.HealthColourAvailable() then return rule.color, "static", "health" end
    return rule.color, "static", "rule"
  end
  return rule.color, rule.effect, "rule", rule.color2
end

-- Where a channel's colour comes from: colour, effect, which source it is ("rule",
-- "pet", "health", "power", "cast", "classpower" or "own") and the source's own second
-- colour (nil: the shared one from the Health Bar page). For "health" the
-- colour is the full-health end (a rule's), or nil for your own colour.
-- The power and cast bars and the class resources take a rule of their own first, then
-- their own colour, and otherwise follow your health bar. The heal and absorb overlays
-- take a shade of it.
local OWN_SETTING = { power = "power", cast = "cast", classpower = "classPower" }

function P.ChannelSource(channel)
  local p = P.DB.profile
  if channel == "absorb" then channel = "player" end
  local setting = OWN_SETTING[channel]
  if setting then
    local rule = P.ActiveRule(channel)
    if rule then return FromRule(rule, channel) end
    local own = p[setting]
    if own.mode == "custom" then return own.color, own.effect, channel, own.color2 end
    channel = "player" -- Match health bar (or off, while only a rule takes the bar)
  end
  local rule = P.ActiveRule(channel)
  if rule then return FromRule(rule, channel) end
  if ShowsPetColour(channel) then return P.activePet.color, P.activePet.effect, "pet", P.activePet.color2 end
  -- Colour by Health cannot carry an effect (the game works the colour out), so an
  -- effect you pick shows instead; None brings colouring by health back.
  if channel == "player" and P.HealthColourOn() and (p.effect or "static") == "static" then
    return nil, "static", "health"
  end
  return p.color, p.effect, "own"
end

function P.ChannelEffect(channel)
  local _, effect = P.ChannelSource(channel)
  return effect or "static"
end

---------------------------------------------------------------------
-- FADES
---------------------------------------------------------------------
-- When a colour's source changes (a pet is called, a preset loads, a rule starts),
-- each channel blends from what it last showed to the new colour.
local lastShown = { player = {}, pet = {}, power = {}, cast = {}, classpower = {}, absorb = {} }
local fadeFrom, fadeStart = {}, nil

function P.StartFade()
  local p = P.DB and P.DB.profile
  if not p or not p.fade or p.reduceMotion then return end
  for channel, c in pairs(lastShown) do
    fadeFrom[channel] = c[1] and { c[1], c[2], c[3], c[4] } or nil
  end
  fadeStart = GetTime()
  P.UpdateAnimator()
end

local function FadeProgress()
  if not fadeStart then return end
  local k = (GetTime() - fadeStart) / FADE_TIME
  if k >= 1 then
    fadeStart = nil
    return
  end
  return k
end

function P.IsFading() return fadeStart ~= nil end

-- The colour a channel shows this frame: r, g, b, a and, for Sweep, where its band
-- is and the band's colour. Nothing when it is drawn from your health.
-- How far the heal and absorb overlays are lifted towards white, so they stand out
-- from the health bar under them.
local OVERLAY_LIFT = 0.45

function P.ChannelColour(channel, fade)
  local colour, effect, kind, second = P.ChannelSource(channel)
  local last = lastShown[channel]
  if channel == "absorb" then
    -- your health bar's colour and effect, lifted; no band and no gradient on a thin overlay
    if kind == "health" then colour, effect = colour or P.DB.profile.color, "static" end
    local r, g, b, a = P.EffectColour(effect, colour, second)
    return r + (1 - r) * OVERLAY_LIFT, g + (1 - g) * OVERLAY_LIFT, b + (1 - b) * OVERLAY_LIFT, a
  end
  if kind == "health" then
    last[1] = nil
    healthHigh[channel] = colour
    return
  end
  local r, g, b, a, at, pr, pg, pb = P.EffectColour(effect, colour, second)
  local from = fadeFrom[channel]
  if fade and from then
    r, g, b, a = from[1] + (r - from[1]) * fade, from[2] + (g - from[2]) * fade,
                 from[3] + (b - from[3]) * fade, from[4] + (a - from[4]) * fade
  end
  last[1], last[2], last[3], last[4] = r, g, b, a
  return r, g, b, a, at, pr, pg, pb
end

---------------------------------------------------------------------
-- PAINTING & HOOKS
---------------------------------------------------------------------
-- Sweep's band: a soft-edged strip that crosses the bar. Two halves, each fading in
-- from nothing, make the soft edges; each is 37.5% of the bar, as in the plan.
--
-- The band takes the shape of the bar it crosses. It sits on a frame clipped to the
-- visible fill, and a mask made from the fill's own texture (the same file and the
-- same texture coordinates the bar is showing) cuts it to that texture's alpha: the
-- angled ends and casing of AzeriteUI's health bar, the facets of its power crystal.
-- AzeriteUI describes those shapes with a spark map; the texture is the exact source
-- of it. A horizontal bar is crossed left to right, a vertical one (the crystal)
-- bottom to top. A bar with no fill texture to follow (AzeriteUI's mana orb) shimmers
-- as the band passes instead.
local SWEEP_EDGE = 0.375
local WHITE = "Interface\\Buttons\\WHITE8X8"
local bands = setmetatable({}, { __mode = "k" })

-- The fill you see: JuNNeZ Edition draws its power crystal with a FakeFill of its own.
local function VisibleFill(bar)
  local fake = bar.FakeFill
  if type(fake) == "table" and type(fake.GetTexture) == "function" and (not fake.IsShown or fake:IsShown()) then
    return fake
  end
  return type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture() or nil
end

local function IsVertical(bar)
  if bar.GetOrientation and bar:GetOrientation() == "VERTICAL" then return true end
  local w, h = bar:GetWidth() or 0, bar:GetHeight() or 0
  return h > w
end

local function Band(bar, fill)
  local band = bands[bar]
  if band and band.fill == fill then return band end
  if not band then
    band = CreateFrame("Frame", nil, bar)
    band:SetClipsChildren(true)
    band:EnableMouse(false)
    band.left = band:CreateTexture(nil, "ARTWORK")
    band.right = band:CreateTexture(nil, "ARTWORK")
    band.left:SetTexture(WHITE)
    band.right:SetTexture(WHITE)
    -- light added on top: the fill's own texture (the crystal's facets, the bar's
    -- grain) shows through instead of being painted over
    band.left:SetBlendMode("ADD")
    band.right:SetBlendMode("ADD")
    if band.CreateMaskTexture then
      band.mask = band:CreateMaskTexture()
      band.left:AddMaskTexture(band.mask)
      band.right:AddMaskTexture(band.mask)
    end
    bands[bar] = band
  end
  band.fill, band.maskFile = fill, nil
  band:ClearAllPoints()
  band:SetAllPoints(fill)
  band:SetFrameLevel(bar:GetFrameLevel() + 1)
  if band.mask then
    band.mask:ClearAllPoints()
    band.mask:SetAllPoints(fill)
  end
  return band
end

-- The mask copies what the fill shows right now; a status bar changes its texture
-- coordinates as it empties, so they are read on every paint.
local function ShapeMask(band, fill)
  local mask = band.mask
  if not mask then return end
  local atlas = fill.GetAtlas and fill:GetAtlas()
  local file = (atlas and atlas ~= "") and ("atlas:" .. atlas) or (fill.GetTexture and fill:GetTexture())
  if file and file ~= band.maskFile then
    if atlas and atlas ~= "" then
      mask:SetAtlas(atlas)
    else
      mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    band.maskFile = file
  end
  if fill.GetTexCoord then mask:SetTexCoord(fill:GetTexCoord()) end
end

local function HideBand(bar)
  if bands[bar] then bands[bar]:Hide() end
end

-- The band's sides and length only change with the bar's shape, so they are set again
-- only then; each paint just moves the band along.
local function LayoutBand(band, bar, vertical, edge)
  if band.vertical == vertical and band.edge == edge then return end
  band.vertical, band.edge = vertical, edge
  local left, right = band.left, band.right
  left:ClearAllPoints()
  right:ClearAllPoints()
  if vertical then
    -- bottom to top: "left" is the lower half, "right" the upper
    left:SetPoint("LEFT", bar, "LEFT");   left:SetPoint("RIGHT", bar, "RIGHT");   left:SetHeight(edge)
    right:SetPoint("LEFT", bar, "LEFT");  right:SetPoint("RIGHT", bar, "RIGHT");  right:SetHeight(edge)
  else
    left:SetPoint("TOP", bar, "TOP");     left:SetPoint("BOTTOM", bar, "BOTTOM"); left:SetWidth(edge)
    right:SetPoint("TOP", bar, "TOP");    right:SetPoint("BOTTOM", bar, "BOTTOM"); right:SetWidth(edge)
  end
end

-- Draws the band; false when the bar has nothing to draw it on.
local function ShowBand(bar, fill, at, r, g, b, a)
  if not (fill and CreateColor) then return false end
  local band = Band(bar, fill)
  ShapeMask(band, fill)
  local vertical = IsVertical(bar)
  local length = (vertical and bar:GetHeight() or bar:GetWidth()) or 0
  if length <= 0 then band:Hide(); return true end
  local edge = length * SWEEP_EDGE
  -- the centre runs from one edge-length before the start to one past the end
  local centre = -edge + at * (length + 2 * edge)
  -- softer on a vertical bar such as the crystal, where the band covers more of it
  local strength = min(1, max(0.1, tonumber(P.DB.profile.sweepStrength) or 0.6)) * (vertical and 0.6 or 1)
  -- one pair of colours per band, refilled on every paint (SetGradient copies them)
  local low, high = band.low, band.high
  if not low then
    low, high = CreateColor(r, g, b, 0), CreateColor(r, g, b, 1)
    band.low, band.high = low, high
  end
  low.r, low.g, low.b, low.a = r, g, b, 0
  high.r, high.g, high.b, high.a = r, g, b, (a or 1) * strength
  LayoutBand(band, bar, vertical, edge)
  if vertical then
    band.left:SetPoint("BOTTOM", bar, "BOTTOM", 0, centre - edge)
    band.right:SetPoint("BOTTOM", bar, "BOTTOM", 0, centre)
    band.left:SetGradient("VERTICAL", low, high)
    band.right:SetGradient("VERTICAL", high, low)
  else
    band.left:SetPoint("LEFT", bar, "LEFT", centre - edge, 0)
    band.right:SetPoint("LEFT", bar, "LEFT", centre, 0)
    band.left:SetGradient("HORIZONTAL", low, high)
    band.right:SetGradient("HORIZONTAL", high, low)
  end
  band:Show()
  return true
end

-- How far the band's colour reaches into a bar it cannot be drawn on, 0..1.
local function Shimmer(at)
  local centre = -SWEEP_EDGE + at * (1 + 2 * SWEEP_EDGE) -- where the band would be, 0..1 across
  return max(0, 1 - math.abs(centre - 0.5) / SWEEP_EDGE)
end

-- AzeriteUI turns your cast bar red for a cast that cannot be interrupted, and for one
-- that failed or was interrupted. Those colours are information, so they are left alone,
-- as is an idle bar (Shadowed Unit Frames keeps its idle cast bar see-through).
local function CastSaysSomething(bar)
  if channels[bar] ~= "cast" then return false end
  if bar.notInterruptible then return true end
  return not (bar.casting or bar.channeling or bar.empowering or bar.spellName) -- spellName: Shadowed Unit Frames
end

-- The texture that shows a bar's colour: a status bar's fill, PitBull 4's foreground,
-- or the bar itself when it is a plain texture (AzeriteUI's heal prediction).
local function FillTexture(bar)
  if type(bar.GetStatusBarTexture) == "function" then return bar:GetStatusBarTexture() end
  if type(bar.fg) == "table" and type(bar.fg.SetVertexColor) == "function" then return bar.fg end
  if type(bar.SetVertexColor) == "function" then return bar end
end

-- Gradient's two ends, refilled on every paint (SetGradient copies them)
local gradientFrom, gradientTo

local function ShowGradient(bar, texture, r, g, b, a, er, eg, eb)
  if not (texture and texture.SetGradient and CreateColor) then return end
  if not gradientFrom then gradientFrom, gradientTo = CreateColor(r, g, b, a), CreateColor(er, eg, eb, a) end
  gradientFrom.r, gradientFrom.g, gradientFrom.b, gradientFrom.a = r, g, b, a
  gradientTo.r, gradientTo.g, gradientTo.b, gradientTo.a = er, eg, eb, a
  -- left to right, or bottom to top on a vertical bar such as the crystal
  texture:SetGradient(IsVertical(bar) and "VERTICAL" or "HORIZONTAL", gradientFrom, gradientTo)
end

-- `at` is where Sweep's band is; without it, `pr, pg, pb` is Gradient's far end.
local function applyColour(bar, r, g, b, a, at, pr, pg, pb)
  if CastSaysSomething(bar) then return end
  local gradient = not at and pr ~= nil
  local fill = at and VisibleFill(bar)
  if at and not (fill and CreateColor) then
    local k = Shimmer(at)
    r, g, b = r + (pr - r) * k, g + (pg - g) * k, b + (pb - b) * k
    at = nil
  end
  -- an overlay keeps the alpha its owner gives it (hidden, or see-through)
  local owner = ownerColour[bar]
  if owner then a = owner[4] end
  if blizzardBars[bar] then
    -- The default bar art is coloured; desaturate it so the tint shows the real colour.
    -- Nothing is ever written onto Blizzard's frames (no lockColor): a value an addon
    -- writes there taints Blizzard's own code when it reads it, and tainted code may
    -- not compare Midnight's secret health values (TextStatusBar.lua errors). The hook
    -- on SetStatusBarColor puts our colour back in the same frame instead.
    if bar.SetStatusBarDesaturated then bar:SetStatusBarDesaturated(true) end
  end
  -- Alpha goes on the bar texture only, so overlays and frame fading are left alone.
  if type(bar.SetStatusBarColor) == "function" then
    bar:SetStatusBarColor(r, g, b, a)
  end
  local texture = FillTexture(bar)
  if texture and type(texture.SetVertexColor) == "function" then
    texture:SetVertexColor(r, g, b, a)
  end
  if gradient then ShowGradient(bar, texture, r, g, b, a, pr, pg, pb) end
  if at then ShowBand(bar, fill, at, pr, pg, pb, a) else HideBand(bar) end
  -- JuNNeZ Edition draws its player power bar with a fill texture of its own.
  local fake = bar.FakeFill
  if type(fake) == "table" and type(fake.SetVertexColor) == "function" then
    fake:SetVertexColor(r, g, b, a)
    if gradient then ShowGradient(bar, fake, r, g, b, a, pr, pg, pb) end
  end
end

---------------------------------------------------------------------
-- COLOUR VISION PREVIEW
---------------------------------------------------------------------
-- The Studio preview can show your colours as they look with a common kind of colour
-- blindness. Only the preview bars change. Machado, Oliveira & Fernandes (2009) at full
-- strength, applied in linear light; monochrome is the eye's luminance.
P.VISION_MODES = { "normal", "protanopia", "deuteranopia", "tritanopia", "achromatopsia" }
P.VISION_VALUES = {
  normal = L["Normal vision"], protanopia = L["Protanopia (no red)"], deuteranopia = L["Deuteranopia (no green)"],
  tritanopia = L["Tritanopia (no blue)"], achromatopsia = L["Monochrome"],
}
local VISION = {
  protanopia    = { 0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998 },
  deuteranopia  = { 0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881 },
  tritanopia    = { 1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900 },
  achromatopsia = { 0.2126, 0.7152, 0.0722, 0.2126, 0.7152, 0.0722, 0.2126, 0.7152, 0.0722 },
}
local vision -- the matrix the preview shows, or nil

local function ToLinear(v) return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
local function ToScreen(v)
  v = min(1, max(0, v))
  return v <= 0.0031308 and v * 12.92 or 1.055 * v ^ (1 / 2.4) - 0.055
end

local function Seen(r, g, b)
  local m = vision
  r, g, b = ToLinear(r), ToLinear(g), ToLinear(b)
  return ToScreen(m[1] * r + m[2] * g + m[3] * b), ToScreen(m[4] * r + m[5] * g + m[6] * b),
         ToScreen(m[7] * r + m[8] * g + m[9] * b)
end
P.SimulateVision = function(mode, r, g, b)
  local saved = vision
  vision = VISION[mode]
  if vision then r, g, b = Seen(r, g, b) end
  vision = saved
  return r, g, b
end

-- Paints one bar. `r` nil means "your health decides", for the player channel.
local function paintBar(bar, r, g, b, a, at, pr, pg, pb)
  local factor = targets[bar]
  if not factor then return end
  painting[bar] = true
  local ok, err
  if r == nil then
    local c = healthHigh[channels[bar]] or P.DB.profile.color
    local hr, hg, hb, ha = HealthColour(factor, c)
    if hr ~= nil then
      ok, err = pcall(applyColour, bar, hr, hg, hb, ha) -- secret: passed on, never touched
    else
      ok, err = pcall(applyColour, bar, c[1] * factor, c[2] * factor, c[3] * factor, c[4] or 1)
    end
  else
    r, g, b = r * factor, g * factor, b * factor
    if pr then pr, pg, pb = pr * factor, pg * factor, pb * factor end
    if vision and previews[bar] then
      r, g, b = Seen(r, g, b)
      if pr then pr, pg, pb = Seen(pr, pg, pb) end
    end
    ok, err = pcall(applyColour, bar, r, g, b, a, at, pr, pg, pb)
  end
  painting[bar] = nil
  if not ok then P.Debug(err) end
end

-- Each channel's colour for one repaint, in tables kept from one repaint to the next
-- (this runs up to 60 times a second, so it makes no garbage). Every channel is worked
-- out, bars or not, so a bar that turns up mid-fade fades from what its channel showed.
local CHANNELS = { "player", "pet", "power", "cast", "classpower", "absorb" }
local frameColours = { player = {}, pet = {}, power = {}, cast = {}, classpower = {}, absorb = {} }

-- Notes whether the channel shows anything new. A channel drawn from your health
-- (r nil) always counts as new: its colour lives inside the game.
local function Fill(out, r, g, b, a, at, pr, pg, pb)
  out.changed = r == nil or out[1] ~= r or out[2] ~= g or out[3] ~= b or out[4] ~= a
    or out[5] ~= at or out[6] ~= pr or out[7] ~= pg or out[8] ~= pb
  out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8] = r, g, b, a, at, pr, pg, pb
end

-- `onlyChanged` (the animator) leaves bars alone whose channel shows what it showed:
-- while the pet frame pulses, a still health bar is not painted 30 times a second.
local function Repaint(onlyChanged)
  if not P.DB then return end
  local fade = FadeProgress()
  for i = 1, #CHANNELS do
    local channel = CHANNELS[i]
    Fill(frameColours[channel], P.ChannelColour(channel, fade))
  end
  for bar, channel in pairs(channels) do
    -- a bar you cannot see (a pet frame with no pet, a closed window's preview) waits:
    -- it is painted as it shows (see addTarget)
    local c = frameColours[channel]
    if (not onlyChanged or c.changed) and (not bar.IsVisible or bar:IsVisible()) then
      paintBar(bar, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
    end
  end
end

-- Paints every bar: after a setting changes, whatever it was.
function P.Repaint() Repaint(false) end

-- Another addon (or Blizzard) recoloured a bar: put ours back in the same frame.
local function RepaintBar(bar)
  if P.DB and targets[bar] and not painting[bar] then
    paintBar(bar, P.ChannelColour(channels[bar], FadeProgress()))
  end
end

-- An overlay's owner says how see-through it is, and its colour is what it gets back
-- when overlays are switched off.
local function NoteOwner(bar, r, g, b, a)
  if channels[bar] ~= "absorb" or painting[bar] then return end
  a = a or 1
  if not (P.IsAccessible(r) and P.IsAccessible(g) and P.IsAccessible(b) and P.IsAccessible(a)) then return end
  local owner = ownerColour[bar] or {}
  owner[1], owner[2], owner[3], owner[4] = r, g, b, a
  ownerColour[bar] = owner
end

local function onBarColour(bar, r, g, b, a)
  NoteOwner(bar, r, g, b, a)
  RepaintBar(bar)
end

local function onTextureColour(texture, r, g, b, a)
  local bar = textureOwners[texture]
  if not bar then return end
  if bar == texture then NoteOwner(bar, r, g, b, a) end
  RepaintBar(bar)
end

-- The colour an overlay shows before it is taken.
local function ReadOwner(bar)
  local ok, r, g, b, a
  if type(bar.GetStatusBarColor) == "function" then
    ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
  elseif type(bar.GetVertexColor) == "function" then
    ok, r, g, b, a = pcall(bar.GetVertexColor, bar)
  end
  if ok and r ~= nil then NoteOwner(bar, r, g, b, a) end
end

-- oUF in newer AzeriteUI builds colours the texture directly, so hook that as well
local function hookTexture(bar)
  local texture = FillTexture(bar)
  if type(texture) ~= "table" or textureOwners[texture] or type(texture.SetVertexColor) ~= "function" then return end
  if pcall(hooksecurefunc, texture, "SetVertexColor", onTextureColour) then
    textureOwners[texture] = bar
  end
end

local function onBarTexture(bar)
  if painting[bar] then return end
  hookTexture(bar)
  RepaintBar(bar)
end

-- Anything that shows a colour: a status bar, PitBull 4's bar, or a plain texture.
local function CanPaint(bar)
  return type(bar.SetStatusBarColor) == "function" or type(bar.GetStatusBarTexture) == "function"
    or (type(bar.SetColor) == "function" and type(bar.fg) == "table")
    or type(bar.SetVertexColor) == "function"
end

-- `label` names where the bar comes from, for /ahui check.
local function addTarget(bar, factor, channel, label)
  if type(bar) ~= "table" or targets[bar] or not CanPaint(bar) then return end
  targets[bar], channels[bar] = factor, channel
  labels[bar] = label or labels[bar]
  if channel == "absorb" then ReadOwner(bar) end
  -- Hooks cannot be removed, so a bar handed back keeps them; they do nothing without a target.
  if not hooked[bar] then
    hooked[bar] = true
    if type(bar.SetStatusBarColor) == "function" then pcall(hooksecurefunc, bar, "SetStatusBarColor", onBarColour) end
    if type(bar.SetStatusBarTexture) == "function" then pcall(hooksecurefunc, bar, "SetStatusBarTexture", onBarTexture) end
    -- PitBull 4 colours its bars with SetColor
    if type(bar.SetColor) == "function" and type(bar.fg) == "table" then pcall(hooksecurefunc, bar, "SetColor", onBarColour) end
    -- Repaint skips hidden bars; this catches one up the moment it shows
    if type(bar.HookScript) == "function" then pcall(bar.HookScript, bar, "OnShow", RepaintBar) end
  end
  hookTexture(bar)
  RepaintBar(bar)
  return true
end

-- Stop colouring a bar and let its owner colour it again.
local function removeTarget(bar)
  if not targets[bar] then return end
  local owner = ownerColour[bar]
  targets[bar], channels[bar], optionalBars[bar], ownerColour[bar] = nil, nil, nil, nil
  local restore = blizzardBars[bar]
  blizzardBars[bar] = nil
  HideBand(bar)
  pcall(function()
    if type(restore) == "function" then restore(bar)
    elseif owner then
      -- an overlay gets back the colour its owner gave it
      if type(bar.SetStatusBarColor) == "function" then bar:SetStatusBarColor(owner[1], owner[2], owner[3], owner[4]) end
      local texture = FillTexture(bar)
      if texture then texture:SetVertexColor(owner[1], owner[2], owner[3], owner[4]) end
    elseif bar.ForceUpdate then bar:ForceUpdate() end
  end)
end

-- What Frames.lua needs to find and hand over bars.
P.Painter = {
  targets = targets, channels = channels, optionalBars = optionalBars, blizzardBars = blizzardBars,
  labels = labels, addTarget = addTarget, removeTarget = removeTarget,
}

-- For tests and the debug log.
function P.GetTargets() return targets, channels end

-- Bars of the addon's own (the Studio's live preview) that show a channel like the real ones.
function P.AddPreviewTarget(bar, channel)
  previews[bar] = true
  if targets[bar] then channels[bar] = channel; RepaintBar(bar); return end
  addTarget(bar, 1, channel)
end
function P.RemovePreviewTarget(bar) removeTarget(bar) end
function P.IsPreviewTarget(bar) return previews[bar] == true end

-- Shows the preview bars as they look with a kind of colour blindness ("normal" for none).
function P.SetPreviewVision(mode)
  vision = VISION[mode]
  P.previewVision = vision and mode or "normal"
  for bar in pairs(previews) do RepaintBar(bar) end
end
---------------------------------------------------------------------
-- ANIMATION
---------------------------------------------------------------------
local animator = CreateFrame("Frame")
animator:Hide()
local frameElapsed = 0

-- Something moves on a channel that has a bar to show it.
function P.NeedsAnimation()
  if P.DB.profile.reduceMotion then return false end
  local player, pet, power, cast, classpower, absorb
  for _, channel in pairs(channels) do
    if channel == "player" then player = true
    elseif channel == "pet" then pet = true
    elseif channel == "power" then power = true
    elseif channel == "cast" then cast = true
    elseif channel == "classpower" then classpower = true
    else absorb = true end
  end
  local animated = P.IsAnimated
  return ((player or absorb) and animated(P.ChannelEffect("player")))
    or (pet and animated(P.ChannelEffect("pet")))
    or (power and animated(P.ChannelEffect("power")))
    or (cast and animated(P.ChannelEffect("cast")))
    or (classpower and animated(P.ChannelEffect("classpower"))) or false
end

function P.UpdateAnimator()
  if not P.DB then return end
  if P.NeedsAnimation() or P.IsFading() then animator:Show() else animator:Hide() end
end

animator:SetScript("OnUpdate", function(self, elapsed)
  P.AdvanceEffects(elapsed)
  frameElapsed = frameElapsed + elapsed
  local rate = tonumber(P.DB.profile.updateRate) or 30
  if frameElapsed >= 1 / max(1, rate) then
    frameElapsed = 0
    Repaint(true)
    -- a finished fade with nothing else moving needs no more frames
    if not P.IsFading() and not P.NeedsAnimation() then self:Hide() end
  end
end)

---------------------------------------------------------------------
-- YOUR COLOUR AND PRESETS
---------------------------------------------------------------------
P.selectedPreset = nil

-- Picking a colour shows it on your health bar now; a pet colour there comes back
-- on the next pet change. Rainbow ignores your colour, so it stops; other effects stay.
-- The last eight colours you picked, newest first, without repeats.
function P.PushRecent(c)
  local recent = P.DB.profile.recentColours
  local hex = P.Hex(c)
  for i = #recent, 1, -1 do
    if P.Hex(recent[i]) == hex then table.remove(recent, i) end
  end
  table.insert(recent, 1, P.CopyColour(c))
  for i = #recent, 9, -1 do recent[i] = nil end
end

-- `fade` marks a finished choice (a button, a preset, a slash command) rather than a
-- colour picker being dragged: it fades in and goes on the recent colours.
function P.SetUserColour(r, g, b, a, fade)
  local p = P.DB.profile
  if fade then P.StartFade() end
  local c = p.color
  c[1], c[2], c[3], c[4] = r, g, b, a or c[4] or 1
  P.petSuppressed = true
  P.ResetHealthCurves()
  if p.effect == "rainbow" then p.effect = "static" end
  if fade then P.PushRecent(c) end
  P.UpdateAnimator()
  P.Repaint()
end

-- Preset packs, added from the Presets section. High Contrast is the Okabe-Ito
-- palette, chosen to stay distinct for every common kind of colour blindness.
P.PRESET_PACK_ORDER = { "fantasy", "elements", "pastel", "contrast", "midnight", "classes" }
P.PRESET_PACKS = {
  fantasy = { label = L["Class Fantasy"], presets = {
    { "Fel", 0.35, 0.85, 0.20 }, { "Frost", 0.40, 0.75, 1.00 }, { "Holy Light", 1.00, 0.85, 0.40 },
    { "Shadow", 0.45, 0.20, 0.65 }, { "Nature", 0.25, 0.70, 0.30 }, { "Arcane", 0.75, 0.45, 1.00 },
    { "Blood", 0.70, 0.05, 0.10 }, { "Storm", 0.30, 0.55, 0.95 },
  } },
  elements = { label = L["Elements"], presets = {
    { "Fire", 1.00, 0.40, 0.10 }, { "Water", 0.15, 0.50, 0.90 }, { "Earth", 0.55, 0.40, 0.20 },
    { "Air", 0.75, 0.90, 0.95 }, { "Lightning", 0.95, 0.95, 0.35 }, { "Ice", 0.70, 0.90, 1.00 },
  } },
  pastel = { label = L["Pastel"], presets = {
    { "Pastel Pink", 1.00, 0.70, 0.80 }, { "Pastel Mint", 0.65, 0.95, 0.80 }, { "Pastel Lavender", 0.80, 0.70, 1.00 },
    { "Pastel Peach", 1.00, 0.80, 0.65 }, { "Pastel Sky", 0.65, 0.85, 1.00 }, { "Pastel Lemon", 1.00, 0.97, 0.65 },
  } },
  contrast = { label = L["High Contrast"], presets = {
    { "HC Orange", 0.90, 0.60, 0.00 }, { "HC Sky Blue", 0.34, 0.71, 0.91 }, { "HC Bluish Green", 0.00, 0.62, 0.45 },
    { "HC Yellow", 0.94, 0.89, 0.26 }, { "HC Blue", 0.00, 0.45, 0.70 }, { "HC Vermillion", 0.84, 0.37, 0.00 },
    { "HC Reddish Purple", 0.80, 0.47, 0.65 }, { "HC White", 1.00, 1.00, 1.00 },
  } },
  -- the places of Midnight
  midnight = { label = L["Midnight"], presets = {
    { "Silvermoon Gold", 1.00, 0.78, 0.30 }, { "Sunwell Light", 1.00, 0.95, 0.70 },
    { "Eversong Crimson", 0.78, 0.12, 0.20 }, { "Void Purple", 0.42, 0.18, 0.70 },
    { "Harandar Green", 0.36, 0.70, 0.32 }, { "Zul'Aman Teal", 0.10, 0.62, 0.58 },
  } },
  -- every class colour, named in the game's language (filled in below)
  classes = { label = L["Class Colours"], presets = {} },
}
do
  local classes = P.PRESET_PACKS.classes.presets
  for class, colour in pairs(RAID_CLASS_COLORS or {}) do
    local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
    if type(colour) == "table" and colour.r then classes[#classes + 1] = { name, colour.r, colour.g, colour.b } end
  end
  table.sort(classes, function(a, b) return a[1] < b[1] end)
end

-- Adds a pack's presets. Names you already have are left as they are.
-- Returns how many were added.
function P.AddPresetPack(key)
  local pack = P.PRESET_PACKS[key]
  if not pack then return 0 end
  local presets, added = P.DB.profile.presets, 0
  for _, preset in ipairs(pack.presets) do
    if not presets[preset[1]] then
      presets[preset[1]] = { preset[2], preset[3], preset[4], 1 }
      added = added + 1
    end
  end
  P.RefreshOptions()
  return added
end

-- Presets in the order you dragged them into; any not placed yet follow alphabetically.
function P.SortedPresetNames()
  local presets, order = P.DB.profile.presets, P.DB.profile.presetOrder
  local names, placed = {}, {}
  for _, name in ipairs(order) do
    if presets[name] and not placed[name] then names[#names + 1] = name; placed[name] = true end
  end
  local rest = {}
  for name in pairs(presets) do if not placed[name] then rest[#rest + 1] = name end end
  table.sort(rest, function(x, y) return x:lower() < y:lower() end)
  for _, name in ipairs(rest) do names[#names + 1] = name end
  return names
end

-- Moves a preset to a place in the list, and saves the whole order.
function P.MovePreset(name, index)
  local names = P.SortedPresetNames()
  local from
  for i, other in ipairs(names) do if other == name then from = i end end
  if not from then return end
  table.remove(names, from)
  table.insert(names, math.max(1, math.min(index, #names + 1)), name)
  P.DB.profile.presetOrder = names
  P.RefreshOptions()
end

-- Saves the current colour over an existing preset.
function P.OverwritePreset(name)
  if not P.DB.profile.presets[name] then return end
  P.DB.profile.presets[name] = P.CopyColour(P.DB.profile.color)
  P.selectedPreset = name
  P.RefreshOptions()
end

function P.SaveNamedPreset(name)
  name = name and strtrim(name) or ""
  if name == "" then return end
  P.DB.profile.presets[name] = P.CopyColour(P.DB.profile.color)
  P.selectedPreset = name
  P.UpdatePetColour() -- the name may belong to the active pet; also refreshes the panel
end

function P.LoadPreset(name)
  local c = P.DB.profile.presets[name]
  if not c then return false end
  P.selectedPreset = name
  P.SetUserColour(c[1], c[2], c[3], c[4], true)
  P.RefreshOptions()
  return true
end

-- The preset after the selected one, alphabetically, wrapping round.
function P.NextPreset()
  local names = P.SortedPresetNames()
  if #names == 0 then return end
  local index = 0
  for i, name in ipairs(names) do if name == P.selectedPreset then index = i end end
  local name = names[index % #names + 1]
  P.LoadPreset(name)
  return name
end

function P.DeletePreset()
  if not P.selectedPreset then return end
  P.DB.profile.presets[P.selectedPreset] = nil
  P.selectedPreset = nil
  P.UpdatePetColour()
end

function P.RenamePreset(newName)
  newName = strtrim(newName or "")
  local presets = P.DB.profile.presets
  local selected = P.selectedPreset
  if not selected or not presets[selected] or newName == "" or newName == selected then
    return false
  end
  if presets[newName] then
    P.Print(L["A preset with that name already exists:"] .. " " .. newName)
    return false
  end
  presets[newName], presets[selected] = presets[selected], nil
  for i, name in ipairs(P.DB.profile.presetOrder) do
    if name == selected then P.DB.profile.presetOrder[i] = newName end
  end
  -- a specialization that loads it follows the new name
  local specPresets = P.DB.char.specPresets
  for spec, name in pairs(specPresets) do
    if type(spec) == "number" and name == selected then specPresets[spec] = newName end
  end
  P.selectedPreset = newName
  P.UpdatePetColour()
  return true
end

-- Give the pet that is out the colour from the colour picker
function P.SaveColourToCurrentPet()
  local pet = P.currentPet
  if not pet then return end
  if pet.number then
    local settings = P.EnsurePetSettings(pet.number)
    settings.mode, settings.color = "custom", P.CopyColour(P.DB.profile.color)
    P.UpdatePetColour()
  elseif pet.name then
    P.SaveNamedPreset(pet.name) -- pets the stable does not know keep using a preset named after them
  end
end

---------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------
-- UNIT_HEALTH comes many times a second in combat; while the animator runs, its next
-- repaint (a frame or two away) picks the new health up anyway.
local function HealthChanged()
  if P.DB and P.HealthColourOn() and not animator:IsShown() then P.Repaint() end
end
P.On("UNIT_HEALTH", HealthChanged, "player")
P.On("UNIT_MAXHEALTH", HealthChanged, "player")

P.OnProfileChanged(function()
  P.selectedPreset = nil
  P.ResetHealthCurves()
end)
