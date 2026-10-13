-- Run from the addon directory: lua Tools/TestLocales.lua (Lua 5.1).
-- Checks every translation in Locales/: each key must still be a text the code shows
-- (a key that is not is a typo, or a text that changed, and would never show), and
-- each translation must keep the key's %d, %s and %.1f, its colour codes and the
-- share string prefix, and each file must carry the packager's markers, so a release
-- takes CurseForge's translations. Missing translations are listed, not failed: they
-- show in English.
local Keys = dofile("Tools/LocaleKeys.lua")

local checks, failures = 0, {}
local function check(value, message)
  checks = checks + 1
  if not value then failures[#failures + 1] = message end
end

local known = {}
for _, key in ipairs(Keys.Keys()) do known[key] = true end

-- The pieces a translation has to carry over unchanged, as a sorted list.
local function Pieces(text)
  local pieces = {}
  for spec in text:gmatch("%%[%-%d%.]*[dsfx]") do pieces[#pieces + 1] = spec end
  for code in text:gmatch("|c%x%x%x%x%x%x%x%x") do pieces[#pieces + 1] = code end
  for _ in text:gmatch("|r") do pieces[#pieces + 1] = "|r" end
  for _ in text:gmatch("!AZUI1!") do pieces[#pieces + 1] = "!AZUI1!" end
  table.sort(pieces)
  return table.concat(pieces, " ")
end

local LOCALES = { "deDE", "frFR", "esES", "ptBR", "itIT", "ruRU", "koKR", "zhCN", "zhTW" }
local total = 0
for _, key in pairs(known) do total = total + 1 end

local function CheckLocale(locale)
  local file = "Locales/" .. locale .. ".lua"
  local chunk = assert(loadfile(file))
  local ns = { Locale = locale, LocaleStrings = {} }
  -- every T["..."] line, in order, so a key written twice is caught too
  local seen = {}
  local source = assert(io.open(file)):read("*a")
  for literal in source:gmatch('\nT%[(".-")%] = ') do
    local key = assert(loadstring("return " .. literal))()
    check(not seen[key], locale .. ": written twice: " .. key)
    seen[key] = true
  end
  -- the packager puts CurseForge's translations in place of the copy kept here
  local marker = '--@localization(locale="' .. locale .. '", format="lua_additive_table", table-name="T"'
  check(source:find(marker, 1, true), locale .. ": no --@localization@ marker for this language")
  local open, close = source:find("--@do-not-package@", 1, true), source:find("--@end-do-not-package@", 1, true)
  check(open and close and open < close and select(2, source:gsub("\nT%[", "")) > 0
    and not source:sub(1, open):find("\nT%["), locale .. ": the translations must sit between the do-not-package markers")
  chunk("AzUI_Color_Picker", ns)
  local count = 0
  for key, text in pairs(ns.LocaleStrings) do
    count = count + 1
    check(known[key], locale .. ": not a text the addon shows: " .. key)
    check(type(text) == "string" and text ~= "", locale .. ": empty translation: " .. key)
    check(Pieces(text) == Pieces(key), locale .. ": %-codes, colour codes or !AZUI1! differ: " .. key)
  end
  -- the file must do nothing for another client
  local other = { Locale = "enUS", LocaleStrings = {} }
  chunk("AzUI_Color_Picker", other)
  check(next(other.LocaleStrings) == nil, locale .. ": fills strings for another language")
  local missing = {}
  for key in pairs(known) do if not ns.LocaleStrings[key] then missing[#missing + 1] = key end end
  table.sort(missing)
  print(string.format("%s: %d of %d translated", locale, count, total))
  for _, key in ipairs(missing) do print("  missing: " .. key) end
end
for _, locale in ipairs(LOCALES) do
  local exists = io.open("Locales/" .. locale .. ".lua")
  check(exists, locale .. ": no file")
  if exists then exists:close(); CheckLocale(locale) end
end

-- The lookup: a translation where there is one, English where there is not.
local ns = {}
local chunk = assert(loadfile("Locales/Locale.lua"))
setfenv(chunk, setmetatable({ GetLocale = function() return "esMX" end }, { __index = _G }))
chunk("AzUI_Color_Picker", ns)
check(ns.Locale == "esES", "the Mexican Spanish client uses the Spanish file")
ns.LocaleStrings["Health Bar"] = "Barra de salud"
check(ns.L["Health Bar"] == "Barra de salud" and ns.L["No such text"] == "No such text", "L falls back to English")

-- The whole addon in each language: it loads, the window opens on every page, the
-- slash commands still take the English effect names, and the texts are translated.
local Mock = dofile("Tools/Mock.lua")
for _, locale in ipairs(LOCALES) do
  local ok, err = pcall(function()
    local game = Mock.New({ locale = locale })
    local env, ns = game.env, game.ns
    local strings = {}
    local file = assert(loadfile("Locales/" .. locale .. ".lua"))
    file("AzUI_Color_Picker", { Locale = locale, LocaleStrings = strings })
    check(ns.L["Health Bar"] == strings["Health Bar"], locale .. ": the addon reads its translation")
    env.SlashCmdList.AZCOLORPICKER("")
    local Panel = ns.OptionsKit.Panel
    check(Panel:IsShown(), locale .. ": the window opens")
    for _, page in ipairs(Panel.pages) do Panel:SelectPage(page.key) end
    Panel:SelectPage("profiles")
    check(Panel.pageTitle.text == strings["Profiles"], locale .. ": page titles are translated")
    env.SlashCmdList.AZCOLORPICKER("effect pulse")
    check(game.db.profile.effect == "pulse", locale .. ": /ahui effect takes the English name")
    env.SlashCmdList.AZCOLORPICKER("effect " .. strings["Breathe"]:lower())
    -- string.lower only lowers A-Z, so a label with other letters is matched as typed
    check(game.db.profile.effect == "breathe", locale .. ": and the translated one")
  end)
  check(ok, locale .. ": the addon runs: " .. tostring(err))
end

if #failures > 0 then
  for _, message in ipairs(failures) do print("FAILED: " .. message) end
  error(#failures .. " locale checks failed")
end
print(checks .. " locale checks passed")
