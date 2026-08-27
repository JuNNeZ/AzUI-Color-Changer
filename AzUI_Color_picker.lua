---@diagnostic disable: undefined-global, undefined-field
--[[
AzUI_Color_Picker.lua - FULL SOURCE (v4.8.0)
* Alpha channel support (colour transparency)
* Rainbow speed slider (0.1-5 Hz)
* "Class Colour" quick‑reset button
* Colour‑blind friendly presets on first run
* Hunter‑pet family fallback presets
* Retail 12.1 API and secret-value compatibility
]]--

---------------------------------------------------------------------
-- SETUP & LIBS
---------------------------------------------------------------------
local addonName = ...
local addon      = CreateFrame("Frame", addonName)

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB           = LibStub("AceDB-3.0")
local AceAddon        = LibStub("AceAddon-3.0", true)
local L               = setmetatable({}, { __index = function(_, key) return key end })
-- DataBroker / Minimap handling
local LDB              = LibStub("LibDataBroker-1.1", true)
local DBIcon           = LibStub("LibDBIcon-1.0", true)

-- Compatibility for unpack across Lua versions
local unpack = table.unpack or unpack

---------------------------------------------------------------------
-- DEFAULTS
---------------------------------------------------------------------
local defaults = {
  profile = {
    color         = { 0.7, 0.1, 0.1, 1 },   -- RGBA
    rainbowActive = false,
    rainbowSpeed  = 1,  -- Hz (0.1‑5)
    rainbowMode   = "cycle",  -- cycle | ping | chaos
    pulseColor    = {1, 1, 1},  -- RGB base for Pulse pattern
    pulseActive   = false,
    presets       = {},
    debug         = false,  -- toggle debug
    petColouring  = false,  -- toggle hunter-pet colour overrides
  },
  global = {
    minimap = { hide = false, showInCompartment = true },
  },
}

-- Ship colour‑blind presets on first run
local cbPresets = {
  ["CB-Blue"]   = {0.2,0.4,0.9,1},
  ["CB-Orange"] = {0.9,0.5,0.1,1},
  ["CB-Yellow"] = {0.9,0.9,0.2,1},
  ["CB-Purple"] = {0.6,0.3,0.8,1},
}

