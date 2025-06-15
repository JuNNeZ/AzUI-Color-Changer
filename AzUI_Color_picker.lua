--[[
AzUI_Color_Picker.lua – FULL SOURCE (v4.7.5)
* Alpha channel support (colour transparency)
* Rainbow speed slider (0.1–5 Hz)
* “Class Colour” quick‑reset button
* Colour‑blind friendly presets on first run
* Hunter‑pet family fallback presets
* AceLocale scaffold for future translations
]]--

---------------------------------------------------------------------
-- SETUP & LIBS
---------------------------------------------------------------------
local addonName, ns = ...
local addon      = CreateFrame("Frame", addonName)

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB           = LibStub("AceDB-3.0")
local AceAddon        = LibStub("AceAddon-3.0")
local AceLocale       = LibStub("AceLocale-3.0")
local L               = AceLocale:GetLocale(addonName, true) or setmetatable({}, {__index=function(t,k) return k end})
-- DataBroker / Minimap handling
local LDB              = LibStub("LibDataBroker-1.1", true)
local DBIcon           = LibStub("LibDBIcon-1.0", true)

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
    minimap = { hide = false },
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

  -- ✦ Mammals --------------------------------------------------------
  ["Bear"]     = {0.45, 0.35, 0.25, 1}, -- Brown fur
  ["Boar"]     = {0.60, 0.40, 0.30, 1}, -- Tusky brown
  ["Cat"]      = {1.00, 0.50, 0.50, 1}, -- Pale pink
  ["Dog"]      = {0.70, 0.55, 0.35, 1}, -- Sandy coat
  ["Fox"]      = {0.95, 0.45, 0.20, 1}, -- Orange fur
  ["Goat"]     = {0.85, 0.85, 0.70, 1}, -- Pale wool
  ["Gorilla"] = {0.40, 0.40, 0.40, 1}, -- Grey shadow
  ["Hyena"]   = {0.80, 0.60, 0.25, 1}, -- Savannah
  ["Monkey"]  = {0.65, 0.55, 0.40, 1}, -- Jungle brown
  ["Oxen"]    = {0.50, 0.45, 0.35, 1}, -- Taupe
  ["Rodent"]  = {0.75, 0.65, 0.55, 1}, -- Whiskered grey
  ["Skunk"]   = {0.20, 0.20, 0.20, 1}, -- Black stripe
  ["Tallstrider"] = {0.85, 0.70, 0.20, 1}, -- Savannah yellow
  ["Mouse"]   = {0.70, 0.70, 0.70, 1}, -- Tiny grey
  ["Camel"]   = {0.75, 0.65, 0.45, 1}, -- Desert beige

  -- ✦ Birds ----------------------------------------------------------
  ["Carrion Bird"] = {0.75, 0.35, 0.20, 1}, -- Vulture red‑brown
  ["Bird of Prey"] = {0.95, 0.85, 0.30, 1}, -- Golden feather
  ["Dragonhawk"]  = {0.90, 0.30, 0.30, 1}, -- Fiery wings
  ["Ravager"]     = {0.80, 0.40, 0.20, 1}, -- Rust chitin
  ["Hawk"]        = {0.95, 0.80, 0.30, 1}, -- Sky gold
  ["Moth"]        = {0.80, 0.75, 0.85, 1}, -- Soft lilac

  -- ✦ Reptiles / Amphibians -----------------------------------------
  ["Basilisk"]   = {0.35, 0.75, 0.60, 1}, -- Jade hide
  ["Crab"]       = {0.90, 0.30, 0.30, 1}, -- Scarlet shell
  ["Crocolisk"] = {0.30, 0.70, 0.35, 1}, -- Swamp reptile
  ["Raptor"]     = {0.80, 0.45, 0.20, 1}, -- Rust scales
  ["Serpent"]    = {0.15, 0.75, 0.40, 1}, -- Emerald serpent
  ["Turtle"]     = {0.20, 0.60, 0.30, 1}, -- Jade shell
  ["Lizard"]     = {0.55, 0.80, 0.35, 1}, -- Lime scales
  ["Sporebat"]   = {0.55, 0.80, 0.90, 1}, -- Cyan spores

  -- ✦ Insects / Arachnids -------------------------------------------
  ["Spider"]   = {0.45, 0.45, 0.55, 1}, -- Web grey
  ["Wasp"]     = {1.00, 0.85, 0.15, 1}, -- Yellow stinger
  ["Beetle"]   = {0.30, 0.70, 0.55, 1}, -- Jade carapace

  -- ✦ Aquatics -------------------------------------------------------
  ["Shark"] = {0.40, 0.60, 0.80, 1}, -- Deep blue
  ["Fish"]  = {0.25, 0.55, 0.75, 1}, -- Ocean teal

  -- ✦ Mechanicals ----------------------------------------------------
  ["Mechanical"] = {0.50, 0.80, 1.00, 1}, -- Arcane blue steel
}

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local DB
local rainbowTicker, pulseTicker
local storedPlayerColor, storedRainbow = nil, false
local storedPulseColor = nil
local selectedPreset, renameBuffer = nil, ""
local lastAppliedColor = {nil,nil,nil,nil}
local knownFrames = setmetatable({}, {__mode="k"})
local storedPlayerColor, storedRainbow = nil, false

