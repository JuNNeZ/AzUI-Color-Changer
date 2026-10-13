-- Frames.lua - finds your bars in the unit frame addons and Blizzard's frames, hands
-- them to the painter (Paint.lua), and hands them back when a setting lets them go.
--
-- Supported: AzeriteUI (5.x, JuNNeZ Edition, AzeriteUI6), ElvUI, Unhalted Unit Frames,
-- Shadowed Unit Frames, Z-Perl, PitBull 4, any layout on the shared oUF, Blizzard's
-- player and pet frames and Blizzard's personal resource display. Class resources
-- (combo points, holy power, chi, arcane charges, soul shards, essence, runes) on
-- AzeriteUI, ElvUI, Unhalted Unit Frames and oUF layouts.
local _, ns = ...
local P = ns.P
local L = P.L

local pairs, ipairs, type = pairs, ipairs, type
local Painter = P.Painter
local targets, optionalBars, blizzardBars = Painter.targets, Painter.optionalBars, Painter.blizzardBars
local addTarget, removeTarget = Painter.addTarget, Painter.removeTarget

-- When to look for frames: when any addon loads (the next frame, once however many
-- load together), a few times after login while unit frame addons build theirs, and
-- then rarely, for a frame an addon switches on later in the session.
local LOGIN_SCANS   = { 1, 3, 6, 12 } -- seconds after entering the world
local SAFETY_SCAN   = 15              -- seconds between the rare looks after that

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
-- The modules that hold your class resources
local AZERITE_CLASSPOWER = { "PlayerClassPowerFrame", "ClassPower" }
-- Global frame names, used when the module lookup finds nothing
local AZERITE_FRAMES  = {
  AzeriteUnitFramePlayer     = "player", AzeriteUnitFramePlayerAlternate = "player", AzeriteUnitFramePet = "pet",
  oUF_AzeriteUnitFramePlayer = "player", oUF_AzeriteUnitFramePet         = "pet",
}
-- AzeriteUI 5.x tints the health preview at 90% on the player frame and 70% on the pet frame
local PREVIEW_FACTOR  = { player = 0.9, pet = 0.7 }

-- The heal and absorb overlays oUF's HealthPrediction element draws: today's names
-- (oUF 12) and the older ones some layouts still use. AzeriteUI's element is itself a
-- texture (the incoming heal) with an absorbBar on it.
local OUF_OVERLAYS = { "healingAll", "healingPlayer", "healingOther", "damageAbsorb", "healAbsorb",
  "myBar", "otherBar", "absorbBar", "healAbsorbBar" }
local function OUFOverlays(frame, add)
  local prediction = frame.HealthPrediction
  if type(prediction) ~= "table" then return end
  if type(prediction.SetVertexColor) == "function" then add(prediction) end
  for _, key in ipairs(OUF_OVERLAYS) do
    if type(prediction[key]) == "table" then add(prediction[key]) end
  end
end

-- Class resources as oUF draws them: ClassPower and Runes, each a list of status bars,
-- one per point. Stagger is left alone: its colour says how heavy the stagger is.
local function OUFClassPower(frame, add)
  for _, key in ipairs({ "ClassPower", "Runes" }) do
    local element = frame[key]
    if type(element) == "table" then
      for i = 1, 10 do
        if type(element[i]) == "table" then add(element[i]) end
      end
    end
  end
end

-- Where each addon keeps a frame's bars: a key, or a function of the frame.
local AZERITE_PARTS = { health = "Health", overlays = OUFOverlays } -- power, cast and class power: see below
local OUF_PARTS = { health = "Health", power = "Power", cast = "Castbar", overlays = OUFOverlays, classpower = OUFClassPower }
local SUF_PARTS = {
  health = "healthBar", power = "powerBar",
  cast = function(frame) return type(frame.castBar) == "table" and frame.castBar.bar or nil end,
  overlays = function(frame, add) add(frame.incHeal); add(frame.incAbsorb); add(frame.healAbsorb) end,
}
local function Stats(key)
  return function(frame) return type(frame.statsFrame) == "table" and frame.statsFrame[key] or nil end
end
local XPERL_PARTS = { health = Stats("healthBar"), power = Stats("manaBar") }
-- PitBull 4 keeps each bar under its module's name; its cast bar colours itself by the cast
local PITBULL_PARTS = { health = "HealthBar", power = "PowerBar" }

-- Other unit frame addons, by global frame name
local NAMED_FRAMES = {
  { label = "ElvUI", parts = OUF_PARTS, frames = { ElvUF_Player = "player", ElvUF_Pet = "pet" } },
  { label = "Unhalted Unit Frames", parts = OUF_PARTS, frames = { UUF_Player = "player", UUF_Pet = "pet" } },
  { label = "Shadowed Unit Frames", parts = SUF_PARTS, frames = { SUFUnitplayer = "player", SUFUnitpet = "pet" } },
  { label = "Z-Perl", parts = XPERL_PARTS, frames = { XPerl_Player = "player", XPerl_Player_Pet = "pet" } },
}

