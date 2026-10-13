-- Rules.lua - colour rules: "when this is true (and, if you like, that too), show this
-- colour and effect on these bars". Either condition can be turned around ("not in a
-- group"). Rules sit above pet colours and your own colour; the first matching rule in
-- the list wins for each bar, and with none matching nothing changes. A rule can be
-- tried for a few seconds from the window, whether its conditions hold or not, and can
-- play a sound when it starts.
local _, ns = ...
local P = ns.P
local L = P.L

local function Specialization()
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    local ok, index = pcall(C_SpecializationInfo.GetSpecialization)
    if ok then return index end
  end
  if GetSpecialization then return GetSpecialization() end
end
P.Specialization = Specialization

-- Every specialization of your class, as { [index] = name }.
function P.SpecChoices()
  local choices = {}
  local classID = select(3, UnitClass("player"))
  local count
  if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID and classID then
    count = C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
  elseif GetNumSpecializations then
    count = GetNumSpecializations()
  end
  local info = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
  for index = 1, tonumber(count) or 0 do
    local ok, _, name = pcall(info, index)
    choices[index] = ok and name or (L["Specialization"] .. " " .. index)
  end
  return choices
end

-- Your role: the one your group gave you, else your specialization's.
function P.Role()
  if UnitGroupRolesAssigned then
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if ok and P.IsAccessible(role) and role ~= "NONE" and role ~= "" then return role end
  end
  local spec = Specialization()
  if spec and GetSpecializationRole then
    local ok, role = pcall(GetSpecializationRole, spec)
    if ok and P.IsAccessible(role) then return role end
  end
end

-- The zone you are in and the place within it, for zone rules.
local function Zones()
  local real = GetRealZoneText and P.Accessible(GetRealZoneText())
  local zone = GetZoneText and P.Accessible(GetZoneText())
  local sub = GetSubZoneText and P.Accessible(GetSubZoneText())
  return real, zone, sub
end

function P.CurrentZone()
  local real, zone = Zones()
  return real or zone or ""
end

-- A name from outside (a rule typed in or imported): no colour codes, not too long.
local function CleanText(text)
  if type(text) ~= "string" then return end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%c|]", "")
  text = strtrim(text)
  if text == "" then return end
  return text:sub(1, 64)
end

P.INSTANCE_VALUES = {
  any = L["Any instance"], party = L["Dungeon"], raid = L["Raid"], scenario = L["Scenario or delve"],
  pvp = L["Battleground"], arena = L["Arena"], none = L["Open world"],
}
P.INSTANCE_SORTING = { "any", "party", "raid", "scenario", "pvp", "arena", "none" }
P.ROLE_VALUES = { TANK = L["Tank"], HEALER = L["Healer"], DAMAGER = L["Damage"] }
P.ROLE_SORTING = { "TANK", "HEALER", "DAMAGER" }
P.GROUP_VALUES = {
  solo = L["Solo"], group = L["In any group"], party = L["In a party"], raid = L["In a raid"],
  bigraid = L["In a raid of 20 or more"],
}
P.GROUP_SORTING = { "solo", "group", "party", "raid", "bigraid" }
P.PET_VALUES = { out = L["Out"], none = L["Not out"] }
P.PET_SORTING = { "out", "none" }
P.TIME_VALUES = { dawn = L["Dawn (5 to 8)"], day = L["Day (8 to 18)"], dusk = L["Dusk (18 to 21)"], night = L["Night (21 to 5)"] }
P.TIME_SORTING = { "dawn", "day", "dusk", "night" }
P.THREAT_VALUES = { aggro = L["I have aggro"], losing = L["Losing aggro"], high = L["About to pull aggro"] }
P.THREAT_SORTING = { "aggro", "losing", "high" }
P.CAST_VALUES = { any = L["Casting or channelling"], cast = L["Casting"], channel = L["Channelling"] }
P.CAST_SORTING = { "any", "cast", "channel" }

-- The part of the day on the game's clock (the realm's time).
function P.TimeOfDay()
  local hours = GetGameTime and GetGameTime()
  hours = tonumber(hours) or 12
  if hours >= 5 and hours < 8 then return "dawn" end
  if hours >= 8 and hours < 18 then return "day" end
  if hours >= 18 and hours < 21 then return "dusk" end
  return "night"
end

-- A test answers this when the game hides the answer (a secret value): the rule
-- waits, whether its condition is turned around or not.
local WAIT = "wait"
P.RULE_WAIT = WAIT

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) or false end

-- Your threat: nil off every threat list, 0 below the tank, 1 above the tank but not
-- tanking, 2 tanking while someone else is above you, 3 tanking securely. The answer
-- is secret while threat is restricted.
local function ThreatStatus()
  if type(UnitThreatSituation) ~= "function" then return end
  local ok, status = pcall(UnitThreatSituation, "player")
  if not ok then return end
  if Secret(status) then return WAIT end
  return tonumber(status)
end

