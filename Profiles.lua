-- Profiles.lua - every character shares the Default profile until you say otherwise.
-- A character can keep its own, and an optional switch picks one per specialization.
-- The pet list always stays per character.
local _, ns = ...
local P = ns.P
local L = P.L

function P.ProfileChoices()
  local list = {}
  for _, name in ipairs(P.DB:GetProfiles()) do list[name] = name end
  return list
end

function P.NewProfile(name)
  name = strtrim(name or "")
  if name == "" then return false end
  P.DB:SetProfile(name)
  return true
end

function P.DeleteProfile(name)
  if not name or name == P.DB:GetCurrentProfile() then return false end
  P.DB:DeleteProfile(name, true)
  -- a specialization can no longer switch to it
  local specs = P.DB.char.specProfiles
  for index, profile in pairs(specs) do
    if type(index) == "number" and profile == name then specs[index] = nil end
  end
  return true
end

-- Switches to the profile picked for the specialization you are in.
function P.ApplySpecProfile()
  local specs = P.DB and P.DB.char.specProfiles
  if not (specs and specs.enabled) then return false end
  local spec = P.Specialization()
  local name = spec and specs[spec]
  if not name or name == P.DB:GetCurrentProfile() then return false end
  -- only to a profile that still exists
  if not P.ProfileChoices()[name] then return false end
  P.DB:SetProfile(name)
  P.Print(L["Switched to profile"] .. " " .. name)
  return true
end

-- A lighter choice than a profile: changing specialization loads the preset picked
-- for it. Only a real change does, so logging in keeps the colour you left with.
local lastSpec
function P.ApplySpecPreset()
  local spec = P.Specialization()
  local changed = lastSpec ~= nil and spec ~= lastSpec
  lastSpec = spec or lastSpec
  local presets = P.DB and P.DB.char.specPresets
  if not (changed and presets and presets.enabled) then return false end
  local name = spec and presets[spec]
  if not (name and P.DB.profile.presets[name]) then return false end
  P.LoadPreset(name)
  P.Print(L["Loaded preset"] .. " " .. name)
  return true
end

-- The profile first, so the preset is looked up in the profile you end up in.
local function SpecChanged()
  P.ApplySpecProfile()
  P.ApplySpecPreset()
end
P.On("PLAYER_SPECIALIZATION_CHANGED", SpecChanged, "player")
P.On("ACTIVE_TALENT_GROUP_CHANGED", SpecChanged)
P.On("PLAYER_ENTERING_WORLD", function()
  P.ApplySpecProfile()
  lastSpec = lastSpec or P.Specialization()
end)
P.OnInitialize(function() lastSpec = P.Specialization() end)
