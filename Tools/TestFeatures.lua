-- Run from the addon directory: lua Tools/TestFeatures.lua (Lua 5.1).
-- The 5.1 and 5.2 features against the mock client in Tools/Mock.lua.
local Mock = dofile("Tools/Mock.lua")
local checks = 0
local function check(value, message)
  if not value then error("FAILED: " .. message, 2) end
  checks = checks + 1
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.02 end
local function colourIs(c, r, g, b) return c and near(c[1], r) and near(c[2], g) and near(c[3], b) end

---------------------------------------------------------------------------
-- Saved data from 5.0 upgrades once
---------------------------------------------------------------------------
do
  local game = Mock.New({ oldProfile = { rainbowActive = true, pulseActive = false } })
  local p = game.db.profile
  check(p.effect == "rainbow" and p.rainbowActive == nil and p.pulseActive == nil, "5.0's rainbow switch becomes the Rainbow effect")
  check(p.schema == game.P.SCHEMA, "the profile is marked as upgraded")
end

local game = Mock.New()
local env, P, db, ns = game.env, game.P, game.db, game.ns
local p = db.profile
local player, pet = game.azPlayer, game.azPet

---------------------------------------------------------------------------
-- Painting and hooks
---------------------------------------------------------------------------
P.SetUserColour(0.5, 0.2, 0.1, 1)
check(colourIs(player.Health.color, 0.5, 0.2, 0.1), "AzeriteUI's health bar shows your colour")
check(colourIs(player.Health.Preview.color, 0.45, 0.18, 0.09), "its preview at 90%")
player.Health:SetStatusBarColor(0, 1, 0)
check(colourIs(player.Health.color, 0.5, 0.2, 0.1), "another addon's recolour is put back")
check(colourIs(env.PetFrame.healthbar.color, 0.5, 0.2, 0.1), "Blizzard's pet frame is coloured (5.1)")
env.PetFrame.healthbar:SetStatusBarColor(0, 1, 0) -- Blizzard recolours it
check(colourIs(env.PetFrame.healthbar.color, 0.5, 0.2, 0.1), "and keeps our colour without a lock")
p.blizzardPetFrame = false
P.RefreshOptionalBars()
check(colourIs(env.PetFrame.healthbar.color, 0, 1, 0), "switching it off hands the pet frame back, green")
env.PetFrame.healthbar:SetStatusBarColor(0, 1, 0)
check(colourIs(env.PetFrame.healthbar.color, 0, 1, 0), "and stops colouring it")
p.blizzardPetFrame = true
P.RefreshOptionalBars()

---------------------------------------------------------------------------
-- Effects (5.2)
---------------------------------------------------------------------------
local base = { 0.4, 0.4, 0.4, 1 }
for _, effect in ipairs(P.EFFECTS) do
  for _, phase in ipairs({ 0, 0.7, 2.1, 5 }) do
    P.SetPhase(phase)
    local r, g, b, a = P.EffectColour(effect, base)
    check(r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1 and a == 1, effect .. " stays a colour")
  end
end
P.SetPhase(2 * math.pi / 3) -- two-tone fully on the second colour
check(colourIs({ P.EffectColour("twotone", base, { 0, 0, 1, 1 }) }, 0, 0, 1), "Two-tone reaches the second colour")
P.SetPhase(0.02)
local hr = P.EffectColour("heartbeat", base)
check(hr > 0.4, "Heartbeat lifts the colour on a beat")
local _, _, _, _, left, right = P.EffectColour("sweep", base)
check(left and right and left ~= right, "Sweep gives the bar a gradient")
p.reduceMotion = true
check(colourIs({ P.EffectColour("pulse", base) }, 0.4, 0.4, 0.4), "Reduce Motion shows the static colour")
p.reduceMotion = false

-- Sweep, as the Feature Plan's preview draws it: #B31B1B dims to #6E0F0F and a
-- #F0604F band crosses the bar left to right every 2.4 s at speed 1.0
P.SetUserColour(0xB3 / 255, 0x1B / 255, 0x1B / 255, 1)
P.SetEffect("sweep")
P.SetPhase(0)
local r0, g0, b0, a0, at, pr, pg, pb = P.EffectColour("sweep")
check(colourIs({ r0, g0, b0 }, 0x6E / 255, 0x0F / 255, 0x0F / 255), "Sweep dims the bar like the preview")
check(math.abs(pr - 0xF0 / 255) < 0.01 and math.abs(pg - 0x60 / 255) < 0.04 and math.abs(pb - 0x4F / 255) < 0.04,
  "and its band peaks at the preview's colour")
