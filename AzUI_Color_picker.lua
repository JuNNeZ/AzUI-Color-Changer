---@diagnostic disable: undefined-global, undefined-field
--[[
AzUI_Color_Picker.lua
Custom colour, rainbow/pulse animations, presets and hunter-pet colours for your
own health bar on AzeriteUI (5.x, JuNNeZ Edition, AzeriteUI6) and the default
Blizzard player frame. AzeriteUI pet frames show the same colour.

The saved colour (DB.profile.color) only changes when you pick a colour.
Animations and pet colours are worked out at display time and never saved.
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
-- Player and pet unit frame modules -> health preview brightness (AzeriteUI 5.x tints it at 90% / 70%).
-- 5.x and JuNNeZ Edition use PlayerFrame(+Alternate) and PetFrame, AzeriteUI6 uses Player and Pet.
local AZERITE_MODULES = {
  PlayerFrame = 0.9, PlayerFrameAlternate = 0.9, PetFrame = 0.7,
  Player      = 0.9, Pet                  = 0.7,
}
-- Global frame names, used when the module lookup finds nothing
local AZERITE_FRAMES  = {
  AzeriteUnitFramePlayer     = 0.9, AzeriteUnitFramePlayerAlternate = 0.9, AzeriteUnitFramePet = 0.7,
  oUF_AzeriteUnitFramePlayer = 0.9, oUF_AzeriteUnitFramePet         = 0.7,
}

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
    petColouring         = false,   -- toggle hunter-pet colour overrides
  },
  global = {
    minimap = { hide = false, showInCompartment = true },
  },
}

-- Colour-blind friendly presets, added once per profile
local cbPresets = {
  ["CB-Blue"]   = {0.2,0.4,0.9,1},
  ["CB-Orange"] = {0.9,0.5,0.1,1},
  ["CB-Yellow"] = {0.9,0.9,0.2,1},
  ["CB-Purple"] = {0.6,0.3,0.8,1},
}