-- Hunter pet‑family fallback hues (used if no name‑preset exists)
local familyColours = {
  -- ✦ Exotics / Rares -------------------------------------------------
  ["Spirit Beast"] = {0.00, 1.00, 1.00, 1}, -- Cyan aura
  ["Devilsaur"]    = {0.90, 0.20, 0.10, 1}, -- Blood‑red scales
  ["Core Hound"]   = {1.00, 0.35, 0.25, 1}, -- Fiery magma
  ["Chimaera"]     = {0.25, 0.80, 1.00, 1}, -- Frost‑blue breath
  ["Clefthoof"]    = {0.55, 0.35, 0.25, 1}, -- Earthen hide
  ["Direhorn"]     = {0.60, 0.40, 0.20, 1}, -- Muddy horn
  ["Kodo"]         = {0.45, 0.35, 0.25, 1}, -- Dusty brown
  ["Scalehide"]    = {0.40, 0.70, 0.30, 1}, -- Mossy scales
  ["Shale Spider"] = {0.60, 0.25, 0.75, 1}, -- Amethyst crystalline
  ["Silithid"]     = {0.80, 0.55, 0.15, 1}, -- Sandy amber
  ["Stone Hound"]  = {0.50, 0.70, 0.90, 1}, -- Azure stone
  ["Water Strider"] = {0.20, 0.60, 0.80, 1}, -- Teal water walker
  ["Hydra"]        = {0.25, 0.75, 0.55, 1}, -- Emerald scales
  ["Aqiri"]        = {0.85, 0.45, 0.15, 1}, -- Bronze carapace
  ["Riverbeast"]   = {0.35, 0.65, 0.45, 1}, -- Swamp green
  ["Worm"]         = {0.70, 0.55, 0.25, 1}, -- Sandy burrower
  ["Carapid"]      = {0.70, 0.30, 0.80, 1}, -- Purple chitin
  ["Pterrordax"]   = {0.80, 0.60, 0.30, 1}, -- Amber wing
  ["Shale Beast"]  = {0.65, 0.50, 0.75, 1}, -- Crystalline purple

  -- ✦ Mammals --------------------------------------------------------
  ["Bear"]         = {0.45, 0.35, 0.25, 1}, -- Brown fur
  ["Boar"]         = {0.60, 0.40, 0.30, 1}, -- Tusky brown
  ["Cat"]          = {1.00, 0.50, 0.50, 1}, -- Pale pink
  ["Dog"]          = {0.70, 0.55, 0.35, 1}, -- Sandy coat
  ["Fox"]          = {0.95, 0.45, 0.20, 1}, -- Orange fur
  ["Goat"]         = {0.85, 0.85, 0.70, 1}, -- Pale wool
  ["Gorilla"]      = {0.40, 0.40, 0.40, 1}, -- Grey shadow
  ["Hyena"]        = {0.80, 0.60, 0.25, 1}, -- Savannah
  ["Monkey"]       = {0.65, 0.55, 0.40, 1}, -- Jungle brown
  ["Oxen"]         = {0.50, 0.45, 0.35, 1}, -- Taupe
  ["Rodent"]       = {0.75, 0.65, 0.55, 1}, -- Whiskered grey
  ["Skunk"]        = {0.20, 0.20, 0.20, 1}, -- Black stripe
  ["Tallstrider"]  = {0.85, 0.70, 0.20, 1}, -- Savannah yellow
  ["Mouse"]        = {0.70, 0.70, 0.70, 1}, -- Tiny grey
  ["Camel"]        = {0.75, 0.65, 0.45, 1}, -- Desert beige
  ["Courser"]      = {0.90, 0.80, 0.60, 1}, -- Golden stallion
  ["Feathermane"]  = {0.75, 0.50, 0.85, 1}, -- Majestic plum
  ["Gruffhorn"]    = {0.55, 0.45, 0.30, 1}, -- Rough hide
  ["Hound"]        = {0.60, 0.50, 0.40, 1}, -- Loyal brown
  ["Mammoth"]      = {0.65, 0.55, 0.45, 1}, -- Tusked grey
  ["Stag"]         = {0.50, 0.70, 0.40, 1}, -- Forest green
  ["Wolf"]         = {0.45, 0.50, 0.55, 1}, -- Pack grey

  -- ✦ Birds ----------------------------------------------------------
  ["Carrion Bird"] = {0.75, 0.35, 0.20, 1}, -- Vulture red‑brown
  ["Bird of Prey"] = {0.95, 0.85, 0.30, 1}, -- Golden feather
  ["Dragonhawk"]   = {0.90, 0.30, 0.30, 1}, -- Fiery wings
  ["Ravager"]      = {0.80, 0.40, 0.20, 1}, -- Rust chitin
  ["Hawk"]         = {0.95, 0.80, 0.30, 1}, -- Sky gold
  ["Moth"]         = {0.80, 0.75, 0.85, 1}, -- Soft lilac
  ["Bat"]          = {0.30, 0.25, 0.35, 1}, -- Night wing
  ["Waterfowl"]    = {0.40, 0.70, 0.90, 1}, -- Lake blue

  -- ✦ Reptiles / Amphibians -----------------------------------------
  ["Basilisk"]     = {0.35, 0.75, 0.60, 1}, -- Jade hide
  ["Crab"]         = {0.90, 0.30, 0.30, 1}, -- Scarlet shell
  ["Crocolisk"]    = {0.30, 0.70, 0.35, 1}, -- Swamp reptile
  ["Raptor"]       = {0.80, 0.45, 0.20, 1}, -- Rust scales
  ["Serpent"]      = {0.15, 0.75, 0.40, 1}, -- Emerald serpent
  ["Turtle"]       = {0.20, 0.60, 0.30, 1}, -- Jade shell
  ["Lizard"]       = {0.55, 0.80, 0.35, 1}, -- Lime scales
  ["Sporebat"]     = {0.55, 0.80, 0.90, 1}, -- Cyan spores
  ["Hopper"]       = {0.60, 0.80, 0.50, 1}, -- Leap green
  ["Ray"]          = {0.70, 0.60, 0.90, 1}, -- Ethereal purple
  ["Wind Serpent"] = {0.50, 0.90, 0.70, 1}, -- Airy teal

  -- ✦ Insects / Arachnids -------------------------------------------
  ["Spider"]       = {0.45, 0.45, 0.55, 1}, -- Web grey
  ["Wasp"]         = {1.00, 0.85, 0.15, 1}, -- Yellow stinger
  ["Beetle"]       = {0.30, 0.70, 0.55, 1}, -- Jade carapace
  ["Scorpid"]      = {0.85, 0.70, 0.30, 1}, -- Desert amber

  -- ✦ Aquatics -------------------------------------------------------
  ["Shark"]        = {0.40, 0.60, 0.80, 1}, -- Deep blue
  ["Fish"]         = {0.25, 0.55, 0.75, 1}, -- Ocean teal

  -- ✦ Mechanicals ----------------------------------------------------
  ["Mechanical"]   = {0.50, 0.80, 1.00, 1}, -- Arcane blue steel

  -- ✦ Special / Skill Required ------------------------------------
  ["Blood Beast"]     = {0.80, 0.15, 0.20, 1}, -- Crimson blood
  ["Lesser Dragonkin"] = {0.60, 0.40, 0.85, 1}, -- Dragon purple
  ["Warp Stalker"]    = {0.85, 0.50, 0.95, 1}, -- Void pink
}

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local DB
local rainbowTicker, pulseTicker
local storedPlayerColor, storedRainbow, storedPulse = nil, false, false
local storedPulseColor = nil
local selectedPreset, renameBuffer = nil, ""
local knownFrames = setmetatable({}, { __mode = "k" })
local hookedBars = setmetatable({}, { __mode = "k" })
local applyingBars = setmetatable({}, { __mode = "k" })
local queuedBars = setmetatable({}, { __mode = "k" })
local pendingCombatApply = false
-- forward declarations so they exist for pop‑ups defined above their body
local StopRainbow, StartRainbow, StopPulse, StartPulse, ApplyColor

