-- Pages/Health.lua - the Health Bar page: your colour, class colours, effects, Colour by
-- Health, presets and maintenance.
local addonName, ns = ...
local P = ns.P
local L = P.L
local opts, panelMeta, ForPanel, GetColour = P.options, ns.PanelMeta, P.ForPanel, P.GetColour

local function DB() return P.DB end

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
    P.SaveNamedPreset(editBox and editBox:GetText())
  end,
  EditBoxOnEnterPressed = function(self)
    P.SaveNamedPreset(self:GetText())
    self:GetParent():Hide()
  end,
}

---------------------------------------------------------------------
-- HEALTH BAR PAGE
---------------------------------------------------------------------
local general = { type = "group", name = L["Health Bar"], icon = P.ADDON_ICON, order = 1, args = {} }
opts.args.general = general

general.args.col = {
  type = "color", name = L["Healthbar Colour"],
  desc = L["Pick a custom RGB-A colour for your own health bar. Alpha controls transparency."],
  hasAlpha = true, order = 1,
  get = function() return GetColour(DB().profile.color) end,
  set = function(_, r, g, b, a) P.SetUserColour(r, g, b, a) end,
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
  if cc.colorStr then name = "|c" .. cc.colorStr .. name .. "|r" end
  general.args.clsG.args[class] = {
    type = "execute",
    name = name,
    func = function() P.SetUserColour(classColor.r, classColor.g, classColor.b, nil, true) end,
  }
end

general.args.classReset = {
  type = "execute", name = L["Class Colour"],
  desc = L["Reset to your class's default colour."], order = 1.7,
  func = function()
    local c = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
    if c then P.SetUserColour(c.r, c.g, c.b, nil, true) end
  end,
}
general.args.rand = {
  type = "execute", name = L["Random Colour"],
  desc = L["Generate a random colour (keeps alpha)."], order = 1.71,
  func = function() P.SetUserColour(math.random(), math.random(), math.random(), nil, true) end,
}

-- effects
general.args.effH = { type = "header", name = L["Effect"], order = 1.8 }
general.args.effect = {
  type = "select", name = L["Effect"], order = 1.81,
  desc = function() return P.EFFECT_HELP[DB().profile.effect] end,
  values = P.EFFECT_VALUES, sorting = P.EFFECTS,
  confirm = function(_, value) return P.EffectConfirm(value) or false end,
  get = function() return DB().profile.effect end,
  set = function(_, v) P.SetEffect(v) end,
}
general.args.second = {
  type = "color", name = L["Second Colour"], order = 1.82, hasAlpha = false,
  desc = L["The colour Two-tone blends towards and Gradient and Flow run to: for your own effect, and for every pet, rule or bar without a second colour of its own."],
  get = function() return GetColour(DB().profile.secondColor) end,
  set = function(_, r, g, b) DB().profile.secondColor = { r, g, b, 1 }; P.Repaint() end,
  hidden = function()
    -- shown while anything uses Two-tone or Gradient: you, a rule, a pet, the power or cast bar
    local p = DB().profile
    local uses = P.UsesSecondColour
    if uses(p.effect) or uses(p.power.effect) or uses(p.cast.effect) or uses(p.classPower.effect) then return false end
    for _, rule in ipairs(p.rules) do if uses(rule.effect) then return false end end
    for _, settings in pairs(p.pets) do if uses(settings.effect) then return false end end
    return true
  end,
}
general.args.speed = {
  type = "range", name = L["Animation Speed"], order = 1.83,
  desc = L["How fast every effect runs, including pet effects and rules. At 1.0 a rainbow cycle takes about 21 seconds and a pulse about 10 seconds; 2.0 is twice as fast."],
  min = 0.1, max = 5, step = 0.1,
  get = function() return DB().profile.rainbowSpeed end,
  set = function(_, v) DB().profile.rainbowSpeed = v end,
}
general.args.sweepStrength = {
  type = "range", name = L["Sweep Strength"], order = 1.835, isPercent = true,
  desc = L["How bright Sweep's band is. It is softer still on a vertical bar such as AzeriteUI's power crystal."],
  min = 0.1, max = 1, step = 0.05,
  get = function() return DB().profile.sweepStrength end,
  set = function(_, v) DB().profile.sweepStrength = v; P.Repaint() end,
}
general.args.sweepPeriod = {
  type = "range", name = L["Sweep Time"], order = 1.836,
  desc = L["How many seconds Sweep's band takes to cross the bar at Animation Speed 1.0."],
  min = 0.8, max = 8, step = 0.2,
  get = function() return DB().profile.sweepPeriod end,
  set = function(_, v) DB().profile.sweepPeriod = v end,
}
general.args.pulseDepth = {
  type = "range", name = L["Pulse Depth"], order = 1.837, isPercent = true,
  desc = L["How dark Pulse gets at its lowest. Lower is a deeper pulse."],
  min = 0.05, max = 0.9, step = 0.05,
  get = function() return DB().profile.pulseDepth end,
  set = function(_, v) DB().profile.pulseDepth = v end,
}
general.args.pattern = {
  type = "select", name = L["Rainbow Pattern"], order = 1.84,
  desc = L["Choose the animation style for the rainbow effect, including pet rainbows."],
  values = { cycle = L["Cycle"], ping = L["Ping-Pong"], chaos = L["Chaos"] },
  sorting = { "cycle", "ping", "chaos" },
  get = function() return DB().profile.rainbowMode end,
  set = function(_, v) DB().profile.rainbowMode = v; P.Repaint() end,
}
general.args.fade = {
  type = "toggle", name = L["Smooth Fades"], order = 1.85,
  desc = L["Blend into a new colour over a third of a second when it changes: a pet is called, a preset loads or a rule starts."],
  get = function() return DB().profile.fade end,
  set = function(_, v) DB().profile.fade = v end,
}
general.args.reduceMotion = {
  type = "toggle", name = L["Reduce Motion"], order = 1.86,
  desc = L["Show every effect as its static colour, everywhere, without changing which effect is picked."],
  get = function() return DB().profile.reduceMotion end,
  set = function(_, v) DB().profile.reduceMotion = v; P.UpdateAnimator(); P.Repaint() end,
}
general.args.updateRate = {
  type = "select", name = L["Update Rate"], order = 1.87,
  desc = L["How often a moving effect repaints the bars. Lower is lighter on slower computers."],
  values = { [15] = L["15 per second"], [30] = L["30 per second"], [60] = L["60 per second"] },
  sorting = { 15, 30, 60 },
  get = function() return DB().profile.updateRate end,
  set = function(_, v) DB().profile.updateRate = v end,
}

-- colour by health
general.args.healthH = {
  type = "header", name = L["Colour by Health"], order = 1.9,
  hidden = function() return not P.HealthColourAvailable() end,
}
general.args.healthColour = {
  type = "toggle", name = L["Colour by Health"], order = 1.91, width = "full",
  desc = L["Your health bar runs from your colour when you are full to the low-health colour when you are nearly dead. The game works the colour out, as your health is hidden from addons, so it cannot carry an effect: an effect you pick shows instead, and None brings colouring by health back. Rules and pet colours still come first."],
  get = function() return DB().profile.healthColour end,
  set = function(_, v) DB().profile.healthColour = v; P.ResetHealthCurves(); P.UpdateAnimator(); P.Repaint() end,
  hidden = function() return not P.HealthColourAvailable() end,
}
general.args.lowHealth = {
  type = "color", name = L["Low Health Colour"], order = 1.92, hasAlpha = true,
  get = function() return GetColour(DB().profile.lowHealthColour) end,
  set = function(_, r, g, b, a) DB().profile.lowHealthColour = { r, g, b, a or 1 }; P.ResetHealthCurves(); P.Repaint() end,
  disabled = function() return not DB().profile.healthColour end,
  hidden = function() return not P.HealthColourAvailable() end,
}

-- preset section
local renameBuffer = ""
general.args.presH = { type = "header", name = L["Presets"], order = 2 }
general.args.sel = {
  type = "select", name = L["Select Preset"],
  desc = L["Apply a saved colour preset."], order = 2.1,
  values = function() local t = {}; for k in pairs(DB().profile.presets) do t[k] = k end return t end,
  get = function() return P.selectedPreset end,
  set = function(_, v) P.LoadPreset(v) end,
}
general.args.renBox = {
  type = "input", name = L["Rename To:"], order = 2.2,
  get = function() return renameBuffer end,
  set = function(_, v) renameBuffer = v end,
  disabled = function() return not P.selectedPreset end,
}
general.args.renBtn = {
  type = "execute", name = L["Rename Preset"],
  desc = L["Rename the selected preset. Names already in use are refused."], order = 2.3,
  func = function() if P.RenamePreset(renameBuffer) then renameBuffer = "" end end,
  disabled = function()
    local newName = strtrim(renameBuffer or "")
    return not P.selectedPreset or newName == "" or newName == P.selectedPreset
  end,
}
general.args.delBtn = {
  type = "execute", name = L["Delete Preset"],
  desc = L["Delete the selected preset."], order = 2.4,
  func = function() P.DeletePreset() end,
  disabled = function() return not P.selectedPreset end,
}
general.args.save = {
  type = "execute", name = L["Save as Preset"],
  desc = L["Save the current colour as a new preset."], order = 2.5,
  func = function() StaticPopup_Show("AZUI_NAME_PRESET") end,
}
-- preset packs: one button each, shown as a grid in the ABCS window
general.args.packs = { type = "group", inline = true, name = L["Preset Packs"], order = 2.7, args = {} }
for index, key in ipairs(P.PRESET_PACK_ORDER) do
  local pack = P.PRESET_PACKS[key]
  local names = {}
  for _, preset in ipairs(pack.presets) do names[#names + 1] = preset[1] end
  general.args.packs.args[key] = {
    type = "execute", order = index,
    name = function() return L["Add"] .. " " .. pack.label end,
    desc = table.concat(names, ", ") .. ". " .. L["Presets you already have keep their colour."],
    func = function()
      local added = P.AddPresetPack(key)
      P.Print(added .. " " .. (added == 1 and L["preset added from"] or L["presets added from"]) .. " " .. pack.label .. ".")
    end,
  }
end

general.args.savePet = {
  type = "execute", name = L["Save to Current Pet"],
  desc = L["Give your active pet the colour from the colour picker as its own colour."], order = 2.6,
  func = function() P.SaveColourToCurrentPet() end,
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
  type = "execute", name = L["Reload"], order = 3.2,
  desc = L["Reloads your UI. All colour and preset changes are saved instantly - this button just forces a /reload."],
  func = function() ReloadUI() end,
}
general.args.minimapToggle = {
  type = "toggle", name = L["Show Minimap Icon"], order = 3.25,
  desc = L["Toggle the minimap launcher button. Left-click opens the ABCS window, right-click the quick palette, Shift-click loads your next preset."],
  get = function() return DB() and not DB().global.minimap.hide end,
  set = function(_, v)
    DB().global.minimap.hide = not v
    if P.DBIcon then if v then P.DBIcon:Show(addonName) else P.DBIcon:Hide(addonName) end end
  end,
}
-- The ABCS window's Studio Health Bar page draws these itself.
for _, key in ipairs({ "col", "effH", "effect", "speed", "sel", "renBox", "renBtn", "delBtn", "save" }) do
  panelMeta[general.args[key]] = { hidden = true, studio = true } -- still found by the window's search
end

general.args.debugT = {
  type = "toggle", name = L["Enable Debug"], order = 90,
  get = function() return DB() and DB().profile.debug end,
  set = function(_, v) DB().profile.debug = v end,
}
general.args.credit = { type = "description", name = "|cff888888Made with love by JuNNeZ — code assisted by ChatGPT and Claude", order = 99 }

P.OnProfileChanged(function() renameBuffer = "" end)
