-- Spells.lua - turns what you type in a buff or debuff rule into spell IDs.
--
-- The game only looks a name up for spells you know yourself, so "Bloodlust" on a
-- hunter found nothing and the rule's box emptied. Names are found here instead, in
-- this order: a spell ID as typed; a buff or debuff on you right now; the table below,
-- by the name the game gives each ID in your language (C_Spell.GetSpellName knows
-- every spell) or by its English name; the game's own lookup; and last, a name the
-- text is the start of, when only one fits. A name that stands for several spells
-- (Exhaustion, the drums) brings all of them.
local _, ns = ...
local P = ns.P

-- When the table was last gone through, against which client and release. A test
-- (Tools/TestRules.lua) fails when the TOC's Interface or Version moves past this,
-- so each patch and each release gets a look for buffs and debuffs to add: a new
-- season's lust drums, raid buffs, class changes. Boss and Mythic+ debuffs are left
-- out on purpose: Midnight hides auras from addons in encounters and Mythic+ runs, so
-- a rule on one could only wait there (see P.SpellSecrecy).
P.KNOWN_SPELLS_REVIEWED = {
  interface = 120105, version = "7.0.0", season = "Midnight Season 2 (12.1)", date = "2026-10-13",
}

-- Buffs and debuffs players often build a rule on: { spell ID, English name }.
P.KNOWN_SPELLS = {
  -- Bloodlust and the like, and what they leave behind
  { 2825, "Bloodlust" }, { 32182, "Heroism" }, { 80353, "Time Warp" }, { 264667, "Primal Rage" },
  { 390386, "Fury of the Aspects" }, { 178207, "Drums of Fury" }, { 230935, "Drums of the Mountain" },
  { 256740, "Drums of the Maelstrom" }, { 309658, "Drums of Deathly Ferocity" }, { 381301, "Feral Hide Drums" },
  { 57724, "Sated" }, { 57723, "Exhaustion" }, { 80354, "Temporal Displacement" }, { 264689, "Fatigued" },
  { 390435, "Exhaustion" },
  -- raid buffs
  { 1126, "Mark of the Wild" }, { 21562, "Power Word: Fortitude" }, { 1459, "Arcane Intellect" },
  { 6673, "Battle Shout" }, { 381748, "Blessing of the Bronze" }, { 462854, "Skyfury" },
  -- given by others
  { 10060, "Power Infusion" }, { 29166, "Innervate" }, { 1022, "Blessing of Protection" },
  { 6940, "Blessing of Sacrifice" }, { 1044, "Blessing of Freedom" }, { 33206, "Pain Suppression" },
  { 47788, "Guardian Spirit" }, { 102342, "Ironbark" }, { 116849, "Life Cocoon" }, { 357170, "Time Dilation" },
  -- your own defensives
  { 642, "Divine Shield" }, { 31850, "Ardent Defender" }, { 86659, "Guardian of Ancient Kings" },
  { 45438, "Ice Block" }, { 186265, "Aspect of the Turtle" }, { 48792, "Icebound Fortitude" },
  { 61336, "Survival Instincts" }, { 22812, "Barkskin" }, { 31224, "Cloak of Shadows" }, { 5277, "Evasion" },
  { 104773, "Unending Resolve" }, { 871, "Shield Wall" }, { 118038, "Die by the Sword" },
  { 184364, "Enraged Regeneration" }, { 19236, "Desperate Prayer" }, { 47585, "Dispersion" },
  { 108271, "Astral Shift" }, { 363916, "Obsidian Scales" }, { 198589, "Blur" }, { 115203, "Fortifying Brew" },
  -- your own cooldowns
  { 31884, "Avenging Wrath" }, { 190319, "Combustion" }, { 12472, "Icy Veins" }, { 365350, "Arcane Surge" },
  { 19574, "Bestial Wrath" }, { 288613, "Trueshot" }, { 1719, "Recklessness" }, { 107574, "Avatar" },
  { 13750, "Adrenaline Rush" }, { 51271, "Pillar of Frost" }, { 194223, "Celestial Alignment" },
  { 106951, "Berserk" }, { 375087, "Dragonrage" },
  -- forms and getting about
  { 1784, "Stealth" }, { 2983, "Sprint" }, { 1850, "Dash" }, { 186257, "Aspect of the Cheetah" },
  { 2645, "Ghost Wolf" }, { 768, "Cat Form" }, { 5487, "Bear Form" }, { 783, "Travel Form" },
  { 24858, "Moonkin Form" },
  -- heals over time and shields
  { 774, "Rejuvenation" }, { 8936, "Regrowth" }, { 33763, "Lifebloom" }, { 139, "Renew" },
  { 17, "Power Word: Shield" }, { 61295, "Riptide" }, { 53563, "Beacon of Light" }, { 119611, "Renewing Mist" },
  { 136, "Mend Pet" },
  -- debuffs that say a cooldown is spent
  { 25771, "Forbearance" }, { 87024, "Cauterized" }, { 41425, "Hypothermia" },
}

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) or false end

