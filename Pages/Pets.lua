-- Pages/Pets.lua - the Hunter Pets page: one group per pet, active slots first.
local addonName, ns = ...
local P = ns.P
local L = P.L
local opts, panelMeta, ForPanel, GetColour = P.options, ns.PanelMeta, P.ForPanel, P.GetColour

local function DB() return P.DB end

---------------------------------------------------------------------
-- HUNTER PETS PAGE
---------------------------------------------------------------------
local MODE_VALUES  = { family = L["Family colour"], custom = L["Own colour"], off = L["No pet colour"] }
local MODE_SORTING = { "family", "custom", "off" }
P.PET_MODE_VALUES, P.PET_MODE_SORTING = MODE_VALUES, MODE_SORTING -- the pet gallery shows the same

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
      color2 = {
        type = "color", name = L["Second Colour"], order = 4.5, hasAlpha = false,
        desc = L["The other colour of Two-tone, and the far end of Gradient and Flow. Until you pick one, the Second Colour on the Health Bar page is used."],
        get = function() return GetColour(P.PetSecondColour(number) or DB().profile.secondColor) end,
        set = function(_, r, g, b) P.SetPetSecondColour(number, r, g, b) end,
        hidden = function() return isOff() or not P.UsesSecondColour(P.PetEffect(number)) end,
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
  }, { hidden = true }) -- the ABCS window draws pets in its gallery
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
