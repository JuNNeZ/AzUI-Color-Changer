-- Run from the addon directory: lua Tools/TestEngine.lua (Lua 5.1).
-- What runs underneath (6.3): repainting only what changes, finding frames when an
-- addon loads, reading buff changes from UNIT_AURA's own list, forgetting pets long
-- gone and timing a repaint; and the 6.2 effects: Flow, Spectrum, Pulse Depth and
-- Sweep Time, and a rule coloured by health. Against Tools/Mock.lua.
local Mock = dofile("Tools/Mock.lua")
local checks = 0
local function check(value, message)
  if not value then error("FAILED: " .. message, 2) end
  checks = checks + 1
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.02 end
local function colourIs(c, r, g, b) return c and near(c[1], r) and near(c[2], g) and near(c[3], b) end

local game = Mock.New({ art = true })
local env, P = game.env, game.P
local p = game.db.profile
local state = game.state
local player, pet = game.azPlayer, game.azPet

p.fade = false
p.rules = {}
P.RulesChanged()
P.SetUserColour(0.5, 0.2, 0.1, 1)
P.SetEffect("static")

---------------------------------------------------------------------------
-- Repainting only what changes
---------------------------------------------------------------------------
do
  -- the pet frame pulses (a rule on it); your health bar holds still
  p.rules = { { enabled = true, condition = "combat", color = { 0.2, 0.6, 0.9, 1 }, effect = "pulse", target = "pet" } }
  P.RulesChanged()
  game.fire("PLAYER_REGEN_DISABLED")
  game.advance(0.2)
  local still, moving = player.Health.color, pet.Health.color
  game.advance(0.5)
  check(player.Health.color == still, "while the pet frame pulses, the still health bar is not painted again")
  check(pet.Health.color ~= moving, "the pulsing pet frame is")
  P.Repaint()
  check(player.Health.color ~= still and colourIs(player.Health.color, 0.5, 0.2, 0.1),
    "a repaint after a setting changes paints every bar")
  player.Health:SetStatusBarColor(0, 1, 0) -- AzeriteUI recolours it
  check(colourIs(player.Health.color, 0.5, 0.2, 0.1), "and a bar its addon recolours is answered at once, as before")
  game.fire("PLAYER_REGEN_ENABLED")
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- A rule coloured by health
---------------------------------------------------------------------------
do
  p.lowHealthColour = { 1, 0, 0, 1 }
  P.ResetHealthCurves()
  local rule = { enabled = true, condition = "combat", color = { 0.2, 0.8, 0.3, 1 }, effect = "health", target = "both" }
  p.rules = { rule }
  P.RulesChanged()
  game.fire("PLAYER_REGEN_DISABLED")
  state.health = 1
  P.Repaint()
  local c = player.Health.color
  check(type(c[1]) == "table" and c[1].secret, "a rule by health hands the bar the game's secret colour, untouched")
  check(near(c[1].v, 0.2), "at full health it is the rule's colour, not yours")
  state.health = 0
  game.fire("UNIT_HEALTH", "player")
  P.Repaint()
  check(near(player.Health.color[1].v, 1), "and runs to the low-health colour as you lose health")
  check(colourIs(pet.Health.color, 0.2, 0.8, 0.3), "on the pet frame (not your health) it shows its colour as it is")
  check(not P.NeedsAnimation(), "it does not move, so nothing repaints on a timer")
  check(P.SanitizeRule(rule).effect == "health" and P.SanitizeRule({ condition = "combat", color = { 1, 0, 0 }, effect = "bogus" }).effect == "static",
    "By health survives sharing; an unknown effect does not")
  game.fire("PLAYER_REGEN_ENABLED")
  state.health = 1
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- Flow, Spectrum, Pulse Depth and Sweep Time
---------------------------------------------------------------------------
do
  local base = { 0.8, 0.2, 0.2, 1 }
  p.secondColor = { 0.2, 0.2, 0.8, 1 }
  P.SetPhase(0)
  local r, g, b, a, at, er, eg, eb = P.EffectColour("flow", base)
  check(at == nil and near(r, 0.8) and near(eb, 0.8), "Flow starts as a gradient from your colour to the second")
  P.SetPhase(math.pi / 1.5) -- half way through its swing
  r, g, b, a, at, er = P.EffectColour("flow", base)
  check(near(r, 0.2) and near(er, 0.8), "and the two ends trade places")
  check(P.IsAnimated("flow") and P.IsAnimated("rainbowgradient") and P.UsesSecondColour("flow"), "Flow and Spectrum move; Flow uses the second colour")
  p.reduceMotion = true
  r, g, b, a, at, er = P.EffectColour("flow", base)
  check(near(r, 0.8) and near(er, 0.2), "Reduce Motion holds Flow still as Gradient")
  p.reduceMotion = false
  local r1, g1, b1, _, at1, r2, g2, b2 = P.EffectColour("rainbowgradient", base)
  check(at1 == nil and r2 and not (near(r1, r2) and near(g1, g2) and near(b1, b2)), "Spectrum has two different ends")
  P.SetEffect("rainbowgradient")
  game.advance(0.1)
  local texture = player.Health:GetStatusBarTexture()
  check(texture.gradient and texture.gradient.orientation == "HORIZONTAL", "Spectrum is drawn across the bar")

  P.SetPhase(math.pi / 2) -- Pulse at its brightest
  check(near(P.EffectColour("pulse", base), 0.8), "Pulse peaks at your colour")
  P.SetPhase(math.pi) -- and its darkest
  p.pulseDepth = 0.3
  check(near(P.EffectColour("pulse", base), 0.8 * 0.3), "Pulse Depth 30% dips to 30%")
  p.pulseDepth = 0.6
  check(near(P.EffectColour("pulse", base), 0.8 * 0.6), "Pulse Depth 60% dips less")
  p.pulseDepth = 0.3

  P.SetPhase(0.3 * 1.2)
  check(near(select(5, P.EffectColour("sweep", base)), 0.5), "at Sweep Time 2.4 s the band is half way after 1.2 s")
  p.sweepPeriod = 4.8
  check(near(select(5, P.EffectColour("sweep", base)), 0.25), "at 4.8 s it is a quarter of the way")
  p.sweepPeriod = 2.4
  P.SetEffect("static")
  game.advance(0.1)