local function isAccessibleValue(value)
  if issecretvalue and issecretvalue(value) then return false end
  return value ~= nil
end

local function ensureDefaultPresets()
  for name, color in pairs(cbPresets) do
    if not DB.profile.presets[name] then
      DB.profile.presets[name] = { unpack(color) }
    end
  end
end

---------------------------------------------------------------------
-- POPUP DIALOGS
---------------------------------------------------------------------
-- Named‑preset prompt
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
    local name = editBox and strtrim(editBox:GetText())
    if name and name ~= "" then
      DB.profile.presets[name] = { unpack(DB.profile.color) }
      selectedPreset = name
    end
  end,
  EditBoxOnEnterPressed = function(self)
    local name = strtrim(self:GetText())
    if name ~= "" then
      DB.profile.presets[name] = { unpack(DB.profile.color) }
      selectedPreset = name
    end
    self:GetParent():Hide()
  end,
}

-- Reset‑to‑defaults confirmation
StaticPopupDialogs["AZUI_RESET_CONFIRM"] = {
  text    = L["This will delete all your profiles and reset colours. Are you sure?"],
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
  OnAccept = function()
    StopRainbow()
    StopPulse(false)
    DB:ResetProfile()
    storedPlayerColor, storedRainbow, storedPulse = nil, false, false
    selectedPreset = nil
    ensureDefaultPresets()
    ApplyColor()
  end,
}

