---@diagnostic disable: undefined-global, undefined-field
--[[
AzUI_Color_Picker.lua
Custom colour, rainbow/pulse animations, presets and hunter-pet colours for your
own health bar on AzeriteUI (5.x, JuNNeZ Edition, AzeriteUI6) and the default
Blizzard player frame, plus the AzeriteUI pet frame.

The saved colour (DB.profile.color) only changes when you pick a colour.
Animations and pet colours are worked out at display time and never saved.
Every bar belongs to a channel: "player" (your health bar) or "pet" (the pet frame).
A pet's colour goes to one or both channels; the other keeps your own colour.
]]--

---------------------------------------------------------------------
-- SETUP & LIBS
---------------------------------------------------------------------
local addonName = ...
local addon     = CreateFrame("Frame")

local AceConfig         = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB             = LibStub("AceDB-3.0")
local AceAddon          = LibStub("AceAddon-3.0", true)
local LDB               = LibStub("LibDataBroker-1.1", true)
local DBIcon            = LibStub("LibDBIcon-1.0", true)
local L                 = setmetatable({}, { __index = function(_, key) return key end })

local VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or ""

local PI, TWO_PI = math.pi, 2 * math.pi
local sin, abs, floor, min, max, random = math.sin, math.abs, math.floor, math.min, math.max, math.random

local PHASE_RATE     = 0.3     -- radians per second at speed 1.0 (one rainbow cycle ~21 s)
local FRAME_INTERVAL = 1 / 30  -- animation repaint cap
local CHAOS_INTERVAL = 0.1     -- Chaos picks a new colour this often
local SCAN_INTERVAL  = 2       -- seconds between looks for late-created frames

-- AceAddon names of the retail AzeriteUI editions (JuNNeZ Edition also registers "AzeriteUI")
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

-- Call Pet 1-5. The summoned pet's Call Pet spell stays current, which is how Blizzard's stable finds it.
local CALL_PET_SPELLS  = { 883, 83242, 83243, 83244, 83245 }
local TAME_BEAST_SPELL = 1515
local COMPANION_SLOT   = 6 -- Beast Mastery's second pet; stabled pets come after it
local ADDON_ICON       = "Interface\\AddOns\\AzUI_Color_Picker\\icon.tga"
local ICON_COORDS      = { 0.08, 0.92, 0.08, 0.92 } -- trims the border off spell and pet icons

---------------------------------------------------------------------
-- DEFAULTS
---------------------------------------------------------------------
local defaults = {
  profile = {
    color                = { 0.7, 0.1, 0.1, 1 }, -- RGBA, only changed by the user
    rainbowActive        = false,
    rainbowSpeed         = 1,       -- 0.1-5 speed multiplier shared by rainbow and pulse
    rainbowMode          = "cycle", -- cycle | ping | chaos
    pulseActive          = false,
    presets              = {},
    defaultPresetsSeeded = false,
    debug                = false,
    petColouring         = false,   -- toggle hunter-pet colours
    petTarget            = "both",  -- both | player | pet: where pet colours are shown
    pets                 = {},      -- [petNumber] = { mode = family|custom|off, color = RGBA, effect = static|pulse|rainbow }
    familyColours        = {},      -- [familyID] = RGBA replacing the built-in family colour
  },
  char = {
    knownPets = {},                 -- [petNumber] = { name, icon, familyName, familyID, specialization, slot }
  },
  global = {
    minimap   = { hide = false, showInCompartment = true },
    familyIDs = {},                 -- [family name in the client language] = family ID
  },
}

-- Colour-blind friendly presets, added once per profile
local cbPresets = {
  ["CB-Blue"]   = {0.2,0.4,0.9,1},
  ["CB-Orange"] = {0.9,0.5,0.1,1},
  ["CB-Yellow"] = {0.9,0.9,0.2,1},
  ["CB-Purple"] = {0.6,0.3,0.8,1},
}

