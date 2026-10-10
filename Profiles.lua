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

P.On("PLAYER_SPECIALIZATION_CHANGED", function() P.ApplySpecProfile() end, "player")
P.On("ACTIVE_TALENT_GROUP_CHANGED", function() P.ApplySpecProfile() end)
P.On("PLAYER_ENTERING_WORLD", function() P.ApplySpecProfile() end)