---------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------
local function debugLog(msg) if DB and DB.profile.debug then print("|cffff8800[AzUI_Color_Picker]|r "..tostring(msg)) end end
local function mutateColor(r,g,b,a) DB.profile.color[1],DB.profile.color[2],DB.profile.color[3],DB.profile.color[4]=r,g,b,a or DB.profile.color[4] end

local function applyStatusBarColor(bar, r, g, b, a)
  if not bar then return end

  applyingBars[bar] = true
  if type(bar.SetStatusBarColor) == "function" then
    bar:SetStatusBarColor(r, g, b)
  end
  if type(bar.GetStatusBarTexture) == "function" then
    local texture = bar:GetStatusBarTexture()
    if texture and type(texture.SetVertexColor) == "function" then
      texture:SetVertexColor(r, g, b)
    end
  end
  if type(bar.SetAlpha) == "function" then
    bar:SetAlpha(a or 1)
  end
  applyingBars[bar] = nil
end

local function hookStatusBar(bar)
  if not bar or hookedBars[bar] or type(bar.SetStatusBarColor) ~= "function" then return end

  local ok = pcall(hooksecurefunc, bar, "SetStatusBarColor", function(self)
    if not DB or applyingBars[self] or queuedBars[self] then return end

    queuedBars[self] = true
    C_Timer.After(0, function()
      queuedBars[self] = nil
      if DB then
        applyStatusBarColor(self, unpack(DB.profile.color))
      end
    end)
  end)
  if ok then hookedBars[bar] = true end
end

local function patchFrame(frame)
  if not frame or not frame.Health then return end

  local bar = frame.Health
  bar.colorClass = false
  bar.colorReaction = false
  bar.colorHealth = false
  bar.colorDisconnected = false
  knownFrames[frame] = true
  hookStatusBar(bar)
end

local function SetHealthColor(frame, r, g, b, a)
  if not frame then return end

  patchFrame(frame)
  local bar = frame.Health or frame
  hookStatusBar(bar)
  applyStatusBarColor(bar, r, g, b, a)
end

---------------------------------------------------------------------
-- BLIZZARD HEALTH BAR COLOR OVERRIDE (Retail 12.1+)
---------------------------------------------------------------------

local function GetBlizzardPlayerHealthBar()
  -- Blizzard provides this helper in current retail; keep structural fallbacks
  -- for users running the addon across a pre-patch transition.
  if type(PlayerFrame_GetHealthBar) == "function" then
    local ok, bar = pcall(PlayerFrame_GetHealthBar)
    if ok and bar then return bar end
  end
  if PlayerFrame
    and PlayerFrame.PlayerFrameContent
    and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
    and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer
  then
    return PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar
  end
  if PlayerFrame and PlayerFrame.healthbar then return PlayerFrame.healthbar end
  return _G.PlayerFrameHealthBar
end

local function ForceBlizzardHealthBarColor(r, g, b, a)
  local bar = GetBlizzardPlayerHealthBar()
  if not bar then return end

  -- UnitFrameHealthBar_Update respects lockColor in current retail.
  bar.lockColor = true
  hookStatusBar(bar)
  applyStatusBarColor(bar, r, g, b, a)
end

---------------------------------------------------------------------
-- APPLY COLOR TO ALL FRAMES
---------------------------------------------------------------------

