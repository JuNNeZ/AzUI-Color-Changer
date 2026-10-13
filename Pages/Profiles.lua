-- Pages/Profiles.lua - the Profiles page, with a profile per specialization.
local addonName, ns = ...
local P = ns.P
local L = P.L
local opts, panelMeta, ForPanel, GetColour = P.options, ns.PanelMeta, P.ForPanel, P.GetColour

local function DB() return P.DB end

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
    presetH = { type = "header", name = L["Preset per Specialization"], order = 20 },
    presetEnable = {
      type = "toggle", name = L["Load a Preset with Specialization"], order = 21, width = "full",
      desc = L["When you change specialization, load the preset picked for it below. Lighter than a profile: only your colour changes."],
      get = function() return DB().char.specPresets.enabled end,
      set = function(_, v) DB().char.specPresets.enabled = v end,
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
    profilesGroup.args["specPreset" .. index] = {
      type = "select", name = name, order = 21 + index,
      values = function()
        local list = {}
        for _, preset in ipairs(P.SortedPresetNames()) do list[preset] = preset end
        list[""] = L["Keep my colour"]
        return list
      end,
      get = function() return DB().char.specPresets[index] or "" end,
      set = function(_, v) DB().char.specPresets[index] = v ~= "" and v or nil end,
      disabled = function() return not DB().char.specPresets.enabled end,
    }
  end
end

P.OnInitialize(BuildSpecProfileOptions)
