-- Run from the addon directory: lua Tools/TestRules.lua (Lua 5.1).
-- The rule conditions (role, group, pet, zone, threat, casting), rules with two
-- conditions, rules on the power and cast bars and the class resources, rule sounds,
-- the Studio rule rows, sharing them, and a preset per specialization, against
-- Tools/Mock.lua.
local Mock = dofile("Tools/Mock.lua")
local checks = 0
local function check(value, message)
  if not value then error("FAILED: " .. message, 2) end
  checks = checks + 1
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.02 end
local function colourIs(c, r, g, b) return c and near(c[1], r) and near(c[2], g) and near(c[3], b) end

local game = Mock.New({ art = true })
local env, P, ns = game.env, game.P, game.ns
local p = game.db.profile
local state = game.state
local player = game.azPlayer
local targets = P.GetTargets()

p.fade = false
P.SetUserColour(0.5, 0.2, 0.1, 1)
p.rules = {}
local function Rule(fields)
  local rule = { enabled = true, color = { 0.9, 0.9, 0.1, 1 }, effect = "static", target = "player" }
  for k, v in pairs(fields) do rule[k] = v end
  p.rules[#p.rules + 1] = rule
  P.RulesChanged()
  return rule
end
local function Showing() return colourIs(player.Health.color, 0.9, 0.9, 0.1) end

---------------------------------------------------------------------------
-- New conditions
---------------------------------------------------------------------------
-- Role: the one your group gave you, else your specialization's
local role = Rule({ condition = "role", value = "HEALER" })
check(not Showing(), "a healer rule waits while you are damage")
state.group, state.role = "party", "HEALER"
game.fire("PLAYER_ROLES_ASSIGNED")
check(Showing(), "and shows when your group makes you its healer")
state.group, state.role = nil, nil
state.specRoles = { "HEALER" }
game.fire("GROUP_ROSTER_UPDATE")
check(Showing(), "solo, your specialization's role counts")
state.specRoles = nil
game.fire("ACTIVE_TALENT_GROUP_CHANGED")
check(not Showing(), "and it goes when the role does")
check(P.DefaultConditionValue("role") == "DAMAGER", "a new role rule starts at your role")
p.rules = {}

-- Group
local group = Rule({ condition = "group", value = "raid" })
check(not Showing(), "a raid rule waits while you are solo")
state.group, state.groupSize = "party", 5
game.fire("GROUP_ROSTER_UPDATE")
check(not Showing(), "a party is not a raid")
group.value = "party"; P.RulesChanged()
check(Showing(), "but a party rule shows in one")
group.value = "bigraid"; state.group, state.groupSize = "raid", 12
game.fire("GROUP_ROSTER_UPDATE")
check(not Showing(), "a raid of 12 is not one of 20 or more")
state.groupSize = 25
game.fire("GROUP_ROSTER_UPDATE")
check(Showing(), "a raid of 25 is")
group.value = "solo"; P.RulesChanged()
check(not Showing(), "solo is false in a group")
state.group = nil
game.fire("GROUP_ROSTER_UPDATE")
check(Showing(), "and true out of one")
p.rules = {}

-- Pet: a reminder to call it
Rule({ condition = "pet", value = "none" })
check(not Showing(), "a no-pet rule waits while your pet is out")
state.petOut = false
game.fire("UNIT_PET", "player")
check(Showing(), "and shows when it is dismissed: call your pet")
state.petOut = nil
game.fire("UNIT_PET", "player")
check(not Showing(), "and goes when it comes back")
p.rules = {}

-- Zone, by name, matched on the zone or a place in it
local zone = Rule({ condition = "zone", value = "goldshire" })
check(Showing(), "a zone rule matches the place you are in, whatever the case")
state.subzone = "Northshire"
game.fire("ZONE_CHANGED")
check(not Showing(), "and stops when you leave it")
zone.value = "Elwynn Forest"; P.RulesChanged()
check(Showing(), "the zone's own name matches too")
check(P.DefaultConditionValue("zone") == "Elwynn Forest", "a new zone rule starts where you are")
check(P.CONDITIONS.zone.input.parse("  |cffff0000Stormwind|r ") == "Stormwind", "a typed zone loses colour codes")
check(P.CONDITIONS.zone.input.parse("   ") == nil, "and an empty one is no zone")
p.rules = {}

---------------------------------------------------------------------------
-- Two conditions
---------------------------------------------------------------------------
local both = Rule({ condition = "combat", condition2 = "group", value2 = "raid" })
game.fire("PLAYER_REGEN_DISABLED")
check(not Showing(), "in combat but not in a raid: a rule with two conditions waits")
state.group, state.groupSize = "raid", 20
game.fire("GROUP_ROSTER_UPDATE")
check(Showing(), "in combat and in a raid: it shows")
game.fire("PLAYER_REGEN_ENABLED")
check(not Showing(), "out of combat it goes again")
check(P.DescribeRule(both) == "In combat and Group: In a raid", "it reads as one sentence: " .. P.DescribeRule(both))
P.SetRuleCondition(both, 2, "none")
check(both.condition2 == nil and both.value2 == nil, "the second condition can be taken away")
P.SetRuleCondition(both, 2, "zone")
check(both.condition2 == "zone" and both.value2 == "Elwynn Forest", "and added again, with its starting value")
state.group = nil
p.rules = {}

---------------------------------------------------------------------------
-- Rules on the power and cast bars
---------------------------------------------------------------------------
do
  local power = player.Power
  p.power.mode = "off"
  P.RefreshOptionalBars()
  check(not targets[power], "the power bar is left alone")
  local rule = Rule({ condition = "combat", target = "power", color = { 0.1, 0.9, 0.9, 1 } })
  game.fire("PLAYER_REGEN_DISABLED")
  check(targets[power] and colourIs(power.color, 0.1, 0.9, 0.9), "a power bar rule takes the bar while it shows")
  check(colourIs(player.Health.color, 0.5, 0.2, 0.1), "and leaves the health bar alone")
  game.fire("PLAYER_REGEN_ENABLED")
  check(not targets[power], "and hands it back when it stops")
  p.power.mode = "custom"; p.power.color = { 0.2, 0.2, 0.8, 1 }
  P.RefreshOptionalBars()
  game.fire("PLAYER_REGEN_DISABLED")
  check(colourIs(power.color, 0.1, 0.9, 0.9), "a rule comes before the power bar's own colour")
  game.fire("PLAYER_REGEN_ENABLED")
  check(colourIs(power.color, 0.2, 0.2, 0.8), "which comes back after")
  rule.target = "all"; P.RulesChanged()
  game.fire("PLAYER_REGEN_DISABLED")
  check(colourIs(power.color, 0.1, 0.9, 0.9) and colourIs(player.Health.color, 0.1, 0.9, 0.9)
    and colourIs(game.azPet.Health.color, 0.1, 0.9, 0.9), "Every bar means every bar")
  check(P.RuleShowing(rule), "the rule knows it is showing")
  game.fire("PLAYER_REGEN_ENABLED")
  p.power.mode = "off"
  P.RefreshOptionalBars()
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- The Studio rule rows
---------------------------------------------------------------------------
do
  ns.OpenPanel("rules")
  local Kit = ns.OptionsKit
  P.AddRule()
  Kit.StudioRules:Update()
  Kit.StudioRules:Layout(800)
  local row = Kit.StudioRules.control.rows[1]
  check(row.addCondition.shown and not row.condition2.shown and row.rowHeight == 46, "one condition, one line, and a +")
  row.addCondition.scripts.OnClick(row.addCondition)
  Kit.StudioRules:Update()
  check(p.rules[1].condition2 == "combat" and row.condition2.shown and not row.addCondition.shown and row.rowHeight > 46,
    "+ adds a second condition on a line of its own")
  row.condition2.owner:Fire("zone")
  Kit.StudioRules:Update()
  check(p.rules[1].condition2 == "zone" and row.spell2.shown and not row.value2.shown, "a zone is typed in")
  row.spell2:SetText("Stormwind City")
  row.spell2.scripts.OnEnterPressed(row.spell2)
  check(p.rules[1].value2 == "Stormwind City", "and kept")
  row.condition.owner:Fire("role")
  Kit.StudioRules:Update()
  check(row.value.shown and row.icon.texture:find("condition-role-damager", 1, true), "role shows its list and the pack's picture of the role")
  row.removeCondition.scripts.OnClick(row.removeCondition)
  Kit.StudioRules:Update()
  check(p.rules[1].condition2 == nil and not row.condition2.shown and row.rowHeight == 46, "✕ takes the second condition away")
  ns.OptionsKit.Panel:Close()
end

---------------------------------------------------------------------------
-- Sharing keeps both conditions and the new bars
---------------------------------------------------------------------------
do
  p.rules = {}
  Rule({ condition = "group", value = "raid", condition2 = "zone", value2 = "Orgrimmar", target = "cast" })
  local text = P.Export({ rules = true })
  local data = P.Decode(text)
  local rule = data.rules[1]
  check(rule.condition2 == "zone" and rule.value2 == "Orgrimmar" and rule.target == "cast", "a shared rule keeps both conditions and its bar")
  local clean = P.SanitizeRule({ condition = "role", value = "WIZARD", condition2 = "nonsense", color = { 1, 0, 0 }, target = "everything" })
  check(clean.value == "DAMAGER" and clean.condition2 == nil and clean.target == "player", "an imported rule is checked: unknown values give way")
  local zoneRule = P.SanitizeRule({ condition = "zone", value = ("x"):rep(300), color = { 1, 0, 0 } })
  check(#zoneRule.value == 64, "an imported zone name is capped")
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- A preset per specialization
---------------------------------------------------------------------------
do
  local specPresets = game.db.char.specPresets
  specPresets.enabled = true
  specPresets[2] = "CB-Blue"
  state.spec = 2
  game.fire("PLAYER_ENTERING_WORLD")
  check(not colourIs(p.color, 0.2, 0.4, 0.9), "logging in keeps the colour you left with")
  state.spec = 1
  game.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
  state.spec = 2
  game.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
  check(colourIs(p.color, 0.2, 0.4, 0.9), "changing to a specialization loads its preset")
  P.SetUserColour(0.5, 0.2, 0.1, 1)
  game.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
  check(colourIs(p.color, 0.5, 0.2, 0.1), "an event without a real change loads nothing")
  P.selectedPreset = "CB-Blue"
  P.RenamePreset("Sea")
  check(specPresets[2] == "Sea", "renaming the preset keeps it on its specialization")
  specPresets.enabled = false
  state.spec = 1
  game.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
  state.spec = 2
  game.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
  check(colourIs(p.color, 0.5, 0.2, 0.1), "switched off, nothing loads")
  local args = P.options.args.profiles.args
  check(args.presetEnable and args.specPreset1 and args.specPreset1.values()[""] and args.specPreset1.values().Sea,
    "the Profiles page has a preset picker per specialization")
end

---------------------------------------------------------------------------
-- 6.2: Not
---------------------------------------------------------------------------
P.SetUserColour(0.5, 0.2, 0.1, 1)
p.rules = {}
do
  local rule = Rule({ condition = "group", value = "group", negate = true })
  state.group = nil
  game.fire("GROUP_ROSTER_UPDATE")
  check(Showing(), "not in a group: shows while solo")
  state.group, state.groupSize = "party", 5
  game.fire("GROUP_ROSTER_UPDATE")
  check(not Showing(), "and not in one")
  state.group = nil
  check(P.DescribeRule(rule) == "not Group: In any group", "it reads: " .. P.DescribeRule(rule))
  -- an answer the game hides waits, turned around or not
  p.rules = {}
  Rule({ condition = "aura", value = 774, negate = true })
  state.aurasSecret = true
  game.fire("UNIT_AURA", "player")
  check(not Showing(), "a hidden buff answer waits, even when the rule is turned around")
  state.aurasSecret = nil
  game.fire("UNIT_AURA", "player")
  check(Showing(), "and once the game answers, not having the buff shows it")
  local clean = P.SanitizeRule({ condition = "combat", negate = "yes", condition2 = "resting", negate2 = true, color = { 1, 0, 0 } })
  check(clean.negate == nil and clean.negate2 == true, "Not survives sharing only as true")
  p.rules = {}
end

---------------------------------------------------------------------------
-- 6.2: any of several buffs
---------------------------------------------------------------------------
do
  check(P.SpellListFrom("Rejuvenation, 80353 ;2825") and #P.SpellListFrom("Rejuvenation, 80353 ;2825") == 3,
    "several spells are typed with commas, by name or ID")
  check(P.SpellListFrom("774") == 774 and P.SpellListFrom(" , ") == nil, "one spell stays one number; none is none")
  check(P.SpellListLabel({ 774, 80353, 999999 }) == "Rejuvenation, Time Warp, 999999", "and read back as names where the game or the table knows them")
  local long = {}
  for i = 1, 40 do long[i] = i end
  check(#P.CleanSpellList(long) == 20 and P.CleanSpellList({ "x" }) == nil, "an imported list is capped and checked")
  Rule({ condition = "aura", value = { 2825, 80353 } })
  state.auras = { [80353] = true }
  game.fire("UNIT_AURA", "player")
  check(Showing(), "any one of the spells shows the rule")
  state.auras = nil
  game.fire("UNIT_AURA", "player")
  check(not Showing(), "none of them, no rule")
  p.rules = {}
end

---------------------------------------------------------------------------
-- 6.2: Mythic+, delves, flying, war mode, vehicles, time of day
---------------------------------------------------------------------------
do
  local function Case(condition, flag, event, unit, value)
    p.rules = {}
    Rule({ condition = condition, value = value })
    check(not Showing(), condition .. " waits")
    state[flag] = true
    if event then game.fire(event, unit) else game.advance(1) end
    check(Showing(), condition .. " shows" .. (event and "" or ", looked at without an event"))
    state[flag] = nil
    if event then game.fire(event, unit) else game.advance(1) end
    check(not Showing(), condition .. " stops")
  end
  Case("mythicplus", "mythicplus", "CHALLENGE_MODE_START")
  Case("delve", "delve", "ZONE_CHANGED_NEW_AREA")
  Case("flying", "flying", nil)
  Case("warmode", "warmode", "PLAYER_FLAGS_CHANGED", "player")
  Case("vehicle", "vehicle", "UNIT_ENTERED_VEHICLE", "player")
  p.rules = {}
  state.hour = 12
  Rule({ condition = "time", value = "night" })
  check(not Showing(), "a night rule waits at noon")
  state.hour = 23
  game.advance(31)
  check(Showing(), "and shows at 23, looked at every half minute")
  state.hour = nil
  check(P.DefaultConditionValue("time") == "day", "a new time rule starts at the time it is now")
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- 6.2: trying a rule
---------------------------------------------------------------------------
do
  game.flush()
  local rule = Rule({ enabled = false, condition = "mythicplus", target = "all" })
  check(not Showing(), "a switched-off rule shows nothing")
  P.TryRule(rule)
  check(Showing() and colourIs(game.azPet.Health.color, 0.9, 0.9, 0.1), "trying it shows it on its bars now")
  check(targets[player.Power] and colourIs(player.Power.color, 0.9, 0.9, 0.1), "even on a power bar otherwise left alone")
  check(P.RuleShowing(rule) and P.TryingRule() == rule, "the rule knows it is being tried")
  game.flush() -- its five seconds run out
  check(not Showing() and not targets[player.Power] and P.TryingRule() == nil, "afterwards everything is as it was")
  P.TryRule(rule)
  P.DeleteRule(1)
  check(P.TryingRule() == nil and not Showing(), "deleting a rule being tried stops it")
  game.flush()
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- 6.2: ready-made rules
---------------------------------------------------------------------------
do
  for _, key in ipairs(P.RULE_RECIPE_ORDER) do
    p.rules = {}
    local index = P.AddRuleRecipe(key)
    local rule = p.rules[index]
    check(rule and rule.enabled == false and P.CONDITIONS[rule.condition], "recipe " .. key .. " is added switched off")
  end
  p.rules = {}
  P.AddRuleRecipe("lust")
  check(type(p.rules[1].value) == "table" and #p.rules[1].value == 5, "the lust recipe watches five spells")
  P.AddRuleRecipe("lust")
  check(p.rules[1].value ~= p.rules[2].value, "each copy has its own list")
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- 6.2 in the windows: When not, Try, ready-made rules, By health
---------------------------------------------------------------------------
do
  ns.OpenPanel("rules")
  local Kit = ns.OptionsKit
  local R = Kit.StudioRules.control
  P.AddRule()
  Kit.StudioRules:Update()
  Kit.StudioRules:Layout(800)
  local row = R.rows[1]
  check(row.when.text.text == "When", "the row starts with When")
  row.when.scripts.OnClick(row.when)
  Kit.StudioRules:Update()
  check(p.rules[1].negate == true and row.when.text.text == "When not", "clicking When turns the condition around")
  row.when.scripts.OnClick(row.when)
  check(p.rules[1].negate == nil, "and back")
  check(row.effect.owner.list.health == "By health", "a rule can be coloured by health")
  row.try.scripts.OnClick(row.try)
  check(P.TryingRule() == p.rules[1], "Try tries the row's rule")
  game.flush()
  R.recipes.owner:Fire("petreminder")
  Kit.StudioRules:Update()
  check(#p.rules == 2 and p.rules[2].condition == "pet" and R.recipes.text.text == "Add a ready-made rule…",
    "picking a ready-made rule adds it, and the list is ready for the next")
  ns.OptionsKit.Panel:Close()

  -- the classic window
  P.BuildRuleOptions()
  local group = P.options.args.rules.args.rule1
  check(group.args.negate and group.args.negate2 and group.args.actions.args.try, "the classic window has Not and Try")
  check(group.args.negate2.hidden(), "the second Not waits for a second condition")
  check(P.options.args.rules.args.recipes.values.night, "and the ready-made rules")
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- 7.0: threat and casting, which the game can hide
---------------------------------------------------------------------------
do
  local threat = Rule({ condition = "threat", value = "aggro" })
  check(not Showing(), "off every threat list, an aggro rule waits")
  state.threat = 3
  game.fire("UNIT_THREAT_SITUATION_UPDATE", "player")
  check(Showing(), "tanking securely is having aggro")
  state.threat = 2
  game.fire("UNIT_THREAT_SITUATION_UPDATE", "player")
  check(Showing(), "and so is tanking while someone else is close")
  threat.value = "losing"; P.RulesChanged()
  check(Showing(), "which is also losing aggro")
  state.threat = 3
  game.fire("UNIT_THREAT_SITUATION_UPDATE", "player")
  check(not Showing(), "tanking securely is not losing it")
  threat.value = "high"; P.RulesChanged()
  state.threat = 1
  game.fire("UNIT_THREAT_SITUATION_UPDATE", "player")
  check(Showing(), "above the tank without tanking: about to pull aggro")
  state.threatSecret = true
  game.fire("UNIT_THREAT_SITUATION_UPDATE", "player")
  check(not Showing(), "while the game hides threat, the rule waits")
  threat.negate = true; P.RulesChanged()
  check(not Showing(), "turned around, it waits too, rather than guess")
  state.threatSecret, state.threat, threat.negate = nil, nil, nil
  check(P.DescribeRule(threat) == "Threat: About to pull aggro", "it reads as a sentence: " .. P.DescribeRule(threat))
  p.rules = {}
  P.RulesChanged()

  local casting = Rule({ condition = "casting", value = "any" })
  check(not Showing(), "a casting rule waits while you do nothing")
  state.casting = "Cobra Shot"
  game.fire("UNIT_SPELLCAST_START", "player")
  check(Showing(), "and shows while you cast")
  state.casting = nil
  game.fire("UNIT_SPELLCAST_STOP", "player")
  check(not Showing(), "and goes when the cast ends")
  state.channeling = "Barrage"
  game.fire("UNIT_SPELLCAST_CHANNEL_START", "player")
  check(Showing(), "a channel counts as casting")
  casting.value = "cast"; P.RulesChanged()
  check(not Showing(), "but not for a rule on casts only")
  casting.value = "channel"; P.RulesChanged()
  check(Showing(), "while a rule on channels shows")
  state.channeling = nil
  state.castSecret = true
  game.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
  check(not Showing(), "a hidden cast makes the rule wait")
  state.castSecret = nil
  p.rules = {}
  P.RulesChanged()

  -- without a rule on them, threat and casting are not looked at
  local looked = 0
  local real = env.UnitThreatSituation
  env.UnitThreatSituation = function(...) looked = looked + 1; return real(...) end
  game.fire("UNIT_THREAT_SITUATION_UPDATE", "player")
  game.fire("UNIT_SPELLCAST_START", "player")
  check(looked == 0, "no threat or casting rule: their events cost nothing")
  env.UnitThreatSituation = real
end

---------------------------------------------------------------------------
-- 7.0: a sound when a rule starts
---------------------------------------------------------------------------
do
  local rule = Rule({ condition = "combat", sound = "raidwarning" })
  game.sounds = {}
  game.fire("PLAYER_REGEN_DISABLED")
  check(#game.sounds == 1 and game.sounds[1][1] == 8959 and game.sounds[1][2] == "Master",
    "a rule with a sound plays it once as it starts, on the Master channel")
  game.fire("UNIT_PET", "player")
  check(#game.sounds == 1, "and not again while it keeps showing")
  game.fire("PLAYER_REGEN_ENABLED")
  check(#game.sounds == 1, "nor when it stops")
  rule.target = "both"; P.RulesChanged()
  game.sounds = {}
  game.fire("PLAYER_REGEN_DISABLED")
  check(#game.sounds == 1, "a rule on two bars plays once")
  game.fire("PLAYER_REGEN_ENABLED")
  -- logging in, or a profile change, shows rules without a sound
  rule.condition = "resting"; P.RulesChanged()
  state.resting = true
  game.sounds = {}
  P.EvaluateRules(true)
  check(#game.sounds == 0 and P.RuleShowing(rule), "a quiet check (logging in, a profile change) shows it without a sound")
  state.resting = false
  P.EvaluateRules(true)
  rule.condition = "combat"; P.RulesChanged()
  game.sounds = {}
  P.TryRule(rule)
  check(#game.sounds == 1, "Try plays the rule's sound, so you hear it")
  P.StopTryingRule()
  game.sounds = {}
  P.SetRuleSound(rule, "alarm")
  check(rule.sound == "alarm" and #game.sounds == 1 and game.sounds[1][1] == 12889, "picking a sound plays it")
  P.SetRuleSound(rule, "none")
  check(rule.sound == nil, "and None takes it away")
  check(P.SanitizeRule({ condition = "combat", color = { 1, 0, 0, 1 }, sound = "alarm" }).sound == "alarm"
    and P.SanitizeRule({ condition = "combat", color = { 1, 0, 0, 1 }, sound = "nosuch" }).sound == nil,
    "an imported rule keeps a sound the addon knows, and only those")
  -- the classic window and the Studio row
  P.SetRuleSound(rule, "readycheck")
  P.BuildRuleOptions()
  local option = P.options.args.rules.args.rule1.args.sound
  check(option and option.get() == "readycheck", "the classic window shows the rule's sound")
  option.set(nil, "none")
  check(rule.sound == nil, "and sets it")
  ns.OpenPanel("rules")
  local Kit = ns.OptionsKit
  Kit.StudioRules:Update()
  Kit.StudioRules:Layout(800)
  local row = Kit.StudioRules.control.rows[1]
  check(row.sound and row.speaker.alpha < 1, "the Studio row has a faint speaker while the rule is silent")
  row.sound.owner:Fire("tell")
  Kit.StudioRules:Update()
  check(rule.sound == "tell" and row.speaker.alpha == 1, "the speaker picks a sound and lights up")
  ns.OptionsKit.Panel:Close()
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- 7.0: the threat recipes
---------------------------------------------------------------------------
do
  P.AddRuleRecipe("pullingaggro")
  local rule = p.rules[1]
  check(rule.condition == "threat" and rule.value == "high" and rule.condition2 == "role" and rule.negate2
    and rule.sound == "raidwarning" and rule.enabled == false, "About to pull aggro comes switched off, with a sound")
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- A second colour of its own: rules, bars and pets
---------------------------------------------------------------------------
do
  p.secondColor = { 0, 0, 1, 1 }
  local rule = Rule({ condition = "combat", effect = "gradient" })
  game.fire("PLAYER_REGEN_DISABLED")
  local _, _, _, _, _, pr, pg, pb = P.ChannelColour("player")
  check(near(pr, 0) and near(pb, 1), "a rule without its own second colour runs to the shared one")
  rule.color2 = { 0, 1, 0, 1 }
  _, _, _, _, _, pr, pg, pb = P.ChannelColour("player")
  check(near(pg, 1) and near(pb, 0), "and to its own once it has one")
  check(P.SanitizeRule(rule).color2[2] == 1, "a shared rule keeps its second colour")
  game.fire("PLAYER_REGEN_ENABLED")
  -- the Studio row shows the second swatch only for effects that use it
  ns.OpenPanel("rules")
  local Kit = ns.OptionsKit
  Kit.StudioRules:Update()
  Kit.StudioRules:Layout(800)
  local row = Kit.StudioRules.control.rows[1]
  check(row.colour2.shown, "a Gradient rule shows its second colour on the row")
  rule.effect = "pulse"
  Kit.StudioRules:Update()
  Kit.StudioRules:Layout(800)
  check(not row.colour2.shown, "a Pulse rule does not")
  -- the condition list shows every condition, with a thumb when it is longer than the list
  row.condition.scripts.OnClick(row.condition)
  local Controls = Kit.Controls
  check(Controls.IsDropdownOpen(), "the condition list opens")
  ns.OptionsKit.Panel:Close()
  P.BuildRuleOptions()
  check(P.options.args.rules.args.rule1.args.color2.hidden(), "the classic window hides it for Pulse too")
  p.rules = {}
  P.RulesChanged()

  -- a bar's own second colour
  local power = player.Power
  p.power.mode, p.power.effect = "custom", "gradient"
  P.RefreshOptionalBars()
  _, _, _, _, _, pr, pg, pb = P.ChannelColour("power")
  check(near(pb, 1), "a bar without its own second colour runs to the shared one")
  local option = P.options.args.bars.args.powerSecond
  check(not option.hidden(), "More Bars shows the power bar's second colour for Gradient")
  option.set(nil, 1, 0.5, 0)
  _, _, _, _, _, pr, pg, pb = P.ChannelColour("power")
  check(near(pr, 1) and near(pg, 0.5) and near(pb, 0), "and the bar runs to it")
  p.power.effect = "static"
  check(option.hidden(), "a bar whose effect has no second colour does not show it")
  p.power.mode = "off"
  P.RefreshOptionalBars()

  -- a pet's own second colour
  local number = 11
  P.EnsurePetSettings(number).mode = "custom"
  P.EnsurePetSettings(number).color = { 1, 1, 1, 1 }
  P.EnsurePetSettings(number).effect = "gradient"
  p.petColouring = true
  P.SetPetSecondColour(number, 0.2, 0.3, 0.4)
  check(P.activePet and P.activePet.color2 and near(P.activePet.color2[3], 0.4), "the pet that is out brings its own second colour")
  check(P.BuildExport({ pets = true }).pets[number].color2, "and shares it")
end

---------------------------------------------------------------------------
-- Buff names as you type them
---------------------------------------------------------------------------
do
  local parse = P.CONDITIONS.aura.input.parse
  -- the game only knows Rejuvenation by name here, as it only knows your own spells
  check(parse("Bloodlust") == 2825, "a buff you cannot cast is found by its name in the table")
  check(parse("bloodlust, heroism") [2] == 32182, "several, in any case")
  local exhaustion = parse("Exhaustion")
  check(type(exhaustion) == "table" and #exhaustion == 2, "a name with several spells brings all of them")
  check(parse("Power Inf") == 10060, "the start of a name is enough when only one fits")
  check(parse("Rejuvenation") == 774 and parse("80353") == 80353, "the game's own lookup and spell IDs still work")
  game.printed = {}
  check(parse("No such buff", 2825) == 2825, "a name that cannot be found keeps what the rule had")
  check(game.printed[1] and game.printed[1]:find("No such buff", 1, true), "and says which name it could not find")
  check(parse("Bloodlust, No such buff") == 2825, "the names that are found are kept")
  check(parse("", 2825) == nil, "an empty box takes the spell away")
  game.secrecy[2825], game.secrecy[32182] = 2, 1
  game.printed = {}
  parse("Bloodlust, Heroism")
  local said = table.concat(game.printed, "\n")
  check(said:find("Bloodlust is hidden from addons in boss encounters", 1, true), "a spell the game hides in encounters is named as such")
  check(said:find("Heroism is always hidden", 1, true), "and one it always hides")
  game.secrecy[2825], game.secrecy[32182] = nil, nil
  game.printed = {}
  parse("Bloodlust")
  check(#game.printed == 0, "a spell addons can see is taken without a word")

  -- each patch and each release gets a look at the table (see P.KNOWN_SPELLS_REVIEWED)
  local toc = assert(io.open("AzUI_Color_Picker.toc")):read("*a")
  local newest = 0
  for number in (toc:match("## Interface:%s*([^\r\n]+)") or ""):gmatch("%d+") do newest = math.max(newest, tonumber(number)) end
  local version = toc:match("## Version:%s*([^\r\n]+)")
  local reviewed = P.KNOWN_SPELLS_REVIEWED
  check(newest <= reviewed.interface, "the TOC is for a newer client (" .. newest .. ") than the buff and debuff table was checked for ("
    .. reviewed.interface .. "): add the new season's buffs and debuffs to P.KNOWN_SPELLS in Spells.lua, then set P.KNOWN_SPELLS_REVIEWED")
  check(version == reviewed.version, "the TOC's Version (" .. tostring(version) .. ") is not the one the buff and debuff table was checked for ("
    .. reviewed.version .. "): look for buffs and debuffs to add to P.KNOWN_SPELLS in Spells.lua, then set P.KNOWN_SPELLS_REVIEWED")
  local ids = {}
  for _, spell in ipairs(P.KNOWN_SPELLS) do
    check(type(spell[1]) == "number" and type(spell[2]) == "string" and spell[2] ~= "", "every entry is a spell ID and a name")
    check(not ids[spell[1]], "spell " .. spell[1] .. " is in the table twice")
    ids[spell[1]] = true
  end
  -- a buff on you right now is found by name, whatever it is
  env.C_UnitAuras.GetAuraDataByIndex = function(_, i, filter)
    if i == 1 and filter == "HELPFUL" then return { name = "Flask of Tempered Swiftness", spellId = 431972 } end
  end
  check(parse("flask of tempered swiftness") == 431972, "a buff on you is found by its name")
  check(P.SpellSuggestions("Flask")[1] == "Flask of Tempered Swiftness", "and comes first in the suggestions")
  env.C_UnitAuras.GetAuraDataByIndex = function() return { secret = true } end
  check(parse("Bloodlust") == 2825, "a hidden aura list does not get in the way")
  env.C_UnitAuras.GetAuraDataByIndex = nil

  -- every game language: names come from the game in its language, any case, and the
  -- commas Chinese players type
  check(P.Lower("ЖАЖДА Крови ÉTÉ Ёлка") == "жажда крови été ёлка", "lower case works for accented Latin and Cyrillic")
  check(P.Lower("嗜血 피의 욕망") == "嗜血 피의 욕망", "and leaves Chinese and Korean as they are")
  local names = { [2825] = "Жажда крови", [32182] = "嗜血", [80353] = "Distorsion temporelle" }
  local realName = env.C_Spell.GetSpellName
  env.C_Spell.GetSpellName = function(id) return names[id] or realName(id) end
  P.ForgetSpellNames()
  check(parse("жажда крови") == 2825, "a Russian name, typed in lower case, is found")
  check(parse("distorsion TEMPORELLE") == 80353, "a French one in any case")
  local both = parse("嗜血，Жажда крови")
  check(type(both) == "table" and both[1] == 32182 and both[2] == 2825, "a Chinese comma separates names too")
  check(parse("Bloodlust") == 2825, "and the English name still works on another language's client")
  check(P.SpellSuggestions("жаж")[1] == "Жажда крови", "suggestions come in the game's language")
  env.C_Spell.GetSpellName = realName
  P.ForgetSpellNames()
  -- zone rules compare names the same way
  state.zone, state.subzone = "Элвиннский лес", "Златоземье"
  local zoneRule = Rule({ condition = "zone", value = "ЗЛАТОЗЕМЬЕ" })
  check(Showing(), "a zone typed in capitals matches a Russian zone name")
  p.rules = {}
  P.RulesChanged()
  state.zone, state.subzone = "Elwynn Forest", "Goldshire"

  -- the Studio row offers names as you type, and picking one sets the rule
  p.rules = {}
  Rule({ condition = "aura" })
  ns.OpenPanel("rules")
  local Kit = ns.OptionsKit
  Kit.StudioRules:Update()
  Kit.StudioRules:Layout(800)
  local row = Kit.StudioRules.control.rows[1]
  row.spell:SetText("Heroism, Blood")
  row.spell.scripts.OnTextChanged(row.spell, true)
  check(Kit.Controls.IsDropdownOpen(), "typing a name opens a list of buffs")
  local picked
  for _, frame in ipairs(game.frames) do
    if frame.kind == "Button" and frame.key == "Bloodlust" and frame.shown then picked = frame end
  end
  check(picked, "Bloodlust is in it")
  picked.scripts.OnClick(picked)
  check(row.spell.text == "Heroism, Bloodlust", "picking it completes the name after the comma")
  local value = p.rules[1].value
  check(type(value) == "table" and value[1] == 32182 and value[2] == 2825, "and the rule watches both")
  ns.OptionsKit.Panel:Close()
  p.rules = {}
  P.RulesChanged()
end

check(#game.taint == 0, "nothing written onto Blizzard's frames: " .. table.concat(game.taint, ", "))
print(checks .. " rule checks passed")
