-- Options.lua - the windows, slash commands, key bindings, launcher and the page in
-- Blizzard's Settings. The option table itself is in Pages/.
local addonName, ns = ...
local P = ns.P
local L = P.L

local function DB() return P.DB end

---------------------------------------------------------------------
-- WINDOWS AND SLASH COMMANDS
---------------------------------------------------------------------
-- The classic Ace3 window, kept for anyone who prefers it (/ahui classic)
function P.ToggleClassicOptions()
  local dialog = P.AceConfigDialog
  if dialog.OpenFrames and dialog.OpenFrames[addonName] then
    dialog:Close(addonName)
  else
    if P.RefreshKnownPets() then P.BuildPetOptions() end
    dialog:Open(addonName)
  end
end

local function Panel()
  return ns.OptionsKit and ns.OptionsKit.Panel
end

ns.OpenPanel = function(page)
  local panel = Panel()
  if P.RefreshKnownPets() then P.BuildPetOptions() end
  if not (panel and panel:Open(page)) then P.ToggleClassicOptions() end
end

function P.ToggleWindow(page)
  local panel, dialog = Panel(), P.AceConfigDialog
  if not panel or DB().global.panel.classic then
    if panel then panel:Close() end
    P.ToggleClassicOptions()
  elseif panel:IsShown() and not page then
    panel:Close()
  else
    if dialog.OpenFrames and dialog.OpenFrames[addonName] then dialog:Close(addonName) end
    ns.OpenPanel(page)
  end
end

-- "#ff8800", "ff8800", "1 0.5 0" or "255 128 0"
function P.ParseColour(text)
  text = strtrim(text or "")
  local hex = text:match("^#?(%x%x%x%x%x%x)$")
  if hex then
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
  end
  local r, g, b = text:match("^([%d%.]+)[%s,]+([%d%.]+)[%s,]+([%d%.]+)$")
  r, g, b = tonumber(r), tonumber(g), tonumber(b)
  if not (r and g and b) then return end
  if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
  if r > 1 or g > 1 or b > 1 then return end
  return r, g, b
end

local HELP = {
  "/ahui - " .. L["open or close the AzUI window"],
  "/ahui classic - " .. L["the previous Ace3 window"],
  "/ahui color #ff8800 - " .. L["set your colour (also 1 0.5 0 or 255 128 0)"],
  "/ahui preset <name> - " .. L["load a preset"],
  "/ahui next - " .. L["load the next preset"],
  "/ahui effect pulse|rainbow|breathe|...|off - " .. L["set your effect"],
  "/ahui pets on|off - " .. L["pet colours on or off"],
  "/ahui share - " .. L["open the Share page"],
  "/ahui check - " .. L["list the bars found and what each shows, for a bug report"],
}

-- Returns true when the command was understood.
function P.HandleSlash(input)
  local command, rest = strtrim(type(input) == "string" and input or ""):match("^(%S*)%s*(.-)$")
  command = (command or ""):lower()
  if command == "" then
    P.ToggleWindow()
  elseif command == "classic" then
    if Panel() then Panel():Close() end
    P.ToggleClassicOptions()
  elseif command == "color" or command == "colour" then
    local r, g, b = P.ParseColour(rest)
    if not r then P.Print(L["Not a colour:"] .. " " .. rest); return false end
    P.SetUserColour(r, g, b, nil, true)
    P.RefreshOptions()
  elseif command == "preset" then
    local wanted = rest:lower()
    for name in pairs(DB().profile.presets) do
      if name:lower() == wanted then P.LoadPreset(name); return true end
    end
    P.Print(L["No preset called"] .. " " .. rest)
    return false
  elseif command == "next" then
    local name = P.NextPreset()
    P.Print(name and (L["Preset:"] .. " " .. name) or L["You have no presets."])
  elseif command == "effect" then
    local wanted = rest:lower()
    if wanted == "off" or wanted == "none" then wanted = "static" end
    for key, label in pairs(P.EFFECT_VALUES) do
      if label:lower() == wanted then wanted = key end
    end
    if not P.SetEffect(wanted) then P.Print(L["No effect called"] .. " " .. rest); return false end
  elseif command == "pets" then
    local value = rest:lower()
    local p = DB().profile
    if value == "on" then p.petColouring = true
    elseif value == "off" then p.petColouring = false
    else p.petColouring = not p.petColouring end
    P.UpdatePetColour(true)
    P.Print(p.petColouring and L["Pet colours on."] or L["Pet colours off."])
  elseif command == "check" then
    P.ScanFrames()
    for _, line in ipairs(P.CheckReport()) do P.Print(line) end
  elseif command == "share" or command == "export" or command == "import" then
    P.ToggleWindow("share")
  else
    for _, line in ipairs(HELP) do P.Print(line) end
    return command == "help"
  end
  return true
end

