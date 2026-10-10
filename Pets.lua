-- Pets.lua - the stable, the pet that is out, and the colour a pet brings.
local _, ns = ...
local P = ns.P
local L = P.L

-- Call Pet 1-5. The summoned pet's Call Pet spell stays current, which is how Blizzard's stable finds it.
P.CALL_PET_SPELLS  = { 883, 83242, 83243, 83244, 83245 }
P.TAME_BEAST_SPELL = 1515
local COMPANION_SLOT   = 6 -- Beast Mastery's second pet; stabled pets come after it
local LAST_ACTIVE_SLOT = P.IS_FOREVER and 1 or COMPANION_SLOT

-- Hunter pet families and their fallback colours, keyed by creature family ID so they work
-- on every client language (UnitCreatureFamily returns the ID as its 2nd value).
-- Each entry is { familyID, name, r, g, b }.
P.FAMILY_GROUPS = {
  { name = "Exotics", families = {
    { 46,  "Spirit Beast",  0.00, 1.00, 1.00 }, -- cyan aura
    { 39,  "Devilsaur",     0.90, 0.20, 0.10 }, -- blood-red scales
    { 45,  "Core Hound",    1.00, 0.35, 0.25 }, -- fiery magma
    { 38,  "Chimaera",      0.25, 0.80, 1.00 }, -- frost-blue breath
    { 43,  "Clefthoof",     0.55, 0.35, 0.25 }, -- earthen hide
    { 138, "Direhorn",      0.60, 0.40, 0.20 }, -- muddy horn
    { 156, "Scalehide",     0.40, 0.70, 0.30 }, -- mossy scales
    { 55,  "Shale Beast",   0.65, 0.50, 0.75 }, -- crystalline purple
    { 128, "Stone Hound",   0.50, 0.70, 0.90 }, -- azure stone
    { 126, "Water Strider", 0.20, 0.60, 0.80 }, -- teal water walker
    { 68,  "Hydra",         0.25, 0.75, 0.55 }, -- emerald scales
    { 41,  "Aqiri",         0.85, 0.45, 0.15 }, -- bronze carapace
    { 150, "Riverbeast",    0.35, 0.65, 0.45 }, -- swamp green
    { 42,  "Worm",          0.70, 0.55, 0.25 }, -- sandy burrower
    { 292, "Carapid",       0.70, 0.30, 0.80 }, -- purple chitin
    { 290, "Pterrordax",    0.80, 0.60, 0.30 }, -- amber wing
  } },
  { name = "Mammals", families = {
    { 4,   "Bear",        0.45, 0.35, 0.25 }, -- brown fur
    { 5,   "Boar",        0.60, 0.40, 0.30 }, -- tusky brown
    { 2,   "Cat",         1.00, 0.50, 0.50 }, -- pale pink
    { 50,  "Fox",         0.95, 0.45, 0.20 }, -- orange fur
    { 9,   "Gorilla",     0.40, 0.40, 0.40 }, -- grey shadow
    { 25,  "Hyena",       0.80, 0.60, 0.25 }, -- savannah
    { 51,  "Monkey",      0.65, 0.55, 0.40 }, -- jungle brown
    { 157, "Oxen",        0.50, 0.45, 0.35 }, -- taupe
    { 127, "Rodent",      0.75, 0.65, 0.55 }, -- whiskered grey
    { 12,  "Tallstrider", 0.85, 0.70, 0.20 }, -- savannah yellow
    { 298, "Camel",       0.75, 0.65, 0.45 }, -- desert beige
    { 299, "Courser",     0.90, 0.80, 0.60 }, -- golden stallion
    { 160, "Feathermane", 0.75, 0.50, 0.85 }, -- majestic plum
    { 129, "Gruffhorn",   0.55, 0.45, 0.30 }, -- rough hide
    { 52,  "Hound",       0.60, 0.50, 0.40 }, -- loyal brown
    { 300, "Mammoth",     0.65, 0.55, 0.45 }, -- tusked grey
    { 151, "Stag",        0.50, 0.70, 0.40 }, -- forest green
    { 1,   "Wolf",        0.45, 0.50, 0.55 }, -- pack grey
  } },
  { name = "Birds", families = {
    { 7,   "Carrion Bird", 0.75, 0.35, 0.20 }, -- vulture red-brown
    { 26,  "Bird of Prey", 0.95, 0.85, 0.30 }, -- golden feather
    { 30,  "Dragonhawk",   0.90, 0.30, 0.30 }, -- fiery wings
    { 31,  "Ravager",      0.80, 0.40, 0.20 }, -- rust chitin
    { 37,  "Moth",         0.80, 0.75, 0.85 }, -- soft lilac
    { 24,  "Bat",          0.30, 0.25, 0.35 }, -- night wing
    { 125, "Waterfowl",    0.40, 0.70, 0.90 }, -- lake blue
  } },
  { name = "Reptiles & Amphibians", families = {
    { 130, "Basilisk",     0.35, 0.75, 0.60 }, -- jade hide
    { 8,   "Crab",         0.90, 0.30, 0.30 }, -- scarlet shell
    { 6,   "Crocolisk",    0.30, 0.70, 0.35 }, -- swamp reptile
    { 11,  "Raptor",       0.80, 0.45, 0.20 }, -- rust scales
    { 35,  "Serpent",      0.15, 0.75, 0.40 }, -- emerald serpent
    { 21,  "Turtle",       0.20, 0.60, 0.30 }, -- jade shell
    { 288, "Lizard",       0.55, 0.80, 0.35 }, -- lime scales
    { 315, "Whiptail",     0.60, 0.75, 0.30 }, -- olive scales
    { 33,  "Sporebat",     0.55, 0.80, 0.90 }, -- cyan spores
    { 291, "Hopper",       0.60, 0.80, 0.50 }, -- leap green
    { 34,  "Ray",          0.70, 0.60, 0.90 }, -- ethereal purple
    { 27,  "Wind Serpent", 0.50, 0.90, 0.70 }, -- airy teal
  } },
  { name = "Insects & Arachnids", families = {
    { 3,   "Spider",  0.45, 0.45, 0.55 }, -- web grey
    { 44,  "Wasp",    1.00, 0.85, 0.15 }, -- yellow stinger
    { 53,  "Beetle",  0.30, 0.70, 0.55 }, -- jade carapace
    { 20,  "Scorpid", 0.85, 0.70, 0.30 }, -- desert amber
  } },
  { name = "Mechanical & Special", families = {
    { 154, "Mechanical",       0.50, 0.80, 1.00 }, -- arcane blue steel
    { 296, "Blood Beast",      0.80, 0.15, 0.20 }, -- crimson blood
    { 303, "Lesser Dragonkin", 0.60, 0.40, 0.85 }, -- dragon purple
    { 32,  "Warp Stalker",     0.85, 0.50, 0.95 }, -- void pink
  } },
}

