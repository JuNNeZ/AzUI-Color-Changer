-- Studio.lua - the AzUI Studio look, from the AzUI Feature Plan's mock-ups.
--
-- A flat, dark interface with rounded surfaces, a bronze window edge and gold for
-- what is selected, set in Marcellus and Source Sans 3 (both under the SIL Open Font
-- License, in Media\Fonts). The shapes are this addon's own art, drawn by
-- Tools\MakeStudioArt.py into Media\Studio: white on transparent, tinted here, and
-- sliced with SetTextureSliceMargins so their corners keep their shape at any size.
--
-- Studio is a theme like Azerite, Dark and Light. Choosing it also swaps the kit's art,
-- which is why changing to or from it asks for a /reload.
local _, ns = ...
local Kit = ns.OptionsKit
local L = ns.L

local Studio = {}
Kit.Studio = Studio

local MEDIA = "Interface\\AddOns\\AzUI_Color_Picker\\Media\\"
function Studio.Media(name) return MEDIA .. "Studio\\" .. name .. ".tga" end

Studio.FONT_BODY    = MEDIA .. "Fonts\\SourceSans3-Regular.ttf"
Studio.FONT_BOLD    = MEDIA .. "Fonts\\SourceSans3-Semibold.ttf"
Studio.FONT_DISPLAY = MEDIA .. "Fonts\\Marcellus-Regular.ttf"

-- The mock-ups' palette.
local function hex(h, a)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end
Studio.C = {
  window  = hex("15141B"), header = hex("1F1D27"), rail = hex("1A1921"),
  surface = hex("1D1C24"), raised = hex("2B2733"), inset = hex("0F0E14"),
  line    = hex("2E2B36"), line2 = hex("3A3645"),
  gold    = hex("FFD100"), goldDim = hex("5A4513"), bronze = hex("6E5B2A"),
  text    = hex("E8E2D0"), text2 = hex("D8D2C2"), muted = hex("9C95A8"), faint = hex("6B6577"),
}
local C = Studio.C

Kit.AddTheme("studio", {
  order = 0,
  accent = { C.gold[1], C.gold[2], C.gold[3] },
  text = { C.text[1], C.text[2], C.text[3] },
  bright = { 1, 1, 1 },
  muted = { C.muted[1], C.muted[2], C.muted[3] },
  border = { C.line2[1], C.line2[2], C.line2[3], 1 },
  window = { C.window[1], C.window[2], C.window[3], .98 },
  backdrop = { C.surface[1], C.surface[2], C.surface[3], 1 },
  inset = { C.inset[1], C.inset[2], C.inset[3], 1 },
  track = { C.line2[1], C.line2[2], C.line2[3], 1 },
}, L["AzUI Studio"])

---------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------
local fonts = {}
-- kind: "body", "bold" or "display"
function Studio.Font(size, kind)
  kind = kind or "body"
  local key = kind .. size
  if fonts[key] then return fonts[key] end
  local font = CreateFont("AzUIStudioFont" .. key)
  local file = kind == "display" and Studio.FONT_DISPLAY or kind == "bold" and Studio.FONT_BOLD or Studio.FONT_BODY
  -- falls back to the game's font if the file cannot be read
  if not font:SetFont(file, size, "") then font:SetFont(GameFontNormal:GetFont(), size, "") end
  font:SetShadowOffset(0, -1)
  font:SetShadowColor(0, 0, 0, .6)
  fonts[key] = font
  return font
end

---------------------------------------------------------------------
-- Rounded surfaces
---------------------------------------------------------------------
local RADII = { 3, 4, 6, 8, 9, 10, 12 }
local function Radius(r)
  local best = RADII[1]
  for _, candidate in ipairs(RADII) do if candidate <= r then best = candidate end end
  return best
end

local function Sliced(texture, file, margin)
  texture:SetTexture(file)
  if texture.SetTextureSliceMargins then
    texture:SetTextureSliceMargins(margin, margin, margin, margin)
    if texture.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
      texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
  end
end

