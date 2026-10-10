-- StudioHealth.lua - the Health Bar page as the AzUI Feature Plan draws it.
--
--   LIVE PREVIEW   your bar, your power bar and your pet's bar, painted by the
--                  addon's own painter so they show exactly what the real bars do
--   Colour         a colour wheel and value strip, Hex, R G B and Alpha, recent colours
--   Presets        swatches with names; click to use, drag to reorder, right-click
--                  to rename, overwrite or delete; + Save adds one
--   Effect         a card per effect with a live preview, and the speed
--   Show on        which bars take your colour; Undo steps back; Done closes
--
-- The page's other settings (class colours, fades, colour by health, …) follow below
-- as ordinary rows. One control in Renderer.lua's sense, laid out first on the page.
local _, ns = ...
local Kit = ns.OptionsKit
local Studio = Kit.Studio
local P = ns.P
if not (Studio and Studio.Button and P) then return end

local L = ns.L
local floor, max, min = math.floor, math.max, math.min
local unpack = unpack

local Health = {}
Kit.StudioHealth = Health

local PAD, GAP = 14, 16
local PREVIEW_H = 124
local PREVIEW_H_AZERITE = 140
-- How far the visible stone of AzeriteUI's cases reaches beyond their bars, in layout
-- units, measured off the textures' alpha (hp_cap_case around a 385x40 bar,
-- cast_back around a 112x11 one); multiplied by each bar's scale.
local HEALTH_CASE = { left = 21, right = 21, above = 26, below = 29, w = 385 }
local PET_CASE = { left = 18, right = 15, w = 112 }
local WHEEL = 156
local TILE_W, TILE_H, TILE_LABEL = 56, 34, 14
local CARD_W, CARD_H = 74, 62
local RECENT = 8
local POWER_BLUE = { 0.18, 0.37, 0.66, 1 }

local function Profile() return P.DB.profile end

---------------------------------------------------------------------
-- Undo: every change made on this page, back to when the window opened
---------------------------------------------------------------------
local undo = {}

local function Snapshot()
  local p = Profile()
  return {
    color = P.CopyColour(p.color), effect = p.effect, secondColor = P.CopyColour(p.secondColor),
    preset = P.selectedPreset, petFrames = p.colourPetFrames, power = p.power.mode,
  }
end

