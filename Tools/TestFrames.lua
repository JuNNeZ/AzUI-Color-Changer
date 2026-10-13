-- Run from the addon directory: lua Tools/TestFrames.lua (Lua 5.1).
-- Unit frame addons beyond AzeriteUI (oUF layouts, Z-Perl, PitBull 4), the heal and
-- absorb overlays, Blizzard's personal resource display, Gradient, the colour vision
-- preview, the Settings page preview, class resources and /ahui check, against
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
local env, P = game.env, game.P
local p = game.db.profile
local player = game.azPlayer
local targets, channels = P.GetTargets()

P.SetUserColour(0.5, 0.2, 0.1, 1)
P.SetEffect("static")

---------------------------------------------------------------------------
-- Any oUF layout, Z-Perl and PitBull 4
---------------------------------------------------------------------------
do
  -- a layout on the shared oUF: its objects say which unit they show
  local mine = game.NewWidget("Button", "oUF_MyLayoutPlayer")
  mine.unit = "player"
  mine.Health = game.NewWidget("StatusBar")
  local target = game.NewWidget("Button", "oUF_MyLayoutTarget")
  target.unit = "target"
  target.Health = game.NewWidget("StatusBar")
  env.oUF = { objects = { mine, target } }

  -- Z-Perl keeps its bars on a stats frame
  local xperl = game.NewWidget("Button", "XPerl_Player")
  xperl.statsFrame = game.NewWidget("Button")
  xperl.statsFrame.healthBar = game.NewWidget("StatusBar")
  env.XPerl_Player = xperl

  -- PitBull 4's bars are not status bars: SetColor tints a foreground texture
  local fg = game.NewWidget("Texture")
  local pitbullBar = { fg = fg, IsVisible = function() return true end }
  function pitbullBar:SetColor(r, g, b) self.fg:SetVertexColor(r, g, b) end
  local pitbull = { unit = "player", HealthBar = pitbullBar }
  env.PitBull4 = { singleton_frames = { [pitbull] = true } }

  P.ScanFrames()
  check(colourIs(mine.Health.color, 0.5, 0.2, 0.1), "a layout on the shared oUF is coloured")
  check(not targets[target.Health], "but only your own frames, not the target's")
  check(colourIs(xperl.statsFrame.healthBar.color, 0.5, 0.2, 0.1), "Z-Perl's player frame is coloured")
  check(colourIs(fg.vertex, 0.5, 0.2, 0.1), "PitBull 4's health bar is coloured through its foreground")
  pitbullBar:SetColor(0, 1, 0)
  check(colourIs(fg.vertex, 0.5, 0.2, 0.1), "and PitBull 4's own SetColor is answered at once")
  local labels = P.Painter.labels
  check(labels[mine.Health] == "oUF" and labels[xperl.statsFrame.healthBar] == "Z-Perl" and labels[pitbullBar] == "PitBull 4",
    "each bar knows where it came from")
end

---------------------------------------------------------------------------
-- Heal and absorb overlays
---------------------------------------------------------------------------
do
  -- AzeriteUI: the incoming heal is a texture, the absorb a bar on it that JuNNeZ
  -- Edition hides with alpha 0
  local predict = { vertex = { 0, 0.7, 0, 0.25 }, IsVisible = function() return true end }
  function predict:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
  function predict:GetVertexColor() return unpack(self.vertex) end
  local absorb = game.NewWidget("StatusBar")
  absorb:SetStatusBarColor(1, 1, 1, 0)
  predict.absorbBar = absorb
  player.HealthPrediction = predict

  P.ScanFrames()
  check(not targets[predict], "the overlays are left alone until switched on")
  p.overlays = true
  P.RefreshOptionalBars()
  check(channels[predict] == "absorb" and channels[absorb] == "absorb", "switched on, both are taken")
  -- your colour lifted 45% towards white, at the overlay's own alpha
  check(colourIs(predict.vertex, 0.5 + 0.5 * 0.45, 0.2 + 0.8 * 0.45, 0.1 + 0.9 * 0.45) and near(predict.vertex[4], 0.25),
    "the incoming heal takes a lighter shade of your colour, as see-through as AzeriteUI made it")
  check(near(absorb.color[4], 0), "a hidden absorb bar stays hidden")
  predict:SetVertexColor(0.6, 0, 0, 0.4) -- its owner shows a heal absorb
  check(near(predict.vertex[4], 0.4) and not colourIs(predict.vertex, 0.6, 0, 0), "a new alpha from its owner is kept, the colour is ours")
  P.SetEffect("pulse")
  check(P.NeedsAnimation(), "the overlays follow your effect")
  P.SetEffect("static")
  p.overlays = false
  P.RefreshOptionalBars()
  check(not targets[predict] and colourIs(predict.vertex, 0.6, 0, 0) and near(predict.vertex[4], 0.4),
    "switched off, the overlay gets back the colour its owner last gave it")