SLASH_AZCOLORPICKER1 = "/ahui"
SlashCmdList["AZCOLORPICKER"] = P.HandleSlash

---------------------------------------------------------------------
-- KEY BINDINGS (Bindings.xml)
---------------------------------------------------------------------
BINDING_HEADER_AZUICOLORPICKER    = "AzUI Color Picker"
BINDING_NAME_AZUICOLORPICKER_OPEN    = L["Open the AzUI window"]
BINDING_NAME_AZUICOLORPICKER_RAINBOW = L["Toggle rainbow"]
BINDING_NAME_AZUICOLORPICKER_PULSE   = L["Toggle pulse"]
BINDING_NAME_AZUICOLORPICKER_NEXT    = L["Next preset"]
BINDING_NAME_AZUICOLORPICKER_PETS    = L["Toggle pet colours"]

function AzUIColorPicker_Binding(action)
  if not P.DB then return end
  if action == "open" then P.ToggleWindow()
  elseif action == "rainbow" then P.ToggleEffect("rainbow")
  elseif action == "pulse" then P.ToggleEffect("pulse")
  elseif action == "next" then P.HandleSlash("next")
  elseif action == "pets" then P.HandleSlash("pets") end
end

---------------------------------------------------------------------
-- LAUNCHER
---------------------------------------------------------------------
local SOURCE_NAMES = { rule = L["from a rule"], pet = L["from your pet"], health = L["by your health"], own = "", power = "" }

local function Swatch(c)
  return "|cff" .. P.Hex(c):sub(2) .. "████|r"
end

local function LauncherTooltip(tooltip)
  tooltip:AddLine("AzUI Color Picker")
  local colour, effect, source = P.ChannelSource("player")
  if source == "health" then
    tooltip:AddLine(L["Health bar:"] .. " " .. L["coloured by your health"], 1, 1, 1)
  else
    colour = colour or DB().profile.color
    local line = Swatch(colour) .. "  " .. P.Hex(colour) .. " · " .. P.EFFECT_VALUES[effect or "static"]
    if SOURCE_NAMES[source] ~= "" then line = line .. " · " .. SOURCE_NAMES[source] end
    tooltip:AddLine(line, 1, 1, 1)
  end
  if P.currentPet and P.currentPet.name then
    tooltip:AddLine(L["Pet out:"] .. " " .. P.currentPet.name, .8, .8, .8)
  end
  tooltip:AddLine(" ")
  tooltip:AddLine(L["Left-click: open the AzUI window"], .6, .8, 1)
  tooltip:AddLine(L["Right-click: quick palette"], .6, .8, 1)
  tooltip:AddLine(L["Shift-click: next preset"], .6, .8, 1)
end

---------------------------------------------------------------------
-- /AHUI CHECK
---------------------------------------------------------------------
-- A self-test: what each bar shows and why, and every bar found, with where it comes
-- from. It turns "the colour does not show" into lines a player can paste in a report.
local CHANNEL_NAMES = {
  player = L["Health bar"], pet = L["Pet frame"], power = L["Power bar"], cast = L["Cast bar"],
  classpower = L["Class resources"], absorb = L["Heal and absorb overlays"],
}
-- The bars that are only taken while switched on, or while a rule shows on them
local OPTIONAL = { power = true, cast = true, classpower = true }

local function DescribeChannel(channel)
  if OPTIONAL[channel] and not P.WantsBars(channel) then return L["left alone"] end
  local colour, effect, source = P.ChannelSource(channel)
  if source == "health" then return L["coloured by your health"] end
  local text = P.Hex(colour or DB().profile.color) .. " · " .. P.EFFECT_VALUES[effect or "static"]
  if source == "rule" then
    text = text .. " · " .. L["from a rule"] .. " (" .. P.DescribeRule(P.ActiveRule(channel == "pet" and "pet" or channel)
      or P.ActiveRule("player")) .. ")"
  elseif source == "pet" then
    text = text .. " · " .. L["from your pet"] .. (P.currentPet and P.currentPet.name and (" " .. P.currentPet.name) or "")
  elseif OPTIONAL[source] then
    text = text .. " · " .. L["its own colour"]
  end
  return text
end

