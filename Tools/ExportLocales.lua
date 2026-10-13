-- Run from the addon directory: lua Tools/ExportLocales.lua (Lua 5.1).
-- Writes the files CurseForge's localization import takes, one per language, to
-- Tools/CurseForge/: enUS.lua with every text the addon shows (the phrases translators
-- see), and <locale>.lua with the translations in Locales/. Import each on the
-- project's Localization page as a "Lua Additive Table" with the table name T; the
-- packager fills the locale files from there at release time (see wiki/Translating.md).
local Keys = dofile("Tools/LocaleKeys.lua")

local LOCALES = { "deDE", "frFR", "esES", "ptBR", "itIT", "ruRU", "koKR", "zhCN", "zhTW" }
local OUT = "Tools/CurseForge"

local windows = package.config:sub(1, 1) == "\\"
os.execute(windows and ('if not exist "' .. OUT:gsub("/", "\\") .. '" mkdir "' .. OUT:gsub("/", "\\") .. '"')
  or ("mkdir -p " .. OUT))

local function Quote(text) return (string.format("%q", text):gsub("\\\n", "\\n")) end

local function Write(locale, lines)
  local path = OUT .. "/" .. locale .. ".lua"
  local file = assert(io.open(path, "wb"))
  file:write(table.concat(lines, "\n"), "\n")
  file:close()
  print(string.format("%-28s %d phrases", path, #lines))
end

local keys = Keys.Keys()
local english = {}
for i, key in ipairs(keys) do english[i] = "T[" .. Quote(key) .. "] = " .. Quote(key) end
Write("enUS", english)

for _, locale in ipairs(LOCALES) do
  local ns = { Locale = locale, LocaleStrings = {} }
  assert(loadfile("Locales/" .. locale .. ".lua"))("AzUI_Color_Picker", ns)
  local lines = {}
  for _, key in ipairs(keys) do
    local text = ns.LocaleStrings[key]
    if text then lines[#lines + 1] = "T[" .. Quote(key) .. "] = " .. Quote(text) end
  end
  Write(locale, lines)
end