-- Call before a change; a drag counts once.
local function Remember()
  undo[#undo + 1] = Snapshot()
  if #undo > 40 then table.remove(undo, 1) end
end

local function Undo()
  local snap = table.remove(undo)
  if not snap then return end
  local p = Profile()
  p.effect, p.secondColor = snap.effect, snap.secondColor
  P.selectedPreset = snap.preset
  P.SetUserColour(snap.color[1], snap.color[2], snap.color[3], snap.color[4], true)
  if p.colourPetFrames ~= snap.petFrames or p.power.mode ~= snap.power then
    p.colourPetFrames, p.power.mode = snap.petFrames, snap.power
    P.RefreshOptionalBars()
  end
  P.ResetPhase()
  P.UpdateAnimator()
  P.RefreshOptions()
end

function Health:OnHide() undo = {} end

---------------------------------------------------------------------
-- Building
---------------------------------------------------------------------
local function Card(parent, radius)
  local frame = CreateFrame("Frame", nil, parent)
  frame.round = Studio.Round(frame, radius or 8)
  return frame
end

local function Portrait(parent, size, unit)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(size, size)
  local bg = holder:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  Studio.Circle(bg)
  bg:SetVertexColor(unpack(Studio.C.raised))
  local face = holder:CreateTexture(nil, "ARTWORK")
  face:SetPoint("TOPLEFT", 3, -3)
  face:SetPoint("BOTTOMRIGHT", -3, 3)
  local mask = holder:CreateMaskTexture()
  mask:SetTexture(Studio.Media("circle-fill"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(face)
  face:AddMaskTexture(mask)
  local ring = holder:CreateTexture(nil, "OVERLAY")
  ring:SetAllPoints()
  Studio.Circle(ring, true)
  ring:SetVertexColor(unpack(Studio.C.bronze))
  holder.face, holder.unit = face, unit
  function holder:Update()
    if UnitExists(self.unit) and SetPortraitTexture then
      SetPortraitTexture(self.face, self.unit)
      self.face:SetTexCoord(0, 1, 0, 1)
      self.face:Show()
    else
      self.face:Hide()
    end
  end
  return holder
end

-- kind: "health", "power" or "pet". In the Azerite look each wears AzeriteUI's own
-- bar texture and case, read from the installed AzeriteUI, in the proportions of
-- its player frame (a 385x40 bar in a 716x188 case, Layouts/Data/PlayerUnitFrame.lua).
local AZERITE_BARS = {
  health = { bar = "hp_cap_bar", case = "hp_cap_case", w = 385, h = 40, caseW = 716, caseH = 188, x = -165, y = -75 },
  pet    = { bar = "cast_bar", case = "cast_back", w = 112, h = 11, caseW = 193, caseH = 93, x = -40, y = -43 },
  power  = { bar = "cast_bar" },
}

local function PreviewBar(parent, height, kind)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetHeight(height)
  local art = Kit.ArtStyle == "azerite" and AZERITE_BARS[kind]
  bar:SetStatusBarTexture(art and Kit.GetMedia(art.bar) or "Interface\\Buttons\\WHITE8X8")
  if art and art.case then
    -- the case is the bar's backdrop, as in AzeriteUI: below the fill, sized from the
    -- bar so it fits at any width
    local caseFrame = CreateFrame("Frame", nil, bar)
    caseFrame:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
    local case = caseFrame:CreateTexture(nil, "ARTWORK")
    case:SetTexture(Kit.GetMedia(art.case))
    bar.case, bar.caseFrame, bar.art = case, caseFrame, art
    bar:HookScript("OnSizeChanged", function(self, w)
      local s = (w or 0) / art.w
      if s <= 0 then return end
      self.case:SetSize(art.caseW * s, art.caseH * s)
      self.case:ClearAllPoints()
      self.case:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", art.x * s, art.y * s)
      self:SetHeight(art.h * s)
    end)
  end
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0.86)
  local back = bar:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0, 0, 0, .45)
  local edge = CreateFrame("Frame", nil, bar)
  edge:SetAllPoints()
  edge:SetFrameLevel(bar:GetFrameLevel() + 3)
  -- a thin dark rim, as a unit frame bar has (the Azerite case is its own rim)
  if not (art and art.case) then
    local rim = Studio.Round(edge, 3, nil, nil, true)
    rim:SetFill(nil)
    rim:SetEdge({ 0, 0, 0 }, .6)
  end
  return bar
end

local function BuildPreview(control)
  local card = Card(control.frame, 8)
  control.preview = card
  local caption = Studio.Caption(card, L["Live preview"])
  caption:SetPoint("TOPLEFT", PAD, -12)

  local you = Portrait(card, 58, "player")
  you:SetPoint("LEFT", PAD + 2, -8)
  card.you = you
  local youLabel = Studio.Label(card, 11, "body", Kit.TextDisabled)
  youLabel:SetPoint("BOTTOMLEFT", you, "TOPRIGHT", 12, -14)
  youLabel:SetText(L["You"])
  card.youLabel = youLabel

  local health = PreviewBar(card, 24, "health")
  health:SetPoint("TOPLEFT", youLabel, "BOTTOMLEFT", 0, -4)
  card.health = health
  local healthText = Studio.Label(health, 12, "bold", Kit.TextHighlight)
  healthText:SetPoint("CENTER")
  healthText:SetText("86%")
  local power = PreviewBar(card, 9, "power")
  power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -5)
  power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -5)
  card.power = power

  local pet = Portrait(card, 36, "pet")
  card.pet = pet
  local petLabel = Studio.Label(card, 11, "body", Kit.TextDisabled)
  petLabel:SetPoint("BOTTOMLEFT", pet, "TOPRIGHT", 10, -10)
  card.petLabel = petLabel
  local petBar = PreviewBar(card, 16, "pet")
  petBar:SetPoint("TOPLEFT", petLabel, "BOTTOMLEFT", 0, -4)
  card.petBar = petBar

  P.AddPreviewTarget(health, "player")
  P.AddPreviewTarget(petBar, "pet")
end

local function Header(parent, text)
  local label = Studio.Label(parent, 14, Kit.ArtStyle == "studio" and "display" or "bold", Kit.TextSelected)
  label:SetText(text)
  return label
end

---------------------------------------------------------------------
-- Colour column
---------------------------------------------------------------------
local setting -- true while this page moves the wheel itself

