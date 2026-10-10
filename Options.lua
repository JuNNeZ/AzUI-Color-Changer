-- Options.lua - the option table (one source for the AzUI window, the classic Ace3
-- window and Blizzard's Settings), slash commands, key bindings and the launcher.
local addonName, ns = ...
local P = ns.P
local L = P.L

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

StaticPopupDialogs["AZUI_RESET_CONFIRM"] = {
  text    = L["This will reset all settings and delete your presets and pet colours in the current profile. Are you sure?"],
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
  OnAccept = function() DB():ResetProfile() end, -- OnProfileReset does the rest
}

---------------------------------------------------------------------
-- OPTIONS TABLE
---------------------------------------------------------------------
local opts = { name = addonName, type = "group", childGroups = "tree", args = {} }
P.options = opts

-- What only the AzUI window needs to know about an option: hidden there, or how it
-- knows it was changed and puts it back. Kept beside the table, because
-- AceConfigRegistry refuses option keys it does not know.
local panelMeta = setmetatable({}, { __mode = "k" })
ns.PanelMeta = panelMeta
local function ForPanel(option, meta) panelMeta[option] = meta; return option end

local function GetColour(c) return c[1], c[2], c[3], c[4] or 1 end

opts.args.ver = { type = "description", name = "|cff999999Version " .. P.VERSION, order = 0 }
opts.args.openPanel = ForPanel({
  type = "execute", name = L["Open the AzUI window"], order = 0.5,
  desc = L["The AzUI window has a pet gallery with portraits and models, and search across every setting."],
  func = function() if ns.OpenPanel then ns.OpenPanel() end end,
}, { hidden = true })

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
  desc = L["The colour Two-tone blends towards, for your own effect and every Two-tone pet or rule."],
  get = function() return GetColour(DB().profile.secondColor) end,
  set = function(_, r, g, b) DB().profile.secondColor = { r, g, b, 1 }; P.Repaint() end,
  hidden = function()
    -- shown while anything uses Two-tone: you, a rule, a pet or the power bar
    local p = DB().profile
    if p.effect == "twotone" or p.power.effect == "twotone" then return false end
    for _, rule in ipairs(p.rules) do if rule.effect == "twotone" then return false end end
    for _, settings in pairs(p.pets) do if settings.effect == "twotone" then return false end end
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
  desc = L["Toggle the minimap launcher button. Left-click opens the AzUI window, right-click the quick palette, Shift-click loads your next preset."],
  get = function() return DB() and not DB().global.minimap.hide end,
  set = function(_, v)
    DB().global.minimap.hide = not v
    if P.DBIcon then if v then P.DBIcon:Show(addonName) else P.DBIcon:Hide(addonName) end end
  end,
}
-- The AzUI window's Studio Health Bar page draws these itself.
for _, key in ipairs({ "col", "effH", "effect", "speed", "sel", "renBox", "renBtn", "delBtn", "save" }) do
  panelMeta[general.args[key]] = { hidden = true, studio = true } -- still found by the window's search
end

general.args.debugT = {
  type = "toggle", name = L["Enable Debug"], order = 90,
  get = function() return DB() and DB().profile.debug end,
  set = function(_, v) DB().profile.debug = v end,
}
general.args.credit = { type = "description", name = "|cff888888Made with love by JuNNeZ — code assisted by ChatGPT and Claude", order = 99 }

---------------------------------------------------------------------
-- RULES PAGE
---------------------------------------------------------------------
local rulesGroup = {
  type = "group", name = L["Rules"], order = 2, args = {},
  icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
  iconCoords = P.ICON_COORDS,
}
opts.args.rules = rulesGroup

local rulesStatic = {
  help = {
    type = "description", order = 1,
    name = L["A rule shows its colour and effect while its condition is true: in combat, mounted, in a dungeon and so on. Rules come before pet colours and your own colour, and the first rule that matches wins for each bar."],
  },
  add = {
    type = "execute", name = L["Add Rule"], order = 2,
    desc = L["Adds a rule at the bottom of the list. Move it up to let it win over the others."],
    func = function() P.AddRule() end,
  },
  examples = {
    type = "execute", name = L["Add Example Rules"], order = 2.5,
    desc = L["Adds five rules many players use, switched off: grey while dead, a red pulse in combat, violet in stealth, gold in raids and green while resting."],
    func = function() P.AddExampleRules() end,
  },
  empty = {
    type = "description", order = 3,
    name = "|cff999999" .. L["No rules yet."] .. "|r",
    hidden = function() return #DB().profile.rules > 0 end,
  },
}