-- Hunter pet families and their fallback colours, keyed by creature family ID so they work
-- on every client language (UnitCreatureFamily returns the ID as its 2nd value).
-- Each entry is { familyID, name, r, g, b }.
local FAMILY_GROUPS = {
  { name = "Exotics", families = {
    { 46,  "Spirit Beast",  0.00, 1.00, 1.00 }, -- cyan aura
    { 39,  "Devilsaur",     0.90, 0.20, 0.10 }, -- blood-red scales
    { 45,  "Core Hound",    1.00, 0.35, 0.25 }, -- fiery magma
    { 38,  "Chimaera",      0.25, 0.80, 1.00 }, -- frost-blue breath
    { 43,  "Clefthoof",     0.55, 0.35, 0.25 }, -- earthen hide
    { 138, "Direhorn",      0.60, 0.40, 0.20 }, -- muddy horn
    { 156, "Scalehide",     0.40, 0.70, 0.30 }, -- mossy scales
    { 55,  "Shale Beast",   0.65, 0.50, 0.75 }, -- crystalline purple
    { 128, "Stone Hound",   0.50, 0.70, 0.90 }, -- azure stone
    { 126, "Water Strider", 0.20, 0.60, 0.80 }, -- teal water walker
    { 68,  "Hydra",         0.25, 0.75, 0.55 }, -- emerald scales
    { 41,  "Aqiri",         0.85, 0.45, 0.15 }, -- bronze carapace
    { 150, "Riverbeast",    0.35, 0.65, 0.45 }, -- swamp green
    { 42,  "Worm",          0.70, 0.55, 0.25 }, -- sandy burrower
    { 292, "Carapid",       0.70, 0.30, 0.80 }, -- purple chitin
    { 290, "Pterrordax",    0.80, 0.60, 0.30 }, -- amber wing
  } },
  { name = "Mammals", families = {
    { 4,   "Bear",        0.45, 0.35, 0.25 }, -- brown fur
    { 5,   "Boar",        0.60, 0.40, 0.30 }, -- tusky brown
    { 2,   "Cat",         1.00, 0.50, 0.50 }, -- pale pink
    { 50,  "Fox",         0.95, 0.45, 0.20 }, -- orange fur
    { 9,   "Gorilla",     0.40, 0.40, 0.40 }, -- grey shadow
    { 25,  "Hyena",       0.80, 0.60, 0.25 }, -- savannah
    { 51,  "Monkey",      0.65, 0.55, 0.40 }, -- jungle brown
    { 157, "Oxen",        0.50, 0.45, 0.35 }, -- taupe
    { 127, "Rodent",      0.75, 0.65, 0.55 }, -- whiskered grey
    { 12,  "Tallstrider", 0.85, 0.70, 0.20 }, -- savannah yellow
    { 298, "Camel",       0.75, 0.65, 0.45 }, -- desert beige
    { 299, "Courser",     0.90, 0.80, 0.60 }, -- golden stallion
    { 160, "Feathermane", 0.75, 0.50, 0.85 }, -- majestic plum
    { 129, "Gruffhorn",   0.55, 0.45, 0.30 }, -- rough hide
    { 52,  "Hound",       0.60, 0.50, 0.40 }, -- loyal brown
    { 300, "Mammoth",     0.65, 0.55, 0.45 }, -- tusked grey
    { 151, "Stag",        0.50, 0.70, 0.40 }, -- forest green
    { 1,   "Wolf",        0.45, 0.50, 0.55 }, -- pack grey
  } },
  { name = "Birds", families = {
    { 7,   "Carrion Bird", 0.75, 0.35, 0.20 }, -- vulture red-brown
    { 26,  "Bird of Prey", 0.95, 0.85, 0.30 }, -- golden feather
    { 30,  "Dragonhawk",   0.90, 0.30, 0.30 }, -- fiery wings
    { 31,  "Ravager",      0.80, 0.40, 0.20 }, -- rust chitin
    { 37,  "Moth",         0.80, 0.75, 0.85 }, -- soft lilac
    { 24,  "Bat",          0.30, 0.25, 0.35 }, -- night wing
    { 125, "Waterfowl",    0.40, 0.70, 0.90 }, -- lake blue
  } },
  { name = "Reptiles & Amphibians", families = {
    { 130, "Basilisk",     0.35, 0.75, 0.60 }, -- jade hide
    { 8,   "Crab",         0.90, 0.30, 0.30 }, -- scarlet shell
    { 6,   "Crocolisk",    0.30, 0.70, 0.35 }, -- swamp reptile
    { 11,  "Raptor",       0.80, 0.45, 0.20 }, -- rust scales
    { 35,  "Serpent",      0.15, 0.75, 0.40 }, -- emerald serpent
    { 21,  "Turtle",       0.20, 0.60, 0.30 }, -- jade shell
    { 288, "Lizard",       0.55, 0.80, 0.35 }, -- lime scales
    { 315, "Whiptail",     0.60, 0.75, 0.30 }, -- olive scales
    { 33,  "Sporebat",     0.55, 0.80, 0.90 }, -- cyan spores
    { 291, "Hopper",       0.60, 0.80, 0.50 }, -- leap green
    { 34,  "Ray",          0.70, 0.60, 0.90 }, -- ethereal purple
    { 27,  "Wind Serpent", 0.50, 0.90, 0.70 }, -- airy teal
  } },
  { name = "Insects & Arachnids", families = {
    { 3,   "Spider",  0.45, 0.45, 0.55 }, -- web grey
    { 44,  "Wasp",    1.00, 0.85, 0.15 }, -- yellow stinger
    { 53,  "Beetle",  0.30, 0.70, 0.55 }, -- jade carapace
    { 20,  "Scorpid", 0.85, 0.70, 0.30 }, -- desert amber
  } },
  { name = "Mechanical & Special", families = {
    { 154, "Mechanical",       0.50, 0.80, 1.00 }, -- arcane blue steel
    { 296, "Blood Beast",      0.80, 0.15, 0.20 }, -- crimson blood
    { 303, "Lesser Dragonkin", 0.60, 0.40, 0.85 }, -- dragon purple
    { 32,  "Warp Stalker",     0.85, 0.50, 0.95 }, -- void pink
  } },
}

local familyColours, familyNames, familyIDsByName = {}, {}, {}
for _, group in ipairs(FAMILY_GROUPS) do
  for _, family in ipairs(group.families) do
    local id = family[1]
    familyColours[id] = { family[3], family[4], family[5], 1 }
    familyNames[id] = family[2]
    familyIDsByName[family[2]] = id -- English names, for stabled pets not yet seen out on this client
  end
end

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local DB
local optionsRegistered = false
local isHunter = false
local selectedPreset, renameBuffer = nil, ""
local currentPet            -- { number, name, icon, familyName, familyID } of the pet that is out; hunter pets have a number
local activePet             -- { color, effect } while a coloured pet is out (never saved)
local petSuppressed = false -- you picked a colour or effect while the pet colour was on your health bar
local animPhase, frameElapsed, chaosElapsed = 0, 0, 0
local chaosColour = { random(), random(), random() }

local targets       = setmetatable({}, { __mode = "k" }) -- health bar -> brightness factor
local channels      = setmetatable({}, { __mode = "k" }) -- health bar -> "player" | "pet"
local blizzardBars  = setmetatable({}, { __mode = "k" })
local textureOwners = setmetatable({}, { __mode = "k" }) -- bar texture -> health bar
local painting      = setmetatable({}, { __mode = "k" })
local knownFrames   = setmetatable({}, { __mode = "k" })

local BuildPetOptions -- rebuilds the Hunter Pets page; defined with the options table

---------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------
local function Print(msg) print("|cffff8800[AzUI Color Picker]|r " .. tostring(msg)) end
local function debugLog(msg) if DB and DB.profile.debug then Print(msg) end end

