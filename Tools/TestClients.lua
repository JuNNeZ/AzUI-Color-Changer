-- Run from the addon directory: lua Tools/TestClients.lua (Lua 5.1).
-- The hunter stable on Retail and on Forever, recognised from the TOC or the build.
local Mock = dofile("Tools/Mock.lua")
local checks = 0
local function check(value, message)
  if not value then error("FAILED: " .. message, 2) end
  checks = checks + 1
end

for _, client in ipairs({ "retail", "foreverToc", "foreverBuild" }) do
  local forever = client ~= "retail"
  local slots = {
    [1] = { petNumber = 11, slotID = 1, name = "Wolf", familyName = "Wolf" },
    [2] = { petNumber = 22, slotID = 2, name = "Cat", familyName = "Cat" },
    [6] = { petNumber = 66, slotID = 6, name = "Bear", familyName = "Bear" },
    [7] = { petNumber = 77, slotID = 7, name = "Boar", familyName = "Boar" },
  }
  local stable = { atStable = false, failed = false }
  local game = Mock.New({
    forever = forever, noMarker = client == "foreverBuild",
    stable = function(env)
      env.UnitName = function() return "Cat" end
      env.C_Spell.IsCurrentSpell = function(id) return id == 83242 end
      env.C_StableInfo = {
        GetStablePetInfo = function(slot) if stable.failed and slot == 2 then error("Unavailable") end; return slots[slot] end,
        GetActivePetList = function() assert(not forever, "Camelot must use indexed stable"); return { slots[1], slots[2], slots[6] } end,
        GetStabledPetList = function() if stable.failed then error("Unavailable") end; return { slots[7] } end,
        IsAtStableMaster = function() return stable.atStable end,
      }
    end,
  })
  local P, db = game.P, game.db
  check(P.IS_FOREVER == forever, client .. ": client recognised")
  check(P.currentPet and P.currentPet.number == (forever and 11 or 22), client .. ": the summoned pet")
  P.BuildPetOptions()
  local args = P.options.args.pets.args
  check(args.pet11 ~= nil, client .. ": current slot is active")
  if forever then
    check(args.pet22 == nil and args.stabled.args.pet22 ~= nil, client .. ": slot 2 is stabled")
    check(P.PetSummary(22, db.char.knownPets[22]):find("Stabled"), client .. ": stable label")
    check(not db.char.knownPets[66], client .. ": Retail slots are not read")
  else
    check(args.pet22 and args.pet66, "retail: active and companion slots")
    check(args.stabled.args.pet77, "retail: stabled slot")
    check(P.PetSummary(66, db.char.knownPets[66]):find("Second pet slot"), "retail: companion label")
  end
  db.char.knownPets[99] = { name = "Previously known" }
  P.RefreshKnownPets()
  check(db.char.knownPets[99], client .. ": cache kept away from the stable")
  stable.atStable, stable.failed = true, true
  P.RefreshKnownPets()
  check(db.char.knownPets[99], client .. ": incomplete stable reads keep the cache")
  stable.failed = false
  P.RefreshKnownPets()
  check(not db.char.knownPets[99], client .. ": complete stable reads drop abandoned pets")
end
print(checks .. " client checks passed")
