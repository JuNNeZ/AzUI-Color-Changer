-- Pages/Families.lua - the Pet Families page: family and specialization colours.
local addonName, ns = ...
local P = ns.P
local L = P.L
local opts, panelMeta, ForPanel, GetColour = P.options, ns.PanelMeta, P.ForPanel, P.GetColour

local function DB() return P.DB end

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
    -- the ABCS window puts a reset arrow on the colour itself instead
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