local function ShowColour(control)
  local c = Profile().color
  setting = true
  control.wheel:SetColorRGB(c[1], c[2], c[3])
  setting = nil
  control.hex:SetValue(P.Hex(c))
  for i, box in ipairs(control.rgb) do box:SetValue(tostring(floor(c[i] * 255 + .5))) end
  control.alpha:SetValue(c[4] or 1)
  control.alphaText:SetText(floor((c[4] or 1) * 100 + .5) .. "%")
end

local function PickColour(r, g, b, a, final)
  P.SetUserColour(r, g, b, a or Profile().color[4], final)
  if final then P.RefreshOptions() end
end

local function BuildColour(control)
  local col = CreateFrame("Frame", nil, control.frame)
  control.colourCol = col
  local header = Header(col, L["Colour"])
  header:SetPoint("TOPLEFT", 0, 0)

  -- the wheel and value strip are drawn by the game: a ColorSelect fills them in
  local wheel = CreateFrame("ColorSelect", nil, col)
  wheel:SetSize(WHEEL + 30, WHEEL)
  wheel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
  local disc = wheel:CreateTexture(nil, "ARTWORK")
  disc:SetSize(WHEEL, WHEEL)
  disc:SetPoint("TOPLEFT")
  wheel:SetColorWheelTexture(disc)
  local thumb = wheel:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(12, 12)
  Studio.Circle(thumb, true)
  wheel:SetColorWheelThumbTexture(thumb)
  local value = wheel:CreateTexture(nil, "ARTWORK")
  value:SetSize(14, WHEEL)
  value:SetPoint("TOPLEFT", disc, "TOPRIGHT", 16, 0)
  wheel:SetColorValueTexture(value)
  local valueThumb = wheel:CreateTexture(nil, "OVERLAY")
  valueThumb:SetSize(22, 6)
  valueThumb:SetTexture(Studio.Media("round3-fill"))
  wheel:SetColorValueThumbTexture(valueThumb)
  wheel:SetScript("OnColorSelect", function(_, r, g, b)
    if setting then return end
    PickColour(r, g, b, nil, false)
    control.hex:SetValue(P.Hex({ r, g, b }))
    for i, v in ipairs({ r, g, b }) do control.rgb[i]:SetValue(tostring(floor(v * 255 + .5))) end
  end)
  wheel:HookScript("OnMouseDown", function() Remember() end)
  wheel:HookScript("OnMouseUp", function()
    P.PushRecent(Profile().color)
    P.RefreshOptions()
  end)
  control.wheel = wheel

  -- Hex, R G B, Alpha
  local fields = CreateFrame("Frame", nil, col)
  fields:SetSize(100, WHEEL)
  fields:SetPoint("TOPLEFT", value, "TOPRIGHT", 18, 0)
  local hexLabel = Studio.Label(fields, 11, "body", Kit.TextDisabled)
  hexLabel:SetPoint("TOPLEFT", 0, 0)
  hexLabel:SetText(L["Hex"])
  control.hex = Studio.Edit(fields, 100, 24, function(_, text)
    local r, g, b = P.ParseColour(text)
    if r then Remember(); PickColour(r, g, b, nil, true) else ShowColour(control) end
  end)
  control.hex:SetPoint("TOPLEFT", hexLabel, "BOTTOMLEFT", 0, -4)
  local rgbLabel = Studio.Label(fields, 11, "body", Kit.TextDisabled)
  rgbLabel:SetPoint("TOPLEFT", control.hex, "BOTTOMLEFT", 0, -12)
  rgbLabel:SetText(L["R · G · B"])
  control.rgb = {}
  for i = 1, 3 do
    local box = Studio.Edit(fields, 31, 24, function(_, text)
      local v = tonumber(text)
      if not v then ShowColour(control); return end
      local c = P.CopyColour(Profile().color)
      c[i] = min(255, max(0, v)) / 255
      Remember()
      PickColour(c[1], c[2], c[3], nil, true)
    end, true)
    box:SetPoint("TOPLEFT", rgbLabel, "BOTTOMLEFT", (i - 1) * 34.5, -4)
    control.rgb[i] = box
  end
  local alphaLabel = Studio.Label(fields, 11, "body", Kit.TextDisabled)
  alphaLabel:SetPoint("TOPLEFT", control.rgb[1], "BOTTOMLEFT", 0, -12)
  alphaLabel:SetText(L["Alpha"])
  control.alpha = Studio.Slider(fields, 100, 0, 1, 0.01, function(v, final)
    local c = Profile().color
    PickColour(c[1], c[2], c[3], v, final)
    control.alphaText:SetText(floor(v * 100 + .5) .. "%")
  end)
  control.alpha.onStart = Remember
  control.alpha:SetPoint("TOPLEFT", alphaLabel, "BOTTOMLEFT", 0, -8)
  control.alphaText = Studio.Label(fields, 11, "body", Kit.TextNormal)
  control.alphaText:SetPoint("TOPLEFT", control.alpha, "BOTTOMLEFT", 0, -6)

  -- recent colours
  local recentLabel = Studio.Caption(col, L["Recent"])
  recentLabel:SetPoint("TOPLEFT", wheel, "BOTTOMLEFT", 0, -16)
  control.recent = {}
  for i = 1, RECENT do
    local swatch = Studio.Swatch(col, 22, 22, 3)
    swatch:SetPoint("TOPLEFT", recentLabel, "BOTTOMLEFT", (i - 1) * 28, -8)
    swatch:SetScript("OnClick", function(self)
      if not self.colour then return end
      Remember()
      PickColour(self.colour[1], self.colour[2], self.colour[3], self.colour[4], true)
    end)
    Studio.Tooltip(swatch, function(self) return self.colour and P.Hex(self.colour) end, L["Click to use this colour again."])
    control.recent[i] = swatch
  end
  control.colourHeight = 14 + 12 + WHEEL + 16 + 12 + 8 + 22
