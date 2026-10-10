local Addon, ns = ...
ns.L = setmetatable({}, { __index = function(_, key) return key end })
ns.BackdropTemplate = "BackdropTemplate"
ns.Colors = { normal = { .86, .72, .42 }, offwhite = { .84, .84, .80 }, highlight = { 1, 1, 1 }, class = {} }
for class, color in pairs(RAID_CLASS_COLORS) do
  ns.Colors.class[class] = { color.r, color.g, color.b }
end

-- Reference installed AzeriteUI art; no restricted media is copied or bundled.
local artAddon = "AzeriteUI5_JuNNeZ_Edition"
ns.HasAzeriteArt = C_AddOns.IsAddOnLoaded(artAddon)
local plain = "Interface\\ChatFrame\\ChatFrameBackground"
local fonts = {}
-- Studio.lua points some names at its own art; looked up first.
ns.MediaOverride = {}
ns.API = {
  GetMedia = function(name)
    if ns.MediaOverride[name] then return ns.MediaOverride[name] end
    if name == "plain" then return plain end
    if ns.HasAzeriteArt then return "Interface\\AddOns\\" .. artAddon .. "\\Assets\\" .. name .. ".tga" end
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