local function isAccessibleValue(value)
  if issecretvalue and issecretvalue(value) then return false end
  return value ~= nil
end

local function accessible(value)
  if isAccessibleValue(value) then return value end
end

local function copyColour(c) return { c[1], c[2], c[3], c[4] or 1 } end

local function SpellIcon(spellID)
  if not (C_Spell and C_Spell.GetSpellTexture) then return end
  local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
  if ok then return accessible(icon) end
end

local function RefreshOptions()
  if optionsRegistered then AceConfigRegistry:NotifyChange(addonName) end
end

---------------------------------------------------------------------
-- DISPLAY COLOUR
---------------------------------------------------------------------
-- 0-1 hue to RGB for the Ping-Pong pattern
local function hsvToRgb(h)
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

-- A colour with an effect applied. Rainbow ignores the colour's RGB but keeps its alpha.
local function EffectColour(effect, c)
  local a = c and c[4] or 1
  if effect == "rainbow" then
    local mode = DB.profile.rainbowMode
    if mode == "chaos" then
      return chaosColour[1], chaosColour[2], chaosColour[3], a
    elseif mode == "ping" then
      -- sweep hue 0 -> 1 -> 0
      local x = animPhase % TWO_PI
      if x > PI then x = TWO_PI - x end
      local r, g, b = hsvToRgb(x / PI)
      return r, g, b, a
    end
    return 0.5 + 0.5 * sin(animPhase),
           0.5 + 0.5 * sin(animPhase + TWO_PI / 3),
           0.5 + 0.5 * sin(animPhase + 2 * TWO_PI / 3), a
  elseif effect == "pulse" then
    local s = 0.3 + 0.7 * abs(sin(animPhase))
    return c[1] * s, c[2] * s, c[3] * s, a
  end
  return c[1], c[2], c[3], a
end

local function PlayerEffect()
  local p = DB.profile
  return p.rainbowActive and "rainbow" or p.pulseActive and "pulse" or "static"
end

-- Does the pet colour belong on this channel right now?
local function ShowsPetColour(channel)
  if not activePet or (channel == "player" and petSuppressed) then return false end
  local target = DB.profile.petTarget
  return target == "both" or target == channel
end

local function ChannelEffect(channel)
  if ShowsPetColour(channel) then return activePet.effect end
  return PlayerEffect()
end

-- The colour a channel shows: the pet colour where it applies, otherwise your own colour and effect
local function ChannelColour(channel)
  if ShowsPetColour(channel) then return EffectColour(activePet.effect, activePet.color) end
  return EffectColour(PlayerEffect(), DB.profile.color)
end

---------------------------------------------------------------------
-- PAINTING & HOOKS
---------------------------------------------------------------------
local function applyColour(bar, r, g, b, a)
  if blizzardBars[bar] then
    -- Blizzard already locks the player bar colour; only set it where a client doesn't.
    if bar.lockColor ~= true then bar.lockColor = true end
    -- The default bar art is coloured; desaturate it so the tint shows the real colour.
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
end

local function paintBar(bar, r, g, b, a)
  local factor = targets[bar]
  if not factor then return end
  painting[bar] = true
  local ok, err = pcall(applyColour, bar, r * factor, g * factor, b * factor, a)
  painting[bar] = nil
  if not ok then debugLog(err) end
end

local function Repaint()
  if not DB then return end
  local r, g, b, a = ChannelColour("player")
  local pr, pg, pb, pa = ChannelColour("pet")
  for bar in pairs(targets) do
    if channels[bar] == "pet" then
      paintBar(bar, pr, pg, pb, pa)
    else
      paintBar(bar, r, g, b, a)
    end
  end
end

-- Another addon (or Blizzard) recoloured a bar: put ours back in the same frame.
local function RepaintBar(bar)
  if DB and not painting[bar] then paintBar(bar, ChannelColour(channels[bar])) end
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
  if type(bar.SetStatusBarColor) == "function" then pcall(hooksecurefunc, bar, "SetStatusBarColor", onBarColour) end
  if type(bar.SetStatusBarTexture) == "function" then pcall(hooksecurefunc, bar, "SetStatusBarTexture", onBarTexture) end
  hookTexture(bar)
  RepaintBar(bar)
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

local function registerUnitFrame(frame, channel)
  if type(frame) ~= "table" or knownFrames[frame] or type(frame.Health) ~= "table" then return end
  knownFrames[frame] = true
  addTarget(frame.Health, 1, channel)
  if type(frame.Health.Preview) == "table" then
    addTarget(frame.Health.Preview, PREVIEW_FACTOR[channel], channel)
  end
  debugLog("Colouring AzeriteUI frame " .. tostring(frame.GetName and frame:GetName() or "?"))
end

local function ScanFrames()
  if not DB then return end
  if AceAddon then
    for i = 1, #AZERITE_ADDONS do
      local aui = AceAddon:GetAddon(AZERITE_ADDONS[i], true)
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
  local blizzardBar = GetBlizzardPlayerHealthBar()
  if blizzardBar and not targets[blizzardBar] then
    blizzardBars[blizzardBar] = true
    addTarget(blizzardBar, 1, "player")
  end
end

---------------------------------------------------------------------
-- ANIMATIONS
---------------------------------------------------------------------
local animator = CreateFrame("Frame")
animator:Hide()
animator:SetScript("OnUpdate", function(_, elapsed)
  local speed = min(5, max(0.1, tonumber(DB.profile.rainbowSpeed) or 1))
  animPhase = animPhase + elapsed * speed * PHASE_RATE
  chaosElapsed = chaosElapsed + elapsed
  if chaosElapsed >= CHAOS_INTERVAL then
    chaosElapsed = 0
    chaosColour[1], chaosColour[2], chaosColour[3] = random(), random(), random()
  end
  frameElapsed = frameElapsed + elapsed
  if frameElapsed >= FRAME_INTERVAL then
    frameElapsed = 0
    Repaint()
  end
end)