end

---------------------------------------------------------------------
-- Presets column
---------------------------------------------------------------------
StaticPopupDialogs.AZUI_RENAME_PRESET = {
  text = L["New name for %s:"],
  button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel",
  hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  OnShow = function(self, data)
    local box = self.GetEditBox and self:GetEditBox() or self.editBox
    if box then box:SetText(data or ""); box:HighlightText() end
  end,
  OnAccept = function(self, data)
    local box = self.GetEditBox and self:GetEditBox() or self.editBox
    P.selectedPreset = data
    P.RenamePreset(box and box:GetText())
  end,
  EditBoxOnEnterPressed = function(self)
    local dialog = self:GetParent()
    P.selectedPreset = dialog.data
    P.RenamePreset(self:GetText())
    dialog:Hide()
  end,
}

local function PresetMenu(tile)
  local name = tile.preset
  local function Delete()
    Kit.Confirm(L["Delete the preset"] .. " " .. name .. "?", function()
      P.selectedPreset = name
      P.DeletePreset()
    end)
  end
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(tile, function(_, root)
      root:CreateTitle(name)
      root:CreateButton(L["Rename…"], function() StaticPopup_Show("AZUI_RENAME_PRESET", name, nil, name) end)
      root:CreateButton(L["Save current colour here"], function() P.OverwritePreset(name) end)
      root:CreateButton(L["Delete"], Delete)
    end)
  else
    Delete()
  end
end

local function PresetTile(control, index)
  local tile = Studio.Swatch(control.presetCol, TILE_W, TILE_H, 4)
  tile.label = Studio.Label(control.presetCol, 10, "body", Kit.TextNormal)
  tile.label:SetPoint("TOP", tile, "BOTTOM", 0, -3)
  tile.label:SetWidth(TILE_W + 6)
  tile.label:SetJustifyH("CENTER")
  tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  tile:RegisterForDrag("LeftButton")
  tile:SetScript("OnClick", function(self, button)
    if button == "RightButton" then PresetMenu(self); return end
    Remember()
    P.LoadPreset(self.preset)
  end)
  -- drag a swatch onto another to put it there
  tile:SetScript("OnDragStart", function(self) control.dragging = self.preset; self:SetAlpha(.4) end)
  tile:SetScript("OnDragStop", function(self)
    self:SetAlpha(1)
    local name = control.dragging
    control.dragging = nil
    for i, other in ipairs(control.tiles) do
      if other:IsShown() and other ~= self and other:IsMouseOver() then P.MovePreset(name, i); return end
    end
  end)
  Studio.Tooltip(tile, function(self) return self.preset end,
    L["Click to use. Drag to move. Right-click to rename, overwrite or delete."])
  control.tiles[index] = tile
  return tile
end