local familyColours, familyIDsByName = {}, {}
P.familyNames = {}
for _, group in ipairs(P.FAMILY_GROUPS) do
  for _, family in ipairs(group.families) do
    local id = family[1]
    familyColours[id] = { family[3], family[4], family[5], 1 }
    P.familyNames[id] = family[2]
    familyIDsByName[family[2]] = id -- English names, for stabled pets not yet seen out on this client
  end
end

-- Hunter pet specializations by spec ID, with English names for when no pet of that spec is known yet.
-- Forever's stable has no pet specializations, so this is Retail only.
P.PET_SPECS = {
  { 74, "Ferocity", 0.85, 0.25, 0.20 }, -- blood red
  { 81, "Tenacity", 0.30, 0.65, 0.35 }, -- steady green
  { 79, "Cunning",  0.55, 0.40, 0.85 }, -- sly violet
}
local specColours = {}
P.specNames = {}
for _, spec in ipairs(P.PET_SPECS) do
  specColours[spec[1]] = { spec[3], spec[4], spec[5], 1 }
  P.specNames[spec[1]] = spec[2]
end

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
P.currentPet = nil     -- { number, name, icon, familyName, familyID } of the pet that is out; hunter pets have a number
P.activePet = nil      -- { color, effect } while a coloured pet is out (never saved)
P.petSuppressed = false -- you picked a colour or effect while the pet colour was on your health bar

