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
-- `keycap` draws the fill as a key, as AdvancedHotkeyOverlaySystem does: a face
-- lifted off a darker lip under it (and implies `exact`).
Studio.LipShade = .55

function Studio.Round(frame, radius, thick, layer, exact, keycap)
  if Kit.ArtStyle == "azerite" and not (exact or keycap) and (radius or 6) >= 4 then
    return AzeriteRound(frame, radius or 6)
  end
  local r = Radius(radius or 6)
  local margin = r + 2
  local fill = frame:CreateTexture(nil, layer or "BACKGROUND", nil, -6)
  Sliced(fill, Studio.Media("round" .. r .. "-fill"), margin)
  fill:SetAllPoints()
  local face
  if keycap then
    face = frame:CreateTexture(nil, layer or "BACKGROUND", nil, -5)
    Sliced(face, Studio.Media("round" .. r .. "-face"), margin)
    face:SetAllPoints()
  end
  local edge = frame:CreateTexture(nil, layer or "BACKGROUND", nil, -4)
  Sliced(edge, Studio.Media("round" .. r .. (thick and "-edge2" or "-edge")), margin)
  edge:SetAllPoints()
  local round = { fill = fill, face = face, edge = edge }
  function round:SetFill(c, a)
    if not c then
      self.fill:Hide()
      if self.face then self.face:Hide() end
      return
    end
    local alpha = a or c[4] or 1
    if self.face then
      local shade = Studio.LipShade
      self.fill:SetVertexColor(c[1] * shade, c[2] * shade, c[3] * shade, alpha)
      self.face:SetVertexColor(c[1], c[2], c[3], alpha)
      self.face:Show()
    else
      self.fill:SetVertexColor(c[1], c[2], c[3], alpha)
    end
    self.fill:Show()
  end
  function round:SetEdge(c, a)
    if not c then self.edge:Hide(); return end
    self.edge:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
    self.edge:Show()
  end
  function round:SetShown(shown)
    self.fill:SetShown(shown)
    if self.face then self.face:SetShown(shown) end
    self.edge:SetShown(shown)
  end
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

---------------------------------------------------------------------
-- Whole pixels (switches)
---------------------------------------------------------------------
-- Taken from AdvancedHotkeyOverlaySystem's options/Look.lua. The UI scale (often
-- 0.64-0.75) puts an 18-unit switch on 12.6 physical pixels, so an edge drawn at a
-- size in UI units lands between pixels and smears. Switches are sized here in whole
-- physical pixels instead, and drawn in every look, not only Studio's.

-- One physical screen pixel, in `frame`'s units.
function Studio.PixelSize(frame)
  local height = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize())
  local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
  if not (height and height > 0 and scale and scale > 0) then return 1 end
  return 768 / height / scale
end

-- `units` rounded to whole physical pixels (at least one); `even` keeps the count
-- even, so a circle or pill has a centre on a pixel boundary.
function Studio.Snap(frame, units, even)
  local px = Studio.PixelSize(frame)
  local count = units / px
  if even then
    count = math.max(2, math.floor(count / 2 + .5) * 2)
  else
    count = math.max(1, math.floor(count + .5))
  end
  return count * px, px
end

-- A texture that stays clean drawn far below its file's size: mipmapped
-- (TRILINEAR) where the client takes a filter mode.
function Studio.SmoothTexture(texture, file)
  if not pcall(texture.SetTexture, texture, file, "CLAMP", "CLAMP", "TRILINEAR") then
    texture:SetTexture(file)
  end
end

local PLAIN = "Interface\\Buttons\\WHITE8X8"

-- One row of a pill: round caps cut from the circle art, a flat middle.
local function PillLayer(parent, layer, sublevel)
  local left = parent:CreateTexture(nil, layer, nil, sublevel)
  Studio.SmoothTexture(left, Studio.Media("circle-fill"))
  left:SetTexCoord(0, .5, 0, 1)
  local right = parent:CreateTexture(nil, layer, nil, sublevel)
  Studio.SmoothTexture(right, Studio.Media("circle-fill"))
  right:SetTexCoord(.5, 1, 0, 1)
  local mid = parent:CreateTexture(nil, layer, nil, sublevel)
  mid:SetTexture(PLAIN)
  return { left, mid, right }
end

local function PlacePill(parts, anchor, height, inset)
  local left, mid, right = parts[1], parts[2], parts[3]
  local cap = height / 2
  left:ClearAllPoints()
  left:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
  left:SetSize(cap, height)
  right:ClearAllPoints()
  right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -inset, -inset)
  right:SetSize(cap, height)
  -- between the caps, by anchors: a pill narrower than its two caps draws no middle
  mid:ClearAllPoints()
  mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
  mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
end

local function ColorParts(parts, c, a)
  for _, t in ipairs(parts) do
    t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
  end
end

-- A pill on `frame` (filling it) with a one-pixel edge: an outer pill in the edge
-- colour and an inner one, a pixel in, in the fill colour. Flat colours only; a
-- gradient across a few pixels only reads as blur.
--   pill:Layout(height, px)    height and pixel size in `frame`'s units
--   pill:SetColors(fill, edge) edge nil: the fill reaches the outside edge
function Studio.Pill(frame, layer, sublevel)
  layer = layer or "ARTWORK"
  local pill = { frame = frame, outer = PillLayer(frame, layer, sublevel or 0), inner = PillLayer(frame, layer, (sublevel or 0) + 1) }
  function pill:Layout(height, px)
    self.height, self.px = height, px
    PlacePill(self.outer, self.frame, height, 0)
    PlacePill(self.inner, self.frame, math.max(px, height - 2 * px), px)
  end
  function pill:SetColors(fill, edge, alpha)
    ColorParts(self.outer, edge or fill, alpha)
    ColorParts(self.inner, fill, alpha)
  end
  -- Colour only in SetColors: whether a pill shows is this one's (a slider at its
  -- minimum hides its fill, and a restyle must not bring it back).
  function pill:SetShown(shown)
    for _, t in ipairs(self.outer) do t:SetShown(shown) end
    for _, t in ipairs(self.inner) do t:SetShown(shown) end
  end
  return pill