-- forward declarations so they exist for pop‑ups defined above their body
local StopRainbow, StartRainbow, ApplyColor

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
    local name = self.editBox:GetText()
    if name and name:trim() ~= "" then
      DB.profile.presets[name] = { unpack(DB.profile.color) }
      selectedPreset = name
    end
  end,
  EditBoxOnEnterPressed = function(self)
    local name = self:GetText()
    if name and name:trim() ~= "" then
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
    StopRainbow(); DB:ResetProfile(); ApplyColor()
  end,
}

---------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------
local function debugLog(msg) if DB and DB.profile.debug then print("|cffff8800[AzUI_Color_Picker]|r "..tostring(msg)) end end
local function mutateColor(r,g,b,a) DB.profile.color[1],DB.profile.color[2],DB.profile.color[3],DB.profile.color[4]=r,g,b,a or DB.profile.color[4] end

local function PatchFrame(f)
  if f and f.Health and not f.Health.__AzPatched then
    f.Health.colorClass=false; f.Health.colorReaction=false; f.Health.colorHealth=false; f.Health.colorDisconnected=false; f.Health.__AzPatched=true
    hooksecurefunc(f.Health,"SetStatusBarColor",function(_,R,G,B) if not f.__block then f.__block=true; f.Health:SetStatusBarColor(unpack(DB.profile.color)); f.Health:SetAlpha(DB.profile.color[4] or 1); f.__block=false end end)
  end
end

local function SetHealthColor(f,r,g,b,a)
  if not(f and f.Health) then return end
  knownFrames[f]=true; PatchFrame(f); f.Health:SetStatusBarColor(r,g,b); f.Health:SetAlpha(a)
end

function ApplyColor()
  local r,g,b,a=unpack(DB.profile.color)
  if r==lastAppliedColor[1] and g==lastAppliedColor[2] and b==lastAppliedColor[3] and a==lastAppliedColor[4] then return end
  lastAppliedColor[1],lastAppliedColor[2],lastAppliedColor[3],lastAppliedColor[4]=r,g,b,a

  local AUI=AceAddon:GetAddon("AzeriteUI",true); if AUI and AUI.Colors then AUI.Colors.health={r,g,b,a} end
  if AUI and AUI.UnitFrames and AUI.UnitFrames.units then for _,u in pairs(AUI.UnitFrames.units) do SetHealthColor(u,r,g,b,a) end end
  if PlayerFrame and PlayerFrame.healthbar then SetHealthColor(PlayerFrame,r,g,b,a) elseif PlayerFrameHealthBar then SetHealthColor({Health=PlayerFrameHealthBar},r,g,b,a) end
  if oUF_Player then SetHealthColor(oUF_Player,r,g,b,a) end
  for _,n in ipairs({"AzeriteUnitFramePlayer","AzeriteUnitFramePlayerAlternate","AzeriteUnitFramePlayer_Alternate"}) do local f=_G[n]; if f then SetHealthColor(f,r,g,b,a) end end
  for f in pairs(knownFrames) do SetHealthColor(f,r,g,b,a) end
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
  DB.profile.rainbowActive = false
  if rainbowTicker then rainbowTicker:Cancel() end
  rainbowTicker = nil
end

function ToggleRainbow()
  if DB.profile.rainbowActive then
    StopRainbow()
  else
    StartRainbow()
  end
end