-- Hunter pet family fallback colours, keyed by creature family ID so they work
-- on every client language (UnitCreatureFamily returns the ID as its 2nd value).
local familyColours = {
  -- ✦ Exotics --------------------------------------------------------
  [46]  = {0.00, 1.00, 1.00, 1}, -- Spirit Beast: cyan aura
  [39]  = {0.90, 0.20, 0.10, 1}, -- Devilsaur: blood-red scales
  [45]  = {1.00, 0.35, 0.25, 1}, -- Core Hound: fiery magma
  [38]  = {0.25, 0.80, 1.00, 1}, -- Chimaera: frost-blue breath
  [43]  = {0.55, 0.35, 0.25, 1}, -- Clefthoof: earthen hide
  [138] = {0.60, 0.40, 0.20, 1}, -- Direhorn: muddy horn
  [156] = {0.40, 0.70, 0.30, 1}, -- Scalehide: mossy scales
  [55]  = {0.65, 0.50, 0.75, 1}, -- Shale Beast: crystalline purple
  [128] = {0.50, 0.70, 0.90, 1}, -- Stone Hound: azure stone
  [126] = {0.20, 0.60, 0.80, 1}, -- Water Strider: teal water walker
  [68]  = {0.25, 0.75, 0.55, 1}, -- Hydra: emerald scales
  [41]  = {0.85, 0.45, 0.15, 1}, -- Aqiri: bronze carapace
  [150] = {0.35, 0.65, 0.45, 1}, -- Riverbeast: swamp green
  [42]  = {0.70, 0.55, 0.25, 1}, -- Worm: sandy burrower
  [292] = {0.70, 0.30, 0.80, 1}, -- Carapid: purple chitin
  [290] = {0.80, 0.60, 0.30, 1}, -- Pterrordax: amber wing

  -- ✦ Mammals --------------------------------------------------------
  [4]   = {0.45, 0.35, 0.25, 1}, -- Bear: brown fur
  [5]   = {0.60, 0.40, 0.30, 1}, -- Boar: tusky brown
  [2]   = {1.00, 0.50, 0.50, 1}, -- Cat: pale pink
  [50]  = {0.95, 0.45, 0.20, 1}, -- Fox: orange fur
  [9]   = {0.40, 0.40, 0.40, 1}, -- Gorilla: grey shadow
  [25]  = {0.80, 0.60, 0.25, 1}, -- Hyena: savannah
  [51]  = {0.65, 0.55, 0.40, 1}, -- Monkey: jungle brown
  [157] = {0.50, 0.45, 0.35, 1}, -- Oxen: taupe
  [127] = {0.75, 0.65, 0.55, 1}, -- Rodent: whiskered grey
  [12]  = {0.85, 0.70, 0.20, 1}, -- Tallstrider: savannah yellow
  [298] = {0.75, 0.65, 0.45, 1}, -- Camel: desert beige
  [299] = {0.90, 0.80, 0.60, 1}, -- Courser: golden stallion
  [160] = {0.75, 0.50, 0.85, 1}, -- Feathermane: majestic plum
  [129] = {0.55, 0.45, 0.30, 1}, -- Gruffhorn: rough hide
  [52]  = {0.60, 0.50, 0.40, 1}, -- Hound: loyal brown
  [300] = {0.65, 0.55, 0.45, 1}, -- Mammoth: tusked grey
  [151] = {0.50, 0.70, 0.40, 1}, -- Stag: forest green
  [1]   = {0.45, 0.50, 0.55, 1}, -- Wolf: pack grey

  -- ✦ Birds ----------------------------------------------------------
  [7]   = {0.75, 0.35, 0.20, 1}, -- Carrion Bird: vulture red-brown
  [26]  = {0.95, 0.85, 0.30, 1}, -- Bird of Prey: golden feather
  [30]  = {0.90, 0.30, 0.30, 1}, -- Dragonhawk: fiery wings
  [31]  = {0.80, 0.40, 0.20, 1}, -- Ravager: rust chitin
  [37]  = {0.80, 0.75, 0.85, 1}, -- Moth: soft lilac
  [24]  = {0.30, 0.25, 0.35, 1}, -- Bat: night wing
  [125] = {0.40, 0.70, 0.90, 1}, -- Waterfowl: lake blue

  -- ✦ Reptiles / Amphibians -----------------------------------------
  [130] = {0.35, 0.75, 0.60, 1}, -- Basilisk: jade hide
  [8]   = {0.90, 0.30, 0.30, 1}, -- Crab: scarlet shell
  [6]   = {0.30, 0.70, 0.35, 1}, -- Crocolisk: swamp reptile
  [11]  = {0.80, 0.45, 0.20, 1}, -- Raptor: rust scales
  [35]  = {0.15, 0.75, 0.40, 1}, -- Serpent: emerald serpent
  [21]  = {0.20, 0.60, 0.30, 1}, -- Turtle: jade shell
  [288] = {0.55, 0.80, 0.35, 1}, -- Lizard: lime scales
  [315] = {0.60, 0.75, 0.30, 1}, -- Whiptail: olive scales
  [33]  = {0.55, 0.80, 0.90, 1}, -- Sporebat: cyan spores
  [291] = {0.60, 0.80, 0.50, 1}, -- Hopper: leap green
  [34]  = {0.70, 0.60, 0.90, 1}, -- Ray: ethereal purple
  [27]  = {0.50, 0.90, 0.70, 1}, -- Wind Serpent: airy teal

  -- ✦ Insects / Arachnids -------------------------------------------
  [3]   = {0.45, 0.45, 0.55, 1}, -- Spider: web grey
  [44]  = {1.00, 0.85, 0.15, 1}, -- Wasp: yellow stinger
  [53]  = {0.30, 0.70, 0.55, 1}, -- Beetle: jade carapace
  [20]  = {0.85, 0.70, 0.30, 1}, -- Scorpid: desert amber

  -- ✦ Mechanical & Special ------------------------------------------
  [154] = {0.50, 0.80, 1.00, 1}, -- Mechanical: arcane blue steel
  [296] = {0.80, 0.15, 0.20, 1}, -- Blood Beast: crimson blood
  [303] = {0.60, 0.40, 0.85, 1}, -- Lesser Dragonkin: dragon purple
  [32]  = {0.85, 0.50, 0.95, 1}, -- Warp Stalker: void pink
}

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local DB
local optionsRegistered = false
local selectedPreset, renameBuffer = nil, ""
local petOverride -- colour shown while a coloured hunter pet is out (never saved)
local animPhase, frameElapsed, chaosElapsed = 0, 0, 0
local chaosColour = { random(), random(), random() }

local targets       = setmetatable({}, { __mode = "k" }) -- health bar -> brightness factor
local blizzardBars  = setmetatable({}, { __mode = "k" })
local textureOwners = setmetatable({}, { __mode = "k" }) -- bar texture -> health bar
local painting      = setmetatable({}, { __mode = "k" })
local knownFrames   = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------
local function Print(msg) print("|cffff8800[AzUI Color Picker]|r " .. tostring(msg)) end
local function debugLog(msg) if DB and DB.profile.debug then Print(msg) end end