local function UpdateAnimator()
  if ChannelEffect("player") ~= "static" or ChannelEffect("pet") ~= "static" then
    animator:Show()
  else
    animator:Hide()
  end
end

local function SetAnimation(rainbow, pulse)
  local p = DB.profile
  p.rainbowActive, p.pulseActive = rainbow, pulse
  animPhase, frameElapsed, chaosElapsed = 0, 0, 0
  -- starting an effect shows on your health bar now; the pet colour returns when the pet changes
  if rainbow or pulse then petSuppressed = true end
  UpdateAnimator()
  Repaint()
end

local function ToggleRainbow() SetAnimation(not DB.profile.rainbowActive, false) end
local function TogglePulse() SetAnimation(false, not DB.profile.pulseActive) end

---------------------------------------------------------------------
-- USER COLOUR
---------------------------------------------------------------------
local function SetUserColour(r, g, b, a)
  local c = DB.profile.color
  c[1], c[2], c[3], c[4] = r, g, b, a or c[4] or 1
  petSuppressed = true -- show the picked colour now; the pet colour returns on the next pet change
  SetAnimation(false, false)
end

---------------------------------------------------------------------
-- HUNTER PETS
---------------------------------------------------------------------
local function FamilyColour(familyID)
  return familyID and (DB.profile.familyColours[familyID] or familyColours[familyID])
end

local function PetMode(number)
  local settings = number and DB.profile.pets[number]
  return settings and settings.mode or "family"
end

local function PetEffect(number)
  local settings = number and DB.profile.pets[number]
  return settings and settings.effect or "static"
end

local function EnsurePetSettings(number)
  local pets = DB.profile.pets
  if not pets[number] then pets[number] = { mode = "family", effect = "static" } end
  return pets[number]
end

-- Older versions coloured a pet with a preset named after it; turn that into the pet's own colour once
local function MigrateNamePreset(number, name)
  local p = DB.profile
  if not number or not name or p.pets[number] or not p.presets[name] then return end
  p.pets[number] = { mode = "custom", color = copyColour(p.presets[name]), effect = "static" }
end