---------------------------------------------------------------------
-- COLOURS
---------------------------------------------------------------------
function P.FamilyColour(familyID)
  return familyID and (P.DB.profile.familyColours[familyID] or familyColours[familyID])
end

function P.SpecColour(specID)
  return specID and (P.DB.profile.specColours[specID] or specColours[specID])
end

-- What a family-coloured pet shows: its specialization's colour when those are on, otherwise its family's
function P.GroupColour(number, familyID)
  local pet = number and P.DB.char.knownPets[number]
  if P.DB.profile.useSpecColours and not P.IS_FOREVER and pet then
    local colour = P.SpecColour(pet.specID)
    if colour then return colour end
  end
  return P.FamilyColour(familyID)
end

function P.PetMode(number)
  local settings = number and P.DB.profile.pets[number]
  return settings and settings.mode or "family"
end

function P.PetEffect(number)
  local settings = number and P.DB.profile.pets[number]
  return settings and settings.effect or "static"
end

function P.EnsurePetSettings(number)
  local pets = P.DB.profile.pets
  if not pets[number] then pets[number] = { mode = "family", effect = "static" } end
  return pets[number]
end

-- Older versions coloured a pet with a preset named after it; turn that into the pet's own colour once
function P.MigrateNamePreset(number, name)
  local p = P.DB.profile
  if not number or not name or p.pets[number] or not p.presets[name] then return end
  p.pets[number] = { mode = "custom", color = P.CopyColour(p.presets[name]), effect = "static" }
end