end

---------------------------------------------------------------------------
-- Finding frames when an addon loads
---------------------------------------------------------------------------
do
  local targets = P.GetTargets()
  local elv = game.NewWidget("Button", "ElvUF_Player")
  elv.Health = game.NewWidget("StatusBar")
  env.ElvUF_Player = elv
  check(not targets[elv.Health], "a frame made after login is not known yet")
  game.fire("ADDON_LOADED", "ElvUI")
  game.fire("ADDON_LOADED", "ElvUI_Options") -- several load together: one look covers them
  local queued = #game.timers
  game.flush()
  check(queued == 1, "addons loading together are looked at once")
  check(targets[elv.Health] and colourIs(elv.Health.color, 0.5, 0.2, 0.1), "and the new frame is coloured")
  env.ElvUF_Player = nil
end

---------------------------------------------------------------------------
-- Buff rules read UNIT_AURA's own list
---------------------------------------------------------------------------
do
  local rule = { enabled = true, condition = "aura", value = { 2825, 80353 }, color = { 0.9, 0.9, 0.1, 1 }, effect = "static", target = "player" }
  p.rules = { rule }
  P.RulesChanged()
  local function showing() return colourIs(player.Health.color, 0.9, 0.9, 0.1) end
  state.auras = { [80353] = true }
  game.fire("UNIT_AURA", "player", { addedAuras = { { spellId = 80353, auraInstanceID = 180353 } } })
  check(showing(), "one of the rule's spells coming on shows the rule")
  state.auras = {}
  game.fire("UNIT_AURA", "player", { addedAuras = { { spellId = 12345, auraInstanceID = 5 } } })
  check(showing(), "an aura the rule does not care about does not even check the rules")
  game.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { 7 } })
  check(showing(), "nor does one going that the rule never matched")
  game.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { 180353 } })
  check(not showing(), "the matched aura going checks them, and the rule stops")
  state.auras = { [2825] = true }
  game.fire("UNIT_AURA", "player", { addedAuras = { { spellId = { secret = true } } } })
  check(showing(), "an aura the game hides checks them all, as before")
  state.auras = {}
  game.fire("UNIT_AURA", "player", { isFullUpdate = true })
  check(not showing(), "and so does a full update")
  state.auras = { [2825] = true }
  game.fire("UNIT_AURA", "player")
  check(showing(), "an event without its list checks them too")
  state.auras = nil
  p.rules = {}
  P.RulesChanged()
end

---------------------------------------------------------------------------
-- Pets long gone are forgotten
---------------------------------------------------------------------------
do
  local known = game.db.char.knownPets
  game.now = 1800000000
  known[999] = { name = "Old Friend", familyName = "Wolf", lastSeen = game.now - 200 * 24 * 3600 }
  known[998] = { name = "Recent", familyName = "Cat", lastSeen = game.now - 10 * 24 * 3600 }
  known[997] = { name = "Unknown Age", familyName = "Bear" }
  p.pets[999] = { mode = "custom", color = { 1, 0, 0, 1 }, effect = "static" }
  P.RefreshKnownPets()
  check(known[999] == nil, "a pet the stable has not shown for half a year is forgotten")
  check(known[998] and known[997] and known[997].lastSeen == game.now,
    "a recent one stays, and one saved before this starts counting now")
  check(known[11].lastSeen == game.now, "the stable's pets are seen now")
  check(p.pets[999], "its colour settings stay in the profile")
  known[998], known[997] = nil, nil
end

---------------------------------------------------------------------------
-- /ahui check times a repaint
---------------------------------------------------------------------------
do
  game.printed = {}
  env.SlashCmdList.AZCOLORPICKER("check")
  local all = table.concat(game.printed, "\n")
  check(all:find("One repaint of every bar takes", 1, true) and all:find("%d+%.%d%d ms"), "it says what a repaint costs on this machine")
end

check(#game.taint == 0, "nothing written onto Blizzard's frames: " .. table.concat(game.taint, ", "))
print(checks .. " engine checks passed")
