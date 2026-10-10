--[[
  Translations.

  Every text the addon shows is written in English and looked up through L["..."].
  The file for the game client's language fills ns.LocaleStrings; a text it does not
  have shows in English, so a translation can be partial and nothing breaks.

  The English text is the key, so a translation only needs the line it changes:

      T["Health Bar"] = "Lebensleiste"

  Tools/TestLocales.lua checks that every translated key still exists in the code and
  that %d, %s and colour codes survive the translation.
--]]
local _, ns = ...

local locale = GetLocale and GetLocale() or "enUS"
if locale == "enGB" then locale = "enUS" end
if locale == "esMX" then locale = "esES" end -- one Spanish file for both clients

ns.Locale = locale
ns.LocaleStrings = {}

local strings = ns.LocaleStrings
ns.L = setmetatable({}, {
  __index = function(_, key)
    local text = strings[key]
    if text == nil or text == "" then return key end
    return text
  end,
})
