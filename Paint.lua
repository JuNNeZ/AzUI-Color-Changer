-- Paint.lua - the bars, the channels they belong to, the mixer that picks each
-- channel's colour, fades, and the painter that puts it on screen.
--
-- Channels: "player" (your health bar), "pet" (the pet frames) and "power" (your power
-- bar, only while that is switched on). For each channel the mixer takes, in order:
-- the first matching rule, the pet's colour, your health (if Colour by Health is on,
-- your health bar only), and finally your own colour and effect.
local _, ns = ...
local P = ns.P
local L = P.L

local min, max = math.min, math.max
local pairs, pcall, type = pairs, pcall, type

local FADE_TIME     = 0.3 -- seconds to blend into a new colour
local SCAN_INTERVAL = 2   -- seconds between looks for late-created frames

-- AceAddon names of the AzeriteUI editions (JuNNeZ Edition also registers "AzeriteUI").
-- JuNNeZ Edition's themes (Hunter, Mage, Paladin, Legacy HUD) keep the native Health bar
-- and only add casings around it, so the same frames are coloured under every theme.
local AZERITE_ADDONS  = { "AzeriteUI", "AzeriteUI6", "AzeriteUI5_JuNNeZ_Edition" }
-- Unit frame modules -> channel. 5.x and JuNNeZ Edition use PlayerFrame(+Alternate) and PetFrame,
-- AzeriteUI6 uses Player and Pet.
local AZERITE_MODULES = {
  PlayerFrame = "player", PlayerFrameAlternate = "player", PetFrame = "pet",
  Player      = "player", Pet                  = "pet",
}
-- Global frame names, used when the module lookup finds nothing
local AZERITE_FRAMES  = {
  AzeriteUnitFramePlayer     = "player", AzeriteUnitFramePlayerAlternate = "player", AzeriteUnitFramePet = "pet",
  oUF_AzeriteUnitFramePlayer = "player", oUF_AzeriteUnitFramePet         = "pet",
}
-- AzeriteUI 5.x tints the health preview at 90% on the player frame and 70% on the pet frame
local PREVIEW_FACTOR  = { player = 0.9, pet = 0.7 }

local targets       = setmetatable({}, { __mode = "k" }) -- bar -> brightness factor
local channels      = setmetatable({}, { __mode = "k" }) -- bar -> "player" | "pet" | "power"
local blizzardBars  = setmetatable({}, { __mode = "k" }) -- bar -> how to hand it back to Blizzard
local optionalBars  = setmetatable({}, { __mode = "k" }) -- bar -> "blizzardPet" | "petFrame" | "power"
local textureOwners = setmetatable({}, { __mode = "k" }) -- bar texture -> bar
local hooked        = setmetatable({}, { __mode = "k" })
local painting      = setmetatable({}, { __mode = "k" })
local knownFrames   = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------
-- COLOUR BY HEALTH
---------------------------------------------------------------------
-- Midnight keeps health secret from addons, so no Lua maths on it. A colour curve
-- runs inside the game instead: UnitHealthPercent evaluates it and hands back a
-- colour the bar can take as it is (SetStatusBarColor accepts secret values). The
-- preview bar's 90% is baked into a curve of its own, as nothing may be multiplied.
local curves = {}

function P.HealthColourAvailable()
  return C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent and CreateColor and true or false
end

function P.HealthColourOn()
  return P.DB.profile.healthColour and P.HealthColourAvailable()
end

function P.ResetHealthCurves()
  for key in pairs(curves) do curves[key] = nil end
end

local function HealthCurve(factor)
  local curve = curves[factor]
  if curve then return curve end
  local p = P.DB.profile
  local low, high = p.lowHealthColour, p.color
  curve = C_CurveUtil.CreateColorCurve()
  curve:AddPoint(0, CreateColor(low[1] * factor, low[2] * factor, low[3] * factor, low[4] or 1))
  curve:AddPoint(1, CreateColor(high[1] * factor, high[2] * factor, high[3] * factor, high[4] or 1))
  curves[factor] = curve
  return curve
end

-- The colour for your health right now, untouched, or nothing if the game would not say.
local function HealthColour(factor)
  local ok, colour = pcall(UnitHealthPercent, "player", true, HealthCurve(factor))
  if not ok or colour == nil then return end
  local unpacked, r, g, b, a = pcall(function() return colour:GetRGBA() end)
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