-- The Azerite look draws the same surfaces with AzeriteUI's own border art, read
-- from the installed AzeriteUI (never copied): the tooltip border on cards and
-- buttons, the aura border on small parts. A backdrop frame sits just below `frame`,
-- as Kit.CreateBackdrop does, so it never covers what `frame` draws.
local function AzeriteRound(frame, radius)
  local holder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  holder:SetAllPoints(frame)
  holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
  local small = radius <= 4
  holder:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = Kit.GetMedia(small and "border-aura" or "border-tooltip"),
    -- thin on small parts (number boxes), so the border leaves room for the text
    edgeSize = small and 8 or (radius >= 8 and 16 or 12),
    insets = small and { left = 2, right = 2, top = 2, bottom = 2 } or { left = 3, right = 3, top = 3, bottom = 3 },
  })
  local round = { holder = holder }
  function round:SetFill(c, a)
    if not c then holder:SetBackdropColor(0, 0, 0, 0); return end
    holder:SetBackdropColor(c[1], c[2], c[3], a or c[4] or 1)
  end
  function round:SetEdge(c, a)
    if not c then holder:SetBackdropBorderColor(0, 0, 0, 0); return end
    -- the sculpted border is grey by design: tint it gently, never fully
    holder:SetBackdropBorderColor(.55 + c[1] * .45, .55 + c[2] * .45, .55 + c[3] * .45, a or c[4] or 1)
  end
  function round:SetShown(shown) holder:SetShown(shown) end
  return round
end

-- A rounded fill and edge on `frame`, filling it. Returns an object with SetFill,
-- SetEdge and SetShown; either colour can be nil to hide that part.
-- `exact` keeps Studio's own shape in every look (switches, swatches, knobs).
function Studio.Round(frame, radius, thick, layer, exact)
  if Kit.ArtStyle == "azerite" and not exact and (radius or 6) >= 4 then
    return AzeriteRound(frame, radius or 6)
  end
  local r = Radius(radius or 6)
  local margin = r + 2
  local fill = frame:CreateTexture(nil, layer or "BACKGROUND", nil, -6)
  Sliced(fill, Studio.Media("round" .. r .. "-fill"), margin)
  fill:SetAllPoints()
  local edge = frame:CreateTexture(nil, layer or "BACKGROUND", nil, -5)
  Sliced(edge, Studio.Media("round" .. r .. (thick and "-edge2" or "-edge")), margin)
  edge:SetAllPoints()
  local round = { fill = fill, edge = edge }
  function round:SetFill(c, a)
    if not c then self.fill:Hide(); return end
    self.fill:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
    self.fill:Show()
  end
  function round:SetEdge(c, a)
    if not c then self.edge:Hide(); return end
    self.edge:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
    self.edge:Show()
  end
  function round:SetShown(shown) self.fill:SetShown(shown); self.edge:SetShown(shown) end
  return round
end

-- A soft shadow around `frame`, on a frame of its own just below it.
function Studio.Shadow(frame, spread)
  spread = spread or 18
  local holder = CreateFrame("Frame", nil, frame)
  holder:SetPoint("TOPLEFT", -spread, spread)
  holder:SetPoint("BOTTOMRIGHT", spread, -spread)
  holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
  local shadow = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
  Sliced(shadow, Studio.Media("shadow"), 40)
  shadow:SetAllPoints()
  shadow:SetVertexColor(0, 0, 0, .85)
  return shadow
end

function Studio.Glyph(texture, name)
  texture:SetTexture(Studio.Media("glyph-" .. name))
  texture:SetTexCoord(0, 1, 0, 1)
end

function Studio.Circle(texture, ring)
  texture:SetTexture(Studio.Media(ring and "circle-ring" or "circle-fill"))
  texture:SetTexCoord(0, 1, 0, 1)
end