-- The colour a pet shows, or nil: its own colour, a preset named after a pet the stable
-- does not know (such as another class's pet), or its family colour
function P.PetColour(number, name, familyID)
  local mode = P.PetMode(number)
  if mode == "off" then return nil end
  if mode == "custom" and P.DB.profile.pets[number].color then return P.DB.profile.pets[number].color end
  if not number and name and P.DB.profile.presets[name] then return P.DB.profile.presets[name] end
  return P.GroupColour(number, familyID)
end

---------------------------------------------------------------------
-- THE STABLE
---------------------------------------------------------------------
-- Keep what the stable told us about a pet, so the Hunter Pets page can list it later.
-- Returns the pet's number and whether the list changed.
function P.RememberPet(info, slot)
  local number = type(info) == "table" and tonumber(info.petNumber)
  if not number or number <= 0 then return end
  local known = P.DB.char.knownPets
  local pet = known[number]
  slot = slot or info.slotID
  local changed = not pet or pet.name ~= info.name or pet.slot ~= slot or pet.icon ~= info.icon
    or pet.displayID ~= info.displayID or pet.specID ~= info.specID
  if not pet then
    pet = {}
    known[number] = pet
  end
  pet.name, pet.slot, pet.icon = info.name, slot, info.icon
  pet.familyName, pet.specialization = info.familyName, info.specialization
  -- for the gallery's portraits and model; Forever's stable may leave these out
  pet.displayID, pet.uiModelSceneID = tonumber(info.displayID), tonumber(info.uiModelSceneID)
  pet.specID, pet.level, pet.isExotic = tonumber(info.specID), tonumber(info.level), info.isExotic and true or nil
  local familyName = info.familyName or ""
  pet.familyID = pet.familyID or P.DB.global.familyIDs[familyName] or familyIDsByName[familyName]
  return number, changed
end

function P.RefreshKnownPets()
  if not P.DB or not P.isHunter or not C_StableInfo then return false end
  local seen, changed = {}, false
  local complete = true
  local function rememberInfo(info, slot)
    local number, isChanged = P.RememberPet(info, slot)
    if number then
      seen[number] = true
      changed = changed or isChanged
    end
  end
  local function remember(getList)
    local ok, list = pcall(getList)
    if not ok or type(list) ~= "table" then complete = false; return end
    for _, info in ipairs(list) do
      rememberInfo(info)
    end
  end
  if P.IS_FOREVER then
    -- Blizzard's Camelot stable reads slot 1 (current pet), then stable slots.
    local slots = Constants and Constants.PetConsts and Constants.PetConsts.NUM_PET_SLOTS_HUNTER
    if type(slots) ~= "number" then return false end
    for slot = 1, slots do
      local ok, info = pcall(C_StableInfo.GetStablePetInfo, slot)
      if ok then rememberInfo(info, slot) else complete = false end
    end
  else
    remember(C_StableInfo.GetActivePetList)
    remember(C_StableInfo.GetStabledPetList)
  end
  -- Only a stable master shows every pet, so only forget abandoned pets there
  if complete and next(seen) and C_StableInfo.IsAtStableMaster and C_StableInfo.IsAtStableMaster() then
    local known = P.DB.char.knownPets
    for number in pairs(known) do
      if not seen[number] then
        known[number] = nil
        changed = true
      end
    end
  end
  return changed
end

-- The summoned hunter pet's stable entry. Unlike UnitName this still works when the game hides unit names.
function P.GetSummonedPetInfo()
  if not P.isHunter or not (C_StableInfo and C_StableInfo.GetStablePetInfo) then return end
  if P.IS_FOREVER then
    return C_StableInfo.GetStablePetInfo(1)
  end
  local name = P.Accessible(UnitName("pet"))
  if C_Spell and C_Spell.IsCurrentSpell then
    for slot = 1, #P.CALL_PET_SPELLS do
      local ok, current = pcall(C_Spell.IsCurrentSpell, P.CALL_PET_SPELLS[slot])
      if ok and P.IsAccessible(current) and current then
        local info = C_StableInfo.GetStablePetInfo(slot)
        if type(info) == "table" and (not name or info.name == name) then return info end
      end
    end
  end
  local ok, list = pcall(C_StableInfo.GetActivePetList)
  if name and ok and type(list) == "table" then
    for _, info in ipairs(list) do
      if info.name == name then return info end
    end
  end
end

-- Note the pet's family while the game shows it, so other pets of that family get its colour too
local function ReadPetFamily(pet)
  local familyName, familyID = UnitCreatureFamily("pet")
  familyName, familyID = P.Accessible(familyName), P.Accessible(familyID)
  if familyID then
    if familyName then P.DB.global.familyIDs[familyName] = familyID end
    if pet then pet.familyID = familyID end
  end
  return familyName or (pet and pet.familyName), familyID or (pet and pet.familyID)
end

-- Work out which pet is out and the colour it brings
local function ResolvePet()
  P.currentPet, P.activePet = nil, nil
  if not UnitExists("pet") then return end
  local info = P.GetSummonedPetInfo()
  local number = info and P.RememberPet(info, P.IS_FOREVER and 1 or nil)
  local pet = number and P.DB.char.knownPets[number]
  local familyName, familyID = ReadPetFamily(pet)
  local name = pet and pet.name or P.Accessible(UnitName("pet"))
  P.currentPet = { number = number, name = name, icon = pet and pet.icon, familyName = familyName, familyID = familyID }
  P.MigrateNamePreset(number, name)
  if not P.DB.profile.petColouring then return end
  local colour, effect = P.PetColour(number, name, familyID), P.PetEffect(number)
  if colour or (effect == "rainbow" and P.PetMode(number) ~= "off") then
    P.activePet = { color = colour, effect = effect }
  end
end

-- Recolour for the current pet without touching the options panel (safe while a colour picker is open)
function P.ApplyPetColour()
  if not P.DB then return end
  ResolvePet()
  P.UpdateAnimator()
  P.Repaint()
end

-- A pet or pet setting changed: recolour and rebuild the Hunter Pets page.
-- `fade` blends into the new colour, for a pet being called or dismissed.
function P.UpdatePetColour(fade)
  if not P.DB then return end
  if fade then P.StartFade() end
  P.petSuppressed = false
  P.ApplyPetColour()
  if P.BuildPetOptions then P.BuildPetOptions() end
  P.RefreshOptions()
end

-- Make a pet's colour its family's colour, so every pet of that family shows it
function P.CopyPetColourToFamily(number)
  local pet = number and P.DB.char.knownPets[number]
  local colour = pet and pet.familyID and P.PetColour(number, pet.name, pet.familyID)
  if not colour then return false end
  P.DB.profile.familyColours[pet.familyID] = P.CopyColour(colour)
  P.UpdatePetColour()
  return true
end

---------------------------------------------------------------------
-- LISTING
---------------------------------------------------------------------
local function SlotKey(pet)
  local slot = pet.slot or math.huge
  return slot <= LAST_ACTIVE_SLOT and slot or LAST_ACTIVE_SLOT + 1
end

function P.IsActiveSlot(pet) return SlotKey(pet) <= LAST_ACTIVE_SLOT end

-- every remembered pet as { number, pet }, call-pet slots first, then stabled pets by name
function P.GetKnownPets()
  local list = {}
  if not P.DB then return list end
  for number, pet in pairs(P.DB.char.knownPets) do list[#list + 1] = { number = number, pet = pet } end
  table.sort(list, function(a, b)
    local keyA, keyB = SlotKey(a.pet), SlotKey(b.pet)
    if keyA ~= keyB then return keyA < keyB end
    return (a.pet.name or "") < (b.pet.name or "")
  end)
  return list
end

function P.PetSummary(number, pet)
  local text = pet.familyName or P.familyNames[pet.familyID] or L["Unknown family"]
  if pet.specialization and pet.specialization ~= "" then text = text .. " · " .. pet.specialization end
  if P.IS_FOREVER then
    text = text .. "\n" .. (pet.slot == 1 and L["Current pet slot"] or L["Stabled"])
  elseif pet.slot and pet.slot <= #P.CALL_PET_SPELLS then
    text = text .. "\n" .. L["Call Pet"] .. " " .. pet.slot
  elseif pet.slot == COMPANION_SLOT then
    text = text .. "\n" .. L["Second pet slot"]
  else
    text = text .. "\n" .. L["Stabled"]
  end
  if P.currentPet and P.currentPet.number == number then
    text = text .. " · |cff00ff00" .. L["Out now"] .. "|r"
  end
  return text
end

---------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------
P.On("PLAYER_ENTERING_WORLD", function()
  if not P.DB then return end
  P.RefreshKnownPets()
  P.UpdatePetColour()
end)

P.On("UNIT_PET", function()
  if not P.DB then return end
  P.RefreshKnownPets()
  P.UpdatePetColour(true)
  -- the stable can lag behind a summon; look once more so the pet's own colour is not missed
  if P.isHunter and UnitExists("pet") and not (P.currentPet and P.currentPet.number) then
    C_Timer.After(1, function() P.UpdatePetColour() end)
  end
end, "player")

local function StableChanged()
  if P.DB and P.RefreshKnownPets() then P.UpdatePetColour() end
end
P.On("PET_STABLE_UPDATE", StableChanged)
P.On("PET_STABLE_SHOW", StableChanged)

P.OnInitialize(function()
  P.RefreshKnownPets()
end)