local function DescribeRule(rule)
  local condition = P.CONDITIONS[rule.condition]
  local text = condition and condition.label or "?"
  if condition and condition.hasValue and rule.value ~= nil then
    local values = condition.values()
    text = text .. ": " .. tostring(values[rule.value] or rule.value)
  end
  return text
end

local function RuleGroup(index)
  local function rule() return DB().profile.rules[index] end
  local function changed() P.RulesChanged() end
  return {
    type = "group", inline = true, order = 10 + index,
    name = function()
      local r = rule()
      if not r then return "" end
      local state = r.enabled and "" or ("  |cff999999(" .. L["off"] .. ")|r")
      local live = (P.ActiveRule("player") == r or P.ActiveRule("pet") == r) and ("  |cff00ff00" .. L["showing now"] .. "|r") or ""
      return L["Rule"] .. " " .. index .. ": " .. DescribeRule(r) .. state .. live
    end,
    args = {
      enabled = {
        type = "toggle", name = L["On"], order = 1,
        get = function() return rule().enabled end,
        set = function(_, v) rule().enabled = v; changed() end,
      },
      condition = {
        type = "select", name = L["When"], order = 2,
        values = P.CONDITION_VALUES, sorting = P.CONDITION_SORTING,
        get = function() return rule().condition end,
        set = function(_, v)
          local r = rule()
          r.condition = v
          r.value = (v == "spec" and P.Specialization()) or (v == "instance" and "any") or nil
          changed()
        end,
      },
      value = {
        type = "select", name = function() return rule().condition == "spec" and L["Specialization"] or L["Instance"] end,
        order = 3,
        values = function()
          local condition = P.CONDITIONS[rule().condition]
          return condition and condition.values and condition.values() or {}
        end,
        sorting = function() return rule().condition == "instance" and P.INSTANCE_SORTING or nil end,
        get = function() return rule().value end,
        set = function(_, v) rule().value = v; changed() end,
        hidden = function()
          local condition = rule() and P.CONDITIONS[rule().condition]
          return not (condition and condition.hasValue)
        end,
      },
      color = {
        type = "color", name = L["Colour"], order = 4, hasAlpha = true,
        get = function() return GetColour(rule().color) end,
        set = function(_, r, g, b, a) rule().color = { r, g, b, a or 1 }; P.Repaint() end,
        disabled = function() return rule().effect == "rainbow" end,
      },
      effect = {
        type = "select", name = L["Effect"], order = 5,
        values = P.EFFECT_VALUES, sorting = P.EFFECTS,
        confirm = function(_, value) return P.EffectConfirm(value) or false end,
        get = function() return rule().effect end,
        set = function(_, v) rule().effect = v; P.UpdateAnimator(); P.Repaint() end,
      },
      target = {
        type = "select", name = L["Show On"], order = 6,
        values = P.RULE_TARGETS, sorting = P.RULE_TARGET_SORTING,
        get = function() return rule().target end,
        set = function(_, v) rule().target = v; changed() end,
      },
      actions = {
        type = "group", inline = true, name = "", order = 7,
        args = {
          up = {
            type = "execute", name = L["Move Up"], order = 1, width = "half",
            func = function() P.MoveRule(index, -1) end,
            disabled = function() return index == 1 end,
          },
          down = {
            type = "execute", name = L["Move Down"], order = 2, width = "half",
            func = function() P.MoveRule(index, 1) end,
            disabled = function() return index == #DB().profile.rules end,
          },
          delete = {
            type = "execute", name = L["Delete"], order = 3, width = "half",
            confirm = function() return L["Delete this rule?"] end,
            func = function() P.DeleteRule(index) end,
          },
        },
      },
    },
  }
end

function P.BuildRuleOptions()
  if not P.DB then return end
  local args = rulesGroup.args
  wipe(args)
  for key, option in pairs(rulesStatic) do args[key] = option end
  for index in ipairs(P.DB.profile.rules) do
    -- the AzUI window draws rules as sentences on its Studio Rules page
    args["rule" .. index] = ForPanel(RuleGroup(index), { hidden = true })
  end