-- Where a channel's colour comes from: colour, effect, and which source it is
-- ("rule", "pet", "health", "power" or "own"). Health has no colour of its own here.
function P.ChannelSource(channel)
  local p = P.DB.profile
  if channel == "power" then
    if p.power.mode == "custom" then return p.power.color, p.power.effect, "power" end
    channel = "player" -- Match health bar
  end
  local rule = P.ActiveRule(channel)
  if rule then return rule.color, rule.effect, "rule" end
  if ShowsPetColour(channel) then return P.activePet.color, P.activePet.effect, "pet" end
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
local lastShown = { player = {}, pet = {}, power = {} }
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
function P.ChannelColour(channel, fade)
  local colour, effect, kind = P.ChannelSource(channel)
  local last = lastShown[channel]
  if kind == "health" then
    last[1] = nil
    return
  end
  local r, g, b, a, at, pr, pg, pb = P.EffectColour(effect, colour)
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
  local low, high = CreateColor(r, g, b, 0), CreateColor(r, g, b, (a or 1) * strength)
  band.left:ClearAllPoints()
  band.right:ClearAllPoints()
  if vertical then
    -- bottom to top: "left" is the lower half, "right" the upper
    for _, half in ipairs({ band.left, band.right }) do
      half:SetPoint("LEFT", bar, "LEFT")
      half:SetPoint("RIGHT", bar, "RIGHT")
      half:SetHeight(edge)
    end
    band.left:SetPoint("BOTTOM", bar, "BOTTOM", 0, centre - edge)
    band.right:SetPoint("BOTTOM", bar, "BOTTOM", 0, centre)
    band.left:SetGradient("VERTICAL", low, high)
    band.right:SetGradient("VERTICAL", high, low)
  else
    for _, half in ipairs({ band.left, band.right }) do
      half:SetPoint("TOP", bar, "TOP")
      half:SetPoint("BOTTOM", bar, "BOTTOM")
      half:SetWidth(edge)
    end
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

local function applyColour(bar, r, g, b, a, at, pr, pg, pb)
  local fill = at and VisibleFill(bar)
  if at and not (fill and CreateColor) then
    local k = Shimmer(at)
    r, g, b = r + (pr - r) * k, g + (pg - g) * k, b + (pb - b) * k
    at = nil
  end
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
  local texture = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
  if texture and type(texture.SetVertexColor) == "function" then
    texture:SetVertexColor(r, g, b, a)
  end
  if at then ShowBand(bar, fill, at, pr, pg, pb, a) else HideBand(bar) end
  -- JuNNeZ Edition draws its player power bar with a fill texture of its own.
  local fake = bar.FakeFill
  if type(fake) == "table" and type(fake.SetVertexColor) == "function" then
    fake:SetVertexColor(r, g, b, a)
  end
end

-- Paints one bar. `r` nil means "your health decides", for the player channel.
local function paintBar(bar, r, g, b, a, at, pr, pg, pb)
  local factor = targets[bar]
  if not factor then return end
  painting[bar] = true
  local ok, err
  if r == nil then
    local hr, hg, hb, ha = HealthColour(factor)
    if hr ~= nil then
      ok, err = pcall(applyColour, bar, hr, hg, hb, ha) -- secret: passed on, never touched
    else
      local c = P.DB.profile.color
      ok, err = pcall(applyColour, bar, c[1] * factor, c[2] * factor, c[3] * factor, c[4] or 1)
    end
  else
    ok, err = pcall(applyColour, bar, r * factor, g * factor, b * factor, a,
      at, pr and pr * factor, pg and pg * factor, pb and pb * factor)
  end
  painting[bar] = nil
  if not ok then P.Debug(err) end
end

function P.Repaint()
  if not P.DB then return end
  local fade = FadeProgress()
  local colours = {}
  for _, channel in ipairs({ "player", "pet", "power" }) do
    colours[channel] = { P.ChannelColour(channel, fade) }
  end
  for bar, channel in pairs(channels) do
    paintBar(bar, unpack(colours[channel]))
  end
end

-- Another addon (or Blizzard) recoloured a bar: put ours back in the same frame.
local function RepaintBar(bar)
  if P.DB and targets[bar] and not painting[bar] then
    paintBar(bar, P.ChannelColour(channels[bar], FadeProgress()))
  end
