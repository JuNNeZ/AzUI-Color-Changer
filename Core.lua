---@diagnostic disable: undefined-global, undefined-field
--[[
Core.lua - AzUI Color Picker
Custom colour, effects, rules, presets and hunter-pet colours for your own health bar
on AzeriteUI (5.x, JuNNeZ Edition with every theme, AzeriteUI6), ElvUI, Shadowed and
Unhalted Unit Frames and the default Blizzard player frame, plus the pet frames and,
if you want, your power bar and cast bar.
Runs on Retail and on Forever (Camelot).

The addon is split the way the AzUI Feature Plan lays it out. Every file shares the
private table `P` (ns.P); load order is set by the TOC:

  Locales/       translations for the client's language, English where there are none
  Core.lua       saved variables, schema upgrades, events, helpers
  Effects.lua    pulse, rainbow, breathe, heartbeat, two-tone, flicker, sweep
  Pets.lua       the stable, the pet that is out, pet and family colours
  Rules.lua      colour rules: combat, mounted, resting, stealth, spec, instance, dead, auras
  Paint.lua      bars, channels, the mixer that picks a colour, fades, the painter
  Share.lua      import and export strings
  Profiles.lua   per-specialization profiles
  Options.lua    the option table, slash commands, key bindings, launcher
  QuickPalette.lua  the minimap button's right-click palette

The saved colour (profile.color) only changes when you pick a colour. Effects, rules
and pet colours are worked out at display time and never saved over it.
]]--

local addonName, ns = ...
local P = {}
ns.P = P

P.addonName = addonName
P.L = ns.L or setmetatable({}, { __index = function(_, key) return key end }) -- Locales/Locale.lua

P.AceConfig         = LibStub("AceConfig-3.0")
P.AceConfigDialog   = LibStub("AceConfigDialog-3.0")
P.AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
P.AceDB             = LibStub("AceDB-3.0")
P.AceAddon          = LibStub("AceAddon-3.0", true)
P.LDB               = LibStub("LibDataBroker-1.1", true)
P.DBIcon            = LibStub("LibDBIcon-1.0", true)

local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
P.VERSION = GetMetadata and GetMetadata(addonName, "Version") or ""
-- Forever (Camelot) shares the modern UI engine, but has a different hunter stable.
-- Trust the TOC's client marker first, then Forever's 1.6x interface numbers.
P.IS_FOREVER = (GetMetadata and GetMetadata(addonName, "X-AzUI-Client") == "Forever")
  or (function()
    local interface = select(4, GetBuildInfo())
    return type(interface) == "number" and interface >= 16000 and interface < 17000
  end)() or false

P.ADDON_ICON  = "Interface\\AddOns\\AzUI_Color_Picker\\icon.tga"
P.ICON_COORDS = { 0.08, 0.92, 0.08, 0.92 } -- trims the border off spell and pet icons

-- Raised whenever saved data needs upgrading once. See Migrate below.
P.SCHEMA = 2

---------------------------------------------------------------------
-- DEFAULTS
---------------------------------------------------------------------
P.defaults = {
  profile = {
    schema               = 0,       -- upgraded by Migrate; 0 means "not yet seen by this version"
    color                = { 0.7, 0.1, 0.1, 1 }, -- RGBA, only changed by the user
    effect               = "static", -- static | pulse | breathe | heartbeat | twotone | flicker | sweep | rainbow
    secondColor          = { 0.15, 0.35, 0.85, 1 }, -- the other colour of Two-tone
    rainbowSpeed         = 1,       -- 0.1-5 speed multiplier shared by every effect
    rainbowMode          = "cycle", -- cycle | ping | chaos
    sweepStrength        = 0.6,     -- how bright Sweep's band is, 0.1-1
    fade                 = true,    -- blend for 0.3 s when the colour's source changes
    reduceMotion         = false,   -- show every effect as its static colour
    updateRate           = 30,      -- repaints per second while something animates
    healthColour         = false,   -- colour your health bar by your health
    lowHealthColour      = { 1, 0.1, 0.1, 1 },
    presets              = {},
    presetOrder          = {},      -- preset names in the order you dragged them; new ones go last
    recentColours        = {},      -- the last eight colours you picked, newest first
    defaultPresetsSeeded = false,
    debug                = false,
    petColouring         = false,   -- toggle hunter-pet colours
    petTarget            = "both",  -- both | player | pet: where pet colours are shown
    pets                 = {},      -- [petNumber] = { mode = family|custom|off, color = RGBA, effect }
    familyColours        = {},      -- [familyID] = RGBA replacing the built-in family colour
    useSpecColours       = false,   -- family-coloured pets use their specialization's colour instead
    specColours          = {},      -- [specID] = RGBA replacing the built-in specialization colour
    rules                = {},      -- { enabled, condition, value, color, effect, target }, first match wins
    exampleRulesSeeded   = false,   -- the five example rules were offered once
    colourPetFrames      = true,    -- colour the pet frames at all ("Show on: Pet frame")
    blizzardPetFrame     = true,    -- colour Blizzard's pet frame like AzeriteUI's
    power                = { mode = "off", color = { 0.2, 0.45, 1, 1 }, effect = "static" }, -- off | health | custom
    cast                 = { mode = "off", color = { 1, 0.82, 0.2, 1 }, effect = "static" }, -- your cast bar, the same way
  },
  char = {
    knownPets    = {},              -- [petNumber] = { name, icon, displayID, familyName, familyID, specialization, specID, slot }
    specProfiles = { enabled = false }, -- [specIndex] = profile name
  },
  global = {
    minimap   = { hide = false, showInCompartment = true },
    familyIDs = {},                 -- [family name in the client language] = family ID
    panel     = { theme = "studio", opacity = 1, scale = 1, classic = false }, -- the options window
  },
}