local function Key(text) return P.Lower(strtrim(tostring(text or ""))) end

-- The game's name for a spell, in your language, or nil.
local function GameName(id)
  if not (C_Spell and C_Spell.GetSpellName) then return end
  local ok, name = pcall(C_Spell.GetSpellName, id)
  if ok and not Secret(name) and type(name) == "string" and name ~= "" then return name end
end

-- name (lower case) -> { ids }, and every name as it is shown, built once
local index, shown
local function Add(name, id)
  local key = Key(name)
  if key == "" then return end
  if not index[key] then index[key] = {}; shown[#shown + 1] = name end
  for _, known in ipairs(index[key]) do if known == id then return end end
  table.insert(index[key], id)
end

local function Index()
  if index then return index end
  index, shown = {}, {}
  for _, spell in ipairs(P.KNOWN_SPELLS) do
    Add(GameName(spell[1]) or spell[2], spell[1])
    Add(spell[2], spell[1])
  end
  table.sort(shown, function(a, b) return P.Lower(a) < P.Lower(b) end)
  return index
end

-- The buffs and debuffs on you now, as { name, id }; none while the game hides them.
local function OnYou()
  local out = {}
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if type(get) ~= "function" then return out end
  for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
    for i = 1, 40 do
      local ok, aura = pcall(get, "player", i, filter)
      if not ok or aura == nil or Secret(aura) then break end
      local name, id = aura.name, aura.spellId
      if not Secret(name) and not Secret(id) and type(name) == "string" and type(id) == "number" then
        out[#out + 1] = { name, id }
      end
    end
  end
  return out
end

-- The table's English name for a spell, for a client that cannot name it.
function P.KnownSpellName(id)
  for _, spell in ipairs(P.KNOWN_SPELLS) do
    if spell[1] == id then return spell[2] end
  end
end

-- Whether the game shows a spell to addons when it is on you: "never" hidden, hidden
-- "always", or hidden "sometimes" (in encounters, Mythic+ and other restricted
-- combat). nil when the client cannot say.
local SECRECY = { [0] = "never", [1] = "always", [2] = "sometimes" }
function P.SpellSecrecy(id)
  if type(id) ~= "number" or not (C_Secrets and C_Secrets.GetSpellAuraSecrecy) then return end
  local ok, level = pcall(C_Secrets.GetSpellAuraSecrecy, id)
  if ok and not Secret(level) then return SECRECY[level] end
end

-- Forget the names, so they are read again (for the tests, which change language).
function P.ForgetSpellNames() index, shown = nil, nil end

-- One typed name or ID as a list of spell IDs, or nil.
function P.FindSpell(text)
  text = strtrim(tostring(text or ""))
  if text == "" then return end
  local id = tonumber(text)
  if id then return { id } end
  local key = Key(text)
  local found = {}
  for _, aura in ipairs(OnYou()) do
    if Key(aura[1]) == key then found[#found + 1] = aura[2] end
  end
  if #found > 0 then return found end
  local known = Index()[key]
  if known then return known end
  if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
    local ok, game = pcall(C_Spell.GetSpellIDForSpellIdentifier, text)
    if ok and not Secret(game) and type(game) == "number" then return { game } end
  end
  -- the start of a name, when only one name fits
  local only
  for _, name in ipairs(P.SpellSuggestions(text, 2)) do
    if only then return end
    only = name
  end
  if only then return P.FindSpell(only) end
end

-- Names that start with (or else contain) `text`: the buffs on you first, then the
-- table. At most `limit`.
function P.SpellSuggestions(text, limit)
  Index()
  limit = limit or 12
  local key, out, seen = Key(text), {}, {}
  if key == "" then return out end
  local function Offer(name)
    local lower = Key(name)
    if not seen[lower] and #out < limit then seen[lower] = true; out[#out + 1] = name end
  end
  for pass = 1, 2 do
    local function Fits(name)
      local at = Key(name):find(key, 1, true)
      if pass == 1 then return at == 1 end
      return at ~= nil and at > 1
    end
    for _, aura in ipairs(OnYou()) do if Fits(aura[1]) then Offer(aura[1]) end end
    for _, name in ipairs(shown) do if Fits(name) then Offer(name) end end
  end
  return out
end