local function BuildPresets(control)
  local col = CreateFrame("Frame", nil, control.frame)
  control.presetCol = col
  control.presetHeader = Header(col, L["Presets"])
  control.presetHeader:SetPoint("TOPLEFT")
  control.tiles = {}

  -- + Save: a dashed tile
  local add = CreateFrame("Button", nil, col)
  add:SetSize(TILE_W, TILE_H)
  add.dashes = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local dash = add:CreateTexture(nil, "ARTWORK")
    local horizontal = side == "TOP" or side == "BOTTOM"
    dash:SetTexture(Studio.Media(horizontal and "dash-h" or "dash-v"), horizontal and "REPEAT" or nil, horizontal and nil or "REPEAT")
    if horizontal then
      dash:SetHeight(2); dash:SetPoint(side .. "LEFT", 2, 0); dash:SetPoint(side .. "RIGHT", -2, 0)
      if dash.SetHorizTile then dash:SetHorizTile(true) end
    else
      dash:SetWidth(2); dash:SetPoint("TOP" .. side, 0, -2); dash:SetPoint("BOTTOM" .. side, 0, 2)
      if dash.SetVertTile then dash:SetVertTile(true) end
    end
    add.dashes[#add.dashes + 1] = dash
  end
  add.text = Studio.Label(add, 12, "body", Kit.TextNormal)
  add.text:SetPoint("CENTER")
  add.text:SetText(L["+ Save"])
  add:SetScript("OnClick", function() PlaySound(852); StaticPopup_Show("AZUI_NAME_PRESET") end)
  add:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
  add:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(Kit.TextNormal)) end)
  Studio.Tooltip(add, L["Save as Preset"], L["Save the current colour as a new preset."])
  control.addTile = add
end

local function LayoutPresets(control, width)
  local names = P.SortedPresetNames()
  local presets = Profile().presets
  local columns = max(1, floor((width + 8) / (TILE_W + 8)))
  local cell_h = TILE_H + TILE_LABEL + 10
  local top = 26
  local count = #names + 1
  for i = 1, count do
    local tile
    if i <= #names then
      tile = control.tiles[i] or PresetTile(control, i)
      local name = names[i]
      tile.preset = name
      tile:SetColour(presets[name])
      tile:SetSelected(name == P.selectedPreset)
      tile.label:SetText(name)
      tile:Show(); tile.label:Show()
    else
      tile = control.addTile
    end
    local column, row = (i - 1) % columns, floor((i - 1) / columns)
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", control.presetCol, "TOPLEFT", column * (TILE_W + 8), -top - row * cell_h)
  end
  for i = #names + 1, #control.tiles do control.tiles[i]:Hide(); control.tiles[i].label:Hide() end
  local rows = floor((count + columns - 1) / columns)
  return top + rows * cell_h
end

---------------------------------------------------------------------
-- Effect cards
---------------------------------------------------------------------
local function EffectCard(control, index, effect)
  local card = CreateFrame("Button", nil, control.presetCol)
  card:SetSize(CARD_W, CARD_H)
  card.round = Studio.Round(card, 6, true)
  card.effect = effect
  local bar = CreateFrame("Frame", nil, card)
  bar:SetSize(CARD_W - 20, 12)
  bar:SetPoint("TOP", 0, -12)
  bar:SetClipsChildren(true)
  bar.fill = bar:CreateTexture(nil, "ARTWORK")
  bar.fill:SetAllPoints()
  bar.fill:SetTexture(Kit.ArtStyle == "azerite" and Kit.GetMedia("cast_bar") or "Interface\\Buttons\\WHITE8X8")
  -- Sweep's band, in miniature
  bar.left = bar:CreateTexture(nil, "OVERLAY")
  bar.right = bar:CreateTexture(nil, "OVERLAY")
  for _, half in ipairs({ bar.left, bar.right }) do
    half:SetTexture("Interface\\Buttons\\WHITE8X8")
    half:SetBlendMode("ADD")
    half:SetHeight(12)
    half:Hide()
  end
  card.bar = bar
  card.text = Studio.Label(card, 11, "body", Kit.TextNormal)
  card.text:SetPoint("BOTTOM", 0, 10)
  card.text:SetText((P.EFFECT_VALUES[effect]:gsub(" %(.-%)", "")))
  card:SetScript("OnClick", function(self)
    local function apply() Remember(); P.SetEffect(self.effect) end
    local question = P.EffectConfirm(self.effect)
    if question and Profile().effect ~= self.effect then Kit.Confirm(question, apply) else apply() end
  end)
  card:SetScript("OnEnter", function(self) self.hovered = true; Health:StyleCard(self) end)
  card:SetScript("OnLeave", function(self) self.hovered = nil; Health:StyleCard(self) end)
  Studio.Tooltip(card, P.EFFECT_VALUES[effect], P.EFFECT_HELP[effect])
  control.cards[index] = card
  return card
end