local function isAccessibleValue(value)
  if issecretvalue and issecretvalue(value) then return false end
  return value ~= nil
end

local function copyColour(c) return { c[1], c[2], c[3], c[4] or 1 } end

local function RefreshOptions()
  if optionsRegistered then AceConfigRegistry:NotifyChange(addonName) end
end

local function ToggleOptions()
  if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[addonName] then
    AceConfigDialog:Close(addonName)
  else
    AceConfigDialog:Open(addonName)
  end
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

-- The colour that belongs on screen right now: pet colour, then animation, then saved colour
local function GetDisplayColour()
  if petOverride then
    return petOverride[1], petOverride[2], petOverride[3], petOverride[4] or 1
  end
  local p = DB.profile
  local c = p.color
  local a = c[4] or 1
  if p.rainbowActive then
    if p.rainbowMode == "chaos" then
      return chaosColour[1], chaosColour[2], chaosColour[3], a
    elseif p.rainbowMode == "ping" then
      -- sweep hue 0 -> 1 -> 0
      local x = animPhase % TWO_PI
      if x > PI then x = TWO_PI - x end
      local r, g, b = hsvToRgb(x / PI)
      return r, g, b, a
    end
    return 0.5 + 0.5 * sin(animPhase),
           0.5 + 0.5 * sin(animPhase + TWO_PI / 3),
           0.5 + 0.5 * sin(animPhase + 2 * TWO_PI / 3), a
  elseif p.pulseActive then
    local s = 0.3 + 0.7 * abs(sin(animPhase))
    return c[1] * s, c[2] * s, c[3] * s, a
  end
  return c[1], c[2], c[3], a
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
  local r, g, b, a = GetDisplayColour()
  for bar in pairs(targets) do paintBar(bar, r, g, b, a) end
end

-- Another addon (or Blizzard) recoloured a bar: put ours back in the same frame.
local function RepaintBar(bar)
  if DB and not painting[bar] then paintBar(bar, GetDisplayColour()) end
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

local function addTarget(bar, factor)
  if type(bar) ~= "table" or targets[bar] then return end
  if type(bar.SetStatusBarColor) ~= "function" and type(bar.GetStatusBarTexture) ~= "function" then return end
  targets[bar] = factor
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

local function registerUnitFrame(frame, previewFactor)
  if type(frame) ~= "table" or knownFrames[frame] or type(frame.Health) ~= "table" then return end
  knownFrames[frame] = true
  addTarget(frame.Health, 1)
  if type(frame.Health.Preview) == "table" then
    addTarget(frame.Health.Preview, previewFactor)
  end
  debugLog("Colouring AzeriteUI frame " .. tostring(frame.GetName and frame:GetName() or "?"))
end

local function ScanFrames()
  if not DB then return end
  if AceAddon then
    for i = 1, #AZERITE_ADDONS do
      local aui = AceAddon:GetAddon(AZERITE_ADDONS[i], true)
      if type(aui) == "table" and type(aui.GetModule) == "function" then
        for moduleName, previewFactor in pairs(AZERITE_MODULES) do
          local module = aui:GetModule(moduleName, true)
          if type(module) == "table" then registerUnitFrame(module.frame, previewFactor) end
        end
      end
    end
  end
  for frameName, previewFactor in pairs(AZERITE_FRAMES) do
    registerUnitFrame(_G[frameName], previewFactor)
  end
  local blizzardBar = GetBlizzardPlayerHealthBar()
  if blizzardBar and not targets[blizzardBar] then
    blizzardBars[blizzardBar] = true
    addTarget(blizzardBar, 1)
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
  local p = DB.profile
  if not petOverride and (p.rainbowActive or p.pulseActive) then
    animator:Show()
  else
    animator:Hide()
  end
end

local function SetAnimation(rainbow, pulse)
  local p = DB.profile
  p.rainbowActive, p.pulseActive = rainbow, pulse
  animPhase, frameElapsed, chaosElapsed = 0, 0, 0
  if rainbow or pulse then petOverride = nil end -- starting an effect wins until the pet changes
  UpdateAnimator()
  Repaint()
end

local function ToggleRainbow() SetAnimation(not DB.profile.rainbowActive, false) end
local function TogglePulse() SetAnimation(false, not DB.profile.pulseActive) end