-- The colour a pet shows, or nil: its own colour, a preset named after a pet the stable
-- does not know (such as another class's pet), or its family colour
local function PetColour(number, name, familyID)
  local mode = PetMode(number)
  if mode == "off" then return nil end
  if mode == "custom" and DB.profile.pets[number].color then return DB.profile.pets[number].color end
  if not number and name and DB.profile.presets[name] then return DB.profile.presets[name] end
  return FamilyColour(familyID)
end

-- Keep what the stable told us about a pet, so the Hunter Pets page can list it later.
-- Returns the pet's number and whether the list changed.
local function RememberPet(info)
  local number = type(info) == "table" and tonumber(info.petNumber)
  if not number or number <= 0 then return end
  local known = DB.char.knownPets
  local pet = known[number]
  local changed = not pet or pet.name ~= info.name or pet.slot ~= info.slotID or pet.icon ~= info.icon
  if not pet then
    pet = {}
    known[number] = pet
  end
  pet.name, pet.slot, pet.icon = info.name, info.slotID, info.icon
  pet.familyName, pet.specialization = info.familyName, info.specialization
  local familyName = info.familyName or ""
  pet.familyID = pet.familyID or DB.global.familyIDs[familyName] or familyIDsByName[familyName]
  return number, changed
end

local function RefreshKnownPets()
  if not DB or not isHunter or not C_StableInfo then return false end
  local seen, changed = {}, false
  local function remember(getList)
    local ok, list = pcall(getList)
    if not ok or type(list) ~= "table" then return end
    for _, info in ipairs(list) do
      local number, isChanged = RememberPet(info)
      if number then
        seen[number] = true
        changed = changed or isChanged
      end
    end
  end
  remember(C_StableInfo.GetActivePetList)
  remember(C_StableInfo.GetStabledPetList)
  -- Only a stable master shows every pet, so only forget abandoned pets there
  if next(seen) and C_StableInfo.IsAtStableMaster and C_StableInfo.IsAtStableMaster() then
    local known = DB.char.knownPets
    for number in pairs(known) do
      if not seen[number] then
        known[number] = nil
        changed = true
      end
    end
  end
  return changed
end

-- The summoned hunter pet's stable entry. Unlike UnitName this still works when the game hides unit names.
local function GetSummonedPetInfo()
  if not isHunter or not (C_StableInfo and C_StableInfo.GetStablePetInfo) then return end
  local name = accessible(UnitName("pet"))
  if C_Spell and C_Spell.IsCurrentSpell then
    for slot = 1, #CALL_PET_SPELLS do
      local ok, current = pcall(C_Spell.IsCurrentSpell, CALL_PET_SPELLS[slot])
      if ok and isAccessibleValue(current) and current then
        local info = C_StableInfo.GetStablePetInfo(slot)
        if type(info) == "table" and (not name or info.name == name) then return info end
      end
    end
  end
  local ok, list = pcall(C_StableInfo.GetActivePetList)
  if name and ok and type(list) == "table" then
    for _, info in ipairs(list) do
      if info.name == name then return info end
    end
  end
end

-- Note the pet's family while the game shows it, so other pets of that family get its colour too
local function ReadPetFamily(pet)
  local familyName, familyID = UnitCreatureFamily("pet")
  familyName, familyID = accessible(familyName), accessible(familyID)
  if familyID then
    if familyName then DB.global.familyIDs[familyName] = familyID end
    if pet then pet.familyID = familyID end
  end
  return familyName or (pet and pet.familyName), familyID or (pet and pet.familyID)
end

-- Work out which pet is out and the colour it brings
local function ResolvePet()
  currentPet, activePet = nil, nil
  if not UnitExists("pet") then return end
  local info = GetSummonedPetInfo()
  local number = info and RememberPet(info)
  local pet = number and DB.char.knownPets[number]
  local familyName, familyID = ReadPetFamily(pet)
  local name = pet and pet.name or accessible(UnitName("pet"))
  currentPet = { number = number, name = name, icon = pet and pet.icon, familyName = familyName, familyID = familyID }
  MigrateNamePreset(number, name)
  if not DB.profile.petColouring then return end
  local colour, effect = PetColour(number, name, familyID), PetEffect(number)
  if colour or (effect == "rainbow" and PetMode(number) ~= "off") then
    activePet = { color = colour, effect = effect }
  end
end

-- Recolour for the current pet without touching the options panel (safe while a colour picker is open)
local function ApplyPetColour()
  if not DB then return end
  ResolvePet()
  UpdateAnimator()
  Repaint()
end

-- A pet or pet setting changed: recolour and rebuild the Hunter Pets page
local function UpdatePetColour()
  if not DB then return end
  petSuppressed = false
  ApplyPetColour()
  BuildPetOptions()
  RefreshOptions()
end

---------------------------------------------------------------------
-- PRESETS
---------------------------------------------------------------------
local function ensureDefaultPresets()
  local p = DB.profile
  if p.defaultPresetsSeeded then return end
  for name, colour in pairs(cbPresets) do
    if not p.presets[name] then p.presets[name] = copyColour(colour) end
  end
  p.defaultPresetsSeeded = true
end

local function SaveNamedPreset(name)
  name = name and strtrim(name) or ""
  if name == "" then return end
  DB.profile.presets[name] = copyColour(DB.profile.color)
  selectedPreset = name
  UpdatePetColour() -- the name may belong to the active pet; also refreshes the panel
end

local function LoadPreset(name)
  local c = DB.profile.presets[name]
  if not c then return end
  selectedPreset = name
  SetUserColour(c[1], c[2], c[3], c[4])
end

local function DeletePreset()
  if not selectedPreset then return end
  DB.profile.presets[selectedPreset] = nil
  selectedPreset = nil
  UpdatePetColour()
end

local function RenamePreset(newName)
  newName = strtrim(newName or "")
  local presets = DB.profile.presets
  if not selectedPreset or not presets[selectedPreset] or newName == "" or newName == selectedPreset then
    return false
  end
  if presets[newName] then
    Print(L["A preset with that name already exists:"] .. " " .. newName)
    return false
  end
  presets[newName], presets[selectedPreset] = presets[selectedPreset], nil
  selectedPreset = newName
  UpdatePetColour()
  return true
end

-- Give the pet that is out the colour from the colour picker
local function SaveColourToCurrentPet()
  if not currentPet then return end
  if currentPet.number then
    local settings = EnsurePetSettings(currentPet.number)
    settings.mode, settings.color = "custom", copyColour(DB.profile.color)
    UpdatePetColour()
  elseif currentPet.name then
    SaveNamedPreset(currentPet.name) -- pets the stable does not know keep using a preset named after them
  end
end

---------------------------------------------------------------------
-- POPUP DIALOGS
---------------------------------------------------------------------
StaticPopupDialogs["AZUI_NAME_PRESET"] = {
  text = L["Enter a name for your new preset:"],
  button1 = SAVE,
  button2 = CANCEL,
  hasEditBox = true,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
  OnAccept = function(self)
    local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
    SaveNamedPreset(editBox and editBox:GetText())
  end,
  EditBoxOnEnterPressed = function(self)
    SaveNamedPreset(self:GetText())
    self:GetParent():Hide()
  end,
}

StaticPopupDialogs["AZUI_RESET_CONFIRM"] = {
  text    = L["This will reset all settings and delete your presets and pet colours in the current profile. Are you sure?"],
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
  OnAccept = function() DB:ResetProfile() end, -- OnProfileReset does the rest
}

---------------------------------------------------------------------
-- OPTIONS TABLE
---------------------------------------------------------------------
local opts = { name = addonName, type = "group", childGroups = "tree", args = {} }
opts.args.ver = { type = "description", name = "|cff999999Version " .. VERSION, order = 0 }

local general = { type = "group", name = L["Health Bar"], icon = ADDON_ICON, order = 1, args = {} }
opts.args.general = general

general.args.col = {
  type = "color", name = L["Healthbar Colour"],
  desc = L["Pick a custom RGB-A colour for your own health bar. Alpha controls transparency."],
  hasAlpha = true, order = 1,
  get = function() local c = DB.profile.color; return c[1], c[2], c[3], c[4] or 1 end,
  set = function(_, r, g, b, a) SetUserColour(r, g, b, a) end,
}

-- class colours section
general.args.clsH1 = { type = "header", name = L["Class Colours"], order = 1.5 }
general.args.clsG = { type = "group", inline = true, name = "", order = 1.6, args = {} }
for class, cc in pairs(RAID_CLASS_COLORS) do
  local classColor = cc
  local male = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]
  local female = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[class]
  local name = male or female or class
  if male and female and female ~= male then
    name = male .. " / " .. female
  end
  general.args.clsG.args[class] = {
    type = "execute",
    name = name,
    func = function() SetUserColour(classColor.r, classColor.g, classColor.b) end,
  }
end