P.SetPhase(0.3 * 1.2) -- 1.2 s in: half way
check(near(select(5, P.EffectColour("sweep")), 0.5), "the band is half way across after 1.2 s")
game.advance(0.2)
local band
for _, w in ipairs(game.frames) do if w.left and w.right and w.parent == player.Health then band = w end end
check(band and band.shown and band.left.gradient and band.right.gradient, "the band is drawn on the bar")
local function bandX() for _, point in ipairs(band.left.points) do if point[1] == "LEFT" then return point[4] end end end
local x1 = bandX()
game.advance(0.4)
check(bandX() > x1, "and moves left to right")
check(colourIs(player.Health.color, 0x6E / 255, 0x0F / 255, 0x0F / 255), "under it the bar is dimmed")
P.SetEffect("static")
game.advance(0.1)
check(not band.shown, "another effect takes the band away")

-- Flicker asks first, and No leaves the effect alone
game.answer = false
ns.OpenPanel("general")
local Panel = ns.OptionsKit.Panel
local Studio = ns.OptionsKit.StudioHealth.control
local flickerCard
for _, card in ipairs(Studio.cards) do if card.effect == "flicker" then flickerCard = card end end
flickerCard.scripts.OnClick(flickerCard)
check(p.effect == "static" and game.popups[#game.popups].text:find("Flicker"), "Flicker asks before it starts")
game.answer = nil
flickerCard.scripts.OnClick(flickerCard)
check(p.effect == "flicker", "and starts when you say yes")
P.SetEffect("static")
Panel:Close()

---------------------------------------------------------------------------
-- Fades (5.1)
---------------------------------------------------------------------------
P.SetUserColour(1, 0, 0, 1)
game.advance(0.05)
p.presets["Sea"] = { 0, 0, 1, 1 }
P.LoadPreset("Sea")
game.advance(0.15)
local mid = player.Health.color
check(mid[1] > 0.1 and mid[1] < 0.9 and mid[3] > 0.1 and mid[3] < 0.9, "a preset fades in")
game.advance(0.3)
check(colourIs(player.Health.color, 0, 0, 1), "and arrives")
p.fade = false
P.LoadPreset("CB-Orange")
check(colourIs(player.Health.color, 0.9, 0.5, 0.1), "with Smooth Fades off it changes at once")
p.fade = true

---------------------------------------------------------------------------
-- Sweep on a bar shaped like a crystal shimmers instead of drawing a band
do
  local saved = P.CopyColour(p.color)
  local crystal = game.azPlayer.Power
  crystal.width, crystal.height = 60, 120
  p.power.mode = "health"
  P.RefreshOptionalBars()
  P.SetUserColour(0.5, 0.1, 0.1, 1)
  P.SetEffect("sweep")
  P.SetPhase(0.3 * 1.2) -- band half way: the crystal is at its brightest
  P.Repaint()
  local band
  for _, w in ipairs(game.frames) do if w.left and w.right and w.parent == crystal then band = w end end
  check(band and band.shown and band.left.gradient.orientation == "VERTICAL", "the band climbs the crystal, bottom to top")
  check(band.left.blend == "ADD", "the band adds light, so the crystal's facets show through")
  check(near(band.left.gradient[2].a, 0.6 * 0.6), "softer on the crystal: 60% of the 60% default strength")
  p.sweepStrength = 1
  P.Repaint()
  check(near(band.left.gradient[2].a, 0.6), "Sweep Strength turns it up")
  p.sweepStrength = 0.6
  check(band.mask and band.fill == crystal.FakeFill,
    "cut to the crystal's own fill (JuNNeZ Edition's FakeFill), not its box")
  -- the mana orb has no fill texture to follow, so it shimmers instead
  local orb = { name = "ManaOrb" }
  function orb:SetStatusBarColor(r, g, b, a) self.color = { r, g, b, a } end
  game.azPlayer.ManaOrb = orb
  P.ScanFrames()
  P.Repaint()
  check(orb.color and orb.color[1] > 0.5 * 0.615 + 0.05, "the mana orb is coloured and shimmers as the band passes")
  game.azPlayer.ManaOrb = nil
  P.SetEffect("static")
  p.power.mode = "off"
  P.RefreshOptionalBars()
  crystal.width, crystal.height = 600, 20
  P.SetUserColour(saved[1], saved[2], saved[3], saved[4])
  game.advance(0.4)
end

-- Power bar channel (5.2, test)
---------------------------------------------------------------------------
player.Power:SetStatusBarColor(0, 0, 1)
check(colourIs(player.Power.color, 0, 0, 1), "the power bar is left alone while off")
p.power.mode = "health"
P.RefreshOptionalBars()
check(colourIs(player.Power.color, 0.9, 0.5, 0.1) and colourIs(player.Power.FakeFill.vertex, 0.9, 0.5, 0.1),
  "Match my health bar, including JuNNeZ Edition's fill texture")
check(colourIs(env.PlayerFrame.manabar.color, 0.9, 0.5, 0.1), "Blizzard's mana bar too")
p.power.mode, p.power.color = "custom", { 0.1, 0.8, 0.9, 1 }
P.RefreshOptionalBars()
check(colourIs(player.Power.color, 0.1, 0.8, 0.9), "Its own colour")
p.power.mode = "off"
P.RefreshOptionalBars()
player.Power:SetStatusBarColor(0, 0, 1)
check(colourIs(player.Power.color, 0, 0, 1) and colourIs(env.PlayerFrame.manabar.color, 0, 0, 1), "Off hands the power bars back")

---------------------------------------------------------------------------
-- Rules (5.2)
---------------------------------------------------------------------------
-- a profile with no rules of its own starts with five examples, switched off
check(#p.rules == 5, "five example rules come with a new profile")
local anyOn = false
for _, r in ipairs(p.rules) do anyOn = anyOn or r.enabled end
check(not anyOn and p.exampleRulesSeeded, "all switched off, offered once")
game.state.resting = true
P.EvaluateRules()
check(not P.ActiveRule("player"), "switched-off examples change nothing")
game.state.resting = false
P.EvaluateRules()
p.rules = {}
P.RulesChanged()
P.AddRule()
local rule = p.rules[1]
rule.color = { 1, 0, 0, 1 }
P.RulesChanged()
check(not P.ActiveRule("player"), "a combat rule waits for combat")
game.fire("PLAYER_REGEN_DISABLED")
game.advance(0.4)
check(P.ActiveRule("player") == rule and colourIs(player.Health.color, 1, 0, 0), "in combat the rule's colour shows")
check(not P.ActiveRule("pet") and colourIs(pet.Health.color, 0.9, 0.5, 0.1), "the pet frame keeps its colour")
game.fire("PLAYER_REGEN_ENABLED")
game.advance(0.4)
check(colourIs(player.Health.color, 0.9, 0.5, 0.1), "after combat your colour comes back")

-- first match wins, and the order can change
P.AddRule()
local mounted = p.rules[2]
mounted.condition, mounted.color, mounted.target = "mounted", { 0, 1, 0, 1 }, "both"
game.state.mounted = true
game.fire("PLAYER_REGEN_DISABLED")
game.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check(P.ActiveRule("player") == rule and P.ActiveRule("pet") == mounted, "first matching rule wins per bar")
P.MoveRule(2, -1)
check(P.ActiveRule("player") == mounted, "moving a rule up lets it win")
game.fire("PLAYER_REGEN_ENABLED")
game.state.mounted = false
game.fire("PLAYER_MOUNT_DISPLAY_CHANGED")

-- conditions with a value
p.rules[1].condition, p.rules[1].value = "spec", 2
P.RulesChanged()
check(not P.ActiveRule("player"), "a spec rule waits for its specialization")
game.state.spec = 2
game.fire("ACTIVE_TALENT_GROUP_CHANGED")
check(P.ActiveRule("player") == p.rules[1], "and shows in it")
game.state.spec = 1
p.rules[1].condition, p.rules[1].value = "instance", "party"
game.state.instance = "party"
game.fire("ZONE_CHANGED_NEW_AREA")
check(P.ActiveRule("player") == p.rules[1], "an instance rule shows in a dungeon")
game.state.instance = nil
game.fire("ZONE_CHANGED_NEW_AREA")
check(not P.ActiveRule("player"), "and not outside")
-- a buff or debuff, by spell ID or name
check(P.SpellIDFrom(" 774 ") == 774 and P.SpellIDFrom("Rejuvenation") == 774 and P.SpellIDFrom("Nope") == nil,
  "a spell is found by ID or name")
check(P.SpellLabel(774) == "Rejuvenation" and P.SpellLabel(1) == "1", "a rule names its spell")
p.rules[1].condition, p.rules[1].value = "aura", 774
P.RulesChanged()
check(not P.ActiveRule("player"), "an aura rule waits for its buff")
game.state.auras = { [774] = true }
game.fire("UNIT_AURA", "player")
check(P.ActiveRule("player") == p.rules[1], "and shows while you have it")
game.state.aurasSecret = true
game.fire("UNIT_AURA", "player")
check(not P.ActiveRule("player"), "hidden aura data makes the rule wait")
game.state.aurasSecret, game.state.auras = nil, nil
game.fire("UNIT_AURA", "player")
check(not P.ActiveRule("player"), "and it goes when the buff does")
check(P.SanitizeRule({ condition = "aura", value = "774", color = { 1, 0, 0 } }).value == 774, "an imported aura rule keeps its spell")
for _, condition in ipairs({ "resting", "stealth", "dead" }) do
  p.rules[1].condition, p.rules[1].value = condition, nil
  game.state[condition] = true
  P.EvaluateRules()
  check(P.ActiveRule("player") == p.rules[1], condition .. " rule")
  game.state[condition] = false
  P.EvaluateRules()
end
p.rules[1].enabled = false
game.state.resting = true
P.RulesChanged()
check(not P.ActiveRule("player"), "a rule switched off never shows")
game.state.resting = false
P.DeleteRule(2)
check(#p.rules == 1, "rules can be deleted")

---------------------------------------------------------------------------
-- Colour by health (5.2, test): the colour is secret and passed on untouched
---------------------------------------------------------------------------
p.healthColour = true
P.ResetHealthCurves()
P.Repaint()
local c = player.Health.color
check(type(c[1]) == "table" and c[1].secret, "the health bar takes the curve's colour as it is")
game.fire("UNIT_HEALTH", "player")
check(type(player.Health.color[1]) == "table", "health changes repaint without touching the value")
-- an effect you pick shows instead of colouring by health; None brings it back
P.SetUserColour(0.2, 0.4, 0.6, 1)
P.SetEffect("pulse")
game.advance(0.2)
check(type(player.Health.color[1]) == "number", "an effect beats Colour by Health")
P.SetEffect("static")
P.Repaint()
check(type(player.Health.color[1]) == "table", "None brings colouring by health back")
p.healthColour = false
P.Repaint()

---------------------------------------------------------------------------
-- Share strings (5.1)
---------------------------------------------------------------------------
p.presets["Tank Red"] = { 0.7, 0.1, 0.1, 1 }
p.familyColours[1] = { 0.2, 0.3, 0.4, 1 }
local text = P.Export(P.shareParts)
check(text and text:sub(1, 7) == "!AZUI1!", "a share string starts with !AZUI1!")
local data = P.Decode(text)
check(data and data.presets["Tank Red"] and data.families[1] and #data.rules == 1, "and reads back")
local lines = table.concat(P.DescribeImport(data), "\n")
check(lines:find("replace yours: ") and lines:find("Tank Red") and lines:find("1 rule"), "the preview says what changes: " .. lines)
check(select(2, P.Decode("hello")):find("not an AzUI share string"), "other text is refused")
check(select(2, P.Decode("!AZUI1!zz")):find("damaged"), "a damaged string is refused")

-- a hostile payload: only clean data survives
local E = env.C_EncodingUtil
local evil = "!AZUI1!" .. E.EncodeBase64(E.CompressString(E.SerializeCBOR({
  v = 1,
  color = { 5, -1, "x", 1 },
  presets = { [("x"):rep(200) .. "|cffff0000"] = { 2, 0.5, 0.5 }, ok = { 0.1, 0.2, 0.3 } },
  pets = { [42] = { mode = "evil", color = { 0, 0, 0 }, effect = "explode" } },
  rules = { { condition = "os.execute", color = { 1, 1, 1 } }, { condition = "combat", color = { 9, 9, 9 }, effect = "flicker", target = "everything" } },
  extra = function() end,
})))
local clean = P.Decode(evil)
check(clean and clean.color == nil, "a colour that is not one is dropped")
local longName
for name in pairs(clean.presets) do if name ~= "ok" then longName = name end end
check(#longName == 48 and not longName:find("|"), "preset names are capped and cleaned")
check(clean.pets[42].mode == "family" and clean.pets[42].effect == "static", "unknown pet settings fall back")
check(#clean.rules == 1 and clean.rules[1].color[1] == 1 and clean.rules[1].target == "player", "unknown rules are dropped, colours clamped")

-- export only some parts, then import
P.shareParts.rules = false
data = P.Decode(P.Export(P.shareParts))
check(data.rules == nil, "parts left unticked are not exported")
P.shareParts.rules = true
p.presets["Tank Red"] = nil
P.ApplyImport(data)
check(p.presets["Tank Red"], "an import adds its presets")

---------------------------------------------------------------------------
-- Slash commands and key bindings (5.1)
---------------------------------------------------------------------------
check(env.SlashCmdList.AZCOLORPICKER("color #ff8800") and colourIs(p.color, 1, 0.53, 0), "/ahui color #ff8800")
check(env.SlashCmdList.AZCOLORPICKER("colour 0 128 255") and colourIs(p.color, 0, 0.5, 1), "/ahui colour 0 128 255")
check(not env.SlashCmdList.AZCOLORPICKER("color purple"), "/ahui color refuses what is not a colour")
check(env.SlashCmdList.AZCOLORPICKER("preset cb-blue") and P.selectedPreset == "CB-Blue", "/ahui preset finds a name in any case")
env.SlashCmdList.AZCOLORPICKER("next")
check(P.selectedPreset == "CB-Orange", "/ahui next loads the next preset")
check(env.SlashCmdList.AZCOLORPICKER("effect Breathe") and p.effect == "breathe", "/ahui effect breathe")
check(env.SlashCmdList.AZCOLORPICKER("effect off") and p.effect == "static", "/ahui effect off")
env.SlashCmdList.AZCOLORPICKER("pets on")
check(p.petColouring, "/ahui pets on")
env.SlashCmdList.AZCOLORPICKER("pets off")
check(not p.petColouring, "/ahui pets off")
check(not env.SlashCmdList.AZCOLORPICKER("dance") and game.printed[#game.printed]:find("/ahui"), "an unknown command prints the help")
env.SlashCmdList.AZCOLORPICKER("share")
check(Panel:IsShown() and Panel.selected == "share", "/ahui share opens the Share page")
Panel:Close()

env.AzUIColorPicker_Binding("rainbow")
check(p.effect == "rainbow", "the rainbow key binding turns it on")
env.AzUIColorPicker_Binding("rainbow")
check(p.effect == "static", "and off")
env.AzUIColorPicker_Binding("pulse")
check(p.effect == "pulse", "the pulse key binding")
P.SetEffect("static")
local bindings = assert(io.open("Bindings.xml")):read("*a")
for name, body in bindings:gmatch('name="([%w_]+)"[^>]*>([^<]+)<') do
  check(env["BINDING_NAME_" .. name], "binding " .. name .. " has a name")
  check(body:find("AzUIColorPicker_Binding"), "binding " .. name .. " calls the addon")
end
check(env.BINDING_HEADER_AZUICOLORPICKER, "the bindings have a header")

---------------------------------------------------------------------------
-- Launcher and quick palette (5.1)
---------------------------------------------------------------------------
local launcher = ns.dataObj
local tooltip = { lines = {}, AddLine = function(self, text) table.insert(self.lines, text) end }
launcher.OnTooltipShow(tooltip)
check(table.concat(tooltip.lines, "\n"):find("#"), "the tooltip shows your colour")
launcher.OnClick(game.NewWidget("Button"), "RightButton")
local palette = P.GetQuickPalette()
check(palette and palette.shown, "right-click opens the quick palette")
local shownSwatches = 0
for _, swatch in ipairs(palette.swatches) do if swatch.shown then shownSwatches = shownSwatches + 1 end end
check(shownSwatches == math.min(8, #P.SortedPresetNames()) and shownSwatches > 0, "it shows your presets, up to eight")
palette.swatches[1].scripts.OnClick(palette.swatches[1])
check(P.selectedPreset == P.SortedPresetNames()[1], "a swatch loads its preset")
local chips = {}
for _, chip in ipairs(palette.chips) do chips[chip.effect] = chip end
chips.pulse.scripts.OnClick(chips.pulse)
check(p.effect == "pulse", "an effect chip sets the effect")
game.answer = false
chips.flicker.scripts.OnClick(chips.flicker)
check(p.effect == "pulse", "the Flicker chip asks first")
game.answer = nil
palette.pets.scripts.OnClick(palette.pets)
check(p.petColouring, "the pet colours switch")
launcher.OnClick(game.NewWidget("Button"), "RightButton")
check(not palette.shown, "right-click again closes it")
local before = P.selectedPreset
game.shift = true
launcher.OnClick(game.NewWidget("Button"), "LeftButton")
game.shift = false
check(P.selectedPreset ~= before, "Shift-click loads the next preset")
launcher.OnClick(game.NewWidget("Button"), "LeftButton")
check(Panel:IsShown(), "left-click opens the AzUI window")
Panel:Close()

---------------------------------------------------------------------------
-- Profiles (5.2)
---------------------------------------------------------------------------
P.SetUserColour(0.3, 0.3, 0.3)
P.NewProfile("Tank")
check(db:GetCurrentProfile() == "Tank" and colourIs(db.profile.color, 0.7, 0.1, 0.1), "a new profile starts from the defaults")
check(db.profile.presets["CB-Blue"], "and gets the colour-blind presets")
db:SetProfile("Default")
check(colourIs(db.profile.color, 0.3, 0.3, 0.3), "switching back brings your colour back")
db.char.specProfiles.enabled = true
db.char.specProfiles[2] = "Tank"
game.state.spec = 2
game.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
check(db:GetCurrentProfile() == "Tank", "changing specialization switches profile")
game.state.spec = 1
game.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
check(db:GetCurrentProfile() == "Tank", "a specialization without a profile keeps the current one")
db:SetProfile("Default")
P.DeleteProfile("Tank")
check(not P.ProfileChoices().Tank and db.char.specProfiles[2] == nil, "deleting a profile forgets its specialization")
check(not P.DeleteProfile("Default"), "the current profile cannot be deleted")

---------------------------------------------------------------------------
-- Your cast bar (AzeriteUI's PlayerCastBarFrame module)
do
  local castbar = game.NewWidget("StatusBar", "AzeriteCastbar")
  castbar.casting = true
  game.libs["AceAddon-3.0"].GetAddon = function(_, name)
    if name == "AzeriteUI" then
      return { GetModule = function(_, key) if key == "PlayerCastBarFrame" then return { frame = { Castbar = castbar } } end end }
    end
  end
  P.SetUserColour(0.2, 0.6, 0.3, 1)
  P.SetEffect("static")
  p.cast.mode = "health"
  P.RefreshOptionalBars()
  local h = game.azPlayer.Health.color
  check(colourIs(castbar.color, h[1], h[2], h[3]), "the cast bar matches your health bar, rules included")
  castbar.notInterruptible = true
  castbar:SetStatusBarColor(1, 0, 0) -- AzeriteUI: this cast cannot be interrupted
  check(colourIs(castbar.color, 1, 0, 0), "a cast that cannot be interrupted keeps AzeriteUI's red")
  castbar.notInterruptible, castbar.casting = nil, false
  castbar:SetStatusBarColor(1, 0, 0) -- AzeriteUI: the cast failed
  check(colourIs(castbar.color, 1, 0, 0), "so does a failed or interrupted cast")
  castbar.casting = true
  p.cast.mode, p.cast.color = "custom", { 0.9, 0.8, 0.1, 1 }
  game.advance(0.4) -- let any fade finish
  check(colourIs(castbar.color, 0.9, 0.8, 0.1), "or the cast bar's own colour")
  p.cast.mode = "off"
  P.RefreshOptionalBars()
  castbar:SetStatusBarColor(0.5, 0.5, 0.5)
  check(colourIs(castbar.color, 0.5, 0.5, 0.5), "off leaves it to AzeriteUI")
  game.libs["AceAddon-3.0"].GetAddon = function() end
end

-- Other unit frame addons: ElvUI and Unhalted Unit Frames (oUF), Shadowed Unit Frames
do
  local W, env = game.NewWidget, game.env
  local function OUF(name)
    local frame = W("Frame", name)
    frame.Health, frame.Power, frame.Castbar = W("StatusBar"), W("StatusBar"), W("StatusBar")
    env[name] = frame
    return frame
  end
  local elv, elvPet, uuf = OUF("ElvUF_Player"), OUF("ElvUF_Pet"), OUF("UUF_Player")
  local suf = W("Frame", "SUFUnitplayer")
  suf.healthBar, suf.powerBar = W("StatusBar"), W("StatusBar")
  suf.castBar = W("Frame"); suf.castBar.bar = W("StatusBar")
  env.SUFUnitplayer = suf
  P.SetUserColour(0.2, 0.6, 0.3, 1)
  p.power.mode, p.cast.mode = "health", "health"
  P.RefreshOptionalBars()
  game.advance(0.4)
  local h = game.azPlayer.Health.color
  for label, bar in pairs({ ElvUI = elv.Health, Unhalted = uuf.Health, Shadowed = suf.healthBar,
      ["ElvUI power"] = elv.Power, ["Shadowed power"] = suf.powerBar }) do
    check(colourIs(bar.color, h[1], h[2], h[3]), label .. " is coloured like your health bar")
  end
  local _, channels = P.GetTargets()
  check(channels[elvPet.Health] == "pet", "ElvUI's pet frame takes the pet colour")
  elv.Castbar.casting = true
  elv.Castbar:SetStatusBarColor(1, 1, 1)
  check(colourIs(elv.Castbar.color, h[1], h[2], h[3]), "ElvUI's cast bar while casting")
  suf.castBar.bar:SetStatusBarColor(0, 0, 0, 0)
  check(colourIs(suf.castBar.bar.color, 0, 0, 0) and suf.castBar.bar.color[4] == 0,
    "Shadowed Unit Frames' idle cast bar stays see-through")
  suf.castBar.bar.spellName = "Fireball"
  suf.castBar.bar:SetStatusBarColor(1, 0.7, 0)
  check(colourIs(suf.castBar.bar.color, h[1], h[2], h[3]), "and is coloured while casting")
  elv.Health:SetStatusBarColor(0.1, 0.1, 0.1)
  check(colourIs(elv.Health.color, h[1], h[2], h[3]), "ElvUI recolouring its bar gets ours back")
  p.power.mode, p.cast.mode = "off", "off"
  P.RefreshOptionalBars()
  suf.powerBar:SetStatusBarColor(0, 0, 1)
  check(colourIs(suf.powerBar.color, 0, 0, 1), "power off hands the bar back")
  for _, name in ipairs({ "ElvUF_Player", "ElvUF_Pet", "UUF_Player", "SUFUnitplayer" }) do env[name] = nil end
end

-- Preset packs add their colours once, and never over your own
p.presets["Fire"] = { 0.1, 0.1, 0.1, 1 }
local added = P.AddPresetPack("elements")
check(added == 5 and p.presets["Ice"] and p.presets["Fire"][1] == 0.1, "a pack adds what you lack and keeps your own Fire")
check(P.AddPresetPack("elements") == 0, "adding it again adds nothing")
for _, key in ipairs(P.PRESET_PACK_ORDER) do check(#P.PRESET_PACKS[key].presets >= 6, "pack " .. key) end

-- Every page validates with the real AceConfigRegistry, rules included
---------------------------------------------------------------------------
P.AddRule()
p.rules[#p.rules].condition, p.rules[#p.rules].value = "spec", 1
P.BuildRuleOptions()
local realEnv = setmetatable({}, { __index = _G })
realEnv._G = realEnv
realEnv.geterrorhandler = function() return error end
for _, file in ipairs({ "Libs/LibStub/LibStub.lua", "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
  "Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua" }) do
  local chunk = assert(loadfile(file))
  setfenv(chunk, realEnv)
  chunk()
end
local registry = realEnv.LibStub("AceConfigRegistry-3.0")
local ok, err = pcall(registry.ValidateOptionsTable, registry, P.options, "AzUI_Color_Picker")
check(ok, "AceConfigRegistry accepts every page: " .. tostring(err))

-- every page of the AzUI window draws without a control it cannot draw
ns.OpenPanel()
for _, info in ipairs(Panel.pages) do
  Panel:SelectPage(info.key)
  for _, control in ipairs(Panel.page:GetControls()) do
    check(not (control.labelText and control.labelText:find("cannot draw")), info.key .. ": " .. tostring(control.labelText))
  end
end

-- Nothing in all of the above wrote onto Blizzard's frames or ran Blizzard's update
-- code from the addon, which is what tainted TextStatusBar in the field.
check(#game.taint == 0, "no field written onto Blizzard's frames: " .. table.concat(game.taint, ", "))
check(#game.blizzardCalls == 0, "no Blizzard update function called: " .. table.concat(game.blizzardCalls, ", "))

print(checks .. " feature checks passed")