ApplyColor = function()
  if not DB then return end

  local AUI = AceAddon and AceAddon:GetAddon("AzeriteUI", true)
  if AUI and not AUI.__AzUI_ColorPickerApplied then
    AUI.__AzUI_ColorPickerApplied = true
  end
  local r, g, b, a = unpack(DB.profile.color)

  if AUI and AUI.Colors then AUI.Colors.health = { r, g, b, a } end
  if _G.oUF and _G.oUF.colors then _G.oUF.colors.health = { r, g, b, a } end
  if AUI and AUI.GetModule then
    if InCombatLockdown and InCombatLockdown() then
      pendingCombatApply = true
    else
      local pm = AUI:GetModule("PlayerFrame", true)
      if pm and pm.Update then pcall(pm.Update, pm) end
      if pm and pm.frame and pm.frame.Health and pm.frame.Health.ForceUpdate then pcall(pm.frame.Health.ForceUpdate, pm.frame.Health) end
      local pam = AUI:GetModule("PlayerFrameAlternate", true)
      if pam and pam.Update then pcall(pam.Update, pam) end
      if pam and pam.frame and pam.frame.Health and pam.frame.Health.ForceUpdate then pcall(pam.frame.Health.ForceUpdate, pam.frame.Health) end
    end
  end
  if AUI and AUI.UnitFrames and AUI.UnitFrames.units then
    for _, u in pairs(AUI.UnitFrames.units) do SetHealthColor(u, r, g, b, a) end
  end

  -- Blizzard health bar (Midnight 12.1+)
  ForceBlizzardHealthBarColor(r, g, b, a)

  if _G.oUF_Player then SetHealthColor(_G.oUF_Player, r, g, b, a) end
  for _, n in ipairs({"AzeriteUnitFramePlayer", "AzeriteUnitFramePlayerAlternate", "AzeriteUnitFramePlayer_Alternate"}) do
    local f = _G[n]
    if f then SetHealthColor(f, r, g, b, a) end
  end
  for f in pairs(knownFrames) do SetHealthColor(f, r, g, b, a) end
end

---------------------------------------------------------------------
-- RAINBOW CYCLE
-- helper to convert 0‑1 hue to RGB for Ping‑Pong mode
local function hsvToRgb(h)
  local i = math.floor(h * 6)
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
---------------------------------------------------------------------
StopRainbow = function()
  if DB then DB.profile.rainbowActive = false end
  if rainbowTicker then rainbowTicker:Cancel() end
  rainbowTicker = nil
end

local function ToggleRainbow()
  if DB.profile.rainbowActive then
    StopRainbow()
  else
    StartRainbow()
  end
end

StartRainbow = function()
  StopPulse()
  StopRainbow()
  DB.profile.rainbowActive = true
  local mode = DB.profile.rainbowMode or "cycle"
  local t, dir = 0, 1
  local spd = math.min(5, math.max(0.1, DB.profile.rainbowSpeed)) * 0.03
  rainbowTicker = C_Timer.NewTicker(0.1, function()
    if mode == "cycle" then
      t = t + spd
      local r = 0.5 + 0.5 * math.sin(t)
      local g = 0.5 + 0.5 * math.sin(t + 2 * math.pi / 3)
      local b = 0.5 + 0.5 * math.sin(t + 4 * math.pi / 3)
      mutateColor(r, g, b)
      ApplyColor()
    elseif mode == "ping" then
      -- Sweep hue 0→1 then back using HSV for a sharper contrast vs Cycle
      t = t + dir * spd
      if t >= math.pi then
        t, dir = math.pi, -1
      elseif t <= 0 then
        t, dir = 0, 1
      end
      local hue = t / math.pi        -- 0‑1 forward, then backward
      local r2, g2, b2 = hsvToRgb(hue)
      mutateColor(r2, g2, b2)
      ApplyColor()
    elseif mode == "chaos" then
      -- Every tick choose a new random hue (lots of flicker, clearly different)
      mutateColor(math.random(), math.random(), math.random())
      ApplyColor()
    end
  end)
end

---------------------------------------------------------------------
-- PULSE BUTTON
---------------------------------------------------------------------
StopPulse = function(restoreColor)
  if DB then DB.profile.pulseActive = false end
  if pulseTicker then pulseTicker:Cancel() end
  pulseTicker = nil
  if storedPulseColor then
    if restoreColor ~= false then
      mutateColor(unpack(storedPulseColor))
      ApplyColor()
    end
    storedPulseColor = nil
  end