end
for _, option in pairs(rulesStatic) do panelMeta[option] = { hidden = true } end

---------------------------------------------------------------------
-- HUNTER PETS PAGE
---------------------------------------------------------------------
local MODE_VALUES  = { family = L["Family colour"], custom = L["Own colour"], off = L["No pet colour"] }
local MODE_SORTING = { "family", "custom", "off" }

local petsGroup = {
  type = "group", name = L["Hunter Pets"], order = 3, args = {},
  icon = function() return P.currentPet and P.currentPet.icon or P.SpellIcon(P.CALL_PET_SPELLS[1]) end,
  iconCoords = P.ICON_COORDS,
}
opts.args.pets = petsGroup

local stabledGroup = ForPanel({ type = "group", name = L["Stabled Pets"], order = 1000, args = {} }, { hidden = true })
local stabledHelp = {
  type = "description", order = 1,
  name = L["Pets in your stable. A colour or effect you give them here shows when you call them."],
}

local function CurrentPetText()
  local pet = P.currentPet
  if not pet then return L["No pet out."] end
  local text = L["Out now:"] .. " |cffffffff" .. (pet.name or L["your pet"]) .. "|r"
  if pet.familyName then text = text .. " (" .. pet.familyName .. ")" end
  if not DB().profile.petColouring then
    text = text .. "\n|cff999999" .. L["Turn on Use Pet Colours to show its colour."] .. "|r"
  elseif not P.activePet then
    text = text .. "\n|cff999999" .. L["This pet has no colour to show."] .. "|r"
  end
  return text
end

local petStatic = {
  enable = {
    type = "toggle", name = L["Use Pet Colours"], width = "full", order = 1,
    desc = L["While a pet is out, show its colour: its own colour or effect from this page, or its family colour. Your own colour and effects come back when the pet is dismissed."],
    get = function() return DB().profile.petColouring end,
    set = function(_, v) DB().profile.petColouring = v; P.UpdatePetColour(true) end,
  },
  target = {
    type = "select", name = L["Show Pet Colours On"], width = "double", order = 2,
    desc = L["Where a pet's colour goes. The other bar keeps your own colour and effect."],
    values = { both = L["Health bar and pet frame"], player = L["Health bar only"], pet = L["Pet frame only"] },
    sorting = { "both", "player", "pet" },
    get = function() return DB().profile.petTarget end,
    set = function(_, v) DB().profile.petTarget = v; P.UpdatePetColour() end,
    disabled = function() return not DB().profile.petColouring end,
  },
  current = {
    type = "description", fontSize = "medium", order = 3,
    name = CurrentPetText,
    image = function() return P.currentPet and P.currentPet.icon end,
    imageCoords = P.ICON_COORDS, imageWidth = 32, imageHeight = 32,
  },
  help = {
    type = "description", order = 4,
    name = L["Pick a pet to give it its own colour or effect. Pets without one use their family colour, which you can change under Pet Families. If a stabled pet is missing, visit a stable master."],
    hidden = function() return not P.isHunter end,
  },
  otherHelp = {
    type = "description", order = 4,
    name = L["Your pet uses a preset named after it, or its family colour from Pet Families."],
    hidden = function() return P.isHunter end,
  },
}