function Health:StyleCard(card)
  local selected = Profile().effect == card.effect
  card.round:SetFill(Kit.BackdropColor)
  card.round:SetEdge(selected and Kit.TextSelected or card.hovered and Kit.TextHighlight or Kit.BorderIdle,
    (selected or not card.hovered) and 1 or .5)
  card.text:SetTextColor(unpack(selected and Kit.TextSelected or Kit.TextNormal))
end

-- Each card plays its effect on your colour, at the page's own pace.
local previewPhase = 0
local function AnimateCards(control, elapsed)
  local p = Profile()
  previewPhase = previewPhase + elapsed * min(5, max(.1, p.rainbowSpeed or 1)) * 0.3
  for _, card in ipairs(control.cards) do
    local r, g, b, a, at, pr, pg, pb = P.EffectColourAt(previewPhase, card.effect, p.color, p.secondColor)
    local bar = card.bar
    bar.fill:SetVertexColor(r, g, b, 1)
    if at and CreateColor then
      local w, edge = bar:GetWidth(), bar:GetWidth() * .375
      local centre = -edge + at * (w + 2 * edge)
      bar.left:SetWidth(edge); bar.right:SetWidth(edge)
      bar.left:ClearAllPoints(); bar.right:ClearAllPoints()
      bar.left:SetPoint("LEFT", bar, "LEFT", centre - edge, 0)
      bar.right:SetPoint("LEFT", bar, "LEFT", centre, 0)
      local k = min(1, max(.1, p.sweepStrength or .6))
      bar.left:SetGradient("HORIZONTAL", CreateColor(pr, pg, pb, 0), CreateColor(pr, pg, pb, k))
      bar.right:SetGradient("HORIZONTAL", CreateColor(pr, pg, pb, k), CreateColor(pr, pg, pb, 0))
      bar.left:Show(); bar.right:Show()
    else
      bar.left:Hide(); bar.right:Hide()
    end
  end
end

local function BuildEffects(control)
  control.effectHeader = Header(control.presetCol, L["Effect"])
  control.cards = {}
  for i, effect in ipairs(P.EFFECTS) do EffectCard(control, i, effect) end
  control.speedLabel = Studio.Label(control.presetCol, 11, "body", Kit.TextDisabled)
  control.speed = Studio.Slider(control.presetCol, 180, 0.1, 5, 0.1, function(v)
    Profile().rainbowSpeed = v
    control.speedLabel:SetText(string.format(L["Speed %.1f×"], v))
  end)
end