-- Are you casting (UnitCastingInfo) or channelling (UnitChannelInfo, empowered spells
-- too)? WAIT when the game hides it.
local function CastsWith(fn)
  if type(fn) ~= "function" then return false end
  local ok, name = pcall(fn, "player")
  if not ok then return false end
  if Secret(name) then return WAIT end
  return name ~= nil
end

-- Auras a buff rule has seen on you, by aura instance: when one of them goes, the
-- rules are checked again (see UNIT_AURA below).
local trackedAuras = {}
local function TrackAura(aura)
  local id = aura.auraInstanceID
  if P.IsAccessible(id) then trackedAuras[id] = true end
end

local function CallIf(fn, ...)
  if type(fn) ~= "function" then return false end
  local ok, result = pcall(fn, ...)
  return ok and result
end

local function KeyOf(values, fallback)
  return function(value) return values[value] and value or fallback end
end

-- Combat follows its own events: while PLAYER_REGEN_DISABLED is being handled the
-- game may not report you as in combat yet.
local inCombat = false

-- Each condition: a label and a test. Some take a value: picked from a list (`values`,
-- in `sorting` order) or typed in (`input`). `default` is the value a new rule starts
-- with, `clean` checks a value from outside, and `icon` is shown on the Studio's rule
-- row when the art pack has no picture of its own for the condition.
P.CONDITIONS = {
  combat  = { label = L["In combat"], test = function() return inCombat end },
  -- Midnight hides threat in some content; the rule then waits rather than guess
  threat = {
    label = L["Threat"], hasValue = true,
    values = function() return P.THREAT_VALUES end, sorting = P.THREAT_SORTING,
    default = function() return "aggro" end,
    clean = KeyOf(P.THREAT_VALUES, "aggro"),
    test = function(value)
      local status = ThreatStatus()
      if status == WAIT then return WAIT end
      if status == nil then return false end
      if value == "losing" then return status == 2 end
      if value == "high" then return status == 1 end
      return status >= 2
    end,
    icon = function() return "Interface\\Icons\\Ability_Warrior_DefensiveStance" end,
  },
  -- and casting in some content, so this one waits as well
  casting = {
    label = L["Casting"], hasValue = true,
    values = function() return P.CAST_VALUES end, sorting = P.CAST_SORTING,
    default = function() return "any" end,
    clean = KeyOf(P.CAST_VALUES, "any"),
    test = function(value)
      local cast = value ~= "channel" and CastsWith(UnitCastingInfo) or false
      local channel = value ~= "cast" and CastsWith(UnitChannelInfo) or false
      if cast == true or channel == true then return true end
      if cast == WAIT or channel == WAIT then return WAIT end
      return false
    end,
    icon = function() return "Interface\\Icons\\Spell_Nature_Lightning" end,
  },
  mounted = { label = L["Mounted"], test = function() return IsMounted() end },
  resting = { label = L["Resting"], test = function() return IsResting() end },
  stealth = { label = L["Stealthed"], test = function() return IsStealthed() end },
  dead    = { label = L["Dead or a ghost"], test = function() return UnitIsDeadOrGhost("player") end },
  spec    = {
    label = L["Specialization"], hasValue = true,
    values = function() return P.SpecChoices() end,
    default = function() return Specialization() end,
    clean = function(value) return tonumber(value) end,
    test = function(value) return value ~= nil and Specialization() == value end,
  },
  instance = {
    label = L["In an instance"], hasValue = true,
    values = function() return P.INSTANCE_VALUES end, sorting = P.INSTANCE_SORTING,
    default = function() return "any" end,
    clean = KeyOf(P.INSTANCE_VALUES, "any"),
    test = function(value)
      local inside, kind = IsInInstance()
      if value == "none" then return not inside end
      if not inside then return false end
      if value == "any" or value == nil then return true end
      -- delves report themselves as scenarios
      return kind == value
    end,
  },
  role = {
    label = L["Role"], hasValue = true,
    values = function() return P.ROLE_VALUES end, sorting = P.ROLE_SORTING,
    default = function() return P.Role() or "DAMAGER" end,
    clean = KeyOf(P.ROLE_VALUES, "DAMAGER"),
    test = function(value) return value ~= nil and P.Role() == value end,
    icon = function(value)
      return ({ TANK = "Interface\\Icons\\Ability_Defend", HEALER = "Interface\\Icons\\Spell_Holy_FlashHeal" })[value]
        or "Interface\\Icons\\Ability_DualWield"
    end,
  },
  group = {
    label = L["Group"], hasValue = true,
    values = function() return P.GROUP_VALUES end, sorting = P.GROUP_SORTING,
    default = function() return "group" end,
    clean = KeyOf(P.GROUP_VALUES, "group"),
    test = function(value)
      local raid, group = IsInRaid(), IsInGroup()
      if value == "solo" then return not group end
      if value == "party" then return group and not raid end
      if value == "raid" then return raid end
      if value == "bigraid" then return raid and (tonumber(GetNumGroupMembers()) or 0) >= 20 end
      return group
    end,
    icon = function() return "Interface\\Icons\\Ability_Warrior_RallyingCry" end,
  },
  pet = {
    label = L["Pet"], hasValue = true,
    values = function() return P.PET_VALUES end, sorting = P.PET_SORTING,
    default = function() return "out" end,
    clean = KeyOf(P.PET_VALUES, "out"),
    test = function(value)
      local out = UnitExists("pet") and true or false
      if value == "none" then return not out end
      return out
    end,
    icon = function() return P.SpellIcon(P.CALL_PET_SPELLS and P.CALL_PET_SPELLS[1] or 883) end,
  },
  -- A buff or debuff on you, by spell ID. Midnight hides aura data from addons in some
  -- combat (the answer comes back secret); the rule then waits rather than guess.
  aura = {
    label = L["Buff or debuff"], hasValue = true,
    input = {
      label = L["Spell"],
      help = L["The buff or debuff, by name or spell ID; names come up to pick from as you type. Several, separated by commas, match when any one is on you. While Blizzard hides aura data from addons, as in some combat, the rule waits."],
      -- a name that cannot be found keeps what the rule had, and says so
      parse = function(text, old)
        local ids, missing = P.SpellListFrom(text)
        if #missing > 0 then
          P.Print(string.format(L["No buff or debuff called \"%s\" was found. Type its spell ID, or pick a name from the list as you type."], table.concat(missing, ", ")))
        end
        if ids == nil and strtrim(tostring(text or "")) ~= "" then return old end
        -- say so when the game hides a chosen spell from addons
        local always, sometimes = {}, {}
        for _, id in ipairs(type(ids) == "table" and ids or { ids }) do
          local secrecy = P.SpellSecrecy(id)
          if secrecy == "always" then always[#always + 1] = P.SpellLabel(id) end
          if secrecy == "sometimes" then sometimes[#sometimes + 1] = P.SpellLabel(id) end
        end
        if #always > 0 then
          P.Print(string.format(L["%s is always hidden from addons, so the rule cannot see it."], table.concat(always, ", ")))
        end
        if #sometimes > 0 then
          P.Print(string.format(L["%s is hidden from addons in boss encounters, Mythic+ and other restricted combat; the rule waits there and works everywhere else."], table.concat(sometimes, ", ")))
        end
        return ids
      end,
      suggest = function(text) return P.SpellSuggestions(text) end,
      format = function(value) return P.SpellListLabel(value) end,
    },
    clean = function(value) return P.CleanSpellList(value) end,
    test = function(value)
      if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
      local hidden = false
      local function Has(id)
        if type(id) ~= "number" then return false end
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if not ok or aura == nil then return false end
        if not P.IsAccessible(aura) then hidden = true; return false end
        TrackAura(aura)
        return true
      end
      if type(value) == "table" then
        for _, id in ipairs(value) do if Has(id) then return true end end
      elseif Has(value) then
        return true
      end
      return hidden and WAIT or false
    end,
    icon = function(value) return P.SpellIcon(type(value) == "table" and value[1] or value) end,
  },
  -- A zone, or a place within one, by name as the game shows it.
  zone = {
    label = L["Zone"], hasValue = true,
    input = {
      label = L["Zone"],
      help = L["A zone or a place in one, by its name as the game shows it under the minimap. Leave it as it is to use where you are now."],
      parse = CleanText,
      format = function(value) return tostring(value or "") end,
    },
    default = function() return CleanText(P.CurrentZone()) end,
    clean = CleanText,
    test = function(value)
      if type(value) ~= "string" then return false end
      value = P.Lower(value)
      local real, zone, sub = Zones()
      return (real and P.Lower(real) == value) or (zone and P.Lower(zone) == value) or (sub and P.Lower(sub) == value) or false
    end,
    icon = function() return "Interface\\Icons\\INV_Misc_Map_01" end,
  },
  mythicplus = {
    label = L["In a Mythic+ run"],
    test = function() return C_ChallengeMode and CallIf(C_ChallengeMode.IsChallengeModeActive) or false end,
    icon = function() return "Interface\\Icons\\INV_Misc_Key_03" end,
  },
  delve = {
    label = L["In a delve"],
    test = function() return C_PartyInfo and CallIf(C_PartyInfo.IsDelveInProgress) or false end,
    icon = function() return "Interface\\Icons\\Spell_Shadow_Teleport" end,
  },
  -- Flying has no event of its own, so a flying rule is looked at twice a second
  flying = {
    label = L["Flying"], poll = 0.5,
    test = function() return CallIf(IsFlying) or false end,
    icon = function() return "Interface\\Icons\\Ability_Mount_Gryphon_01" end,
  },
  warmode = {
    label = L["War Mode"],
    test = function()
      if not C_PvP then return false end
      if type(C_PvP.IsWarModeActive) == "function" then return CallIf(C_PvP.IsWarModeActive) or false end
      return CallIf(C_PvP.IsWarModeDesired) or false
    end,
    icon = function() return "Interface\\Icons\\INV_Sword_04" end,
  },
  vehicle = {
    label = L["In a vehicle"],
    test = function() return CallIf(UnitHasVehicleUI, "player") or false end,
    icon = function() return "Interface\\Icons\\INV_Misc_Wrench_01" end,
  },
  -- The game's clock moves without events; a time rule is looked at every half minute
  time = {
    label = L["Time of day"], hasValue = true, poll = 30,
    values = function() return P.TIME_VALUES end, sorting = P.TIME_SORTING,
    default = function() return P.TimeOfDay() end,
    clean = KeyOf(P.TIME_VALUES, "night"),
    test = function(value) return value ~= nil and P.TimeOfDay() == value end,
    icon = function() return "Interface\\Icons\\Spell_Nature_TimeStop" end,
  },
}

-- A spell ID, or a spell's name, as a spell ID (the first, when a name has several).
function P.SpellIDFrom(text)
  local ids = P.FindSpell(text)
  return ids and ids[1]
end

local MAX_SPELLS = 20 -- spells in one buff rule

-- "Bloodlust, Heroism, 80353": one spell ID, a list of them, or nil; and the names
-- that could not be found.
function P.SpellListFrom(text)
  local ids, seen, missing = {}, {}, {}
  for part in P.PlainSeparators(text):gmatch("[^,;]+") do
    local found = P.FindSpell(part)
    if found then
      for _, id in ipairs(found) do
        if not seen[id] and #ids < MAX_SPELLS then seen[id] = true; ids[#ids + 1] = id end
      end
    elseif strtrim(part) ~= "" then
      missing[#missing + 1] = strtrim(part)
    end
  end
  if #ids == 0 then return nil, missing end
  if #ids == 1 then return ids[1], missing end
  return ids, missing
end

-- A spell list from outside (an import), checked: a number, a list of numbers, or nil.
function P.CleanSpellList(value)
  if type(value) == "number" then return value end
  if type(value) ~= "table" then return tonumber(value) end
  local ids = {}
  for i = 1, math.min(#value, MAX_SPELLS) do
    local id = tonumber(value[i])
    if id then ids[#ids + 1] = id end
  end
  if #ids == 0 then return nil end
  if #ids == 1 then return ids[1] end
  return ids
end

function P.SpellListLabel(value)
  if type(value) ~= "table" then return P.SpellLabel(value) end
  local names = {}
  for i, id in ipairs(value) do names[i] = P.SpellLabel(id) end
  return table.concat(names, ", ")
end

-- A spell's name for a rule, or its ID when the name is unknown.
function P.SpellLabel(id)
  if type(id) ~= "number" then return "" end
  if C_Spell and C_Spell.GetSpellName then
    local ok, name = pcall(C_Spell.GetSpellName, id)
    if ok and P.IsAccessible(name) and name then return name end
  end
  return P.KnownSpellName and P.KnownSpellName(id) or tostring(id)
end

P.CONDITION_SORTING = { "combat", "threat", "casting", "role", "group", "instance", "mythicplus", "delve", "zone", "mounted",
  "flying", "vehicle", "resting", "stealth", "dead", "pet", "warmode", "time", "spec", "aura" }
P.CONDITION_VALUES = {}
for key, condition in pairs(P.CONDITIONS) do P.CONDITION_VALUES[key] = condition.label end
-- The second condition can also be nothing
P.SECOND_CONDITION_VALUES = { none = L["Nothing else"] }
for key, label in pairs(P.CONDITION_VALUES) do P.SECOND_CONDITION_VALUES[key] = label end
P.SECOND_CONDITION_SORTING = { "none" }
for _, key in ipairs(P.CONDITION_SORTING) do P.SECOND_CONDITION_SORTING[#P.SECOND_CONDITION_SORTING + 1] = key end

-- The value a condition starts with when a rule switches to it.
function P.DefaultConditionValue(key)
  local condition = P.CONDITIONS[key]
  return condition and condition.default and condition.default() or nil
end

P.RULE_TARGETS = {
  player = L["Health bar"], pet = L["Pet frame"], both = L["Health bar and pet frame"],
  power = L["Power bar"], cast = L["Cast bar"], classpower = L["Class resources"], all = L["Every bar"],
}
P.RULE_TARGET_SORTING = { "player", "pet", "both", "power", "cast", "classpower", "all" }

-- A sound a rule can play when it starts showing: the game's own sound kits.
P.RULE_SOUND_ORDER = { "none", "raidwarning", "readycheck", "alarm", "bosswhisper", "tell", "toast", "quest" }
P.RULE_SOUNDS = {
  none        = { label = L["No sound"] },
  raidwarning = { label = L["Raid warning"], kit = 8959 },    -- SOUNDKIT.RAID_WARNING
  readycheck  = { label = L["Ready check"], kit = 8960 },     -- SOUNDKIT.READY_CHECK
  alarm       = { label = L["Alarm clock"], kit = 12889 },    -- SOUNDKIT.ALARM_CLOCK_WARNING_3
  bosswhisper = { label = L["Boss whisper"], kit = 37666 },   -- SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING
  tell        = { label = L["Whisper"], kit = 3081 },         -- SOUNDKIT.TELL_MESSAGE
  toast       = { label = L["Friend online"], kit = 18019 },  -- SOUNDKIT.UI_BNET_TOAST
  quest       = { label = L["Quest complete"], kit = 23404 }, -- SOUNDKIT.UI_AUTO_QUEST_COMPLETE
}
P.RULE_SOUND_VALUES = {}
for key, sound in pairs(P.RULE_SOUNDS) do P.RULE_SOUND_VALUES[key] = sound.label end

-- Plays a rule's sound on the Master channel, so it is heard with sound effects off.
function P.PlayRuleSound(key)
  local sound = P.RULE_SOUNDS[key]
  if not (sound and sound.kit) or type(PlaySound) ~= "function" then return false end
  return pcall(PlaySound, sound.kit, "Master") and true or false
end

-- A condition with its value, turned around when `negate` is set. A condition whose
-- answer the game hides stays false either way: the rule waits rather than guess.
local function MatchOne(key, value, negate)
  local condition = P.CONDITIONS[key]
  if not condition then return false end
  local ok, result = pcall(condition.test, value)
  if not ok or result == WAIT or not P.IsAccessible(result) then return false end
  result = result and true or false
  if negate then return not result end
  return result
end

local function Matches(rule)
  if not rule.enabled or not MatchOne(rule.condition, rule.value, rule.negate) then return false end
  return not rule.condition2 or MatchOne(rule.condition2, rule.value2, rule.negate2)
end

local function Covers(rule, channel)
  local target = rule.target
  return target == channel or target == "all" or (target == "both" and (channel == "player" or channel == "pet"))
end

-- A condition and its value in words: "Raid", "Buff or debuff: Rejuvenation",
-- "not Resting".
local function DescribeCondition(key, value, negate)
  local condition = P.CONDITIONS[key]
  local text = condition and condition.label or "?"
  if negate then text = L["not"] .. " " .. text end
  if condition and condition.input and value ~= nil then
    text = text .. ": " .. condition.input.format(value)
  elseif condition and condition.hasValue and value ~= nil then
    text = text .. ": " .. tostring(condition.values()[value] or value)
  end
  return text
end

-- A rule's conditions in words: "In combat and Group: In a raid".
function P.DescribeRule(rule)
  local text = DescribeCondition(rule.condition, rule.value, rule.negate)
  if rule.condition2 then
    text = text .. " " .. L["and"] .. " " .. DescribeCondition(rule.condition2, rule.value2, rule.negate2)
  end
  return text
end

-- The rule each bar shows right now, worked out when something it depends on changes.
local active = { player = nil, pet = nil, power = nil, cast = nil, classpower = nil }
local CHANNELS = { "player", "pet", "power", "cast", "classpower" }
-- A rule being tried from the window shows on its bars for a few seconds, above the others
local trial, trialTimer
local TRIAL_TIME = 5

function P.ActiveRule(channel)
  if trial and Covers(trial, channel) then return trial end
  return active[channel]
end

-- Is this rule showing on any bar now?
function P.RuleShowing(rule)
  if trial == rule then return true end
  for i = 1, #CHANNELS do if active[CHANNELS[i]] == rule then return true end end
  return false
end

function P.TryingRule() return trial end

local function Shown()
  -- a rule on the power or cast bar takes that bar, so the bars are looked at again
  P.StartFade()
  if P.RefreshOptionalBars then P.RefreshOptionalBars() else P.UpdateAnimator(); P.Repaint() end
  P.RefreshOptions()
end

-- Shows a rule on its bars for a few seconds, whether its conditions hold or not, so a
-- raid or Mythic+ rule can be set up in town.
function P.TryRule(rule, seconds)
  if type(rule) ~= "table" then return end
  if trialTimer and trialTimer.Cancel then trialTimer:Cancel() end
  trial = rule
  P.PlayRuleSound(rule.sound)
  local token = {}
  trialTimer = token
  local function Done() if trialTimer == token then P.StopTryingRule() end end
  if C_Timer.NewTimer then
    token.timer = C_Timer.NewTimer(seconds or TRIAL_TIME, Done)
    token.Cancel = function() token.timer:Cancel() end
  else
    C_Timer.After(seconds or TRIAL_TIME, Done)
  end
  Shown()
end

function P.StopTryingRule()
  if not trial then return end
  if trialTimer and trialTimer.Cancel then trialTimer:Cancel() end
  trial, trialTimer = nil, nil
  Shown()
end

-- The rule each bar would show, refilled on every check
local found = {}

-- The sound of the first rule that has just started showing, if it has one.
local function SoundForNew()
  for i = 1, #CHANNELS do
    local rule = found[CHANNELS[i]]
    if rule and rule.sound and not P.RuleShowing(rule) then return rule.sound end
  end
end

-- Re-checks every rule. Returns true when a bar's rule changed, after fading to it.
-- `noFade` is a check that is not something happening in play (logging in, a profile
-- change): no fade, and no sound.
function P.EvaluateRules(noFade)
  if not P.DB then return false end
  for i = 1, #CHANNELS do found[CHANNELS[i]] = nil end
  local left = #CHANNELS
  for _, rule in ipairs(P.DB.profile.rules) do
    if left == 0 then break end
    if Matches(rule) then
      for i = 1, #CHANNELS do
        local channel = CHANNELS[i]
        if not found[channel] and Covers(rule, channel) then found[channel] = rule; left = left - 1 end
      end
    end
  end
  local same, barsChanged = true, false
  for i = 1, #CHANNELS do
    local channel = CHANNELS[i]
    if found[channel] ~= active[channel] then
      same = false
      -- a rule on the power or cast bar or the class resources takes those bars while
      -- it shows, even ones left alone
      if channel ~= "player" and channel ~= "pet" and (found[channel] ~= nil) ~= (active[channel] ~= nil) then
        barsChanged = true
      end
    end
  end
  if same then return false end
  local sound = not noFade and SoundForNew()
  if not noFade then P.StartFade() end
  for i = 1, #CHANNELS do active[CHANNELS[i]] = found[CHANNELS[i]] end
  if sound then P.PlayRuleSound(sound) end
  if barsChanged and P.RefreshOptionalBars then
    P.RefreshOptionalBars()
  else
    P.UpdateAnimator()
    P.Repaint()
  end
  return true
end

---------------------------------------------------------------------
-- EXAMPLES
---------------------------------------------------------------------
-- Five rules players often want, in an order where each still gets its turn. They are
-- added switched off, so nothing changes until you turn one on.
P.EXAMPLE_RULES = {
  { condition = "dead",     color = { 0.55, 0.55, 0.55, 1 }, effect = "static",  target = "both" },   -- grey while dead
  { condition = "combat",   color = { 0.82, 0.18, 0.18, 1 }, effect = "pulse",   target = "player" }, -- red pulse in combat
  { condition = "stealth",  color = { 0.48, 0.31, 0.85, 1 }, effect = "breathe", target = "player" }, -- violet in stealth
  { condition = "instance", value = "raid", color = { 0.88, 0.66, 0.00, 1 }, effect = "static", target = "player" }, -- gold in raids
  { condition = "resting",  color = { 0.37, 0.69, 0.48, 1 }, effect = "breathe", target = "both" },   -- calm green when resting
}

local function ExampleRule(example)
  return {
    enabled = false, condition = example.condition, value = example.value,
    color = P.CopyColour(example.color), effect = example.effect, target = example.target,
  }
end

-- Ready-made rules beyond the examples, picked one at a time and added switched off.
P.RULE_RECIPE_ORDER = { "petreminder", "raidhealer", "mythicplus", "delve", "lust", "warmode", "night",
  "pullingaggro", "losingaggro" }
P.RULE_RECIPES = {
  petreminder = { label = L["Pet reminder: your pet is not out"],
    rule = { condition = "pet", value = "none", color = { 1, 0.55, 0.1, 1 }, effect = "heartbeat", target = "player" } },
  raidhealer = { label = L["Healing a raid"],
    rule = { condition = "role", value = "HEALER", condition2 = "group", value2 = "raid",
      color = { 0.3, 0.85, 0.45, 1 }, effect = "static", target = "player" } },
  mythicplus = { label = L["In a Mythic+ run"],
    rule = { condition = "mythicplus", color = { 0.1, 0.65, 0.7, 1 }, effect = "static", target = "player" } },
  delve = { label = L["In a delve"],
    rule = { condition = "delve", color = { 0.9, 0.6, 0.15, 1 }, effect = "breathe", target = "player" } },
  -- Bloodlust, Heroism, Time Warp, Primal Rage, Fury of the Aspects
  lust = { label = L["Bloodlust and the like"],
    rule = { condition = "aura", value = { 2825, 32182, 80353, 264667, 390386 },
      color = { 1, 0.25, 0.2, 1 }, effect = "pulse", target = "player" } },
  warmode = { label = L["War Mode"],
    rule = { condition = "warmode", color = { 0.8, 0.1, 0.15, 1 }, effect = "static", target = "player" } },
  night = { label = L["Night"],
    rule = { condition = "time", value = "night", color = { 0.35, 0.45, 0.85, 1 }, effect = "breathe", target = "both" } },
  -- damage dealers and healers: a warning before the boss turns round
  pullingaggro = { label = L["About to pull aggro (not tanking)"],
    rule = { condition = "threat", value = "high", condition2 = "role", value2 = "TANK", negate2 = true,
      color = { 1, 0.5, 0, 1 }, effect = "heartbeat", target = "player", sound = "raidwarning" } },
  losingaggro = { label = L["A tank losing aggro"],
    rule = { condition = "threat", value = "losing", condition2 = "role", value2 = "TANK",
      color = { 1, 0.15, 0.1, 1 }, effect = "pulse", target = "player", sound = "alarm" } },
}
P.RULE_RECIPE_VALUES = {}
for key, recipe in pairs(P.RULE_RECIPES) do P.RULE_RECIPE_VALUES[key] = recipe.label end

-- Adds a recipe at the bottom of the list, switched off. Returns its place.
function P.AddRuleRecipe(key)
  local recipe = P.RULE_RECIPES[key]
  if not recipe then return end
  local rule = P.SanitizeRule(recipe.rule)
  rule.enabled = false
  local rules = P.DB.profile.rules
  rules[#rules + 1] = rule
  P.RulesChanged()
  return #rules
end

function P.AddExampleRules()
  local rules = P.DB.profile.rules
  for _, example in ipairs(P.EXAMPLE_RULES) do rules[#rules + 1] = ExampleRule(example) end
  P.RulesChanged()
end

-- Once per profile: a profile with no rules of its own gets the examples, switched off.
function P.EnsureExampleRules()
  local p = P.DB.profile
  if p.exampleRulesSeeded then return end
  p.exampleRulesSeeded = true
  if #p.rules > 0 then return end
  for _, example in ipairs(P.EXAMPLE_RULES) do p.rules[#p.rules + 1] = ExampleRule(example) end
end

---------------------------------------------------------------------
-- EDITING
---------------------------------------------------------------------
function P.RulesChanged()
  local stopped = false
  if trial then
    -- a tried rule that was deleted stops showing
    local still = false
    for _, rule in ipairs(P.DB.profile.rules) do if rule == trial then still = true end end
    if not still then
      if trialTimer and trialTimer.Cancel then trialTimer:Cancel() end
      trial, trialTimer, stopped = nil, nil, true
    end
  end
  P.WatchRules()
  -- the bars show the rules again even when no rule changed
  if not P.EvaluateRules() and stopped then Shown() end
  if P.BuildRuleOptions then P.BuildRuleOptions() end
  P.RefreshOptions()
end

function P.AddRule()
  local rules = P.DB.profile.rules
  rules[#rules + 1] = {
    enabled = true, condition = "combat", color = { 0.85, 0.15, 0.15, 1 }, effect = "static", target = "player",
  }
  P.RulesChanged()
  return #rules
end

-- Switches a rule's first (which = 1) or second (2) condition; "none" takes the second away.
function P.SetRuleCondition(rule, which, key)
  if which == 2 then
    if key == "none" or not P.CONDITIONS[key] then
      rule.condition2, rule.value2 = nil, nil
    else
      rule.condition2, rule.value2 = key, P.DefaultConditionValue(key)
    end
  elseif P.CONDITIONS[key] then
    rule.condition, rule.value = key, P.DefaultConditionValue(key)
  end
  P.RulesChanged()
end

-- A rule's sound ("none" for none), played once so you hear what you picked.
function P.SetRuleSound(rule, key)
  rule.sound = key ~= "none" and P.RULE_SOUNDS[key] and key or nil
  P.PlayRuleSound(rule.sound)
  P.RulesChanged()
end

function P.DeleteRule(index)
  table.remove(P.DB.profile.rules, index)
  P.RulesChanged()
end

function P.MoveRule(index, delta)
  local rules = P.DB.profile.rules
  local other = index + delta
  if not rules[index] or not rules[other] then return end
  rules[index], rules[other] = rules[other], rules[index]
  P.RulesChanged()
end

-- Moves a rule to another place in the list (dragging it on the Rules page).
function P.PlaceRule(from, to)
  local rules = P.DB.profile.rules
  if not rules[from] or from == to then return end
  local rule = table.remove(rules, from)
  table.insert(rules, math.max(1, math.min(to, #rules + 1)), rule)
  P.RulesChanged()
end

-- A condition's value from outside, checked; nil when the condition takes none.
local function CleanValue(key, value)
  local condition = P.CONDITIONS[key]
  if condition and condition.clean then return condition.clean(value) end
end

-- A clean copy of a rule from outside (an import), or nil if it is not one.
function P.SanitizeRule(rule)
  if type(rule) ~= "table" or not P.CONDITIONS[rule.condition] then return end
  local colour = P.SanitizeColour(rule.color)
  if not colour then return end
  local clean = {
    enabled = rule.enabled ~= false, condition = rule.condition, color = colour,
    value = CleanValue(rule.condition, rule.value),
    effect = P.IsRuleEffect(rule.effect) and rule.effect or "static",
    target = P.RULE_TARGETS[rule.target] and rule.target or "player",
    negate = rule.negate == true or nil,
    sound = rule.sound ~= "none" and P.RULE_SOUNDS[rule.sound] and rule.sound or nil,
    color2 = rule.color2 ~= nil and P.SanitizeColour(rule.color2) or nil,
  }
  if P.CONDITIONS[rule.condition2] then
    clean.condition2, clean.value2 = rule.condition2, CleanValue(rule.condition2, rule.value2)
    clean.negate2 = rule.negate2 == true or nil
  end
  return clean
end

-- A colour from outside, clamped to 0..1, or nil.
function P.SanitizeColour(c)
  if type(c) ~= "table" then return end
  local out = {}
  for i = 1, 4 do
    local v = c[i]
    if v == nil and i == 4 then v = 1 end
    if type(v) ~= "number" or v ~= v then return end
    out[i] = math.min(1, math.max(0, v))
  end
  return out
end

---------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------
local function Recheck() P.EvaluateRules() end
P.On("PLAYER_REGEN_DISABLED", function() inCombat = true; Recheck() end)
P.On("PLAYER_REGEN_ENABLED", function() inCombat = false; Recheck() end)
for _, event in ipairs({
  "PLAYER_MOUNT_DISPLAY_CHANGED",                                 -- mounted
  "PLAYER_UPDATE_RESTING",                                        -- resting
  "UPDATE_STEALTH",                                               -- stealth
  "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",                -- dead
  "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",               -- instance, zone
  "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",                         -- zone
  "ACTIVE_TALENT_GROUP_CHANGED",                                  -- spec, role
  "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",                 -- group, role
  "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", -- Mythic+
  "PLAYER_FLAGS_CHANGED", "WAR_MODE_STATUS_UPDATE",               -- war mode
}) do
  P.On(event, Recheck)
end
P.On("PLAYER_SPECIALIZATION_CHANGED", Recheck, "player")
P.On("UNIT_PET", Recheck, "player")                               -- pet
P.On("UNIT_ENTERED_VEHICLE", Recheck, "player")                   -- vehicle
P.On("UNIT_EXITED_VEHICLE", Recheck, "player")

-- Threat and casting change many times a fight; they are only looked at while a rule
-- uses them (see WatchRules).
local threatRules, castRules = false, false
P.On("UNIT_THREAT_SITUATION_UPDATE", function() if threatRules then Recheck() end end, "player")
for _, event in ipairs({
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
}) do
  P.On(event, function() if castRules then Recheck() end end, "player")
end

-- What the enabled rules listen for: the spells of buff rules, and how often a rule
-- without events of its own (flying, the time of day) is looked at.
local watchedSpells, auraRules, pollEvery = {}, false, nil
local poller = CreateFrame("Frame")
poller:Hide()
local sincePoll = 0
poller:SetScript("OnUpdate", function(_, elapsed)
  sincePoll = sincePoll + elapsed
  if pollEvery and sincePoll >= pollEvery then sincePoll = 0; Recheck() end
end)

local function WatchCondition(key, value)
  local condition = P.CONDITIONS[key]
  if not condition then return end
  if condition.poll then pollEvery = math.min(pollEvery or condition.poll, condition.poll) end
  if key == "threat" then threatRules = true end
  if key == "casting" then castRules = true end
  if key == "aura" then
    auraRules = true
    if type(value) == "table" then
      for _, id in ipairs(value) do watchedSpells[id] = true end
    elseif value then
      watchedSpells[value] = true
    end
  end
end

function P.WatchRules()
  wipe(watchedSpells)
  auraRules, pollEvery, threatRules, castRules = false, nil, false, false
  for _, rule in ipairs(P.DB and P.DB.profile.rules or {}) do
    if rule.enabled ~= false then
      WatchCondition(rule.condition, rule.value)
      if rule.condition2 then WatchCondition(rule.condition2, rule.value2) end
    end
  end
  poller:SetShown(pollEvery ~= nil)
end

-- UNIT_AURA comes many times a second in combat. Its payload says which auras came and
-- went, so the rules are only checked when one of a buff rule's spells came, or an
-- aura a buff rule matched went. Anything the game hides, or a full update, checks them
-- all, as before.
local function AuraChanged(_, _, info)
  if not auraRules then return end
  if type(info) ~= "table" or not P.IsAccessible(info) or info.isFullUpdate then return Recheck() end
  local added = info.addedAuras
  if added ~= nil then
    if not P.IsAccessible(added) then return Recheck() end
    for _, aura in ipairs(added) do
      local id = P.IsAccessible(aura) and aura.spellId
      if not P.IsAccessible(id) or watchedSpells[id] then return Recheck() end
    end
  end
  local removed = info.removedAuraInstanceIDs
  if removed ~= nil then
    if not P.IsAccessible(removed) then return Recheck() end
    for _, instance in ipairs(removed) do
      if not P.IsAccessible(instance) then return Recheck() end
      if trackedAuras[instance] then trackedAuras[instance] = nil; return Recheck() end
    end
  end
end
P.On("UNIT_AURA", AuraChanged, "player")

P.OnInitialize(function()
  inCombat = UnitAffectingCombat("player") and true or false
  P.EnsureExampleRules()
  P.WatchRules()
  P.EvaluateRules(true)
end)
P.OnProfileChanged(function()
  trial, trialTimer = nil, nil
  P.EnsureExampleRules()
  P.WatchRules()
  P.EvaluateRules(true)
end)
