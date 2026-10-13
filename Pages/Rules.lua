-- Pages/Rules.lua - the Rules page in the classic window (the AzUI window draws its own).
local addonName, ns = ...
local P = ns.P
local L = P.L
local opts, panelMeta, ForPanel, GetColour = P.options, ns.PanelMeta, P.ForPanel, P.GetColour

local function DB() return P.DB end

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
  recipes = {
    type = "select", name = L["Ready-made rules"], order = 2.6,
    desc = L["Adds the rule you pick at the bottom of the list, switched off. Try it, then switch it on."],
    values = P.RULE_RECIPE_VALUES, sorting = P.RULE_RECIPE_ORDER,
    get = function() return nil end,
    set = function(_, key) P.AddRuleRecipe(key) end,
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

-- The controls for one condition of a rule: which (1 or 2), a list to pick its value
-- from, or a box to type it in.
local function ConditionArgs(rule, which, changed, order)
  local key, valueKey = which == 1 and "condition" or "condition2", which == 1 and "value" or "value2"
  local negateKey = which == 1 and "negate" or "negate2"
  local function condition() local r = rule(); return r and P.CONDITIONS[r[key]] end
  return {
    [negateKey] = {
      type = "toggle", order = order + 0.05, width = "half", name = L["Not"],
      desc = L["Show the rule while this is not true, such as not in a group."],
      get = function() return rule()[negateKey] == true end,
      set = function(_, v) rule()[negateKey] = v or nil; changed() end,
      hidden = function() return which == 2 and not rule().condition2 end,
    },
    [key] = {
      type = "select", order = order,
      name = which == 1 and L["When"] or L["And"],
      values = which == 1 and P.CONDITION_VALUES or P.SECOND_CONDITION_VALUES,
      sorting = which == 1 and P.CONDITION_SORTING or P.SECOND_CONDITION_SORTING,
      get = function() return rule()[key] or "none" end,
      set = function(_, v) P.SetRuleCondition(rule(), which, v) end,
    },
    [valueKey] = {
      type = "select", order = order + 0.1,
      name = function() local c = condition(); return c and c.label or "" end,
      values = function() local c = condition(); return c and c.values and c.values() or {} end,
      sorting = function() local c = condition(); return c and c.sorting or nil end,
      get = function() return rule()[valueKey] end,
      set = function(_, v) rule()[valueKey] = v; changed() end,
      hidden = function() local c = condition(); return not (c and c.hasValue) or c.input ~= nil end,
    },
    [valueKey .. "Input"] = {
      type = "input", order = order + 0.2,
      name = function() local c = condition(); return c and c.input and c.input.label or "" end,
      desc = function() local c = condition(); return c and c.input and c.input.help or "" end,
      get = function()
        local c, value = condition(), rule()[valueKey]
        return c and c.input and value ~= nil and c.input.format(value) or ""
      end,
      set = function(_, v) local c = condition(); rule()[valueKey] = c.input.parse(v, rule()[valueKey]); changed() end,
      hidden = function() local c = condition(); return not (c and c.input) end,
    },
  }
end

local function RuleGroup(index)
  local function rule() return DB().profile.rules[index] end
  local function changed() P.RulesChanged() end
  local args = {
    enabled = {
      type = "toggle", name = L["On"], order = 1,
      get = function() return rule().enabled end,
      set = function(_, v) rule().enabled = v; changed() end,
    },
    color = {
      type = "color", name = L["Colour"], order = 4, hasAlpha = true,
      get = function() return GetColour(rule().color) end,
      set = function(_, r, g, b, a) rule().color = { r, g, b, a or 1 }; P.Repaint() end,
      disabled = function() return rule().effect == "rainbow" end,
    },
    color2 = {
      type = "color", name = L["Second Colour"], order = 5.5, hasAlpha = false,
      desc = L["The other colour of Two-tone, and the far end of Gradient and Flow. Until you pick one, the Second Colour on the Health Bar page is used."],
      get = function() return GetColour(rule().color2 or DB().profile.secondColor) end,
      set = function(_, r, g, b) rule().color2 = { r, g, b, 1 }; P.Repaint() end,
      hidden = function() return not P.UsesSecondColour(rule().effect) end,
    },
    effect = {
      type = "select", name = L["Effect"], order = 5,
      values = P.RULE_EFFECT_VALUES, sorting = P.RULE_EFFECTS,
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
    sound = {
      type = "select", name = L["Sound"], order = 6.5,
      desc = L["A sound when the rule starts showing. It plays on the Master channel, so it is heard with sound effects off."],
      values = P.RULE_SOUND_VALUES, sorting = P.RULE_SOUND_ORDER,
      get = function() return rule().sound or "none" end,
      set = function(_, v) P.SetRuleSound(rule(), v) end,
    },
    actions = {
      type = "group", inline = true, name = "", order = 7,
      args = {
        try = {
          type = "execute", name = L["Try"], order = 0.5, width = "half",
          desc = L["Shows the rule on its bars for five seconds, whether or not it would match now."],
          func = function() P.TryRule(rule()) end,
        },
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
  }
  for key, option in pairs(ConditionArgs(rule, 1, changed, 2)) do args[key] = option end
  for key, option in pairs(ConditionArgs(rule, 2, changed, 3)) do args[key] = option end
  return {
    type = "group", inline = true, order = 10 + index,
    name = function()
      local r = rule()
      if not r then return "" end
      local state = r.enabled and "" or ("  |cff999999(" .. L["off"] .. ")|r")
      local live = P.RuleShowing(r) and ("  |cff00ff00" .. L["showing now"] .. "|r") or ""
      return L["Rule"] .. " " .. index .. ": " .. P.DescribeRule(r) .. state .. live
    end,
    args = args,
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