-- fun options
general.args.funH = { type = "header", name = L["Fun Options"], order = 1.8 }
general.args.classReset = {
  type = "execute", name = L["Class Colour"],
  desc = L["Reset to your class's default colour."], order = 1.81,
  func = function()
    local c = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
    if c then SetUserColour(c.r, c.g, c.b) end
  end,
}
general.args.rand = {
  type = "execute", name = L["Random Colour"],
  desc = L["Generate a random colour (keeps alpha)."], order = 1.82,
  func = function() SetUserColour(random(), random(), random()) end,
}
general.args.speed = {
  type = "range",
  name = L["Animation Speed"],
  desc = L["How fast the rainbow and pulse effects run, including pet effects. At 1.0 a rainbow cycle takes about 21 seconds and a pulse about 10 seconds; 2.0 is twice as fast."],
  order = 1.83,
  min = 0.1, max = 5, step = 0.1,
  get = function() return DB.profile.rainbowSpeed end,
  set = function(_, v) DB.profile.rainbowSpeed = v end,
}
general.args.pattern = {
  type = "select",
  name = L["Rainbow Pattern"],
  desc = L["Choose the animation style for the rainbow effect, including pet rainbows."],
  order = 1.835,
  values = { cycle = "Cycle", ping = "Ping-Pong", chaos = "Chaos" },
  get = function() return DB.profile.rainbowMode end,
  set = function(_, v) DB.profile.rainbowMode = v; Repaint() end,
}
general.args.rainToggle = {
  type  = "execute",
  name  = function() return DB.profile.rainbowActive and L["Stop Rainbow Effect"] or L["Rainbow Effect"] end,
  desc  = L["Toggle the animated rainbow effect."],
  order = 1.84,
  func  = ToggleRainbow,
}
general.args.pulseToggle = {
  type  = "execute",
  name  = function() return DB.profile.pulseActive and L["Stop Pulse"] or L["Pulse Colour"] end,
  desc  = L["Toggle a gentle pulse on the current colour."],
  order = 1.86,
  func  = TogglePulse,
}

-- preset section
general.args.presH = { type = "header", name = L["Presets"], order = 2 }
general.args.sel = {
  type = "select", name = L["Select Preset"],
  desc = L["Apply a saved colour preset."], order = 2.1,
  values = function() local t = {}; for k in pairs(DB.profile.presets) do t[k] = k end return t end,
  get = function() return selectedPreset end,
  set = function(_, v) LoadPreset(v) end,
}
general.args.renBox = {
  type = "input", name = L["Rename To:"], order = 2.2,
  get = function() return renameBuffer end,
  set = function(_, v) renameBuffer = v end,
  disabled = function() return not selectedPreset end,
}
general.args.renBtn = {
  type = "execute", name = L["Rename Preset"],
  desc = L["Rename the selected preset. Names already in use are refused."], order = 2.3,
  func = function() if RenamePreset(renameBuffer) then renameBuffer = "" end end,
  disabled = function()
    local newName = strtrim(renameBuffer or "")
    return not selectedPreset or newName == "" or newName == selectedPreset
  end,
}
general.args.delBtn = {
  type = "execute", name = L["Delete Preset"],
  desc = L["Delete the selected preset."], order = 2.4,
  func = DeletePreset,
  disabled = function() return not selectedPreset end,
}
general.args.save = {
  type = "execute", name = L["Save as Preset"],
  desc = L["Save the current colour as a new preset."], order = 2.5,
  func = function() StaticPopup_Show("AZUI_NAME_PRESET") end,
}
general.args.savePet = {
  type = "execute", name = L["Save to Current Pet"],
  desc = L["Give your active pet the colour from the colour picker as its own colour."], order = 2.6,
  func = SaveColourToCurrentPet,
  disabled = function() return not UnitExists("pet") end,
}

-- maintenance
general.args.mainH = { type = "header", name = L["Maintenance"], order = 3 }
general.args.reset = {
  type = "execute", name = L["Reset to Defaults"],
  desc = L["Reset all settings, presets and pet colours in the current profile to factory defaults."], order = 3.1,
  func = function() StaticPopup_Show("AZUI_RESET_CONFIRM") end,
}
general.args.reload = {
  type = "execute",
  name = L["Reload"],
  desc = L["Reloads your UI. All colour and preset changes are saved instantly - this button just forces a /reload."],
  order = 3.2,
  func = function() ReloadUI() end,
}
general.args.minimapToggle = {
  type = "toggle",
  name = L["Show Minimap Icon"],
  desc = L["Toggle the minimap launcher button."],
  order = 3.25,
  get = function() return DB and not DB.global.minimap.hide end,
  set = function(_, v)
    DB.global.minimap.hide = not v
    if DBIcon then if v then DBIcon:Show(addonName) else DBIcon:Hide(addonName) end end
  end,
}
general.args.debugT = {
  type = "toggle", name = L["Enable Debug"], order = 90,
  get = function() return DB and DB.profile.debug end,
  set = function(_, v) DB.profile.debug = v end,
}
general.args.creditH = { type = "header", name = L[""], order = 91 }
general.args.credit = { type = "description", name = "|cff888888Made with love by JuNNeZ — code assisted by ChatGPT", order = 99 }

---------------------------------------------------------------------
-- HUNTER PETS PAGE
---------------------------------------------------------------------
local MODE_VALUES    = { family = L["Family colour"], custom = L["Own colour"], off = L["No pet colour"] }
local MODE_SORTING   = { "family", "custom", "off" }
local EFFECT_VALUES  = { static = L["None"], pulse = L["Pulse"], rainbow = L["Rainbow"] }
local EFFECT_SORTING = { "static", "pulse", "rainbow" }

local petsGroup = {
  type = "group", name = L["Hunter Pets"], order = 2, args = {},
  icon = function() return currentPet and currentPet.icon or SpellIcon(CALL_PET_SPELLS[1]) end,
  iconCoords = ICON_COORDS,
}
opts.args.pets = petsGroup

local stabledGroup = { type = "group", name = L["Stabled Pets"], order = 1000, args = {} }
local stabledHelp = {
  type = "description", order = 1,
  name = L["Pets in your stable. A colour or effect you give them here shows when you call them."],
}

local function CurrentPetText()
  if not currentPet then return L["No pet out."] end
  local text = L["Out now:"] .. " |cffffffff" .. (currentPet.name or L["your pet"]) .. "|r"
  if currentPet.familyName then text = text .. " (" .. currentPet.familyName .. ")" end
  if not DB.profile.petColouring then
    text = text .. "\n|cff999999" .. L["Turn on Use Pet Colours to show its colour."] .. "|r"
  elseif not activePet then
    text = text .. "\n|cff999999" .. L["This pet has no colour to show."] .. "|r"
  end
  return text