local function PetGroup(number, pet, order)
  local function isOff() return P.PetMode(number) == "off" end
  return ForPanel({
    type = "group", order = order, icon = pet.icon, iconCoords = P.ICON_COORDS,
    name = function()
      local name = pet.name or "?"
      if P.currentPet and P.currentPet.number == number then return "|cff00ff00" .. name .. "|r" end
      return name
    end,
    args = {
      info = {
        type = "description", fontSize = "medium", order = 1,
        image = pet.icon, imageCoords = P.ICON_COORDS, imageWidth = 40, imageHeight = 40,
        name = function() return P.PetSummary(number, pet) end,
      },
      mode = {
        type = "select", name = L["Colour"], order = 2,
        desc = L["Family colour: the colour for its family under Pet Families. Own colour: the colour picked here. No pet colour: this pet leaves your bars alone."],
        values = MODE_VALUES, sorting = MODE_SORTING,
        get = function() return P.PetMode(number) end,
        set = function(_, value) P.SetPetMode(number, value) end,
      },
      color = {
        type = "color", name = L["Own Colour"], hasAlpha = true, order = 3,
        desc = L["Picking a colour switches this pet to its own colour."],
        get = function() return GetColour(P.PetColour(number, pet.name, pet.familyID) or DB().profile.color) end,
        set = function(_, r, g, b, a) P.SetPetColour(number, r, g, b, a) end,
        disabled = isOff,
      },
      effect = {
        type = "select", name = L["Effect"], order = 4,
        desc = L["An effect on this pet's colour while it is out. Speed and rainbow pattern come from the Health Bar page."],
        values = P.EFFECT_VALUES, sorting = P.EFFECTS,
        confirm = function(_, value) return P.EffectConfirm(value) or false end,
        get = function() return P.PetEffect(number) end,
        set = function(_, value) P.EnsurePetSettings(number).effect = value; P.UpdatePetColour() end,
        disabled = isOff,
      },
      reset = {
        type = "execute", name = L["Reset"], order = 5,
        desc = L["Go back to the family colour with no effect."],
        func = function() P.ResetPet(number) end,
      },
      family = {
        type = "execute", order = 6,
        name = function() return L["Use for all"] .. " " .. (pet.familyName or P.familyNames[pet.familyID] or L["of this family"]) end,
        desc = L["Make this pet's colour the colour of its whole family under Pet Families."],
        func = function() P.CopyPetColourToFamily(number) end,
        disabled = function() return isOff() or not pet.familyID end,
      },
    },
  }, { hidden = true }) -- the AzUI window draws pets in its gallery
end

function P.SetPetMode(number, mode)
  local settings = P.EnsurePetSettings(number)
  if mode == "custom" and not settings.color then
    local pet = DB().char.knownPets[number]
    settings.color = P.CopyColour(P.GroupColour(number, pet and pet.familyID) or DB().profile.color)
  end
  settings.mode = mode
  P.UpdatePetColour()
end

function P.SetPetColour(number, r, g, b, a)
  local settings = P.EnsurePetSettings(number)
  settings.mode, settings.color = "custom", { r, g, b, a or 1 }
  P.petSuppressed = false
  P.ApplyPetColour()
end

function P.ResetPet(number)
  DB().profile.pets[number] = { mode = "family", effect = "static" }
  P.UpdatePetColour()
end

function P.BuildPetOptions()
  if not P.DB then return end
  local args, stabledArgs = petsGroup.args, stabledGroup.args
  wipe(args)
  wipe(stabledArgs)
  for key, option in pairs(petStatic) do args[key] = option end
  args.stabled, stabledArgs.help = stabledGroup, stabledHelp

  local numStabled = 0
  for i, entry in ipairs(P.GetKnownPets()) do
    P.MigrateNamePreset(entry.number, entry.pet.name)
    local group = PetGroup(entry.number, entry.pet, 10 + i)
    if P.IsActiveSlot(entry.pet) then
      args["pet" .. entry.number] = group
    else
      numStabled = numStabled + 1
      stabledArgs["pet" .. entry.number] = group
    end
  end
  stabledGroup.name = L["Stabled Pets"] .. " (" .. numStabled .. ")"
  stabledGroup.hidden = numStabled == 0
end

---------------------------------------------------------------------
-- PET FAMILIES PAGE
---------------------------------------------------------------------
local familiesGroup = {
  type = "group", name = L["Pet Families"], order = 4, args = {},
  icon = function() return P.SpellIcon(P.TAME_BEAST_SPELL) end,
  iconCoords = P.ICON_COORDS,
}
opts.args.families = familiesGroup