---------------------------------------------------------------------
-- USER COLOUR & HUNTER PETS
---------------------------------------------------------------------
local function SetUserColour(r, g, b, a)
  local c = DB.profile.color
  c[1], c[2], c[3], c[4] = r, g, b, a or c[4] or 1
  petOverride = nil -- show the picked colour now; the pet colour returns on the next pet change
  SetAnimation(false, false)
end

local function FindPetColour()
  local p = DB.profile
  if not p.petColouring or not UnitExists("pet") then return nil end
  local petName = UnitName("pet")
  if isAccessibleValue(petName) and p.presets[petName] then
    return p.presets[petName]
  end
  local _, familyID = UnitCreatureFamily("pet")
  if isAccessibleValue(familyID) then
    return familyColours[familyID]
  end
end

local function UpdatePetColour()
  if not DB then return end
  petOverride = FindPetColour()
  UpdateAnimator()
  Repaint()
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
  text    = L["This will reset all settings and delete your presets in the current profile. Are you sure?"],
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
local opts = { name = addonName, type = "group", args = {} }
opts.args.ver = { type = "description", name = "|cff999999Version " .. VERSION, order = 0 }
opts.args.col = {
  type = "color", name = L["Healthbar Colour"],
  desc = L["Pick a custom RGB-A colour for your own health bar. Alpha controls transparency."],
  hasAlpha = true, order = 1,
  get = function() local c = DB.profile.color; return c[1], c[2], c[3], c[4] or 1 end,
  set = function(_, r, g, b, a) SetUserColour(r, g, b, a) end,
}

-- class colours section
opts.args.clsH1 = { type = "header", name = L["Class Colours"], order = 1.5 }
opts.args.clsG = { type = "group", inline = true, name = "", order = 1.6, args = {} }
for class, cc in pairs(RAID_CLASS_COLORS) do
  local classColor = cc
  local male = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]
  local female = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[class]
  local name = male or female or class
  if male and female and female ~= male then
    name = male .. " / " .. female
  end
  opts.args.clsG.args[class] = {
    type = "execute",
    name = name,
    func = function() SetUserColour(classColor.r, classColor.g, classColor.b) end,
  }
end

-- fun options
opts.args.funH = { type = "header", name = L["Fun Options"], order = 1.8 }
opts.args.classReset = {
  type = "execute", name = L["Class Colour"],
  desc = L["Reset to your class's default colour."], order = 1.81,
  func = function()
    local c = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
    if c then SetUserColour(c.r, c.g, c.b) end
  end,
}
opts.args.rand = {
  type = "execute", name = L["Random Colour"],
  desc = L["Generate a random colour (keeps alpha)."], order = 1.82,
  func = function() SetUserColour(random(), random(), random()) end,
}
opts.args.speed = {
  type = "range",
  name = L["Animation Speed"],
  desc = L["How fast the rainbow and pulse effects run. At 1.0 a rainbow cycle takes about 21 seconds and a pulse about 10 seconds; 2.0 is twice as fast."],
  order = 1.83,
  min = 0.1, max = 5, step = 0.1,
  get = function() return DB.profile.rainbowSpeed end,
  set = function(_, v) DB.profile.rainbowSpeed = v end,
}
opts.args.pattern = {
  type = "select",
  name = L["Rainbow Pattern"],
  desc = L["Choose the animation style for the rainbow effect."],
  order = 1.835,
  values = { cycle = "Cycle", ping = "Ping-Pong", chaos = "Chaos" },
  get = function() return DB.profile.rainbowMode end,
  set = function(_, v) DB.profile.rainbowMode = v; Repaint() end,
}
opts.args.rainToggle = {
  type  = "execute",
  name  = function() return DB.profile.rainbowActive and L["Stop Rainbow Effect"] or L["Rainbow Effect"] end,
  desc  = L["Toggle the animated rainbow effect."],
  order = 1.84,
  func  = ToggleRainbow,
}
opts.args.pulseToggle = {
  type  = "execute",
  name  = function() return DB.profile.pulseActive and L["Stop Pulse"] or L["Pulse Colour"] end,
  desc  = L["Toggle a gentle pulse on the current colour."],
  order = 1.86,
  func  = TogglePulse,
}