end

local petStatic = {
  enable = {
    type = "toggle", name = L["Use Pet Colours"], width = "full", order = 1,
    desc = L["While a pet is out, show its colour: its own colour or effect from this page, or its family colour. Your own colour and effects come back when the pet is dismissed."],
    get = function() return DB.profile.petColouring end,
    set = function(_, v) DB.profile.petColouring = v; UpdatePetColour() end,
  },
  target = {
    type = "select", name = L["Show Pet Colours On"], width = "double", order = 2,
    desc = L["Where a pet's colour goes. The other bar keeps your own colour and effect. The pet frame is AzeriteUI's."],
    values = { both = L["Health bar and pet frame"], player = L["Health bar only"], pet = L["Pet frame only"] },
    sorting = { "both", "player", "pet" },
    get = function() return DB.profile.petTarget end,
    set = function(_, v) DB.profile.petTarget = v; UpdatePetColour() end,
    disabled = function() return not DB.profile.petColouring end,
  },
  current = {
    type = "description", fontSize = "medium", order = 3,
    name = CurrentPetText,
    image = function() return currentPet and currentPet.icon end,
    imageCoords = ICON_COORDS, imageWidth = 32, imageHeight = 32,
  },
  help = {
    type = "description", order = 4,
    name = L["Pick a pet on the left to give it its own colour or effect. Pets without one use their family colour, which you can change under Pet Families. If a stabled pet is missing, visit a stable master."],
    hidden = function() return not isHunter end,
  },
  otherHelp = {
    type = "description", order = 4,
    name = L["Your pet uses a preset named after it, or its family colour from Pet Families."],
    hidden = function() return isHunter end,
  },
}

local function PetSummary(number, pet)
  local text = pet.familyName or familyNames[pet.familyID] or L["Unknown family"]
  if pet.specialization and pet.specialization ~= "" then text = text .. " · " .. pet.specialization end
  if pet.slot and pet.slot <= #CALL_PET_SPELLS then
    text = text .. "\n" .. L["Call Pet"] .. " " .. pet.slot
  elseif pet.slot == COMPANION_SLOT then
    text = text .. "\n" .. L["Second pet slot"]
  else
    text = text .. "\n" .. L["Stabled"]
  end
  if currentPet and currentPet.number == number then
    text = text .. " · |cff00ff00" .. L["Out now"] .. "|r"
  end
  return text
end

local function PetGroup(number, pet, order)
  local function isOff() return PetMode(number) == "off" end
  return {
    type = "group", order = order, icon = pet.icon, iconCoords = ICON_COORDS,
    name = function()
      local name = pet.name or "?"
      if currentPet and currentPet.number == number then return "|cff00ff00" .. name .. "|r" end
      return name
    end,
    args = {
      info = {
        type = "description", fontSize = "medium", order = 1,
        image = pet.icon, imageCoords = ICON_COORDS, imageWidth = 40, imageHeight = 40,
        name = function() return PetSummary(number, pet) end,
      },
      mode = {
        type = "select", name = L["Colour"], order = 2,
        desc = L["Family colour: the colour for its family under Pet Families. Own colour: the colour picked here. No pet colour: this pet leaves your bars alone."],
        values = MODE_VALUES, sorting = MODE_SORTING,
        get = function() return PetMode(number) end,
        set = function(_, value)
          local settings = EnsurePetSettings(number)
          if value == "custom" and not settings.color then
            settings.color = copyColour(FamilyColour(pet.familyID) or DB.profile.color)
          end
          settings.mode = value
          UpdatePetColour()
        end,
      },
      color = {
        type = "color", name = L["Own Colour"], hasAlpha = true, order = 3,
        desc = L["Picking a colour switches this pet to its own colour."],
        get = function()
          local c = PetColour(number, pet.name, pet.familyID) or DB.profile.color
          return c[1], c[2], c[3], c[4] or 1
        end,
        set = function(_, r, g, b, a)
          local settings = EnsurePetSettings(number)
          settings.mode, settings.color = "custom", { r, g, b, a or 1 }
          petSuppressed = false
          ApplyPetColour()
        end,
        disabled = isOff,
      },
      effect = {
        type = "select", name = L["Effect"], order = 4,
        desc = L["Pulse or rainbow this pet's colour while it is out. Speed and rainbow pattern come from the Health Bar page."],
        values = EFFECT_VALUES, sorting = EFFECT_SORTING,
        get = function() return PetEffect(number) end,
        set = function(_, value) EnsurePetSettings(number).effect = value; UpdatePetColour() end,
        disabled = isOff,
      },
      reset = {
        type = "execute", name = L["Reset"], order = 5,
        desc = L["Go back to the family colour with no effect."],
        func = function()
          DB.profile.pets[number] = { mode = "family", effect = "static" }
          UpdatePetColour()
        end,
      },
    },
  }
end

