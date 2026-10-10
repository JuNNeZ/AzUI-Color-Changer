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
local mode = arg and arg[1] or "studio"
local game = Mock.New({ art = mode == "art" })
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
check(Kit.ArtStyle == ({ studio = "studio", art = "azerite", plain = "blizzard" })[mode], "the window's art follows the theme")
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
check(#rowsOf("grid") == 1, "class colours become one grid")
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

print(checks .. " panel checks passed (" .. Kit.ArtStyle .. " art)")