end

---------------------------------------------------------------------------
-- The personal resource display
---------------------------------------------------------------------------
do
  local prd = env.PersonalResourceDisplayFrame
  local health, power = prd.HealthBarsContainer.healthBar, prd.PowerBar
  check(not targets[health], "the personal resource display is left alone to begin with")
  p.personalResource = true
  P.RefreshOptionalBars()
  check(colourIs(health.color, 0.5, 0.2, 0.1), "switched on, its health bar takes your colour")
  check(not targets[power], "its power bar waits for the Power Bar setting")
  p.power.mode = "custom"
  p.power.color = { 0.1, 0.3, 0.9, 1 }
  P.RefreshOptionalBars()
  check(colourIs(power.color, 0.1, 0.3, 0.9), "and then follows it")
  p.power.mode = "off"
  p.personalResource = false
  P.RefreshOptionalBars()
  check(not targets[health] and not targets[power] and colourIs(health.color, 0, 0.8, 0),
    "switched off, both go back to Blizzard with its own green")
  check(#game.taint == 0, "nothing written onto Blizzard's frames: " .. table.concat(game.taint, ", "))
end

---------------------------------------------------------------------------
-- Gradient
---------------------------------------------------------------------------
do
  p.secondColor = { 0.1, 0.4, 0.9, 1 }
  P.SetEffect("gradient")
  local texture = player.Health:GetStatusBarTexture()
  local g = texture.gradient
  check(g and g.orientation == "HORIZONTAL" and near(g[1].r, 0.5) and near(g[2].b, 0.9),
    "Gradient runs across the bar from your colour to the second colour")
  check(not P.NeedsAnimation(), "it does not move, so nothing repaints")
  check(P.EffectColour("gradient") == 0.5, "the bar's own colour is yours")
  p.reduceMotion = true
  local _, _, _, _, _, er = P.EffectColour("gradient")
  check(near(er, 0.1), "Reduce Motion leaves it alone, as it does not move")
  p.reduceMotion = false
  P.SetEffect("static")
  check(texture.gradient == nil, "another effect takes it away")
  check(P.UsesSecondColour("gradient") and P.UsesSecondColour("twotone") and not P.UsesSecondColour("pulse"),
    "Gradient and Two-tone use the second colour")
end

---------------------------------------------------------------------------
-- Colour vision preview
---------------------------------------------------------------------------
do
  local bar = game.NewWidget("StatusBar")
  P.AddPreviewTarget(bar, "player")
  P.SetPreviewVision("achromatopsia")
  local c = bar.color
  check(near(c[1], c[2]) and near(c[2], c[3]), "Monochrome shows the preview in grey")
  check(colourIs(player.Health.color, 0.5, 0.2, 0.1), "only the preview changes; your real bar keeps its colour")
  local r, g, b = P.SimulateVision("protanopia", 1, 0, 0)
  check(r < 0.6 and g > 0.2 and b < 0.1, "Protanopia turns red into a dull olive")
  local r2, g2, b2 = P.SimulateVision("deuteranopia", 0, 1, 0)
  check(r2 > 0.5 and g2 > 0.5 and b2 < 0.3, "Deuteranopia turns green yellowish")
  local r3, g3, b3 = P.SimulateVision("tritanopia", 0, 0, 1)
  check(r3 < 0.1 and g3 > 0.35 and b3 < 0.7, "Tritanopia turns blue a dull teal")
  P.SetPreviewVision("normal")
  check(colourIs(bar.color, 0.5, 0.2, 0.1), "Normal shows it as it is")
  P.RemovePreviewTarget(bar)
end

---------------------------------------------------------------------------
-- The page in Blizzard's Settings shows your bar
---------------------------------------------------------------------------
do
  local page = game.settingsPage
  check(page and page.preview and P.IsPreviewTarget(page.preview), "the Settings page has a preview of your health bar")
  P.SetUserColour(0.3, 0.6, 0.2, 1)
  check(colourIs(page.preview.color, 0.3, 0.6, 0.2), "painted like the real one")
end

---------------------------------------------------------------------------
-- Class resources
---------------------------------------------------------------------------
do
  -- AzeriteUI keeps them on a frame of their own; an oUF layout on the player frame
  p.fade = false
  local points, runes = {}, {}
  local classpower = {}
  for i = 1, 5 do points[i] = game.NewWidget("StatusBar"); classpower[i] = points[i] end
  local module = { frame = { ClassPower = classpower } }
  game.libs["AceAddon-3.0"].GetAddon = function(_, name)
    if name == "AzeriteUI" then return { GetModule = function(_, key) if key == "PlayerClassPowerFrame" then return module end end } end
  end
  local layout = env.oUF.objects[1]
  layout.Runes = {}
  for i = 1, 6 do runes[i] = game.NewWidget("StatusBar"); layout.Runes[i] = runes[i] end
  layout.Stagger = game.NewWidget("StatusBar")

  P.ScanFrames()
  check(not targets[points[1]] and not targets[runes[1]], "class resources are left alone until switched on")
  p.classPower.mode = "health"
  P.RefreshOptionalBars()
  check(channels[points[1]] == "classpower" and channels[points[5]] == "classpower", "AzeriteUI's points are taken")
  check(channels[runes[1]] == "classpower" and channels[runes[6]] == "classpower", "and an oUF layout's runes")
  check(not targets[layout.Stagger], "stagger keeps its own colour: it says how heavy the stagger is")
  local c = player.Health.color
  check(colourIs(points[3].color, c[1], c[2], c[3]), "Match my health bar takes your health bar's colour")
  p.classPower.mode = "custom"; p.classPower.color = { 0.9, 0.1, 0.8, 1 }
  P.Repaint()
  check(colourIs(points[3].color, 0.9, 0.1, 0.8) and colourIs(runes[2].color, 0.9, 0.1, 0.8), "or their own colour")
  points[3]:SetStatusBarColor(1, 1, 0)
  check(colourIs(points[3].color, 0.9, 0.1, 0.8), "and keep it when their addon recolours a point")
  p.classPower.effect = "pulse"
  P.UpdateAnimator()
  check(P.NeedsAnimation(), "an effect on them keeps the animator running")
  p.classPower.effect = "static"
  -- a rule on the class resources
  p.classPower.mode = "off"
  P.RefreshOptionalBars()
  check(not targets[points[1]], "switched off, they are handed back")
  p.rules = { { enabled = true, condition = "combat", color = { 0.1, 0.8, 0.2, 1 }, effect = "static", target = "classpower" } }
  P.RulesChanged()
  game.fire("PLAYER_REGEN_DISABLED")
  check(targets[points[1]] and colourIs(points[1].color, 0.1, 0.8, 0.2), "a rule on the class resources takes them while it shows")
  check(not colourIs(player.Health.color, 0.1, 0.8, 0.2), "and leaves the health bar alone")
  game.fire("PLAYER_REGEN_ENABLED")
  check(not targets[points[1]], "and hands them back when it stops")
  p.rules = {}
  P.RulesChanged()
  p.classPower.mode = "health"
  P.RefreshOptionalBars()
  check(P.options.args.bars.args.classPowerMode.get() == "health", "the More Bars page has them")
  game.libs["AceAddon-3.0"].GetAddon = function() end
end

---------------------------------------------------------------------------
-- /ahui check
---------------------------------------------------------------------------
do
  game.printed = {}
  env.printed = nil
  env.SlashCmdList.AZCOLORPICKER("check")
  local all = table.concat(game.printed, "\n")
  check(all:find("AzUI Color Picker", 1, true) and all:find("Health bar: #4D9933", 1, true),
    "it says what your health bar shows")
  check(all:find("AzeriteUI · Health bar", 1, true) and all:find("Z-Perl · Health bar", 1, true),
    "and lists every bar found, with where it comes from")
  check(not all:find("No health bar found", 1, true), "a health bar was found")
  check(not all:find("Your health bar", 1, true), "the addon's own previews are left out")
  check(all:find("Power bar: left alone", 1, true), "a bar left alone says so")
  check(all:find("Class resources: #", 1, true) and all:find("oUF · Class resources", 1, true),
    "the class resources are listed with the rest")
end

print(checks .. " frame checks passed")