end

local function onBarColour(bar) RepaintBar(bar) end

local function onTextureColour(texture)
  local bar = textureOwners[texture]
  if bar then RepaintBar(bar) end
end

-- oUF in newer AzeriteUI builds colours the texture directly, so hook that as well
local function hookTexture(bar)
  local texture = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
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

local function addTarget(bar, factor, channel)
  if type(bar) ~= "table" or targets[bar] then return end
  if type(bar.SetStatusBarColor) ~= "function" and type(bar.GetStatusBarTexture) ~= "function" then return end
  targets[bar], channels[bar] = factor, channel
  -- Hooks cannot be removed, so a bar handed back keeps them; they do nothing without a target.
  if not hooked[bar] then
    hooked[bar] = true
    if type(bar.SetStatusBarColor) == "function" then pcall(hooksecurefunc, bar, "SetStatusBarColor", onBarColour) end
    if type(bar.SetStatusBarTexture) == "function" then pcall(hooksecurefunc, bar, "SetStatusBarTexture", onBarTexture) end
  end
  hookTexture(bar)
  RepaintBar(bar)
  return true
end

-- Stop colouring a bar and let its owner colour it again.
local function removeTarget(bar)
  if not targets[bar] then return end
  targets[bar], channels[bar], optionalBars[bar] = nil, nil, nil
  local restore = blizzardBars[bar]
  blizzardBars[bar] = nil
  HideBand(bar)
  pcall(function()
    if type(restore) == "function" then restore(bar)
    elseif bar.ForceUpdate then bar:ForceUpdate() end
  end)
end

---------------------------------------------------------------------
-- FRAME DISCOVERY
---------------------------------------------------------------------
local function GetBlizzardPlayerHealthBar()
  if type(PlayerFrame_GetHealthBar) == "function" then
    local ok, bar = pcall(PlayerFrame_GetHealthBar)
    if ok and bar then return bar end
  end
  local main = PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
  local container = main and main.HealthBarsContainer
  if container and container.HealthBar then return container.HealthBar end
  return PlayerFrame and PlayerFrame.healthbar or _G.PlayerFrameHealthBar
end

local function GetBlizzardPlayerManaBar()
  if type(PlayerFrame_GetManaBar) == "function" then
    local ok, bar = pcall(PlayerFrame_GetManaBar)
    if ok and bar then return bar end
  end
  return PlayerFrame and PlayerFrame.manabar or _G.PlayerFrameManaBar
end

local function GetBlizzardPetHealthBar()
  return PetFrame and PetFrame.healthbar or _G.PetFrameHealthBar
end

-- How each Blizzard bar gets its own colour back. Blizzard's update functions are
-- never called from here: run from an addon they compare secret values while
-- tainted and error. The bar is given its default colour, and Blizzard's next
-- update takes over from there.
local function RestoreBlizzard(bar)
  if bar.SetStatusBarDesaturated then bar:SetStatusBarDesaturated(false) end
end

local function RestoreBlizzardPet(bar)
  RestoreBlizzard(bar)
  bar:SetStatusBarColor(0, 1, 0)
end

local function RestoreBlizzardMana(bar)
  RestoreBlizzard(bar)
  local ok, kind = pcall(UnitPowerType, "player")
  local colour = ok and P.IsAccessible(kind) and PowerBarColor and PowerBarColor[kind]
  if colour then bar:SetStatusBarColor(colour.r, colour.g, colour.b) else bar:SetStatusBarColor(0, 0, 1) end
end

local function addBlizzardTarget(bar, channel, restore, optional)
  if not bar or targets[bar] then return end
  blizzardBars[bar] = restore
  if addTarget(bar, 1, channel) then
    optionalBars[bar] = optional
  else
    blizzardBars[bar] = nil
  end
end

