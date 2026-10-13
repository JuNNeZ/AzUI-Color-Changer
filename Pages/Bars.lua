-- Pages/Bars.lua - the More Bars page: pet frames, power bar, cast bar, class resources.
local addonName, ns = ...
local P = ns.P
local L = P.L
local opts, panelMeta, ForPanel, GetColour = P.options, ns.PanelMeta, P.ForPanel, P.GetColour

local function DB() return P.DB end

---------------------------------------------------------------------
-- MORE BARS PAGE
---------------------------------------------------------------------
local POWER_MODES = { off = L["Leave it alone"], health = L["Match my health bar"], custom = L["Its own colour"] }

-- A bar's own second colour, shown while its own effect uses one.
local function SecondColour(key, order)
  return {
    type = "color", name = L["Second Colour"], order = order, hasAlpha = false,
    desc = L["The other colour of Two-tone, and the far end of Gradient and Flow. Until you pick one, the Second Colour on the Health Bar page is used."],
    get = function() return GetColour(DB().profile[key].color2 or DB().profile.secondColor) end,
    set = function(_, r, g, b) DB().profile[key].color2 = { r, g, b, 1 }; P.Repaint() end,
    hidden = function()
      local bar = DB().profile[key]
      return bar.mode ~= "custom" or not P.UsesSecondColour(bar.effect)
    end,
  }
end

opts.args.bars = {
  type = "group", name = L["More Bars"], order = 5,
  icon = "Interface\\Icons\\Spell_Holy_PowerInfusion", iconCoords = P.ICON_COORDS,
  args = {
    help = {
      type = "description", order = 1,
      name = L["Bars beyond your health bar: the pet frames, your power and cast bars, your class resources, the heal and absorb overlays and Blizzard's personal resource display."],
    },
    rulesNote = {
      type = "description", order = 2,
      name = "|cff999999" .. L["A rule set to show on the power bar, the cast bar or the class resources takes them while the rule shows, even when they are left alone here."] .. "|r",
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
    castH = { type = "header", name = L["Cast Bar"], order = 30 },
    castMode = {
      type = "select", name = L["Cast Bar"], order = 31,
      desc = L["Colour your cast bar (AzeriteUI 5.x, JuNNeZ Edition, ElvUI, Shadowed and Unhalted Unit Frames, oUF layouts). A cast that cannot be interrupted, or one that failed, keeps its own colour."],
      values = POWER_MODES, sorting = { "off", "health", "custom" },
      get = function() return DB().profile.cast.mode end,
      set = function(_, v) DB().profile.cast.mode = v; P.RefreshOptionalBars() end,
    },
    castColour = {
      type = "color", name = L["Cast Bar Colour"], order = 32, hasAlpha = true,
      get = function() return GetColour(DB().profile.cast.color) end,
      set = function(_, r, g, b, a) DB().profile.cast.color = { r, g, b, a or 1 }; P.Repaint() end,
      disabled = function() return DB().profile.cast.mode ~= "custom" end,
    },
    castEffect = {
      type = "select", name = L["Cast Bar Effect"], order = 33,
      values = P.EFFECT_VALUES, sorting = P.EFFECTS,
      confirm = function(_, value) return P.EffectConfirm(value) or false end,
      get = function() return DB().profile.cast.effect end,
      set = function(_, v) DB().profile.cast.effect = v; P.UpdateAnimator(); P.Repaint() end,
      disabled = function() return DB().profile.cast.mode ~= "custom" end,
    },
    powerSecond = SecondColour("power", 23.5),
    castSecond = SecondColour("cast", 33.5),
    classPowerSecond = SecondColour("classPower", 38.5),
    powerH = { type = "header", name = L["Power Bar"], order = 20 },
    powerMode = {
      type = "select", name = L["Power Bar"], order = 21,
      desc = L["Colour your power bar: your unit frame addon's, or the one on Blizzard's player frame. Match my health bar follows your colour, rules and pet colours; Its own colour uses the colour and effect below."],
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
    classPowerH = { type = "header", name = L["Class Resources"], order = 35 },
    classPowerMode = {
      type = "select", name = L["Class Resources"], order = 36,
      desc = L["Colour your combo points, holy power, chi, arcane charges, soul shards, essence or runes, on AzeriteUI, ElvUI, Unhalted Unit Frames and oUF layouts. Points that are not filled keep how faint their addon draws them."],
      values = POWER_MODES, sorting = { "off", "health", "custom" },
      get = function() return DB().profile.classPower.mode end,
      set = function(_, v) DB().profile.classPower.mode = v; P.RefreshOptionalBars() end,
    },
    classPowerColour = {
      type = "color", name = L["Class Resource Colour"], order = 37, hasAlpha = true,
      get = function() return GetColour(DB().profile.classPower.color) end,
      set = function(_, r, g, b, a) DB().profile.classPower.color = { r, g, b, a or 1 }; P.Repaint() end,
      disabled = function() return DB().profile.classPower.mode ~= "custom" end,
    },
    classPowerEffect = {
      type = "select", name = L["Class Resource Effect"], order = 38,
      values = P.EFFECT_VALUES, sorting = P.EFFECTS,
      confirm = function(_, value) return P.EffectConfirm(value) or false end,
      get = function() return DB().profile.classPower.effect end,
      set = function(_, v) DB().profile.classPower.effect = v; P.UpdateAnimator(); P.Repaint() end,
      disabled = function() return DB().profile.classPower.mode ~= "custom" end,
    },
    overlaysH = { type = "header", name = L["Heal and Absorb Overlays"], order = 40 },
    overlays = {
      type = "toggle", name = L["Colour the Heal and Absorb Overlays"], order = 41, width = "full",
      desc = L["The incoming heal and absorb shields drawn over your health bar take a lighter shade of its colour, and keep how see-through their addon makes them. AzeriteUI, ElvUI, Shadowed and Unhalted Unit Frames and oUF layouts."],
      get = function() return DB().profile.overlays end,
      set = function(_, v) DB().profile.overlays = v; P.RefreshOptionalBars() end,
    },
    prdH = { type = "header", name = L["Personal Resource Display"], order = 50 },
    personalResource = {
      type = "toggle", name = L["Colour the Personal Resource Display"], order = 51, width = "full",
      desc = L["The health bar Blizzard draws under your character gets your health bar's colour, and its power bar follows the Power Bar setting above."],
      get = function() return DB().profile.personalResource end,
      set = function(_, v) DB().profile.personalResource = v; P.RefreshOptionalBars() end,
    },
  },
}