-- A frame that answers SetBackdropColor and SetBackdropBorderColor like a backdrop
-- does, drawn with rounded surfaces. Kit.CreateBackdrop hands these out in Studio.
local function RoundBackdrop(parent, radius, inset)
  inset = inset or 0
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", -inset, inset)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset, -inset)
  local level = parent:GetFrameLevel()
  frame:SetFrameLevel(level > 0 and level - 1 or 0)
  local round = Studio.Round(frame, radius)
  frame.round = round
  frame.SetBackdrop = function() end
  frame.SetBackdropColor = function(_, r, g, b, a) round:SetFill({ r, g, b, a or 1 }) end
  frame.SetBackdropBorderColor = function(_, r, g, b, a) round:SetEdge({ r, g, b, a or 1 }) end
  round:SetFill(C.surface)
  round:SetEdge(C.line2)
  return frame
end

---------------------------------------------------------------------
-- Switching the kit to Studio art
---------------------------------------------------------------------
local GLYPHS = {
  check = "check", chevron = "chevron", cross = "cross", search = "search",
  revert = "undo", grip = "grip", dash = "plus",
}

function Studio.UseArt()
  Kit.ArtStyle = "studio"
  local flat = Studio.Media("round4-fill")

  -- Knobs are plain circles that fit inside their track, not sculpted points.
  Kit.DrawSize = function(body, which)
    if which == "point_diamond" then return body * 0.62 end
    return body
  end
  Kit.SetGlyph = function(texture, name)
    if name == "gem" then Studio.Circle(texture) return end
    Studio.Glyph(texture, GLYPHS[name] or "check")
  end
  Kit.GetFont = function(size, outline) return Studio.Font(size, outline and "bold" or "body") end

  -- Toggle and slider tracks: a pill. A circle sliced down the middle keeps
  -- round ends at any width, with the cap exactly half the height.
  ns.MediaOverride.point_diamond = Studio.Media("circle-fill")
  ns.MediaOverride.point_crystal = Studio.Media("circle-fill")
  ns.MediaOverride["bar-small"] = "Interface\\Buttons\\WHITE8X8"
  ns.MediaOverride.cast_back = Studio.Media("circle-fill")
  ns.MediaOverride.cast_bar = Studio.Media("circle-fill")
  for _, spec in ipairs({ Kit.Trough, Kit.Fill }) do
    spec.capSource, spec.bodyHeight = 32, 64
    spec.left, spec.mid, spec.right = { 0, .5, 0, 1 }, { .49, .51, 0, 1 }, { .5, 1, 0, 1 }
  end
  Kit.FillTopRatio, Kit.FillRatio, Kit.FillAlpha, Kit.FillOvershoot = 0.2, 0.6, 1, 0

  -- What still takes a plain backdrop (the dropdown list, the quick palette) gets a
  -- crisp one-pixel edge; everything made through CreateBackdrop is rounded.
  local square = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 } }
  Kit.WindowBackdrop, Kit.ButtonBackdrop, Kit.InsetBackdrop = square, square, square
  Kit.CreateBackdrop = function(parent, backdrop, inset)
    local radius = (backdrop == Kit.InsetBackdrop) and 4 or 4
    local frame = RoundBackdrop(parent, radius, inset)
    frame:SetBackdropColor(unpack(Kit.BackdropColor))
    frame:SetBackdropBorderColor(unpack(Kit.BorderIdle))
    return frame
  end
  Studio.flat = flat
end

-- Which art the kit draws with, decided once, before the first window is built:
-- the Studio theme brings its own; other themes use AzeriteUI's when it is
-- installed, Blizzard's otherwise (Color.lua).
function Kit.PrepareArt(theme)
  if Kit.ArtStyle then return Kit.ArtStyle end
  if theme == "studio" then
    Studio.UseArt()
  else
    Kit.ArtStyle = ns.HasAzeriteArt and "azerite" or "blizzard"
  end
  return Kit.ArtStyle
end

-- The two looks AzUI has: its own (Studio) and AzUI with Azerite.
function Studio.WindowTitle()
  if Kit.ArtStyle == "azerite" then return "|cffFFD100AzUI|r  |cff4488bbAzerite|r" end
  return L["AzUI Studio"]
end

-- The art a theme would draw with, to know whether changing to it needs a /reload.
function Kit.ArtFor(theme)
  if theme == "studio" then return "studio" end
  return ns.HasAzeriteArt and "azerite" or "blizzard"
end