end

StartPulse = function()
  StopRainbow()
  StopPulse()
  DB.profile.pulseActive = true
  storedPulseColor = { unpack(DB.profile.color) }
  local t, spd = 0, math.min(5, math.max(0.1, DB.profile.rainbowSpeed)) * 0.03
  local base = { unpack(DB.profile.color) }
  pulseTicker = C_Timer.NewTicker(0.1, function()
    t = t + spd
    local s = 0.3 + 0.7 * math.abs(math.sin(t))
    mutateColor(base[1]*s, base[2]*s, base[3]*s, base[4])
    ApplyColor()
  end)
end

local function StopAnimations(restorePulseColor)
  StopRainbow()
  StopPulse(restorePulseColor)
end

-- Toggle helper wraps Start/Stop Pulse into one button
local function TogglePulse()
  if DB.profile.pulseActive then
    StopPulse()
  else
    StartPulse()
  end
end

---------------------------------------------------------------------
-- PRESET HELPERS
---------------------------------------------------------------------
local function SavePreset() StaticPopup_Show("AZUI_NAME_PRESET") end
local function LoadPreset(n) local c=DB.profile.presets[n]; if c then StopAnimations(); mutateColor(unpack(c)); ApplyColor(); selectedPreset=n end end
local function DeletePreset() if selectedPreset then DB.profile.presets[selectedPreset]=nil; selectedPreset=nil end end
local function RenamePreset(newName) newName=strtrim(newName); if selectedPreset and newName~="" then DB.profile.presets[newName]=DB.profile.presets[selectedPreset]; DB.profile.presets[selectedPreset]=nil; selectedPreset=newName end end

---------------------------------------------------------------------
-- OPTIONS TABLE
---------------------------------------------------------------------
local opts={ name=addonName,type="group",args={} }
opts.args.ver = { type = "description", name = "|cff999999Version 4.8.0", order = 0 }
opts.args.col = { type="color", name=L["Healthbar Colour"],
  desc=L["Pick a custom RGB‑A colour for your own health bar. Alpha controls transparency."], hasAlpha=true, order=1, get=function() return unpack(DB.profile.color) end, set=function(_,r,g,b,a) StopAnimations(); mutateColor(r,g,b,a); ApplyColor() end }

-- class colours section
opts.args.clsH1={ type="header", name=L["Class Colours"], order=1.5 }
opts.args.clsG={ type="group", inline=true, name="", order=1.6, args={} }
for class,cc in pairs(RAID_CLASS_COLORS) do
    local classColor = cc
    local male = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]
    local female = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[class]
    local name = male
    if female and female ~= male then
        name = male .. " / " .. female
    end
    opts.args.clsG.args[class] = {
        type = "execute",
        name = name or class,
        func = function()
            StopAnimations()
            mutateColor(classColor.r, classColor.g, classColor.b, DB.profile.color[4])
            ApplyColor()
        end
    }
end

-- fun options
opts.args.funH={ type="header", name=L["Fun Options"], order=1.8 }
opts.args.classReset={ type="execute", name=L["Class Colour"],
  desc=L["Reset to your class's default colour."], order=1.81, func=function() local c=RAID_CLASS_COLORS[select(2,UnitClass("player"))]; if c then StopAnimations(); mutateColor(c.r,c.g,c.b,DB.profile.color[4]); ApplyColor() end end }
opts.args.rand={ type="execute", name=L["Random Colour"],
  desc=L["Generate a random colour (keeps alpha)."], order=1.82, func=function() StopAnimations(); mutateColor(math.random(),math.random(),math.random(),DB.profile.color[4]); ApplyColor() end }
