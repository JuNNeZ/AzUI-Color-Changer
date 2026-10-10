-- Rules.lua - colour rules: "when this is true, show this colour and effect on these
-- bars". Rules sit above pet colours and your own colour; the first matching rule in
-- the list wins for each bar, and with none matching nothing changes.
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

P.INSTANCE_VALUES = {
  any = L["Any instance"], party = L["Dungeon"], raid = L["Raid"], scenario = L["Scenario or delve"],
  pvp = L["Battleground"], arena = L["Arena"], none = L["Open world"],
}
P.INSTANCE_SORTING = { "any", "party", "raid", "scenario", "pvp", "arena", "none" }

-- Combat follows its own events: while PLAYER_REGEN_DISABLED is being handled the
-- game may not report you as in combat yet.
local inCombat = false

-- Each condition: a label, a test, and for some a value to pick (spec, instance type).
P.CONDITIONS = {
  combat  = { label = L["In combat"], test = function() return inCombat end },
  mounted = { label = L["Mounted"], test = function() return IsMounted() end },
  resting = { label = L["Resting"], test = function() return IsResting() end },
  stealth = { label = L["Stealthed"], test = function() return IsStealthed() end },
  dead    = { label = L["Dead or a ghost"], test = function() return UnitIsDeadOrGhost("player") end },
  spec    = {
    label = L["Specialization"], hasValue = true,
    values = function() return P.SpecChoices() end,
    test = function(value) return value ~= nil and Specialization() == value end,
  },
  instance = {
    label = L["In an instance"], hasValue = true,
    values = function() return P.INSTANCE_VALUES end,
    test = function(value)
      local inside, kind = IsInInstance()
      if value == "none" then return not inside end
      if not inside then return false end
      if value == "any" or value == nil then return true end
      -- delves report themselves as scenarios
      return kind == value
    end,
  },
}
P.CONDITION_SORTING = { "combat", "mounted", "resting", "stealth", "dead", "spec", "instance" }
P.CONDITION_VALUES = {}
for key, condition in pairs(P.CONDITIONS) do P.CONDITION_VALUES[key] = condition.label end

P.RULE_TARGETS = { player = L["Health bar"], pet = L["Pet frame"], both = L["Health bar and pet frame"] }
P.RULE_TARGET_SORTING = { "player", "pet", "both" }

local function Matches(rule)
  local condition = P.CONDITIONS[rule.condition]
  if not (rule.enabled and condition) then return false end
  local ok, result = pcall(condition.test, rule.value)
  return ok and P.IsAccessible(result) and result and true or false
end

local function Covers(rule, channel)
  return rule.target == "both" or rule.target == channel
end

-- The rule each bar shows right now, worked out when something it depends on changes.
local active = { player = nil, pet = nil }

function P.ActiveRule(channel)
  return active[channel]
end

-- Re-checks every rule. Returns true when a bar's rule changed, after fading to it.
function P.EvaluateRules(noFade)
  if not P.DB then return false end
  local player, pet
  for _, rule in ipairs(P.DB.profile.rules) do
    if (not player or not pet) and Matches(rule) then
      if not player and Covers(rule, "player") then player = rule end
      if not pet and Covers(rule, "pet") then pet = rule end
    end
  end
  if player == active.player and pet == active.pet then return false end
  if not noFade then P.StartFade() end
  active.player, active.pet = player, pet
  P.UpdateAnimator()
  P.Repaint()
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

function P.AddExampleRules()
  local rules = P.DB.profile.rules
  for _, example in ipairs(P.EXAMPLE_RULES) do
    rules[#rules + 1] = {
      enabled = false, condition = example.condition, value = example.value,
      color = P.CopyColour(example.color), effect = example.effect, target = example.target,
    }
  end
  P.RulesChanged()
end

-- Once per profile: a profile with no rules of its own gets the examples, switched off.
function P.EnsureExampleRules()
  local p = P.DB.profile
  if p.exampleRulesSeeded then return end
  p.exampleRulesSeeded = true
  if #p.rules > 0 then return end
  for _, example in ipairs(P.EXAMPLE_RULES) do
    p.rules[#p.rules + 1] = {
      enabled = false, condition = example.condition, value = example.value,
      color = P.CopyColour(example.color), effect = example.effect, target = example.target,
    }
  end
end

---------------------------------------------------------------------
-- EDITING
---------------------------------------------------------------------
function P.RulesChanged()
  P.EvaluateRules()
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

-- A clean copy of a rule from outside (an import), or nil if it is not one.
function P.SanitizeRule(rule)
  if type(rule) ~= "table" or not P.CONDITIONS[rule.condition] then return end
  local colour = P.SanitizeColour(rule.color)
  if not colour then return end
  local clean = {
    enabled = rule.enabled ~= false, condition = rule.condition, color = colour,
    effect = P.IsEffect(rule.effect) and rule.effect or "static",
    target = P.RULE_TARGETS[rule.target] and rule.target or "player",
  }
  if rule.condition == "spec" then
    clean.value = tonumber(rule.value)
  elseif rule.condition == "instance" then
    clean.value = P.INSTANCE_VALUES[rule.value] and rule.value or "any"
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
  "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",               -- instance
  "ACTIVE_TALENT_GROUP_CHANGED",                                  -- spec
}) do
  P.On(event, Recheck)
end
P.On("PLAYER_SPECIALIZATION_CHANGED", Recheck, "player")

P.OnInitialize(function()
  inCombat = UnitAffectingCombat("player") and true or false
  P.EnsureExampleRules()
  P.EvaluateRules(true)
end)
P.OnProfileChanged(function()
  P.EnsureExampleRules()
  P.EvaluateRules(true)
end)
