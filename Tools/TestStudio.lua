-- Run from the addon directory: lua Tools/TestStudio.lua (Lua 5.1).
-- The AzUI Studio look and its Health Bar and Rules pages, against Tools/Mock.lua.
local Mock = dofile("Tools/Mock.lua")
local checks = 0
local function check(value, message)
  if not value then error("FAILED: " .. message, 2) end
  checks = checks + 1
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.02 end
local function colourIs(c, r, g, b) return c and near(c[1], r) and near(c[2], g) and near(c[3], b) end

---------------------------------------------------------------------------
-- Every piece of art and every font the code asks for is on disk
---------------------------------------------------------------------------
local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
end
local sources = {}
for _, file in ipairs({ "Options/Studio.lua", "Options/StudioWidgets.lua", "Options/StudioHealth.lua",
  "Options/StudioRules.lua", "Options/Panel.lua" }) do
  sources[#sources + 1] = assert(io.open(file)):read("*a")
end
local all = table.concat(sources, "\n")
for name in all:gmatch('Studio%.Media%("([%w%-]+)"%)') do
  check(exists("Media/Studio/" .. name .. ".tga"), "art " .. name)
end
for name in all:gmatch('Glyph%([^,]+, "([%w%-]+)"%)') do
  check(exists("Media/Studio/glyph-" .. name .. ".tga"), "glyph " .. name)
end
for _, r in ipairs({ 3, 4, 6, 8, 9, 10, 12 }) do
  for _, part in ipairs({ "fill", "edge", "edge2" }) do
    check(exists("Media/Studio/round" .. r .. "-" .. part .. ".tga"), "round" .. r .. "-" .. part)
  end
end
for _, font in ipairs({ "Marcellus-Regular.ttf", "SourceSans3-Regular.ttf", "SourceSans3-Semibold.ttf",
  "Marcellus-OFL.txt", "SourceSans3-LICENSE.md" }) do
  check(exists("Media/Fonts/" .. font), "font " .. font)
end

-- Every piece of the art pack that Options/StudioPack.lua switches on is shipped,
-- at the size its slot draws it from (Tools/AssetBrief).
do
  local pack = assert(io.open("Options/StudioPack.lua")):read("*a")
  local sizes = { logo = { 64, 64 }, corner = { 64, 64 }, ["empty-rules"] = { 256, 128 }, ["empty-pets"] = { 256, 128 } }
  local files = { logo = { "logo" }, corners = { "corner" }, emptyRules = { "empty-rules" }, emptyPets = { "empty-pets" },
    conditions = { "condition-combat", "condition-mounted", "condition-resting", "condition-stealth",
      "condition-dead", "condition-spec", "condition-instance" } }
  for key, names in pairs(files) do
    if pack:find(key .. "%s*=%s*true") then
      for _, name in ipairs(names) do
        local f = io.open("Media/StudioPack/" .. name .. ".tga", "rb")
        check(f, "art pack file " .. name)
        local header = f:read(18)
        f:close()
        local w, h = header:byte(13) + header:byte(14) * 256, header:byte(15) + header:byte(16) * 256
        local want = sizes[name] or { 64, 64 }
        check(w == want[1] and h == want[2] and header:byte(17) == 32, name .. " is " .. want[1] .. "x" .. want[2] .. " with alpha")
      end
    end
  end
end

---------------------------------------------------------------------------
-- The window in Studio
---------------------------------------------------------------------------
local game = Mock.New()
local env, P, db, ns = game.env, game.P, game.db, game.ns
local p = db.profile
local Kit = ns.OptionsKit
-- Enabled pack switches must refer to real, correctly encoded transparent art.
-- A mock texture accepts a missing path, so inspect the exported bytes as well.
local pack = Kit.Studio.Pack
local assets = { { "logo", "logo", 64, 64 }, { "corners", "corner", 64, 64 },
  { "emptyRules", "empty-rules", 256, 128 }, { "emptyPets", "empty-pets", 256, 128 } }
for _, key in ipairs({ "combat", "mounted", "resting", "stealth", "dead", "spec", "instance" }) do
  assets[#assets + 1] = { "conditions", "condition-" .. key, 64, 64 }
end
for _, spec in ipairs(assets) do
  if pack[spec[1]] then
    local file = assert(io.open("Media/StudioPack/" .. spec[2] .. ".tga", "rb"))
    local data = file:read("*a"); file:close()
    local function word(pos) return data:byte(pos) + 256 * data:byte(pos + 1) end
    check(data:byte(1) == 0 and data:byte(2) == 0 and data:byte(3) == 2 and
      data:byte(17) == 32 and data:byte(18) == 40, spec[2] .. " is 32-bit top-origin TGA with alpha")
    check(word(13) == spec[3] and word(15) == spec[4] and #data == 18 + spec[3] * spec[4] * 4,
      spec[2] .. " has its exact dimensions and pixel data")
    local visible, transparent, white = false, false, true
    for pos = 19, #data, 4 do
      local b, g, r, a = data:byte(pos, pos + 3)
      if a > 0 then visible = true end
      if a == 0 then transparent = true end
      if a > 0 and (r ~= 255 or g ~= 255 or b ~= 255) then white = false end
    end
    check(visible and transparent, spec[2] .. " contains artwork and transparent space")
    if spec[1] == "conditions" then check(white, spec[2] .. " is white for runtime tinting") end
  end
end
ns.OpenPanel("general")
local Panel = Kit.Panel
check(Kit.ArtStyle == "studio" and Kit.GetTheme() == "studio", "Studio is the default theme and art")
check(Panel.windowRound and Panel.railRound, "the window and rail are rounded surfaces")
check(Panel.title.text == "AzUI Studio", "the title reads AzUI Studio")

-- changing to a theme with other art asks for a reload; No keeps Studio
game.answer = false
local theme
for _, control in ipairs((function() Panel:SelectPage("window"); return Panel.page:GetControls() end)()) do
  if control.labelText == "Theme" then theme = control end
end
theme:Fire("azerite")
check(db.global.panel.theme == "studio" and game.popups[#game.popups].text:find("Reload"), "a theme with other art asks to reload")
game.answer = nil
Panel:SelectPage("general")

---------------------------------------------------------------------------
-- Health Bar page
---------------------------------------------------------------------------
local H = Kit.StudioHealth.control
check(Panel.page:GetControls()[1] == H, "the Studio page comes first")

-- live preview: the bars show what the real ones do
local health, petBar = H.preview.health, H.preview.petBar
P.SetUserColour(0.2, 0.4, 0.6, 1)
check(colourIs(health.color, 0.2, 0.4, 0.6), "the preview health bar shows your colour")
check(colourIs(petBar.color, 0.2, 0.4, 0.6), "and the pet bar with no pet colour")

-- the colour wheel, then Hex, R G B and Alpha
H.wheel.scripts.OnColorSelect(H.wheel, 1, 0, 0)
check(colourIs(p.color, 1, 0, 0) and H.hex.committed == "#FF0000", "the wheel picks a colour and fills in Hex")
H.wheel.scripts.OnMouseUp = H.wheel.scripts.OnMouseUp or function() end
H.hex:SetText("#00ff00")
H.hex.scripts.OnEnterPressed(H.hex)
check(colourIs(p.color, 0, 1, 0), "a hex code sets the colour")
check(colourIs(p.recentColours[1], 0, 1, 0), "and goes on the recent colours")
H.rgb[3]:SetText("255")
H.rgb[3].scripts.OnEnterPressed(H.rgb[3])
check(colourIs(p.color, 0, 1, 1), "R G B boxes set a channel")
H.hex:SetText("not a colour")
H.hex.scripts.OnEnterPressed(H.hex)
check(colourIs(p.color, 0, 1, 1) and H.hex.committed == "#00FFFF", "a bad hex code is put back")

-- recent colours
Kit.StudioHealth:Update()
check(H.recent[1].shown and colourIs(H.recent[1].colour, 0, 1, 1), "the newest recent colour comes first")
H.recent[2].scripts.OnClick(H.recent[2])
check(colourIs(p.color, 0, 1, 0), "a recent colour can be used again")

-- undo steps back through this page's changes
H.undo.scripts.OnClick(H.undo)
check(colourIs(p.color, 0, 1, 1), "Undo steps back one change")
H.undo.scripts.OnClick(H.undo)
check(colourIs(p.color, 0, 1, 0), "and another")

-- presets: click, drag, + Save
Kit.StudioHealth:Layout(700)
local tiles = H.tiles
check(tiles[1].shown and tiles[1].preset == P.SortedPresetNames()[1], "presets are swatches in their order")
tiles[2].scripts.OnClick(tiles[2], "LeftButton")
game.flush() -- the window redraws on the next frame
check(P.selectedPreset == tiles[2].preset and tiles[2].selected, "a swatch loads its preset and is ringed")
local moving = tiles[3].preset
tiles[3].scripts.OnDragStart(tiles[3])
tiles[1].IsMouseOver = function() return true end
tiles[3].scripts.OnDragStop(tiles[3])
tiles[1].IsMouseOver = nil
check(P.SortedPresetNames()[1] == moving and p.presetOrder[1] == moving, "dragging a swatch onto the first moves it there")
game.popupText = "Sea"
H.addTile.scripts.OnClick(H.addTile)
check(p.presets.Sea, "+ Save asks for a name and saves the colour")
game.answer = false
tiles[1].scripts.OnClick(tiles[1], "RightButton")
check(p.presets[tiles[1].preset], "right-click without a menu asks before deleting; No keeps it")
game.answer = nil

-- effect cards
local cards = {}
for _, card in ipairs(H.cards) do cards[card.effect] = card end
check(#H.cards == #P.EFFECTS, "a card per effect")
cards.breathe.scripts.OnClick(cards.breathe)
check(p.effect == "breathe", "a card picks its effect")
H.frame.scripts.OnUpdate(H.frame, 0.5)
check(cards.pulse.bar.fill.vertex, "the cards play their effects")
H.frame.scripts.OnUpdate(H.frame, 0.5)
check(cards.sweep.bar.left.shown, "Sweep's card shows its band")

-- Show on
local petChip, powerChip = H.chips[2], H.chips[3]
check(H.chips[1].on and H.chips[1].locked, "Health bar is always on")
petChip.scripts.OnClick(petChip)
check(p.colourPetFrames == false, "Pet frame off leaves the pet frames alone")
game.azPet.Health:SetStatusBarColor(0, 1, 0)
check(colourIs(game.azPet.Health.color, 0, 1, 0), "AzeriteUI colours its pet frame again")
petChip.scripts.OnClick(petChip)
check(p.colourPetFrames and not colourIs(game.azPet.Health.color, 0, 1, 0), "and on takes it back")
powerChip.scripts.OnClick(powerChip)
check(p.power.mode == "health" and H.preview.power, "Power bar matches your health bar")
powerChip.scripts.OnClick(powerChip)
check(p.power.mode == "off", "and off again")

-- Done closes
H.done.scripts.OnClick(H.done)
check(not Panel:IsShown(), "Done closes the window")

---------------------------------------------------------------------------
-- Rules page
---------------------------------------------------------------------------
ns.OpenPanel("rules")
local R = Kit.StudioRules.control
check(Panel.page:GetControls()[1] == R, "the Rules page is the Studio sentence list")
local labels = {}
for _, control in ipairs(Panel.page:GetControls()) do if control.labelText then labels[control.labelText] = true end end
check(not labels["Add Rule"], "the classic rule rows stay out of the window")
local seeded = #p.rules
R.examples.scripts.OnClick(R.examples)
check(#p.rules == seeded + 5 and not p.rules[#p.rules].enabled, "Add example rules adds five, switched off")
local before = #p.rules
R.add.scripts.OnClick(R.add)
Kit.StudioRules:Update()
Kit.StudioRules:Layout(700)
local row = R.rows[#p.rules]
check(#p.rules == before + 1 and row.shown, "+ Add rule adds a row")
row.switch.scripts.OnClick(row.switch)
check(p.rules[row.index].enabled == false, "the switch turns a rule off")
row.switch.scripts.OnClick(row.switch)
row.condition.owner:Fire("spec")
Kit.StudioRules:Update()
check(p.rules[row.index].condition == "spec" and p.rules[row.index].value == 1 and row.value.shown,
  "picking Specialization shows its value, set to the one you are in")
row.value.owner:Fire(2)
check(p.rules[row.index].value == 2, "the value can be changed")
game.answer = false
row.effect.owner:Fire("flicker")
check(p.rules[row.index].effect ~= "flicker", "Flicker on a rule asks first")
game.answer = nil
row.effect.owner:Fire("pulse")
row.target.owner:Fire("both")
check(p.rules[row.index].effect == "pulse" and p.rules[row.index].target == "both", "effect and target")
P.AddRule()
Kit.StudioRules:Update()
local second = p.rules[#p.rules]
local last = R.rows[#p.rules]
last.grip.scripts.OnDragStart(last.grip)
R.rows[1].IsMouseOver = function() return true end
last.grip.scripts.OnDragStop(last.grip)
R.rows[1].IsMouseOver = nil
check(p.rules[1] == second, "dragging a rule's handle moves it to the top")
local count = #p.rules
game.answer = false
R.rows[1].delete.scripts.OnClick(R.rows[1].delete)
check(#p.rules == count, "deleting asks first")
game.answer = nil
R.rows[1].delete.scripts.OnClick(R.rows[1].delete)
check(#p.rules == count - 1, "and deletes on yes")

-- every page still draws in Studio
for _, info in ipairs(Panel.pages) do
  Panel:SelectPage(info.key)
  check(#Panel.page:GetControls() > 0, info.key .. " draws")
end

---------------------------------------------------------------------------
-- With the whole Studio art pack switched on (Options/StudioPack.lua)
---------------------------------------------------------------------------
do
  local packed = Mock.New({ noLogin = true })
  for key in pairs(packed.ns.OptionsKit.Studio.Pack) do packed.ns.OptionsKit.Studio.Pack[key] = true end
  packed.fire("ADDON_LOADED", "AzUI_Color_Picker")
  packed.fire("PLAYER_ENTERING_WORLD")
  packed.flush()
  packed.db.profile.rules = {}
  packed.ns.OpenPanel("rules")
  local K = packed.ns.OptionsKit
  check(K.Panel:IsShown(), "the window builds with the art pack on")
  check(K.StudioRules.control.emptyArt and K.StudioRules.control.emptyArt.shown, "no rules shows the pack's illustration")
  packed.P.AddRule()
  K.StudioRules:Update()
  K.StudioRules:Layout(700)
  local icon = K.StudioRules.control.rows[1].icon
  check(icon and icon.texture and icon.texture:find("condition%-combat"), "a rule shows its condition's icon")
  local logo
  for _, w in ipairs(packed.frames) do
    if type(w.texture) == "string" and w.texture:find("StudioPack", 1, true) and w.texture:find("logo", 1, true) then logo = w end
  end
  check(logo, "the title shows the pack's logo")
end

check(#game.taint == 0, "the Studio pages write nothing onto Blizzard's frames: " .. table.concat(game.taint, ", "))
check(#game.blizzardCalls == 0, "and call none of Blizzard's update functions")

print(checks .. " studio checks passed")