familiesGroup.args.help = {
  type = "description", order = 1,
  name = L["Pets without their own colour use their family's colour. A changed colour gets a Reset button next to it."],
}
familiesGroup.args.resetAll = {
  type = "execute", name = L["Reset All Families"], order = 2,
  desc = L["Put every family back to its built-in colour."],
  func = function() wipe(DB().profile.familyColours); P.UpdatePetColour() end,
  disabled = function() return next(DB().profile.familyColours) == nil end,
}
-- Specialization colours sit between a pet's family colour and its own colour
local specArgs = {
  enable = {
    type = "toggle", name = L["Use Specialization Colours"], width = "full", order = 1,
    desc = L["Pets set to their family colour show their specialization's colour instead. Pets with their own colour keep it."],
    get = function() return DB().profile.useSpecColours end,
    set = function(_, v) DB().profile.useSpecColours = v; P.UpdatePetColour() end,
  },
}
for index, spec in ipairs(P.PET_SPECS) do
  local id = spec[1]
  specArgs["s" .. id] = {
    type = "color", order = 1 + index,
    name = function()
      for _, pet in pairs(DB().char.knownPets) do
        if pet.specID == id and pet.specialization and pet.specialization ~= "" then return pet.specialization end
      end
      return L[P.specNames[id]]
    end,
    disabled = function() return not DB().profile.useSpecColours end,
    get = function() return GetColour(P.SpecColour(id)) end,
    set = function(_, r, g, b)
      DB().profile.specColours[id] = { r, g, b, 1 }
      P.petSuppressed = false
      P.ApplyPetColour()
    end,
  }
  panelMeta[specArgs["s" .. id]] = {
    modified = function() return DB().profile.specColours[id] ~= nil end,
    reset = function() DB().profile.specColours[id] = nil; P.UpdatePetColour() end,
  }
end
familiesGroup.args.specs = {
  type = "group", inline = true, name = L["Specializations"], order = 5, args = specArgs,
  hidden = function() return P.IS_FOREVER end,
}

for groupIndex, group in ipairs(P.FAMILY_GROUPS) do
  local args = {}
  for familyIndex, family in ipairs(group.families) do
    local id = family[1]
    args["f" .. id] = {
      type = "color", name = family[2], order = familyIndex * 2,
      get = function() return GetColour(P.FamilyColour(id)) end,
      set = function(_, r, g, b)
        DB().profile.familyColours[id] = { r, g, b, 1 }
        P.petSuppressed = false
        P.ApplyPetColour()
      end,
    }
    args["r" .. id] = {
      type = "execute", name = L["Reset"], width = "half", order = familyIndex * 2 + 1,
      func = function() DB().profile.familyColours[id] = nil; P.UpdatePetColour() end,
      hidden = function() return not DB().profile.familyColours[id] end,
    }
    -- the AzUI window puts a reset arrow on the colour itself instead
    panelMeta[args["f" .. id]] = {
      modified = function() return DB().profile.familyColours[id] ~= nil end,
      reset = function() DB().profile.familyColours[id] = nil; P.UpdatePetColour() end,
    }
    panelMeta[args["r" .. id]] = { hidden = true }
  end
  familiesGroup.args["group" .. groupIndex] = {
    type = "group", inline = true, name = group.name, order = 10 + groupIndex, args = args,
  }
end

---------------------------------------------------------------------
-- MORE BARS PAGE
---------------------------------------------------------------------
local POWER_MODES = { off = L["Leave it alone"], health = L["Match my health bar"], custom = L["Its own colour"] }

opts.args.bars = {
  type = "group", name = L["More Bars"], order = 5,
  icon = "Interface\\Icons\\Spell_Holy_PowerInfusion", iconCoords = P.ICON_COORDS,
  args = {
    help = {
      type = "description", order = 1,
      name = L["Bars beyond your health bar: Blizzard's pet frame and your power bar."],
    },
    petH = { type = "header", name = L["Blizzard Pet Frame"], order = 10 },
    petFrames = {
      type = "toggle", name = L["Colour the Pet Frames"], order = 10.5, width = "full",
      desc = L["Off leaves AzeriteUI's and Blizzard's pet frames to their own colours. Your pet's colour can still go on your health bar."],
      get = function() return DB().profile.colourPetFrames end,
      set = function(_, v) DB().profile.colourPetFrames = v; P.RefreshOptionalBars() end,
    },
    blizzardPet = {
      type = "toggle", name = L["Colour Blizzard's Pet Frame"], order = 11, width = "full",
      disabled = function() return not DB().profile.colourPetFrames end,
      desc = L["Blizzard's pet frame gets the same colour as AzeriteUI's: your pet's colour where it goes there, otherwise your own."],
      get = function() return DB().profile.blizzardPetFrame end,
      set = function(_, v) DB().profile.blizzardPetFrame = v; P.RefreshOptionalBars() end,
    },
    powerH = { type = "header", name = L["Power Bar"], order = 20 },
    powerMode = {
      type = "select", name = L["Power Bar"], order = 21,
      desc = L["Colour your power bar: AzeriteUI's, or the one on Blizzard's player frame. Match my health bar follows your colour, rules and pet colours; Its own colour uses the colour and effect below."],
      values = POWER_MODES, sorting = { "off", "health", "custom" },
      get = function() return DB().profile.power.mode end,
      set = function(_, v) DB().profile.power.mode = v; P.RefreshOptionalBars() end,
    },
    powerColour = {
      type = "color", name = L["Power Bar Colour"], order = 22, hasAlpha = true,
      get = function() return GetColour(DB().profile.power.color) end,
      set = function(_, r, g, b, a) DB().profile.power.color = { r, g, b, a or 1 }; P.Repaint() end,
      disabled = function() return DB().profile.power.mode ~= "custom" end,
    },
    powerEffect = {
      type = "select", name = L["Power Bar Effect"], order = 23,
      values = P.EFFECT_VALUES, sorting = P.EFFECTS,
      confirm = function(_, value) return P.EffectConfirm(value) or false end,
      get = function() return DB().profile.power.effect end,
      set = function(_, v) DB().profile.power.effect = v; P.UpdateAnimator(); P.Repaint() end,
      disabled = function() return DB().profile.power.mode ~= "custom" end,
    },
  },
}