function StartRainbow()
  StopRainbow(); DB.profile.rainbowActive=true
  local mode = DB.profile.rainbowMode or "cycle"; local t,dir = 0,1
  local spd = math.min(5,math.max(0.1,DB.profile.rainbowSpeed))*0.03
  rainbowTicker = C_Timer.NewTicker(0.1,function()
    if mode=="cycle" then t=t+spd
    elseif mode=="ping" then
    -- Sweep hue 0→1 then back using HSV for a sharper contrast vs Cycle
    t = t + dir * spd
    if t > math.pi or t < 0 then dir = -dir end
    local hue = t / math.pi        -- 0‑1 forward, then backward
    local r2,g2,b2 = hsvToRgb(hue)
    mutateColor(r2,g2,b2)
    ApplyColor()
    return
    
    elseif mode=="chaos" then
    -- Every tick choose a new random hue (lots of flicker, clearly different)
    mutateColor(math.random(), math.random(), math.random()); ApplyColor(); return
  end
    local r=0.5+0.5*math.sin(t); local g=0.5+0.5*math.sin(t+2*math.pi/3); local b=0.5+0.5*math.sin(t+4*math.pi/3)
    mutateColor(r,g,b); ApplyColor()
  end)
end

---------------------------------------------------------------------
-- PULSE BUTTON
---------------------------------------------------------------------
local function StopPulse()
  DB.profile.pulseActive = false
  if pulseTicker then pulseTicker:Cancel() end
  pulseTicker = nil
  if storedPulseColor then mutateColor(unpack(storedPulseColor)); ApplyColor(); storedPulseColor = nil end
end

local function StartPulse()
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
local function LoadPreset(n) local c=DB.profile.presets[n]; if c then StopRainbow(); mutateColor(unpack(c)); ApplyColor(); selectedPreset=n end end
local function DeletePreset() if selectedPreset then DB.profile.presets[selectedPreset]=nil; selectedPreset=nil end end
local function RenamePreset(newName) if selectedPreset and newName~="" then DB.profile.presets[newName]=DB.profile.presets[selectedPreset]; DB.profile.presets[selectedPreset]=nil; selectedPreset=newName end end

---------------------------------------------------------------------
-- OPTIONS TABLE
---------------------------------------------------------------------
local opts={ name=addonName,type="group",args={} }
opts.args.ver = { type = "description", name = "|cff999999Version 4.7.5", order = 0 }
opts.args.col = { type="color", name=L["Healthbar Colour"],
  desc=L["Pick a custom RGB‑A colour for your own health bar. Alpha controls transparency."], hasAlpha=true, order=1, get=function() return unpack(DB.profile.color) end, set=function(_,r,g,b,a) StopRainbow(); mutateColor(r,g,b,a); ApplyColor() end }

-- class colours section
opts.args.clsH1={ type="header", name=L["Class Colours"], order=1.5 }
opts.args.clsG={ type="group", inline=true, name="", order=1.6, args={} }
for class,cc in pairs(RAID_CLASS_COLORS) do opts.args.clsG.args[class]={ type="execute", name=_G.LOCALIZED_CLASS_NAMES_MALE[class] or class, func=function() StopRainbow(); mutateColor(cc.r,cc.g,cc.b,DB.profile.color[4]); ApplyColor() end } end

-- fun options
opts.args.funH={ type="header", name=L["Fun Options"], order=1.8 }
opts.args.classReset={ type="execute", name=L["Class Colour"],
  desc=L["Reset to your class's default colour."], order=1.81, func=function() local c=RAID_CLASS_COLORS[select(2,UnitClass("player"))]; StopRainbow(); mutateColor(c.r,c.g,c.b,DB.profile.color[4]); ApplyColor() end }