---------------------------------------------------------------------
-- PRESET SECTION
---------------------------------------------------------------------
opts.args.presH = { type = "header", name = L["Presets"], order = 2 }
opts.args.sel = {
  type = "select", name = L["Select Preset"],
  desc = L["Apply a saved colour preset."], order = 2.1,
  values = function() local t = {}; for k in pairs(DB.profile.presets) do t[k] = k end return t end,
  get = function() return selectedPreset end,
  set = function(_, v) LoadPreset(v) end,
}
opts.args.renBox = {
  type = "input", name = L["Rename To:"], order = 2.2,
  get = function() return renameBuffer end,
  set = function(_, v) renameBuffer = v end,
  disabled = function() return not selectedPreset end,
}
opts.args.renBtn = {
  type = "execute", name = L["Rename Preset"],
  desc = L["Rename the selected preset. Names already in use are refused."], order = 2.3,
  func = function() if RenamePreset(renameBuffer) then renameBuffer = "" end end,
  disabled = function()
    local newName = strtrim(renameBuffer or "")
    return not selectedPreset or newName == "" or newName == selectedPreset
  end,
}
opts.args.delBtn = {
  type = "execute", name = L["Delete Preset"],
  desc = L["Delete the selected preset."], order = 2.4,
  func = DeletePreset,
  disabled = function() return not selectedPreset end,
}
opts.args.save = {
  type = "execute", name = L["Save as Preset"],
  desc = L["Save the current colour as a new preset."], order = 2.5,
  func = function() StaticPopup_Show("AZUI_NAME_PRESET") end,
}
opts.args.savePet = {
  type = "execute", name = L["Save to Current Pet"],
  desc = L["Bind the colour from the colour picker to your active pet's name."], order = 2.6,
  func = function()
    local petName = UnitName("pet")
    if isAccessibleValue(petName) then SaveNamedPreset(petName) end
  end,
  disabled = function() return not UnitExists("pet") end,
}

---------------------------------------------------------------------
-- MAINTENANCE
---------------------------------------------------------------------
opts.args.mainH = { type = "header", name = L["Maintenance"], order = 3 }
opts.args.reset = {
  type = "execute", name = L["Reset to Defaults"],
  desc = L["Reset all settings and presets in the current profile to factory defaults."], order = 3.1,
  func = function() StaticPopup_Show("AZUI_RESET_CONFIRM") end,
}
opts.args.petToggle = {
  type  = "toggle",
  name  = L["Pet Colour Overrides"],
  desc  = L["When enabled, your health bar uses the preset named after your active hunter pet, or a colour for its pet family. Your own colour and effects come back when the pet is dismissed."],
  width = "double",
  order = 3.15,
  get   = function() return DB and DB.profile.petColouring end,
  set   = function(_, v) DB.profile.petColouring = v; UpdatePetColour() end,
}
opts.args.reload = {
  type = "execute",
  name = L["Reload"],
  desc = L["Reloads your UI. All colour and preset changes are saved instantly - this button just forces a /reload."],
  order = 3.2,
  func = function() ReloadUI() end,
}
opts.args.minimapToggle = {
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
opts.args.debugT = {
  type = "toggle", name = L["Enable Debug"], order = 90,
  get = function() return DB and DB.profile.debug end,
  set = function(_, v) DB.profile.debug = v end,
}
opts.args.creditH = { type = "header", name = L[""], order = 91 }
opts.args.credit = { type = "description", name = "|cff888888Made with love by JuNNeZ — code assisted by ChatGPT", order = 99 }

---------------------------------------------------------------------
-- INITIALISATION & EVENTS
---------------------------------------------------------------------
function addon:OnProfileUpdated()
  selectedPreset, renameBuffer = nil, ""
  ensureDefaultPresets()
  UpdatePetColour()
end

local function Initialize()
  DB = AceDB:New(addonName .. "DB", defaults, true)
  DB.RegisterCallback(addon, "OnProfileChanged", "OnProfileUpdated")
  DB.RegisterCallback(addon, "OnProfileCopied", "OnProfileUpdated")
  DB.RegisterCallback(addon, "OnProfileReset", "OnProfileUpdated")
  ensureDefaultPresets()

  -- Minimap, AddOn Compartment, and DataBroker launcher.
  if LDB and not addon.dataObj then
    addon.dataObj = LDB:NewDataObject(addonName, {
      type  = "launcher",
      icon  = "Interface\\AddOns\\AzUI_Color_Picker\\icon.tga",
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
    UpdatePetColour()
  elseif event == "UNIT_PET" then
    UpdatePetColour()
  end
end)
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterUnitEvent("UNIT_PET", "player")

---------------------------------------------------------------------
-- SLASH COMMAND
---------------------------------------------------------------------
SLASH_AZCOLORPICKER1 = "/ahui"
SlashCmdList["AZCOLORPICKER"] = ToggleOptions