---------------------------------------------------------------------
-- PROFILES PAGE
---------------------------------------------------------------------
local newProfileName = ""

local profilesGroup = {
  type = "group", name = L["Profiles"], order = 6,
  icon = "Interface\\Icons\\INV_Misc_Note_01", iconCoords = P.ICON_COORDS,
  args = {
    help = {
      type = "description", order = 1,
      name = L["Every character starts on the Default profile. A profile holds your colours, effects, presets, rules and pet colours; your pet list stays with each character."],
    },
    current = {
      type = "select", name = L["Current Profile"], order = 2,
      values = function() return P.ProfileChoices() end,
      get = function() return DB():GetCurrentProfile() end,
      set = function(_, v) DB():SetProfile(v) end,
    },
    new = {
      type = "input", name = L["New Profile"], order = 3,
      desc = L["Type a name and press Enter to make a profile with the default settings and switch to it."],
      get = function() return newProfileName end,
      set = function(_, v) if P.NewProfile(v) then newProfileName = "" end end,
    },
    copy = {
      type = "select", name = L["Copy From"], order = 4,
      desc = L["Copy another profile's settings into the current one."],
      values = function()
        local list = P.ProfileChoices()
        list[DB():GetCurrentProfile()] = nil
        return list
      end,
      confirm = function(_, v) return L["Replace the current profile's settings with"] .. " " .. tostring(v) .. "?" end,
      get = function() return nil end,
      set = function(_, v) DB():CopyProfile(v) end,
    },
    delete = {
      type = "select", name = L["Delete a Profile"], order = 5,
      values = function()
        local list = P.ProfileChoices()
        list[DB():GetCurrentProfile()] = nil
        return list
      end,
      confirm = function(_, v) return L["Delete the profile"] .. " " .. tostring(v) .. "?" end,
      get = function() return nil end,
      set = function(_, v) P.DeleteProfile(v) end,
    },
    reset = {
      type = "execute", name = L["Reset Profile"], order = 6,
      desc = L["Put the current profile back to the default settings."],
      func = function() StaticPopup_Show("AZUI_RESET_CONFIRM") end,
    },
    specH = { type = "header", name = L["Per Specialization"], order = 10 },
    specEnable = {
      type = "toggle", name = L["Switch Profile with Specialization"], order = 11, width = "full",
      desc = L["When you change specialization, switch to the profile picked for it below."],
      get = function() return DB().char.specProfiles.enabled end,
      set = function(_, v) DB().char.specProfiles.enabled = v; P.ApplySpecProfile() end,
    },
  },
}
opts.args.profiles = profilesGroup

