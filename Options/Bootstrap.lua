local Addon, ns = ...
ns.L = ns.L or setmetatable({}, { __index = function(_, key) return key end }) -- Locales/Locale.lua
ns.BackdropTemplate = "BackdropTemplate"
ns.Colors = { normal = { .86, .72, .42 }, offwhite = { .84, .84, .80 }, highlight = { 1, 1, 1 }, class = {} }
for class, color in pairs(RAID_CLASS_COLORS) do
  ns.Colors.class[class] = { color.r, color.g, color.b }
end

-- ABCS Azerite draws with the art of whichever AzeriteUI is installed, read from
-- its own folder; nothing is copied or bundled. Each edition ships a slightly
-- different set, checked against its Assets folder: only JuNNeZ Edition has the
-- options window's own glyphs and close button, and AzeriteUI6 has no tooltip
-- border, so it lends its aura border instead. Whatever an edition lacks comes
-- from Blizzard's art below.
local EDITIONS = {
  { addon = "AzeriteUI5_JuNNeZ_Edition", missing = {} },
  { addon = "AzeriteUI", missing = { ["options-glyphs"] = true, ["options-close"] = true, ["options-close-bright"] = true } },
  { addon = "AzeriteUI6", missing = { ["options-glyphs"] = true, ["options-close"] = true, ["options-close-bright"] = true },
    alias = { ["border-tooltip"] = "border-aura" } },
}
local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
local edition
for _, candidate in ipairs(EDITIONS) do
  if isLoaded and isLoaded(candidate.addon) then edition = candidate; break end
end
ns.ArtEdition = edition and edition.addon
ns.HasAzeriteArt = edition ~= nil

-- Whether the installed AzeriteUI has a piece of art.
function ns.HasAzeriteMedia(name)
  return edition ~= nil and not edition.missing[name]
end

local plain = "Interface\\ChatFrame\\ChatFrameBackground"
-- JuNNeZ Edition's themes (Legacy HUD, Hunter, Mage, Paladin) redraw its art, and
-- ABCS Azerite follows whichever is on: through the theme's own ResolveMedia and,
-- for the live preview, its own StyleHealth, so the casing fits by the theme's rules.
local THEME_MODULES = { "LegacyHUD", "HunterTheme", "MageTheme", "PaladinTheme" }
function ns.ActiveAzeriteTheme()
  if not (edition and edition.addon == "AzeriteUI5_JuNNeZ_Edition") then return end
  local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
  local aui = AceAddon and AceAddon:GetAddon("AzeriteUI", true)
  if not (aui and aui.GetModule) then return end
  for _, key in ipairs(THEME_MODULES) do
    local theme = aui:GetModule(key, true)
    if theme and theme.IsActive then
      local ok, active = pcall(theme.IsActive, theme)
      if ok and active then return key, theme end
    end
  end
end

local fonts = {}
-- Studio.lua points some names at its own art; looked up first.
ns.MediaOverride = {}
ns.API = {
  GetMedia = function(name)
    if ns.MediaOverride[name] then return ns.MediaOverride[name] end
    if name == "plain" then return plain end
    if ns.HasAzeriteMedia(name) then
      local _, theme = ns.ActiveAzeriteTheme()
      if theme and theme.ResolveMedia then
        local ok, themed = pcall(theme.ResolveMedia, theme, name)
        if ok and type(themed) == "string" then return themed end
      end
      name = edition.alias and edition.alias[name] or name
      return "Interface\\AddOns\\" .. edition.addon .. "\\Assets\\" .. name .. ".tga"
    end
    if name:find("border", 1, true) then return "Interface\\Tooltips\\UI-Tooltip-Border" end
    if name == "point_diamond" or name == "point_crystal" then return "Interface\\Buttons\\UI-SliderBar-Button-Horizontal" end
    return plain
  end,
  GetFont = function(size, outline)
    local key = tostring(size) .. tostring(outline)
    if not fonts[key] then
      local font = CreateFont(Addon .. "OptionsFont" .. key)
      local file = GameFontNormal:GetFont()
      font:SetFont(file, size, outline and "OUTLINE" or "")
      fonts[key] = font
    end
    return fonts[key]
  end,
}