local function LayoutEffects(control, width, top)
  control.effectHeader:ClearAllPoints()
  control.effectHeader:SetPoint("TOPLEFT", control.presetCol, "TOPLEFT", 0, -top)
  local columns = max(1, floor((width + 8) / (CARD_W + 8)))
  for i, card in ipairs(control.cards) do
    local column, row = (i - 1) % columns, floor((i - 1) / columns)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", control.presetCol, "TOPLEFT", column * (CARD_W + 8), -top - 26 - row * (CARD_H + 8))
  end
  local rows = floor((#control.cards + columns - 1) / columns)
  local y = top + 26 + rows * (CARD_H + 8) + 6
  control.speedLabel:ClearAllPoints()
  control.speedLabel:SetPoint("TOPLEFT", control.presetCol, "TOPLEFT", 0, -y - 2)
  control.speed:ClearAllPoints()
  control.speed:SetPoint("LEFT", control.speedLabel, "LEFT", 76, 0)
  control.speed:SetWidth(max(80, width - 84))
  return y + 18
end

---------------------------------------------------------------------
-- Show on, Undo, Done
---------------------------------------------------------------------
local function BuildFooter(control)
  local bar = CreateFrame("Frame", nil, control.frame)
  bar:SetHeight(40)
  control.footer = bar
  local rule = bar:CreateTexture(nil, "ARTWORK")
  rule:SetTexture("Interface\\Buttons\\WHITE8X8")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT")
  rule:SetPoint("TOPRIGHT")
  control.footerRule = rule
  local label = Studio.Label(bar, 12, "body", Kit.TextDisabled)
  label:SetPoint("LEFT", 0, -4)
  label:SetText(L["Show on"])

  local healthChip = Studio.Chip(bar, L["Health bar"], function() end)
  healthChip.locked = true
  healthChip:SetOn(true)
  healthChip:SetPoint("LEFT", label, "RIGHT", 12, 0)
  Studio.Tooltip(healthChip, L["Health bar"], L["Your colour is always on your health bar."])
  local petChip = Studio.Chip(bar, L["Pet frame"], function(self)
    Remember()
    local p = Profile()
    p.colourPetFrames = not p.colourPetFrames
    self:SetOn(p.colourPetFrames)
    P.RefreshOptionalBars()
    P.RefreshOptions()
  end)
  petChip:SetPoint("LEFT", healthChip, "RIGHT", 8, 0)
  Studio.Tooltip(petChip, L["Pet frame"], L["Colour AzeriteUI's and Blizzard's pet frames. Your pet's own colour goes there when you use pet colours."])
  local powerChip = Studio.Chip(bar, L["Power bar"], function(self)
    Remember()
    local power = Profile().power
    power.mode = power.mode ~= "off" and "off" or "health"
    self:SetOn(power.mode ~= "off")
    P.RefreshOptionalBars()
    P.RefreshOptions()
  end)
  powerChip:SetPoint("LEFT", petChip, "RIGHT", 8, 0)
  Studio.Tooltip(powerChip, L["Power bar"], L["Your power bar matches your health bar. Its own colour is on the More Bars page."])
  control.chips = { healthChip, petChip, powerChip }

  local done = Studio.Button(bar, 80, 28, L["Done"], function() if Kit.Panel then Kit.Panel:Close() end end, "gold")
  done:SetPoint("RIGHT", 0, -4)
  local back = Studio.Button(bar, 74, 28, L["Undo"], function() Undo() end)
  back:SetPoint("RIGHT", done, "LEFT", -10, 0)
  Studio.Tooltip(back, L["Undo"], L["Step back through the changes made on this page since the window opened."])
  control.undo, control.done = back, done
end

---------------------------------------------------------------------
-- The control
---------------------------------------------------------------------
function Health:GetControl(parent)
  if self.control then return self.control end
  local control = { kind = "studio", first = true }
  self.control = control
  local frame = CreateFrame("Frame", nil, parent)
  control.frame = frame

  BuildPreview(control)
  BuildColour(control)
  BuildPresets(control)
  BuildEffects(control)
  BuildFooter(control)

  frame:SetScript("OnUpdate", function(_, elapsed) AnimateCards(control, elapsed) end)

  control.Update = function() Health:Update() end
  control.Measure = function(c, width) return Health:Layout(width) end
  control.GetHeight = function(c) return c.height or 600 end
  control.Restyle = function() Health:Restyle() end
  for _, method in ipairs({ "SetLabel", "SetHelp", "SetDisabled", "SetModified", "SetCallback", "SetOnRevert" }) do
    control[method] = function() end
  end
  return control
end

-- AzUI Azerite: AzeriteUI's bars in their cases. Sized so every case's stone stays
-- inside the card, with the names under the portraits, clear of the stone's spikes,
-- and the power bar under the health bar's case.
function Health:LayoutAzeritePreview(card, width)
  local petW = min(130, floor(width * .17))
  local sp = petW / PET_CASE.w
  -- the fixed parts: margins, portraits and gaps
  local fixed = PAD + 58 + 16 + 20 + 36 + 10 + (PET_CASE.left + PET_CASE.right) * sp + petW + PAD
  -- the health bar takes what is left, its case's ends included, up to 320
  local healthW = min(320, floor((width - fixed) / (1 + (HEALTH_CASE.left + HEALTH_CASE.right) / HEALTH_CASE.w)))
  local s = healthW / HEALTH_CASE.w

  card.you:ClearAllPoints()
  card.you:SetPoint("LEFT", card, "LEFT", PAD, -8)
  card.youLabel:ClearAllPoints()
  card.youLabel:SetPoint("TOP", card.you, "BOTTOM", 0, -3)
  card.health:ClearAllPoints()
  card.health:SetPoint("LEFT", card.you, "RIGHT", 16 + HEALTH_CASE.left * s, 0)
  card.health:SetWidth(healthW)
  card.power:ClearAllPoints()
  card.power:SetPoint("TOPLEFT", card.health, "BOTTOMLEFT", 0, -(HEALTH_CASE.below * s + 3))
  card.power:SetPoint("TOPRIGHT", card.health, "BOTTOMRIGHT", 0, -(HEALTH_CASE.below * s + 3))
  card.power:SetHeight(6)

  card.pet:ClearAllPoints()
  card.pet:SetPoint("LEFT", card.health, "RIGHT", HEALTH_CASE.right * s + 20, 0)
  card.petLabel:ClearAllPoints()
  card.petLabel:SetPoint("TOP", card.pet, "BOTTOM", 0, -3)
  card.petBar:ClearAllPoints()
  card.petBar:SetPoint("LEFT", card.pet, "RIGHT", PET_CASE.left * sp + 10, 0)
  card.petBar:SetWidth(petW)
end

function Health:Layout(width)
  local control = self.control
  width = max(560, (width or 600) - 12)
  self.width = width
  local frame = control.frame

  -- preview: you on the left, your pet on the right
  control.preview:ClearAllPoints()
  control.preview:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
  local card = control.preview
  local previewHeight = PREVIEW_H
  if Kit.ArtStyle == "azerite" then
    previewHeight = PREVIEW_H_AZERITE
    self:LayoutAzeritePreview(card, width)
  else
    local petWidth = max(140, floor(width * .26))
    -- portrait and its gap on the left, the pet's portrait and bar on the right
    card.health:SetWidth(max(120, width - (PAD + 2 + 58 + 12) - (28 + 36 + 10) - petWidth - PAD))
    card.pet:ClearAllPoints()
    card.pet:SetPoint("LEFT", card.health, "RIGHT", 28, 4)
    card.petBar:SetWidth(petWidth)
  end
  control.preview:SetSize(width, previewHeight)

  -- two columns
  local colWidth = floor((width - GAP) / 2)
  local top = previewHeight + 22
  control.colourCol:ClearAllPoints()
  control.colourCol:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -top)
  control.colourCol:SetSize(colWidth, control.colourHeight)
  control.presetCol:ClearAllPoints()
  control.presetCol:SetPoint("TOPLEFT", frame, "TOPLEFT", colWidth + GAP, -top)
  local presetsHeight = LayoutPresets(control, colWidth)
  local rightHeight = LayoutEffects(control, colWidth, presetsHeight + 10)
  control.presetCol:SetSize(colWidth, rightHeight)

  local columns = max(control.colourHeight, rightHeight)
  control.footer:ClearAllPoints()
  control.footer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top - columns - 18)
  control.footer:SetWidth(width)

  control.height = top + columns + 18 + 40 + 18
  frame:SetHeight(control.height)
  return control.height
