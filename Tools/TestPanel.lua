-- Run from the addon directory: lua Tools/TestPanel.lua (Lua 5.1).
-- Loads every file the TOC lists against a mock client, logs in as a hunter with
-- four pets, and drives the AzUI window: every page, the search, the pet gallery's
-- filters, cards and detail controls, and the window's own settings.
local checks = 0
local function check(value, message)
  if not value then error("FAILED: " .. message, 2) end
  checks = checks + 1
end

local Mock = dofile("Tools/Mock.lua")
-- lua Tools/TestPanel.lua         the Studio theme (the default)
-- lua Tools/TestPanel.lua art     the Azerite theme with JuNNeZ Edition's art
-- lua Tools/TestPanel.lua plain   the Azerite theme with Blizzard's art
-- lua Tools/TestPanel.lua stock   the Azerite theme with stock AzeriteUI 5.x's art
-- lua Tools/TestPanel.lua aui6    the Azerite theme with AzeriteUI6's art
local mode = arg and arg[1] or "studio"
local editions = { stock = "AzeriteUI", aui6 = "AzeriteUI6" }
local game = Mock.New({ art = mode == "art", edition = editions[mode] })
local env, db, frames, flush, libs, ns = game.env, game.db, game.frames, game.flush, game.libs, game.ns
if mode ~= "studio" then db.global.panel.theme = "azerite" end