opts.args.rand={ type="execute", name=L["Random Colour"],
  desc=L["Generate a random colour (keeps alpha)."], order=1.82, func=function() StopRainbow(); mutateColor(math.random(),math.random(),math.random(),DB.profile.color[4]); ApplyColor() end }
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
    local n = UnitName("pet");
    if n then DB.profile.presets[n] = { unpack(DB.profile.color) }; selectedPreset = n end
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
  func = function() StopRainbow(); ReloadUI() end,
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
      StopRainbow(); mutateColor(unpack(storedPlayerColor)); ApplyColor()
      if storedRainbow then StartRainbow() end
      storedPlayerColor, storedRainbow = nil, false
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
    -- ===== Minimap / DataBroker launcher =====
    if LDB and not addon.dataObj then
      addon.dataObj = LDB:NewDataObject(addonName, {
        type  = "launcher",
        icon  = "Interface\\AddOns\\AzUI_Color_Picker\\icon.tga", -- double backslashes for Lua string
        text  = "AzUI", -- label shown in Titan Panel
        label = "AzUI Colour",
        OnClick = function()
  if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[addonName] then
    AceConfigDialog:Close(addonName)            -- panel is open → close it
  else
    AceConfigDialog:Open(addonName)             -- panel closed → open it
  end
end,

        OnTooltipShow = function(tt)
          tt:AddLine("AzUI Color Picker")
          tt:AddLine("Click to open options")
        end,
      })
    end
    if DBIcon and addon.dataObj then
      DBIcon:Register(addonName, addon.dataObj, DB.global.minimap)
    end
    if next(DB.profile.presets) == nil then for k,v in pairs(cbPresets) do DB.profile.presets[k] = v end end
    AceConfig:RegisterOptionsTable(addonName, opts)
    AceConfigDialog:AddToBlizOptions(addonName, "AzUI Color Picker")
    C_Timer.After(0.1, function() ApplyColor(); if DB.profile.rainbowActive then StartRainbow() end end)
-- ensure CB presets always exist
for k, v in pairs(cbPresets) do
  if not DB.profile.presets[k] then
    DB.profile.presets[k] = v
  end
end

  elseif ev == "UNIT_PET" and arg == "player" then
    local petName = UnitName("pet")
    local family  = UnitExists("pet") and UnitCreatureFamily("pet") or nil
local preset = nil
if DB.profile.petColouring then
  preset = petName and DB.profile.presets[petName] or (family and familyColours[family])
end

    if preset then
      if not storedPlayerColor then storedPlayerColor = { unpack(DB.profile.color) }; storedRainbow = DB.profile.rainbowActive end
      StopRainbow(); mutateColor(unpack(preset)); ApplyColor()
    elseif storedPlayerColor then
      StopRainbow(); mutateColor(unpack(storedPlayerColor)); ApplyColor(); if storedRainbow then StartRainbow() end
      storedPlayerColor, storedRainbow = nil, false
    end

  elseif ev == "PLAYER_ENTERING_WORLD" or ev == "PLAYER_REGEN_ENABLED" or ev == "PLAYER_REGEN_DISABLED" then
    C_Timer.After(0.05, ApplyColor)
  elseif ev == "UNIT_HEALTH" or ev == "UNIT_MAXHEALTH" then
    ApplyColor()
  end
end)
for _,ev in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_PET"}) do addon:RegisterEvent(ev) end

---------------------------------------------------------------------
-- MONITORS & HOOKS
---------------------------------------------------------------------
local monitor = CreateFrame("Frame"); monitor.elapsed = 0
monitor:SetScript("OnUpdate", function(self,e) self.elapsed = self.elapsed + e; if self.elapsed > 1.5 then ApplyColor(); self.elapsed = 0 end end)

local scanner = CreateFrame("Frame"); scanner.elapsed = 0
scanner:SetScript("OnUpdate", function(self,e)
  self.elapsed = self.elapsed + e; if self.elapsed > 2 then
    for _,n in ipairs({"AzeriteUnitFramePlayer","AzeriteUnitFramePlayerAlternate","AzeriteUnitFramePlayer_Alternate"}) do
      local f = _G[n]; if f and f.Health and not knownFrames[f] then debugLog("Detected:"..n); SetHealthColor(f, unpack(DB.profile.color)) end
    end
    self.elapsed = 0
  end
end)
for _,fn in ipairs({"UnitFrame_UpdateTextures","PlayerFrame_Update","PlayerFrameHealthBar_Update","CompactUnitFrame_UpdateHealthColor"}) do
  if type(_G[fn]) == "function" then hooksecurefunc(fn, function() C_Timer.After(0.05, ApplyColor) end) end
end

---------------------------------------------------------------------
-- SLASH COMMAND
---------------------------------------------------------------------
SLASH_AZCOLOR1 = "/ahui"
SlashCmdList["AZCOLOR"] = function()
  LoadAddOn("Blizzard_InterfaceOptions");
  LibStub("AceConfigDialog-3.0"):Open(addonName)
end