---------------------------------------------------------------------
-- WHAT IS WANTED
---------------------------------------------------------------------
-- Is a kind of optional bar wanted right now? The power and cast bars are taken while
-- they are coloured, or while a rule shows on them.
local function Wants(kind)
  local p = P.DB.profile
  if kind == "power" then return p.power.mode ~= "off" or P.ActiveRule("power") ~= nil end
  if kind == "cast" then return p.cast.mode ~= "off" or P.ActiveRule("cast") ~= nil end
  if kind == "classpower" then return p.classPower.mode ~= "off" or P.ActiveRule("classpower") ~= nil end
  if kind == "petFrame" then return p.colourPetFrames end
  if kind == "blizzardPet" then return p.colourPetFrames and p.blizzardPetFrame end
  if kind == "overlay" then return p.overlays end
  if kind == "prd" then return p.personalResource end
  if kind == "prdPower" then return p.personalResource and Wants("power") end
  return true
end
P.WantsBars = Wants

local function addOptional(bar, channel, kind, label)
  if type(bar) == "table" and addTarget(bar, 1, channel, label) then optionalBars[bar] = kind end
end

---------------------------------------------------------------------
-- UNIT FRAME ADDONS
---------------------------------------------------------------------
local function Part(frame, part)
  if type(part) == "function" then return part(frame) end
  return part and frame[part]
end

local knownFrames = setmetatable({}, { __mode = "k" })

-- `parts` says where the frame keeps its bars.
local function registerUnitFrame(frame, channel, parts, label)
  if type(frame) ~= "table" then return end
  local health = Part(frame, parts.health)
  if type(health) ~= "table" then return end
  -- Pet frames can be left to their addon ("Show on: Pet frame" off)
  local pet = channel == "pet"
  if pet and not Wants("petFrame") then return end
  if not targets[health] then
    if pet then addOptional(health, channel, "petFrame", label) else addTarget(health, 1, channel, label) end
    if parts == AZERITE_PARTS and type(health.Preview) == "table" then
      addTarget(health.Preview, PREVIEW_FACTOR[channel], channel, label)
      if pet then optionalBars[health.Preview] = "petFrame" end
    end
    if not knownFrames[frame] then
      knownFrames[frame] = true
      P.Debug("Colouring unit frame " .. tostring(frame.GetName and frame:GetName() or label))
    end
  end
  if channel ~= "player" then return end
  -- Your power bar, while that is switched on or a rule shows on it
  if Wants("power") then
    if parts == AZERITE_PARTS then
      -- the power bar or crystal, and JuNNeZ Edition's mana orb
      addOptional(frame.Power, "power", "power", label)
      addOptional(frame.ManaOrb, "power", "power", label)
    else
      addOptional(Part(frame, parts.power), "power", "power", label)
    end
  end
  -- Another addon's cast bar lives on its player frame (AzeriteUI's has a module of its own)
  if parts.cast and Wants("cast") then addOptional(Part(frame, parts.cast), "cast", "cast", label) end
  -- Combo points, runes and the like
  if parts.classpower and Wants("classpower") then
    parts.classpower(frame, function(bar) addOptional(bar, "classpower", "classpower", label) end)
  end
  -- The heal and absorb overlays on your health bar
  if parts.overlays and Wants("overlay") then
    parts.overlays(frame, function(bar) addOptional(bar, "absorb", "overlay", label) end)
  end
end

local function ScanAzerite()
  if not P.AceAddon then return end
  for i = 1, #AZERITE_ADDONS do
    local aui = P.AceAddon:GetAddon(AZERITE_ADDONS[i], true)
    if type(aui) == "table" and type(aui.GetModule) == "function" then
      for moduleName, channel in pairs(AZERITE_MODULES) do
        local module = aui:GetModule(moduleName, true)
        if type(module) == "table" then registerUnitFrame(module.frame, channel, AZERITE_PARTS, "AzeriteUI") end
      end
      -- your cast bar: AzeriteUI 5.x's and JuNNeZ Edition's PlayerCastBarFrame module
      if Wants("cast") then
        local module = aui:GetModule("PlayerCastBarFrame", true)
        local cast = type(module) == "table" and type(module.frame) == "table" and module.frame.Castbar
        addOptional(cast, "cast", "cast", "AzeriteUI")
      end
      -- your class resources: a frame of their own, PlayerClassPowerFrame in 5.x and
      -- JuNNeZ Edition, ClassPower in AzeriteUI6, drawn the way oUF draws them
      if Wants("classpower") then
        for _, name in ipairs(AZERITE_CLASSPOWER) do
          local module = aui:GetModule(name, true)
          local frame = type(module) == "table" and module.frame
          if type(frame) == "table" then
            OUFClassPower(frame, function(bar) addOptional(bar, "classpower", "classpower", "AzeriteUI") end)
          end
        end
      end
    end
  end
  for frameName, channel in pairs(AZERITE_FRAMES) do
    registerUnitFrame(_G[frameName], channel, AZERITE_PARTS, "AzeriteUI")
  end