end

function Health:Update()
  local control = self.control
  if not control or not P.DB then return end
  local p = Profile()
  if not (Kit.Controls.IsColorOpen and Kit.Controls.IsColorOpen()) then ShowColour(control) end

  local recent = p.recentColours
  for i, swatch in ipairs(control.recent) do
    swatch:SetColour(recent[i])
    swatch:SetShown(recent[i] ~= nil)
  end

  control.speed:SetValue(p.rainbowSpeed or 1)
  control.speedLabel:SetText(string.format(L["Speed %.1f×"], p.rainbowSpeed or 1))

  local card = control.preview
  card.you:Update()
  card.pet:Update()
  local pet = P.currentPet
  card.petLabel:SetText(L["Pet"] .. (pet and pet.name and (" · " .. pet.name) or ""))
  if p.colourPetFrames then
    P.AddPreviewTarget(card.petBar, "pet")
  else
    P.RemovePreviewTarget(card.petBar)
    card.petBar:SetStatusBarColor(.45, .5, .55, 1)
  end
  if p.power.mode ~= "off" then
    P.AddPreviewTarget(card.power, "power")
  else
    P.RemovePreviewTarget(card.power)
    card.power:SetStatusBarColor(unpack(POWER_BLUE))
  end
  P.Repaint()

  control.chips[2]:SetOn(p.colourPetFrames)
  control.chips[3]:SetOn(p.power.mode ~= "off")
  control.undo:SetDisabled(#undo == 0)
  self:Restyle()
end

function Health:Restyle()
  local control = self.control
  if not control then return end
  local C = Studio.C
  control.preview.round:SetFill(Kit.BackdropColor)
  control.preview.round:SetEdge(C.line)
  for _, c in ipairs(control.cards) do self:StyleCard(c) end
  control.footerRule:SetVertexColor(C.line[1], C.line[2], C.line[3], 1)
  control.hex:Restyle()
  for _, box in ipairs(control.rgb) do box:Restyle() end
  control.alpha:Restyle()
  control.speed:Restyle()
  for _, chip in ipairs(control.chips) do chip:Restyle() end
  control.undo:Restyle()
  control.done:Restyle()
  for _, dash in ipairs(control.addTile.dashes) do dash:SetVertexColor(unpack(C.faint)) end
end