local function registerUnitFrame(frame, channel)
  if type(frame) ~= "table" or type(frame.Health) ~= "table" then return end
  -- Pet frames can be left to AzeriteUI ("Show on: Pet frame" off)
  local pet = channel == "pet"
  if pet and not P.DB.profile.colourPetFrames then return end
  if not targets[frame.Health] then
    addTarget(frame.Health, 1, channel)
    if pet then optionalBars[frame.Health] = "petFrame" end
    if type(frame.Health.Preview) == "table" then
      addTarget(frame.Health.Preview, PREVIEW_FACTOR[channel], channel)
      if pet then optionalBars[frame.Health.Preview] = "petFrame" end
    end
    if not knownFrames[frame] then
      knownFrames[frame] = true
      P.Debug("Colouring AzeriteUI frame " .. tostring(frame.GetName and frame:GetName() or "?"))
    end
  end
  -- Your power bar, while that is switched on
  if channel == "player" and P.DB.profile.power.mode ~= "off" then
    -- the power bar or crystal, and JuNNeZ Edition's mana orb
    for _, bar in ipairs({ frame.Power, frame.ManaOrb }) do
      if type(bar) == "table" and addTarget(bar, 1, "power") then optionalBars[bar] = "power" end
    end
  end
end

function P.ScanFrames()
  if not P.DB then return end
  if P.AceAddon then
    for i = 1, #AZERITE_ADDONS do
      local aui = P.AceAddon:GetAddon(AZERITE_ADDONS[i], true)
      if type(aui) == "table" and type(aui.GetModule) == "function" then
        for moduleName, channel in pairs(AZERITE_MODULES) do
          local module = aui:GetModule(moduleName, true)
          if type(module) == "table" then registerUnitFrame(module.frame, channel) end
        end
      end
    end
  end
  for frameName, channel in pairs(AZERITE_FRAMES) do
    registerUnitFrame(_G[frameName], channel)
  end
  addBlizzardTarget(GetBlizzardPlayerHealthBar(), "player", RestoreBlizzard)
  if P.DB.profile.blizzardPetFrame and P.DB.profile.colourPetFrames then
    addBlizzardTarget(GetBlizzardPetHealthBar(), "pet", RestoreBlizzardPet, "blizzardPet")
  end
  if P.DB.profile.power.mode ~= "off" then
    addBlizzardTarget(GetBlizzardPlayerManaBar(), "power", RestoreBlizzardMana, "power")
  end
end

-- After the Blizzard pet frame or power bar settings change: let go of bars that are
-- switched off, pick up the ones switched on.
function P.RefreshOptionalBars()
  local p = P.DB.profile
  for bar, kind in pairs(optionalBars) do
    if (kind == "power" and p.power.mode == "off") or (kind == "blizzardPet" and not p.blizzardPetFrame)
      or ((kind == "petFrame" or kind == "blizzardPet") and not p.colourPetFrames) then
      removeTarget(bar)
    end
  end
  P.ScanFrames()
  P.UpdateAnimator()
  P.Repaint()
end

-- For tests and the debug log.
function P.GetTargets() return targets, channels end

-- Bars of the addon's own (the Studio's live preview) that show a channel like the real ones.
function P.AddPreviewTarget(bar, channel)
  if targets[bar] then channels[bar] = channel; RepaintBar(bar); return end
  addTarget(bar, 1, channel)
end
function P.RemovePreviewTarget(bar) removeTarget(bar) end

---------------------------------------------------------------------
-- ANIMATION
---------------------------------------------------------------------
local animator = CreateFrame("Frame")
animator:Hide()
local frameElapsed = 0

function P.NeedsAnimation()
  if P.DB.profile.reduceMotion then return false end
  if P.ChannelEffect("player") ~= "static" or P.ChannelEffect("pet") ~= "static" then return true end
  return P.DB.profile.power.mode ~= "off" and P.ChannelEffect("power") ~= "static"
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
    P.Repaint()
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
local function HealthChanged()
  if P.DB and P.HealthColourOn() then P.Repaint() end
end
P.On("UNIT_HEALTH", HealthChanged, "player")
P.On("UNIT_MAXHEALTH", HealthChanged, "player")
P.On("PLAYER_ENTERING_WORLD", function() P.ScanFrames() end)

P.OnInitialize(function()
  if type(PlayerFrame_UpdateArt) == "function" then
    hooksecurefunc("PlayerFrame_UpdateArt", function() P.ScanFrames(); P.Repaint() end)
  end
  -- AzeriteUI creates (and can later enable) its player frames after we load.
  C_Timer.NewTicker(SCAN_INTERVAL, P.ScanFrames)
  P.ScanFrames()
end)

P.OnProfileChanged(function()
  P.selectedPreset = nil
  P.ResetHealthCurves()
  P.RefreshOptionalBars()
end)