opts.args.speed = {
  type = "range",
  name = L["Rainbow Speed (Hz)"],
  desc = L["Controls how fast the rainbow animation cycles."],
  order = 1.83,
  min = 0.1, max = 5, step = 0.1,
  get = function() return DB.profile.rainbowSpeed end,
  set = function(_, v)
    DB.profile.rainbowSpeed = v
    if DB.profile.rainbowActive then StartRainbow() end
    if DB.profile.pulseActive then StartPulse() end
  end,
}
-- new pattern dropdown
opts.args.pattern = {
  type = "select",
  name = L["Rainbow Pattern"],
  desc = L["Choose the animation style for the rainbow effect."],
  order = 1.835,
  values = { cycle = "Cycle", ping = "Ping-Pong", chaos = "Chaos" },
  get = function() return DB.profile.rainbowMode end,
  set = function(_, v) DB.profile.rainbowMode = v; if DB.profile.rainbowActive then StartRainbow() end end,
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
}---------------------------------------------------------------------
-- PRESET SECTION
---------------------------------------------------------------------
opts.args.presH = { type = "header", name = L["Presets"], order = 2 }
opts.args.sel = {
  type = "select", name = L["Select Preset"],
  desc = L["Apply a saved colour preset."], order = 2.1,
  values = function() local t = {}; for k in pairs(DB.profile.presets) do t[k]=k end return t end,
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
  desc = L["Rename the selected preset."], order = 2.3,
  func = function() RenamePreset(renameBuffer); renameBuffer = "" end,
  disabled = function() return not selectedPreset or renameBuffer == "" end,
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
  func = SavePreset,
}
opts.args.savePet = {
  type = "execute", name = L["Save to Current Pet"],
  desc = L["Bind the current colour to your active pet's name."], order = 2.6,
  func = function()
    local n = UnitName("pet")
    if isAccessibleValue(n) then DB.profile.presets[n] = { unpack(DB.profile.color) }; selectedPreset = n end
  end,
  disabled = function() return not UnitExists("pet") end,
}