BuildPetOptions = function()
  if not DB then return end
  local args, stabledArgs = petsGroup.args, stabledGroup.args
  wipe(args)
  wipe(stabledArgs)
  for key, option in pairs(petStatic) do args[key] = option end
  args.stabled, stabledArgs.help = stabledGroup, stabledHelp

  local known, numbers = DB.char.knownPets, {}
  for number, pet in pairs(known) do
    MigrateNamePreset(number, pet.name)
    numbers[#numbers + 1] = number
  end
  -- call-pet slots in slot order first, then stabled pets by name
  local function slotKey(pet)
    local slot = pet.slot or math.huge
    return slot <= COMPANION_SLOT and slot or COMPANION_SLOT + 1
  end
  table.sort(numbers, function(a, b)
    local keyA, keyB = slotKey(known[a]), slotKey(known[b])
    if keyA ~= keyB then return keyA < keyB end
    return (known[a].name or "") < (known[b].name or "")
  end)

  local numStabled = 0
  for i, number in ipairs(numbers) do
    local pet = known[number]
    if slotKey(pet) <= COMPANION_SLOT then
      args["pet" .. number] = PetGroup(number, pet, 10 + i)
    else
      numStabled = numStabled + 1
      stabledArgs["pet" .. number] = PetGroup(number, pet, 10 + i)
    end
  end
  stabledGroup.name = L["Stabled Pets"] .. " (" .. numStabled .. ")"
  stabledGroup.hidden = numStabled == 0
end

---------------------------------------------------------------------
-- PET FAMILIES PAGE
---------------------------------------------------------------------
local familiesGroup = {
  type = "group", name = L["Pet Families"], order = 3, args = {},
  icon = function() return SpellIcon(TAME_BEAST_SPELL) end,
  iconCoords = ICON_COORDS,
}
opts.args.families = familiesGroup

familiesGroup.args.help = {
  type = "description", order = 1,
  name = L["Pets without their own colour use their family's colour. A changed colour gets a Reset button next to it."],
}
familiesGroup.args.resetAll = {
  type = "execute", name = L["Reset All Families"], order = 2,
  desc = L["Put every family back to its built-in colour."],
  func = function() wipe(DB.profile.familyColours); UpdatePetColour() end,
  disabled = function() return next(DB.profile.familyColours) == nil end,
}
for groupIndex, group in ipairs(FAMILY_GROUPS) do
  local args = {}
  for familyIndex, family in ipairs(group.families) do
    local id = family[1]
    args["f" .. id] = {
      type = "color", name = family[2], order = familyIndex * 2,
      get = function() local c = FamilyColour(id); return c[1], c[2], c[3], c[4] or 1 end,
      set = function(_, r, g, b)
        DB.profile.familyColours[id] = { r, g, b, 1 }
        petSuppressed = false
        ApplyPetColour()
      end,
    }
    args["r" .. id] = {
      type = "execute", name = L["Reset"], width = "half", order = familyIndex * 2 + 1,
      func = function() DB.profile.familyColours[id] = nil; UpdatePetColour() end,
      hidden = function() return not DB.profile.familyColours[id] end,
    }
  end
  familiesGroup.args["group" .. groupIndex] = {
    type = "group", inline = true, name = group.name, order = 10 + groupIndex, args = args,
  }
end

---------------------------------------------------------------------
-- INITIALISATION & EVENTS
---------------------------------------------------------------------
function addon:OnProfileUpdated()
  selectedPreset, renameBuffer = nil, ""
  ensureDefaultPresets()
  UpdatePetColour()
end

local function ToggleOptions()
  if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[addonName] then
    AceConfigDialog:Close(addonName)
  else
    if RefreshKnownPets() then BuildPetOptions() end
    AceConfigDialog:Open(addonName)
  end
end

local function Initialize()
  DB = AceDB:New(addonName .. "DB", defaults, true)
  DB.RegisterCallback(addon, "OnProfileChanged", "OnProfileUpdated")
  DB.RegisterCallback(addon, "OnProfileCopied", "OnProfileUpdated")
  DB.RegisterCallback(addon, "OnProfileReset", "OnProfileUpdated")
  isHunter = select(2, UnitClass("player")) == "HUNTER"
  ensureDefaultPresets()

  -- Minimap, AddOn Compartment, and DataBroker launcher.
  if LDB and not addon.dataObj then
    addon.dataObj = LDB:NewDataObject(addonName, {
      type  = "launcher",
      icon  = ADDON_ICON,
      text  = "AzUI",
      label = "AzUI Colour",
      OnClick = ToggleOptions,
      OnTooltipShow = function(tt)
        tt:AddLine("AzUI Color Picker")
        tt:AddLine("Click to open options")
      end,
    })
  end
  if DBIcon and addon.dataObj and not DBIcon:IsRegistered(addonName) then
    DBIcon:Register(addonName, addon.dataObj, DB.global.minimap)
  end

  RefreshKnownPets()
  BuildPetOptions()
  AceConfig:RegisterOptionsTable(addonName, opts)
  optionsRegistered = true
  addon.optionsFrame, addon.optionsCategoryID = AceConfigDialog:AddToBlizOptions(addonName, "AzUI Color Picker")

  if type(PlayerFrame_UpdateArt) == "function" then
    hooksecurefunc("PlayerFrame_UpdateArt", function() ScanFrames(); Repaint() end)
  end
  -- AzeriteUI creates (and can later enable) its player frames after we load.
  C_Timer.NewTicker(SCAN_INTERVAL, ScanFrames)
  ScanFrames()
  UpdatePetColour()
end

addon:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      self:UnregisterEvent("ADDON_LOADED")
      Initialize()
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    ScanFrames()
    RefreshKnownPets()
    UpdatePetColour()
  elseif event == "UNIT_PET" then
    RefreshKnownPets()
    UpdatePetColour()
    -- the stable can lag behind a summon; look once more so the pet's own colour is not missed
    if isHunter and UnitExists("pet") and not (currentPet and currentPet.number) then
      C_Timer.After(1, UpdatePetColour)
    end
  elseif event == "PET_STABLE_UPDATE" or event == "PET_STABLE_SHOW" then
    if RefreshKnownPets() then UpdatePetColour() end
  end
end)
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PET_STABLE_UPDATE")
addon:RegisterEvent("PET_STABLE_SHOW")
addon:RegisterUnitEvent("UNIT_PET", "player")

---------------------------------------------------------------------
-- SLASH COMMAND
---------------------------------------------------------------------
SLASH_AZCOLORPICKER1 = "/ahui"
SlashCmdList["AZCOLORPICKER"] = ToggleOptions