-- one picker per specialization of your class, made once your class is known
local function BuildSpecProfileOptions()
  for index, name in pairs(P.SpecChoices()) do
    profilesGroup.args["spec" .. index] = {
      type = "select", name = name, order = 11 + index,
      values = function()
        local list = P.ProfileChoices()
        list[""] = L["Keep the current profile"]
        return list
      end,
      get = function() return DB().char.specProfiles[index] or "" end,
      set = function(_, v)
        DB().char.specProfiles[index] = v ~= "" and v or nil
        P.ApplySpecProfile()
      end,
      disabled = function() return not DB().char.specProfiles.enabled end,
    }
  end
end

---------------------------------------------------------------------
-- SHARE PAGE
---------------------------------------------------------------------
local exportText, importText, importData, importError = "", "", nil, nil

local shareArgs = {
  help = {
    type = "description", order = 1,
    name = L["Turn your setup, or just the parts you tick, into one line of text to paste in Discord or a guide. Paste one below to bring someone else's in."],
  },
  unavailable = {
    type = "description", order = 2,
    name = "|cffff6060" .. L["This game client cannot make or read share strings."] .. "|r",
    hidden = function() return P.CanShare() end,
  },
  exportH = { type = "header", name = L["Export"], order = 10 },
  exportBtn = {
    type = "execute", name = L["Make Share String"], order = 20,
    desc = L["Makes a string of the parts ticked above. Select it and press Ctrl+C to copy it."],
    func = function()
      local text, err = P.Export(P.shareParts)
      exportText = text or ""
      if err then P.Print(err) end
    end,
    disabled = function() return not P.CanShare() end,
  },
  exportBox = {
    type = "input", name = L["Share String"], order = 21, multiline = 4, width = "full",
    get = function() return exportText end,
    set = function() end,
    disabled = function() return exportText == "" end,
  },
  importH = { type = "header", name = L["Import"], order = 30 },
  importBox = {
    type = "input", name = L["Paste a Share String"], order = 31, multiline = 4, width = "full",
    get = function() return importText end,
    set = function(_, v)
      importText = v or ""
      importData, importError = P.Decode(importText)
    end,
    disabled = function() return not P.CanShare() end,
  },
  preview = {
    type = "description", order = 32,
    name = function()
      if importError then return "|cffff6060" .. importError .. "|r" end
      if not importData then return "" end
      return L["Importing will change:"] .. "\n• " .. table.concat(P.DescribeImport(importData), "\n• ")
    end,
    hidden = function() return not importData and not importError end,
  },
  apply = {
    type = "execute", name = L["Import"], order = 33,
    desc = L["Apply the string to your current profile. Presets and pet colours with the same names are replaced; rules are replaced as a list."],
    confirm = function() return L["Import these settings into your current profile?"] end,
    func = function()
      if not importData then return end
      P.ApplyImport(importData)
      importText, importData, importError = "", nil, nil
      P.Print(L["Imported."])
    end,
    disabled = function() return not importData end,
  },
}
for index, part in ipairs(P.SHARE_PARTS) do
  shareArgs["part_" .. part] = {
    type = "toggle", name = P.SHARE_PART_NAMES[part], order = 10 + index * 0.1,
    get = function() return P.shareParts[part] end,
    set = function(_, v) P.shareParts[part] = v and true or false end,
  }
end
opts.args.share = {
  type = "group", name = L["Share"], order = 7, args = shareArgs,
  icon = "Interface\\Icons\\INV_Letter_15", iconCoords = P.ICON_COORDS,
}

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
  options       = opts,
  appName       = addonName,
  version       = P.VERSION,
  icon          = P.ADDON_ICON,
  iconCoords    = P.ICON_COORDS,
  isForever     = P.IS_FOREVER,
  modeValues    = MODE_VALUES,     modeSorting   = MODE_SORTING,
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
  ResetPet      = function(...) return P.ResetPet(...) end,
  CopyToFamily  = function(number) return P.CopyPetColourToFamily(number) end,
}

---------------------------------------------------------------------
-- SET-UP
---------------------------------------------------------------------
P.OnInitialize(function()
  BuildSpecProfileOptions()
  P.BuildPetOptions()
  P.BuildRuleOptions()
  P.AceConfig:RegisterOptionsTable(addonName, opts)
  P.optionsRegistered = true
  ns.optionsFrame, ns.optionsCategoryID = P.AceConfigDialog:AddToBlizOptions(addonName, "AzUI Color Picker")

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
  renameBuffer = ""
  P.BuildRuleOptions()
  P.UpdatePetColour()
end)