end

-- Units an oUF or PitBull 4 frame shows, if it is yours or your pet's.
local UNITS = { player = "player", pet = "pet" }

-- Any layout on the shared oUF (the oUF addon, or a layout that exports it). ElvUI and
-- Unhalted Unit Frames keep theirs private, so they are found by name above.
local function ScanOUF()
  local oUF = _G.oUF
  if type(oUF) ~= "table" or type(oUF.objects) ~= "table" then return end
  for _, object in ipairs(oUF.objects) do
    local channel = type(object) == "table" and UNITS[object.unit]
    if channel then registerUnitFrame(object, channel, OUF_PARTS, "oUF") end
  end
end

local function ScanPitBull()
  local PitBull4 = _G.PitBull4
  local frames = type(PitBull4) == "table" and PitBull4.singleton_frames
  if type(frames) ~= "table" then return end
  for frame in pairs(frames) do
    local channel = type(frame) == "table" and UNITS[frame.unit]
    if channel then registerUnitFrame(frame, channel, PITBULL_PARTS, "PitBull 4") end
  end
end

---------------------------------------------------------------------
-- BLIZZARD'S FRAMES
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

-- The bars Blizzard draws under your character (Retail)
local function GetPersonalResourceBars()
  local prd = _G.PersonalResourceDisplayFrame
  if type(prd) ~= "table" then return end
  local container = prd.HealthBarsContainer
  return type(container) == "table" and container.healthBar or nil, prd.PowerBar
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

local function RestorePersonalHealth(bar)
  RestoreBlizzard(bar)
  bar:SetStatusBarColor(0, 0.8, 0) -- PersonalResourceDisplayMixin:SetupHealthBar
end

local function addBlizzardTarget(bar, channel, restore, optional, label)
  if not bar or targets[bar] then return end
  blizzardBars[bar] = restore
  if addTarget(bar, 1, channel, label) then
    optionalBars[bar] = optional
  else
    blizzardBars[bar] = nil
  end
end

local function ScanBlizzard()
  addBlizzardTarget(GetBlizzardPlayerHealthBar(), "player", RestoreBlizzard, nil, L["Blizzard's player frame"])
  if Wants("blizzardPet") then
    addBlizzardTarget(GetBlizzardPetHealthBar(), "pet", RestoreBlizzardPet, "blizzardPet", L["Blizzard's pet frame"])
  end
  if Wants("power") then
    addBlizzardTarget(GetBlizzardPlayerManaBar(), "power", RestoreBlizzardMana, "power", L["Blizzard's player frame"])
  end
  if Wants("prd") then
    local health, power = GetPersonalResourceBars()
    addBlizzardTarget(health, "player", RestorePersonalHealth, "prd", L["Personal resource display"])
    if Wants("prdPower") then
      addBlizzardTarget(power, "power", RestoreBlizzardMana, "prdPower", L["Personal resource display"])
    end
  end
end

---------------------------------------------------------------------
-- SCANNING
---------------------------------------------------------------------
function P.ScanFrames()
  if not P.DB then return end
  ScanAzerite()
  for _, addon in ipairs(NAMED_FRAMES) do
    for frameName, channel in pairs(addon.frames) do
      registerUnitFrame(_G[frameName], channel, addon.parts, addon.label)
    end
  end
  ScanOUF()
  ScanPitBull()
  ScanBlizzard()
end

-- After a setting changes which bars are wanted (the pet frames, the power or cast bar,
-- the overlays, a rule on the power or cast bar): let go of bars that are no longer
-- wanted, pick up the ones that are.
function P.RefreshOptionalBars()
  for bar, kind in pairs(optionalBars) do
    if not Wants(kind) then removeTarget(bar) end
  end
  P.ScanFrames()
  P.UpdateAnimator()
  P.Repaint()
end

-- Several addons often load in the same moment; one look covers them all.
local scanQueued = false
local function QueueScan()
  if scanQueued or not P.DB then return end
  scanQueued = true
  C_Timer.After(0, function() scanQueued = false; P.ScanFrames() end)
end
P.QueueScan = QueueScan

P.On("ADDON_LOADED", function() QueueScan() end)
P.On("PLAYER_ENTERING_WORLD", function()
  P.ScanFrames()
  for _, delay in ipairs(LOGIN_SCANS) do C_Timer.After(delay, P.ScanFrames) end
end)

P.OnInitialize(function()
  if type(PlayerFrame_UpdateArt) == "function" then
    hooksecurefunc("PlayerFrame_UpdateArt", function() P.ScanFrames(); P.Repaint() end)
  end
  -- AzeriteUI can switch a player frame on later (its alternate frame, a theme)
  C_Timer.NewTicker(SAFETY_SCAN, P.ScanFrames)
  P.ScanFrames()
end)

P.OnProfileChanged(function() P.RefreshOptionalBars() end)