function P.CheckReport()
  local lines = {}
  lines[1] = "AzUI Color Picker " .. P.VERSION .. " · " .. (P.IS_FOREVER and "Forever" or "Retail")
    .. " · " .. L["Profile"] .. ": " .. DB():GetCurrentProfile()
  for _, channel in ipairs({ "player", "pet", "power", "cast", "classpower" }) do
    lines[#lines + 1] = CHANNEL_NAMES[channel] .. ": " .. DescribeChannel(channel)
  end
  local bars, found = {}, {}
  local labels = P.Painter.labels
  for bar, channel in pairs(P.Painter.channels) do
    if not P.IsPreviewTarget(bar) then
      found[channel] = true
      local hidden = bar.IsVisible and not bar:IsVisible()
      bars[#bars + 1] = "  " .. (labels[bar] or "?") .. " · " .. CHANNEL_NAMES[channel]
        .. (hidden and (" (" .. L["hidden"] .. ")") or "")
    end
  end
  table.sort(bars)
  lines[#lines + 1] = L["Bars coloured:"] .. " " .. #bars
  for _, line in ipairs(bars) do lines[#lines + 1] = line end
  if not found.player then
    lines[#lines + 1] = L["No health bar found. Supported: AzeriteUI, ElvUI, Shadowed and Unhalted Unit Frames, Z-Perl, PitBull 4, oUF layouts and Blizzard's player frame."]
  end
  -- what a repaint of every bar costs on this machine, so a slow-down report has a number
  if type(debugprofilestop) == "function" then
    local REPEATS = 20
    local start = debugprofilestop()
    for _ = 1, REPEATS do P.Repaint() end
    local ms = (debugprofilestop() - start) / REPEATS
    local rate = tonumber(DB().profile.updateRate) or 30
    lines[#lines + 1] = string.format(L["One repaint of every bar takes %.2f ms; with an effect playing that is up to %d a second."], ms, rate)
  end
  return lines
end

function P.LauncherClick(frame, button)
  if button == "RightButton" then
    if P.ToggleQuickPalette then P.ToggleQuickPalette(frame) end
  elseif IsShiftKeyDown() then
    P.HandleSlash("next")
  else
    P.ToggleWindow()
  end
end

---------------------------------------------------------------------
-- WHAT THE AZUI WINDOW READS
---------------------------------------------------------------------
-- The options window (Options\Panel.lua) and its pet gallery (Options\PetGallery.lua)
-- draw from these; the option table stays the one source of every setting.
ns.Core = {
  options       = P.options,
  appName       = addonName,
  version       = P.VERSION,
  icon          = P.ADDON_ICON,
  iconCoords    = P.ICON_COORDS,
  isForever     = P.IS_FOREVER,
  modeValues    = P.PET_MODE_VALUES, modeSorting = P.PET_MODE_SORTING,
  effectValues  = P.EFFECT_VALUES, effectSorting = P.EFFECTS,
  EffectConfirm = P.EffectConfirm,
  Print         = P.Print,
  OpenClassic   = function() P.ToggleClassicOptions() end,
  GetDB         = function() return P.DB end,
  IsHunter      = function() return P.isHunter end,
  GetCurrentPet = function() return P.currentPet end,
  GetKnownPets  = P.GetKnownPets,
  IsActiveSlot  = P.IsActiveSlot,
  PetSummary    = P.PetSummary,
  FamilyName    = function(pet) return pet.familyName or P.familyNames[pet.familyID] end,
  PetMode       = P.PetMode,
  PetEffect     = P.PetEffect,
  PetColour     = function(number, pet) return P.PetColour(number, pet.name, pet.familyID) end,
  SetPetMode    = function(...) return P.SetPetMode(...) end,
  SetPetColour  = function(...) return P.SetPetColour(...) end,
  SetPetEffect  = function(number, effect) P.EnsurePetSettings(number).effect = effect; P.UpdatePetColour() end,
  UsesSecondColour = P.UsesSecondColour,
  PetSecondColour  = function(number) return P.PetSecondColour(number) or P.DB.profile.secondColor end,
  SetPetSecondColour = function(...) return P.SetPetSecondColour(...) end,
  ResetPet      = function(...) return P.ResetPet(...) end,
  CopyToFamily  = function(number) return P.CopyPetColourToFamily(number) end,
}

---------------------------------------------------------------------
-- ESC > OPTIONS > ADDONS
---------------------------------------------------------------------
-- As AzeriteUI does it: Blizzard's Settings get a landing page with the logo, the
-- version and a button into the AzUI window, rather than the whole option list.
-- A client without the canvas Settings API gets the Ace3 page as before.
local function FontObject(...)
  for i = 1, select("#", ...) do
    local name = select(i, ...)
    if _G[name] then return name end
  end
end

-- Leaves Blizzard's Settings first, so the window is not opened underneath it.
function P.OpenFromSettings(classic)
  if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
  if classic then
    local panel = Panel()
    if panel then panel:Close() end
    P.ToggleClassicOptions()
    return
  end
  local panel = Panel()
  if not (panel and panel:IsShown()) then P.ToggleWindow() end
end

function P.RegisterSettingsPage()
  if ns.settingsCategory then return end
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    ns.optionsFrame, ns.optionsCategoryID = P.AceConfigDialog:AddToBlizOptions(addonName, "AzUI Color Picker")
    return
  end

  local page = CreateFrame("Frame")

  local logo = page:CreateTexture(nil, "ARTWORK")
  logo:SetSize(72, 72)
  logo:SetPoint("CENTER", page, "CENTER", 0, 130)
  logo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\StudioPack\\logo")

  local title = page:CreateFontString(nil, "ARTWORK", FontObject("GameFontNormalHuge3", "GameFontNormalHuge", "GameFontNormalLarge"))
  title:SetPoint("CENTER", page, "CENTER", 0, 70)
  title:SetText("|cff00ff00Az|r|cffFFD100UI|r |cffff7d0aColor Picker|r")

  local version = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  version:SetPoint("TOP", title, "BOTTOM", 0, -8)
  local v = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(addonName, "Version") or ""
  version:SetText("|cff999999" .. L["Version"] .. " " .. v .. "|r")

  local about = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  about:SetPoint("TOP", version, "BOTTOM", 0, -18)
  about:SetWidth(520)
  about:SetText(L["Open the AzUI window with /ahui or the button below."])

  local function Button(text, scale, onClick)
    local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    button:SetText(text)
    local label = button:GetFontString()
    local width = label and (label.GetUnboundedStringWidth and label:GetUnboundedStringWidth() or label:GetStringWidth()) or 0
    button:SetSize(math.max(180, math.ceil(width + 40)), 24)
    button:SetScale(scale)
    button:SetScript("OnClick", onClick)
    return button
  end
  -- Your health bar as it is now, colour and effect, painted like the real one while
  -- the page is open (hidden bars are left out of repaints).
  local preview = CreateFrame("StatusBar", nil, page)
  preview:SetSize(320, 22)
  preview:SetPoint("TOP", about, "BOTTOM", 0, -18)
  preview:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  preview:SetMinMaxValues(0, 1)
  preview:SetValue(0.86)
  local previewBack = preview:CreateTexture(nil, "BACKGROUND")
  previewBack:SetAllPoints()
  previewBack:SetColorTexture(0, 0, 0, 0.5)
  local previewLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  previewLabel:SetPoint("BOTTOM", preview, "TOP", 0, 3)
  previewLabel:SetText(L["Your health bar"])
  P.AddPreviewTarget(preview, "player")
  page.preview = preview

  local open = Button(L["Open the AzUI window"], 1.6, function() P.OpenFromSettings() end)
  open:SetPoint("TOP", preview, "BOTTOM", 0, -16)
  local classic = Button(L["Open the Classic Window"], 1, function() P.OpenFromSettings(true) end)
  classic:SetPoint("TOP", open, "BOTTOM", 0, -14)

  local creditsHead = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  creditsHead:SetPoint("BOTTOM", page, "BOTTOM", 0, 74)
  creditsHead:SetText(L["Credits"])
  local credits = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credits:SetPoint("TOP", creditsHead, "BOTTOM", 0, -4)
  credits:SetWidth(520)
  credits:SetText("|cffD1FF00JuNNeZ|r|cff999999 - " .. L["Author"] .. "|r\n"
    .. "|cffffcc00Goldpaw|r|cff999999 & |r|cffffcc00Blakmane|r|cff999999 - " .. L["AzeriteUI, whose art AzUI Azerite borrows with their blessing"] .. "|r")

  -- Settings asks a canvas page for these
  page.OnCommit = function() end
  page.OnDefault = function() end
  page.OnRefresh = function() end

  local category = Settings.RegisterCanvasLayoutCategory(page, "AzUI Color Picker")
  category.ID = "AzUI Color Picker"
  Settings.RegisterAddOnCategory(category)
  page.open, page.classic = open, classic
  ns.settingsCategory, ns.optionsFrame, ns.optionsCategoryID = category, page, category.ID
end

---------------------------------------------------------------------
-- SET-UP
---------------------------------------------------------------------
-- after every page in Pages/ has set itself up
P.OnInitialize(function()
  P.BuildPetOptions()
  P.BuildRuleOptions()
  P.AceConfig:RegisterOptionsTable(addonName, P.options)
  P.optionsRegistered = true
  P.RegisterSettingsPage()

  -- Minimap, AddOn Compartment, Titan Panel and other DataBroker displays
  if P.LDB and not ns.dataObj then
    ns.dataObj = P.LDB:NewDataObject(addonName, {
      type  = "launcher",
      icon  = P.ADDON_ICON,
      text  = "AzUI",
      label = "AzUI Colour",
      OnClick = function(frame, button) P.LauncherClick(frame, button) end,
      OnTooltipShow = LauncherTooltip,
    })
  end
  if P.DBIcon and ns.dataObj and not P.DBIcon:IsRegistered(addonName) then
    P.DBIcon:Register(addonName, ns.dataObj, DB().global.minimap)
  end

  P.UpdatePetColour()
end)

P.OnProfileChanged(function()
  P.BuildRuleOptions()
  P.UpdatePetColour()
end)