---------------------------------------------------------------------
-- MAINTENANCE
---------------------------------------------------------------------
opts.args.mainH = { type = "header", name = L["Maintenance"], order = 3 }
opts.args.reset = {
  type = "execute", name = L["Reset to Defaults"],
  desc = L["Reset all settings and presets to factory defaults."], order = 3.1,
  func = function() StaticPopup_Show("AZUI_RESET_CONFIRM") end,
}
opts.args.reload = {
  type = "execute",
  name = L["Reload"],
  desc = L["Reloads your UI. All colour and preset changes are saved instantly - this button just forces a /reload."],
  order = 3.2,
  func = function() StopAnimations(); ReloadUI() end,
}
opts.args.petToggle = {
  type  = "toggle",
  name  = L["Pet Colour Overrides"],
  desc  = L["When enabled, the addon will automatically recolour your health bar to match a preset saved for your active hunter pet (name first, then family fallback). Turn this off to always keep your chosen player colour."],
  width = "double",
  order = 3.15,
  get   = function() return DB and DB.profile.petColouring end,
  set   = function(_, v)
    DB.profile.petColouring = v
    if not v and storedPlayerColor then
      StopAnimations()
      mutateColor(unpack(storedPlayerColor))
      ApplyColor()
      if storedRainbow then StartRainbow() elseif storedPulse then StartPulse() end
      storedPlayerColor, storedRainbow, storedPulse = nil, false, false
    elseif v then
      addon:GetScript("OnEvent")(addon, "UNIT_PET", "player") -- re-apply
    end
  end,
}
opts.args.minimapToggle = {
  type = "toggle",
  name = L["Show Minimap Icon"],
  desc = L["Toggle the minimap launcher button." ],
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
-- EVENTS
---------------------------------------------------------------------
addon:SetScript("OnEvent", function(_, ev, arg)
  if ev == "ADDON_LOADED" and arg == addonName then
    DB = AceDB:New(addonName .. "DB", defaults, true)

    -- Minimap, AddOn Compartment, and DataBroker launcher.
    if LDB and not addon.dataObj then
      addon.dataObj = LDB:NewDataObject(addonName, {
        type  = "launcher",
        icon  = "Interface\\AddOns\\AzUI_Color_Picker\\icon.tga",
        text  = "AzUI",
        label = "AzUI Colour",
        OnClick = function()
          if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[addonName] then
            AceConfigDialog:Close(addonName)
          else
            AceConfigDialog:Open(addonName)
          end
        end,
        OnTooltipShow = function(tt)
          tt:AddLine("AzUI Color Picker")
          tt:AddLine("Click to open options")
        end,
      })
    end
    if DBIcon and addon.dataObj and not DBIcon:IsRegistered(addonName) then
      DBIcon:Register(addonName, addon.dataObj, DB.global.minimap)
    end
    ensureDefaultPresets()
    AceConfig:RegisterOptionsTable(addonName, opts)
    addon.optionsFrame, addon.optionsCategoryID = AceConfigDialog:AddToBlizOptions(addonName, "AzUI Color Picker")
    C_Timer.After(0.1, function()
      ApplyColor()
      if DB.profile.rainbowActive then
        StartRainbow()
      elseif DB.profile.pulseActive then
        StartPulse()
      end
    end)

  elseif ev == "UNIT_PET" and arg == "player" then
    local preset
    if DB.profile.petColouring and UnitExists("pet") then
      local petName = UnitName("pet")
      local family = UnitCreatureFamily("pet")
      if isAccessibleValue(petName) then
        preset = DB.profile.presets[petName]
      end
      if not preset and isAccessibleValue(family) then
        preset = familyColours[family]
      end
    end

    if preset then
      if not storedPlayerColor then
        storedPlayerColor = { unpack(storedPulseColor or DB.profile.color) }
        storedRainbow = DB.profile.rainbowActive
        storedPulse = DB.profile.pulseActive
      end
      StopAnimations()
      mutateColor(unpack(preset))
      ApplyColor()
    elseif storedPlayerColor then
      local resumeRainbow, resumePulse = storedRainbow, storedPulse
      StopAnimations()
      mutateColor(unpack(storedPlayerColor))
      storedPlayerColor, storedRainbow, storedPulse = nil, false, false
      ApplyColor()
      if resumeRainbow then StartRainbow() elseif resumePulse then StartPulse() end
    end

  elseif ev == "PLAYER_ENTERING_WORLD" or ev == "PLAYER_REGEN_ENABLED" then
    if ev == "PLAYER_REGEN_ENABLED" and pendingCombatApply then
      pendingCombatApply = false
    end
    C_Timer.After(0.05, ApplyColor)
  end
end)
for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
  addon:RegisterEvent(ev)
end
addon:RegisterUnitEvent("UNIT_PET", "player")

---------------------------------------------------------------------
-- FRAME DISCOVERY & HOOKS
---------------------------------------------------------------------
local scanner = CreateFrame("Frame")
scanner.elapsed = 0
scanner:SetScript("OnUpdate", function(self, elapsed)
  self.elapsed = self.elapsed + elapsed
  if self.elapsed > 2 then
    if DB then
      for _, name in ipairs({ "AzeriteUnitFramePlayer", "AzeriteUnitFramePlayerAlternate", "AzeriteUnitFramePlayer_Alternate" }) do
        local frame = _G[name]
        if frame and frame.Health and not knownFrames[frame] then
          debugLog("Detected: " .. name)
          SetHealthColor(frame, unpack(DB.profile.color))
        end
      end
    end
    self.elapsed = 0
  end
end)
if type(PlayerFrame_UpdateArt) == "function" then
  hooksecurefunc("PlayerFrame_UpdateArt", function()
    C_Timer.After(0, ApplyColor)
  end)
end

---------------------------------------------------------------------
-- SLASH COMMAND
---------------------------------------------------------------------
SLASH_AZCOLORPICKER1 = "/ahui"
SlashCmdList["AZCOLORPICKER"] = function()
  AceConfigDialog:Open(addonName)
end