-- Colour-blind friendly presets, added once per profile
P.cbPresets = {
  ["CB-Blue"]   = {0.2,0.4,0.9,1},
  ["CB-Orange"] = {0.9,0.5,0.1,1},
  ["CB-Yellow"] = {0.9,0.9,0.2,1},
  ["CB-Purple"] = {0.6,0.3,0.8,1},
}

---------------------------------------------------------------------
-- STATE AND HELPERS
---------------------------------------------------------------------
P.DB = nil
P.isHunter = false

function P.Print(msg) print("|cffff8800[AzUI Color Picker]|r " .. tostring(msg)) end
function P.Debug(msg) if P.DB and P.DB.profile.debug then P.Print(msg) end end

function P.IsAccessible(value)
  if issecretvalue and issecretvalue(value) then return false end
  return value ~= nil
end

function P.Accessible(value)
  if P.IsAccessible(value) then return value end
end

function P.CopyColour(c) return { c[1], c[2], c[3], c[4] or 1 } end

-- A colour as #RRGGBB
function P.Hex(c)
  return string.format("#%02X%02X%02X", math.floor(c[1] * 255 + .5), math.floor(c[2] * 255 + .5), math.floor(c[3] * 255 + .5))
end

function P.SpellIcon(spellID)
  if not (C_Spell and C_Spell.GetSpellTexture) then return end
  local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
  if ok then return P.Accessible(icon) end
end

-- Tell both option windows that something changed.
function P.RefreshOptions()
  if P.optionsRegistered then P.AceConfigRegistry:NotifyChange(addonName) end
  if ns.OnOptionsChanged then ns.OnOptionsChanged() end
  if P.RefreshQuickPalette then P.RefreshQuickPalette() end
end

---------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------
-- One frame for the whole addon. Each module adds handlers with P.On; an event
-- the client does not know (Forever lacks a few) is skipped instead of erroring.
local eventFrame = CreateFrame("Frame")
local handlers = {}

local function IsEventValid(event)
  return not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
end

function P.On(event, handler, unit)
  if not IsEventValid(event) then return false end
  if not handlers[event] then
    handlers[event] = {}
    local ok = pcall(function()
      if unit then eventFrame:RegisterUnitEvent(event, unit) else eventFrame:RegisterEvent(event) end
    end)
    if not ok then handlers[event] = nil; return false end
  end
  table.insert(handlers[event], handler)
  return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do list[i](event, ...) end
end)

-- Each module's setup, run in load order once the saved variables exist.
local initializers, profileHandlers = {}, {}
function P.OnInitialize(fn) initializers[#initializers + 1] = fn end
function P.OnProfileChanged(fn) profileHandlers[#profileHandlers + 1] = fn end

---------------------------------------------------------------------
-- SAVED DATA
---------------------------------------------------------------------
function P.EnsureDefaultPresets()
  local p = P.DB.profile
  if p.defaultPresetsSeeded then return end
  for name, colour in pairs(P.cbPresets) do
    if not p.presets[name] then p.presets[name] = P.CopyColour(colour) end
  end
  p.defaultPresetsSeeded = true
end

-- Upgrades a profile's saved data once. Each step runs only for profiles older than it.
function P.Migrate(profile)
  local schema = rawget(profile, "schema") or 0
  if schema < 2 then
    -- 5.1: one effect setting instead of separate rainbow and pulse switches
    if rawget(profile, "rainbowActive") then
      profile.effect = "rainbow"
    elseif rawget(profile, "pulseActive") then
      profile.effect = "pulse"
    end
    profile.rainbowActive, profile.pulseActive = nil, nil
  end
  profile.schema = P.SCHEMA
end

local function ProfileChanged()
  P.Migrate(P.DB.profile)
  P.EnsureDefaultPresets()
  for _, fn in ipairs(profileHandlers) do fn() end
end

local function Initialize()
  P.DB = P.AceDB:New(addonName .. "DB", P.defaults, true)
  local callbacks = {}
  function callbacks.OnProfileUpdated() ProfileChanged() end
  P.DB.RegisterCallback(callbacks, "OnProfileChanged", "OnProfileUpdated")
  P.DB.RegisterCallback(callbacks, "OnProfileCopied", "OnProfileUpdated")
  P.DB.RegisterCallback(callbacks, "OnProfileReset", "OnProfileUpdated")
  P.isHunter = select(2, UnitClass("player")) == "HUNTER"
  P.Migrate(P.DB.profile)
  P.EnsureDefaultPresets()
  for _, fn in ipairs(initializers) do fn() end
end

P.On("ADDON_LOADED", function(_, name)
  if name == addonName and not P.DB then Initialize() end
end)