check(ns.Core and ns.OptionsKit and ns.OptionsKit.Panel and ns.OptionsKit.PetGallery, "every Options file loaded")
check(db.char.knownPets[11].displayID == 1001, "the stable's displayID is remembered")
check(db.char.knownPets[77].specID == 81, "the stable's specID is remembered")

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local Kit, Panel, Gallery = ns.OptionsKit, ns.OptionsKit.Panel, ns.OptionsKit.PetGallery
env.SlashCmdList.AZCOLORPICKER("")
check(Panel:IsShown(), "/ahui opens the AzUI window")
check(#Panel.pages == 8, "rail: Health Bar, Rules, Hunter Pets, Pet Families, More Bars, Profiles, Share, Window")

local function rowsOf(kind)
  local found = {}
  for _, control in ipairs(Panel.page:GetControls()) do
    if control.frame.shown and (not kind or control.kind == kind) then found[#found + 1] = control end
  end
  return found
end

Panel:SelectPage("general")
local labels = {}
for _, control in ipairs(rowsOf("color")) do labels[control.labelText] = true end
check(Panel.page:GetControls()[1] == Kit.StudioHealth.control, "Health Bar opens with the Studio page")
check(not labels["Healthbar Colour"] and labels["Low Health Colour"] and not labels["Second Colour"],
  "the Studio page has the colour; the rows keep the rest; Second Colour waits for Two-tone")
check(Kit.ArtStyle == ({ studio = "studio", art = "azerite", plain = "blizzard", stock = "azerite", aui6 = "azerite" })[mode],
  "the window's art follows the theme")
if editions[mode] then
  -- every AzeriteUI edition lends its own art, read from its own folder
  local folder = editions[mode]
  check(ns.ArtEdition == folder, "the installed AzeriteUI is found: " .. folder)
  local health = Kit.StudioHealth.control.preview.health
  check(health.case.texture:find("AddOns\\" .. folder .. "\\Assets", 1, true), "its health bar case comes from " .. folder)
  local border = Kit.GetMedia("border-tooltip")
  check(border:find(folder, 1, true) and (mode ~= "aui6" or border:find("border-aura", 1, true)),
    "cards use its border (AzeriteUI6 lends its aura border)")
  check(not Kit.GetMedia("options-glyphs"):find(folder, 1, true), "the glyph sheet only JuNNeZ Edition has comes from Blizzard")
  check(Panel.title.text:find("Azerite"), "the title reads AzUI Azerite")
end
if mode == "art" then
  -- AzUI with Azerite: AzeriteUI's own health bar and case, referenced from its folder
  local preview = Kit.StudioHealth.control.preview
  check(Panel.title.text:find("Azerite"), "the title reads AzUI Azerite")
  local logo
  for _, w in ipairs(frames) do
    if type(w.texture) == "string" and w.texture:find("StudioPack", 1, true) and w.texture:find("logo", 1, true) then logo = w end
  end
  check(logo, "AzUI's logo from the art pack stands beside it")
  check(preview.health.case and preview.health.case.texture:find("AzeriteUI5_JuNNeZ_Edition", 1, true)
    and preview.health.case.texture:find("hp_cap_case", 1, true), "the preview wears AzeriteUI's hp_cap_case")
end
check(#rowsOf("grid") == 2, "class colours and preset packs are grids of buttons")
local unsupported = 0
for _, control in ipairs(rowsOf("description")) do
  if control.labelText and control.labelText:find("cannot draw") then unsupported = unsupported + 1 end
end
check(unsupported == 0, "no setting is left undrawn")

-- a class colour button sets the colour
local grid = rowsOf("grid")[1]
grid.buttons[1].scripts.OnClick(grid.buttons[1])
check(db.profile.color[1] ~= 0.7, "a class colour button changes your colour")

Panel:SelectPage("families")
local colours = rowsOf("color")
check(#colours > 50, "every family and specialization colour is drawn")
local wolf
for _, control in ipairs(colours) do if control.labelText == "Wolf" then wolf = control end end
check(wolf and not wolf.modified, "an untouched family has no reset arrow")
db.profile.familyColours[1] = { 1, 0, 0, 1 }
Panel:Refresh()
for _, control in ipairs(rowsOf("color")) do if control.labelText == "Wolf" then wolf = control end end
check(wolf.modified and wolf.onRevert, "a changed family shows the reset arrow")
wolf.onRevert(wolf)
check(db.profile.familyColours[1] == nil, "the reset arrow puts the family back")
for _, control in ipairs(rowsOf("execute")) do
  check(control.labelText ~= "Reset", "the classic window's Reset buttons stay out of this one")
end

---------------------------------------------------------------------------
-- Changed from default: a gem on the row, a gem beside the page, the tally
---------------------------------------------------------------------------
do
  local p = db.profile
  local before = { mode = p.power.mode, colour = p.power.color }
  p.power.mode, p.power.color = "off", { 0.2, 0.45, 1, 1 }
  Panel:SelectPage("bars")
  local untouched = Panel.changedByPage.bars
  local shownBefore = Panel.count.shown
  p.power.mode = "custom"
  p.power.color = { 0, 1, 0, 1 }
  Panel:Refresh()
  local mode, colourRow
  for _, control in ipairs(rowsOf("select")) do if control.labelText == "Power Bar" then mode = control end end
  for _, control in ipairs(rowsOf("color")) do if control.labelText == "Power Bar Colour" then colourRow = control end end
  check(mode and mode.modified and mode.onRevert, "a changed setting shows its gem and reset arrow")
  check(colourRow and colourRow.modified and colourRow.onRevert, "so does a changed colour")
  check(Panel.changedByPage.bars == untouched + 2, "the page counts both")
  check(Panel.count.shown and Panel.count.text.text:find("changed"), "the tally shows")
  check(db.profile == p, "your profile is put back after asking the defaults")
  mode.onRevert(mode)
  check(p.power.mode == "off", "the arrow puts one setting back")
  colourRow.onRevert(colourRow)
  check(p.power.color[1] == 0.2 and p.power.color[2] == 0.45, "a colour too")
  p.power.color[1] = 0.21
  check(ns.P.defaults.profile.power.color[1] == 0.2, "a reverted colour is a copy, never the defaults themselves")
  p.power.color[1] = 0.2
  Panel:Refresh()
  check(Panel.changedByPage.bars == untouched and Panel.count.shown == shownBefore, "the tally goes back")
  check(Panel.changedByPage.window == 0, "the window's own look is not counted")
  Panel.count.scripts.OnClick(Panel.count)
  p.power.mode, p.power.color = before.mode, before.colour
  Panel:Refresh()
end

---------------------------------------------------------------------------
-- The pet gallery
---------------------------------------------------------------------------
Panel:SelectPage("pets")
local gallery = Gallery.control
check(gallery and gallery.frame.shown, "Hunter Pets shows the gallery")
check(Gallery.shown == 4, "every remembered pet gets a card")
check(Gallery.selected == 11, "the pet that is out is selected")
check(gallery.detail.model.displayID == 1001, "the selected pet's model is loaded")

-- filters
gallery.chips[3].scripts.OnClick(gallery.chips[3])
check(Gallery.shown == 1, "Stabled shows only stabled pets")
gallery.chips[2].scripts.OnClick(gallery.chips[2])
check(Gallery.shown == 3, "Call slots shows the call-pet slots")
gallery.chips[1].scripts.OnClick(gallery.chips[1])

-- the search box inside the gallery
gallery.search:SetText("cat")
gallery.search.scripts.OnTextChanged(gallery.search, true)
check(Gallery.shown == 1, "the gallery's search finds a pet by family")
gallery.search.scripts.OnEscapePressed(gallery.search)
check(Gallery.shown == 4, "Escape clears the gallery's search")

-- a pet without a displayID falls back to its icon
local skyeCard
for _, w in ipairs(frames) do if w.number == 33 and w.portrait then skyeCard = w end end
check(skyeCard and skyeCard.portrait.portraitID == nil, "a pet without a display uses its icon")
skyeCard.scripts.OnClick(skyeCard)
check(Gallery.selected == 33 and not gallery.detail.model.shown and gallery.detail.fallback.shown, "selecting it shows the icon instead of a model")

-- detail controls write the pet's settings
local mode, colour, effect = unpack(gallery.detail.rows)
mode:Fire("custom")
flush()
check(db.profile.pets[33].mode == "custom" and db.profile.pets[33].color, "Colour: own colour")
colour.callback(colour, 0.1, 0.2, 0.3, 1)
check(db.profile.pets[33].color[3] == 0.3, "the colour swatch sets the pet's own colour")
effect:Fire("rainbow")
flush()
check(db.profile.pets[33].effect == "rainbow", "Effect: rainbow")
gallery.detail.family.scripts.OnClick(gallery.detail.family)
flush()
check(db.profile.familyColours[26] and db.profile.familyColours[26][3] == 0.3, "Use for all copies the colour to the family")
gallery.detail.reset.scripts.OnClick(gallery.detail.reset)
flush()
check(db.profile.pets[33].mode == "family" and db.profile.pets[33].effect == "static", "Reset puts the pet back")

-- specialization colours replace family colours only when switched on
db.profile.familyColours[26] = nil
check(ns.Core.PetColour(22, db.char.knownPets[22])[1] == 1, "Cat uses its family colour")
db.profile.useSpecColours = true
check(ns.Core.PetColour(22, db.char.knownPets[22])[1] == 0.85, "with specialization colours on, Ferocity's colour")
db.profile.useSpecColours = false

---------------------------------------------------------------------------
-- Search across the window
---------------------------------------------------------------------------
Panel:ShowResults("grumble")
check(Panel.searching, "typing searches")
local first
for _, w in ipairs(frames) do if w.result and w.shown and w.result.pet == 77 then first = w end end
check(first, "a pet can be found by name from the window's search")
Panel:OpenResult(first.result)
check(Panel.selected == "pets" and Gallery.selected == 77, "a pet result opens the gallery on that pet")
Panel:ShowResults("animation speed")
local speed
for _, w in ipairs(frames) do if w.result and w.shown and w.result.page == "general" then speed = w end end
check(speed, "settings are found by name")
Panel:ClearSearch()
check(not Panel.searching, "clearing the search shows the page again")

---------------------------------------------------------------------------
-- The window's own page
---------------------------------------------------------------------------
Panel:SelectPage("window")
check(#rowsOf("select") + #rowsOf("range") >= 3, "theme, opacity and scale are drawn")
db.global.panel.theme = "dark"
Panel:ApplyTheme()
check(Kit.GetTheme() == "dark", "the theme applies")
db.global.panel.classic = true
env.SlashCmdList.AZCOLORPICKER("")
check(not Panel:IsShown() and libs["AceConfigDialog-3.0"].OpenFrames.AzUI_Color_Picker, "the classic window can be the default")
db.global.panel.classic = false
env.SlashCmdList.AZCOLORPICKER("")
check(Panel:IsShown() and not libs["AceConfigDialog-3.0"].OpenFrames.AzUI_Color_Picker, "and back")
env.SlashCmdList.AZCOLORPICKER("classic")
check(not Panel:IsShown() and libs["AceConfigDialog-3.0"].OpenFrames.AzUI_Color_Picker, "/ahui classic opens the Ace3 window")

---------------------------------------------------------------------------
-- The classic window and Blizzard's Settings page validate the option table with
-- AceConfigRegistry, which refuses keys it does not know. Run the real library.
---------------------------------------------------------------------------
local realEnv = setmetatable({}, { __index = _G })
realEnv._G = realEnv
realEnv.geterrorhandler = function() return error end
realEnv.securecallfunction = pcall
for _, file in ipairs({
  "Libs/LibStub/LibStub.lua",
  "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
  "Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua",
}) do
  local chunk = assert(loadfile(file))
  setfenv(chunk, realEnv)
  chunk()
end
local registry = realEnv.LibStub("AceConfigRegistry-3.0")
local ok, err = pcall(registry.ValidateOptionsTable, registry, ns.Core.options, "AzUI_Color_Picker")
check(ok, "AceConfigRegistry accepts the option table: " .. tostring(err))

---------------------------------------------------------------------------
-- ESC > Options > AddOns: a landing page with a way into the window, as AzeriteUI's
---------------------------------------------------------------------------
do
  local page = game.settingsPage
  check(page and game.settingsCategory and game.settingsCategory.name == "AzUI Color Picker",
    "the AddOns list in Blizzard's Settings has an AzUI Color Picker page")
  env.SettingsPanel = game.NewWidget("Frame", "SettingsPanel")
  env.SettingsPanel:Show()
  env.HideUIPanel = function(frame) frame:Hide() end
  Panel:Close()
  page.open.scripts.OnClick(page.open)
  check(Panel:IsShown() and not env.SettingsPanel.shown, "its button closes Settings and opens the AzUI window")
  page.open.scripts.OnClick(page.open)
  check(Panel:IsShown(), "and a second click leaves it open")
  page.classic.scripts.OnClick(page.classic)
  check(not Panel:IsShown() and libs["AceConfigDialog-3.0"].OpenFrames[ns.Core.appName or "AzUI_Color_Picker"],
    "the other button opens the classic window instead")
  libs["AceConfigDialog-3.0"]:Close(ns.Core.appName or "AzUI_Color_Picker")
end

---------------------------------------------------------------------------
-- The keyboard: off until the search box is clicked, then Tab walks the window
---------------------------------------------------------------------------
do
  Panel:Open("bars")
  local search = Panel.searchBox
  check(not Panel.keyboard and not Panel.keyboardHost, "an open window does not take the keyboard")
  search:SetFocus()
  search.scripts.OnTabPressed(search)
  local kind, index = Panel:GetKeyboardFocus()
  check(kind == "rail" and index == 1 and Panel.keyboardHost.keyboard, "Tab from the search box goes to the first page")
  local host = Panel.keyboardHost
  host.scripts.OnKeyDown(host, "W")
  check(Panel:GetKeyboardFocus() == "search" and Panel.searching and search.text == "w",
    "a letter searches, and is not handed to the game as movement")
  check(host.propagate == false, "so the key is kept")
  Panel:ClearSearch()
  Panel:SetKeyboardFocus(2)
  host = Panel.keyboardHost
  host.scripts.OnKeyDown(host, "DOWN")
  kind, index = Panel:GetKeyboardFocus()
  check(kind == "rail" and index == 2 and not host.keyboard and Panel.keyboardHost.keyboard,
    "Down moves to the next page, and only that row listens")
  host = Panel.keyboardHost
  host.scripts.OnKeyDown(host, "F1")
  check(host.propagate == true, "a key the window has no use for goes back to the game")
  local barsAt
  for i, info in ipairs(Panel.pages) do if info.key == "bars" then barsAt = i end end
  Panel:SetKeyboardFocus(1 + barsAt)
  Panel.keyboardHost.scripts.OnKeyDown(Panel.keyboardHost, "ENTER")
  check(Panel.selected == "bars", "Enter opens the page")
  -- into the page's settings
  local p = db.profile
  p.power.mode = "off"
  Panel:Refresh()
  local modeAt
  for i = 1, 60 do
    Panel:MoveKeyboardFocus(1)
    local k, at = Panel:GetKeyboardFocus()
    local control = k == "control" and Panel.page:GetControls()[at]
    if control and control.labelText == "Power Bar" then modeAt = Panel.keyboard break end
  end
  check(modeAt, "Tab reaches the page's settings")
  local control = Panel.page:GetControls()[select(2, Panel:GetKeyboardFocus())]
  check(control.focused and control.focusEdge.shown, "the setting shows where the keyboard is")
  Panel.keyboardHost.scripts.OnKeyDown(Panel.keyboardHost, "RIGHT")
  check(p.power.mode ~= "off", "Right steps a list on")
  check(Panel.keyboard == modeAt and Panel:GetKeyboardFocus() == "control", "and the keyboard stays on it after the redraw")
  Panel.keyboardHost.scripts.OnKeyDown(Panel.keyboardHost, "LEFT")
  check(p.power.mode == "off", "Left steps back")
  -- a toggle flips on Enter
  local toggleAt, toggle
  for i = 1, 60 do
    Panel:MoveKeyboardFocus(1)
    local k, at = Panel:GetKeyboardFocus()
    local c = k == "control" and Panel.page:GetControls()[at]
    if c and c.kind == "toggle" and not c.disabled then toggleAt, toggle = Panel.keyboard, c break end
  end
  if toggle then
    local before = toggle.value
    Panel.keyboardHost.scripts.OnKeyDown(Panel.keyboardHost, "SPACE")
    local after = Panel.page:GetControls()[select(2, Panel:GetKeyboardFocus())]
    check(after.value ~= before, "Space flips a toggle")
    Panel.keyboardHost.scripts.OnKeyDown(Panel.keyboardHost, "SPACE")
  end
  -- Escape, a click, combat and closing all hand the keyboard back
  host = Panel.keyboardHost
  host.scripts.OnKeyDown(host, "ESCAPE")
  check(not Panel.keyboard and not host.keyboard, "Escape hands the keyboard back")
  Panel:SetKeyboardFocus(2)
  host = Panel.keyboardHost
  game.fire("PLAYER_REGEN_DISABLED")
  check(not Panel.keyboard and not host.keyboard, "combat hands the keyboard back")
  game.lockdown = true
  Panel:SetKeyboardFocus(2)
  check(not Panel.keyboardHost, "and it cannot be taken in combat")
  game.lockdown = nil
  Panel:SetKeyboardFocus(2)
  host = Panel.keyboardHost
  Panel:Close()
  check(not Panel.keyboard and not host.keyboard, "closing the window hands it back")
end

print(checks .. " panel checks passed (" .. Kit.ArtStyle .. " art" .. (ns.ArtEdition and (", " .. ns.ArtEdition) or "") .. ")")