end

-- A round knob with a hard one-pixel lip under it in place of a blurred shadow.
--   knob:Layout(size, px)  knob:SetColor(c)  knob:SetLip(shown)
--   knob.texture is what gets anchored
function Studio.Knob(frame, layer)
  layer = layer or "OVERLAY"
  local knob = {}
  local lip = frame:CreateTexture(nil, layer, nil, 1)
  Studio.SmoothTexture(lip, Studio.Media("circle-fill"))
  lip:SetVertexColor(0, 0, 0, .35)
  local face = frame:CreateTexture(nil, layer, nil, 2)
  Studio.SmoothTexture(face, Studio.Media("circle-fill"))
  lip:SetPoint("TOP", face, "TOP", 0, -1)
  knob.texture, knob.lip = face, lip
  function knob:Layout(size, px)
    self.size = size
    face:SetSize(size, size)
    lip:SetSize(size, size)
    lip:ClearAllPoints()
    lip:SetPoint("TOP", face, "TOP", 0, -px)
  end
  function knob:SetColor(c, a) face:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end
  function knob:SetLip(shown) lip:SetShown(shown and true or false) end
  return knob
end

-- The switch both the settings rows and the Rules page draw: a pill track and a
-- round knob that slides. Off, the track is a sunk inset with a one-pixel edge and
-- the knob rests muted at the left; on, the track fills with the accent and the
-- knob sits bright at the right, a hard pixel of shadow under it.
--   switch:SetOn(on, animate)  switch:Restyle()  switch.hovered, switch.disabled
local SWITCH_W, SWITCH_H, SWITCH_KNOB = 36, 18, 14
local SLIDE_TIME = .12

function Studio.SwitchArt(box, w, h, knobSize)
  w, h, knobSize = w or SWITCH_W, h or SWITCH_H, knobSize or SWITCH_KNOB
  local art = { box = box, baseW = w, baseH = h, baseKnob = knobSize }
  box:SetSize(w, h)

  art.track = Studio.Pill(box, "ARTWORK")

  -- The knob on a frame of its own, so it always draws above the track.
  local knobHost = CreateFrame("Frame", nil, box)
  knobHost:SetAllPoints(box)
  knobHost:SetFrameLevel(box:GetFrameLevel() + 2)
  art.knobHost = knobHost
  local knob = Studio.Knob(knobHost)
  art.knob = knob

  -- Where the knob's left edge sits, off and on, for the current size.
  local function Ends(self)
    local gap = (self.h - self.knobSize) / 2
    return gap, self.w - gap - self.knobSize
  end

  local function PlaceKnob(x)
    knob.texture:ClearAllPoints()
    knob.texture:SetPoint("LEFT", box, "LEFT", x, 0)
  end

  -- Sizes in whole physical pixels for the scale the window is drawn at now; run
  -- again whenever it is restyled, so a scale change is caught too.
  function art:Layout()
    local sw, px = Studio.Snap(box, self.baseW, true)
    local sh = Studio.Snap(box, self.baseH, true)
    local k = Studio.Snap(box, self.baseKnob, true)
    self.w, self.h, self.knobSize, self.px = sw, sh, k, px
    box:SetSize(sw, sh)
    self.track:Layout(sh, px)
    knob:Layout(k, px)
    if not self.sliding then
      local off, on = Ends(self)
      PlaceKnob(self.on and on or off)
    end
  end

  -- The knob slides over a short moment when you click; set from outside, it is
  -- simply there.
  local function Slide(self)
    local off, on = Ends(self)
    local from, to = self.on and off or on, self.on and on or off
    self.sliding = 0
    knobHost:SetScript("OnUpdate", function(_, elapsed)
      self.sliding = self.sliding + (elapsed or 0)
      local t = math.min(1, self.sliding / SLIDE_TIME)
      t = 1 - (1 - t) * (1 - t)
      -- whole pixels on the way too, or the knob blurs while it moves
      local x = from + (to - from) * t
      PlaceKnob(math.floor(x / self.px + .5) * self.px)
      if t >= 1 then
        self.sliding = nil
        knobHost:SetScript("OnUpdate", nil)
      end
    end)
  end

  function art:SetOn(value, animate)
    value = value and true or false
    -- A page redraws right after a click and sets the same value again: that must
    -- not cut the slide short.
    if not animate and self.sliding and value == self.on then
      self:Restyle()
      return
    end
    self.on = value
    if animate and self.w then
      Slide(self)
    else
      self.sliding = nil
      knobHost:SetScript("OnUpdate", nil)
    end
    self:Layout()
    self:Restyle()
  end

  function art:Restyle()
    self:Layout()
    local live = not self.disabled
    if self.on then
      local accent = Kit.TextSelected
      local lift = (self.hovered and live) and 1.08 or 1
      self.track:SetColors({ math.min(1, accent[1] * lift), math.min(1, accent[2] * lift), math.min(1, accent[3] * lift), 1 })
    else
      local edge = (self.hovered and live) and Kit.BorderHover or Kit.BorderIdle
      self.track:SetColors(Kit.InsetColor, edge)
    end
    knob:SetColor(self.on and Kit.TextHighlight or Kit.TextDisabled)
    knob:SetLip(self.on)
    box:SetAlpha(self.disabled and .45 or 1)
  end

  return art
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
