-- StudioWidgets.lua - the small parts the Studio pages are built from: labels,
-- buttons, pill chips, text boxes, a slider, a switch, swatches, a bare dropdown and
-- a colour button. Drawn with Studio's rounded surfaces and coloured from the kit's
-- theme tables, so they follow whatever theme is chosen.
local _, ns = ...
local Kit = ns.OptionsKit
local Studio = Kit.Studio
local Controls = Kit.Controls
if not (Studio and Controls) then return end

local max, min, floor = math.max, math.min, math.floor
local unpack = unpack

local function Tint(region, c, a) region:SetTextColor(c[1], c[2], c[3], a or 1) end

-- A font string. kind: "body", "bold" or "display".
function Studio.Label(parent, size, kind, colour)
  local text = parent:CreateFontString(nil, "OVERLAY")
  if Kit.ArtStyle == "studio" then
    text:SetFontObject(Studio.Font(size, kind))
  else
    text:SetFontObject(Kit.GetFont(size, kind ~= "body"))
  end
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  Tint(text, colour or Kit.TextNormal)
  return text
end

-- An uppercase, letter-spaced section label (LIVE PREVIEW, RECENT, …).
function Studio.Caption(parent, text)
  local caption = Studio.Label(parent, 10, "bold", Kit.TextDisabled)
  caption:SetText(text:upper():gsub("(.)", "%1 "):sub(1, -2))
  return caption
end

function Studio.Tooltip(frame, title, line)
  frame:HookScript("OnEnter", function(self)
    local t = type(title) == "function" and title(self) or title
    if not t then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(t, 1, 1, 1)
    local l = type(line) == "function" and line(self) or line
    if l then GameTooltip:AddLine(l, Kit.TextNormal[1], Kit.TextNormal[2], Kit.TextNormal[3], true) end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------
-- Buttons and chips
---------------------------------------------------------------------
-- style "gold" is the window's main action (Done, + Add rule)
function Studio.Button(parent, width, height, label, onClick, style)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, height)
  button.round = Studio.Round(button, 4)
  button.text = Studio.Label(button, 13, "bold")
  button.text:SetPoint("CENTER")
  button.text:SetText(label)
  button.style = style
  -- An icon before the label, the two centred together; with no label, the icon alone.
  button.icon = button:CreateTexture(nil, "OVERLAY")
  button.icon:SetSize(14, 14)
  button.icon:Hide()
  function button:SetIcon(glyph)
    self.glyph = glyph
    self.icon:ClearAllPoints()
    self.text:ClearAllPoints()
    if not glyph then
      self.icon:Hide()
      self.text:SetPoint("CENTER")
      return
    end
    Studio.Glyph(self.icon, glyph)
    self.icon:Show()
    local shown = self.text:GetText()
    if shown and shown ~= "" then
      local w = (self.text:GetStringWidth() or 0) + 14 + 6
      -- room for a longer translation and the icon both
      self:SetWidth(max(self:GetWidth() or 0, w + 24))
      self.icon:SetPoint("LEFT", self, "CENTER", -w / 2, 0)
      self.text:SetPoint("LEFT", self.icon, "RIGHT", 6, 0)
    else
      self.icon:SetPoint("CENTER")
      self.text:SetPoint("CENTER")
    end
    self:Restyle()
  end
  function button:Restyle()
    local C = Studio.C
    local tint
    if self.disabled then
      self.round:SetFill(Kit.InsetColor); self.round:SetEdge(Kit.BorderIdle, .5); Tint(self.text, Kit.TextDisabled)
      tint = Kit.TextDisabled
    elseif self.style == "gold" then
      self.round:SetFill(C.goldDim); self.round:SetEdge(Kit.TextSelected, self.hovered and 1 or .85)
      Tint(self.text, Kit.TextSelected)
      tint = Kit.TextSelected
    else
      self.round:SetFill(self.hovered and C.raised or Kit.BackdropColor)
      self.round:SetEdge(self.hovered and Kit.TextHighlight or Kit.BorderIdle, self.hovered and .5 or 1)
      Tint(self.text, self.hovered and Kit.TextHighlight or Kit.TextNormal)
      tint = self.hovered and Kit.TextHighlight or Kit.TextSelected
    end
    self.icon:SetVertexColor(tint[1], tint[2], tint[3])
  end
  function button:SetDisabled(disabled)
    self.disabled = disabled and true or false
    if self.disabled then self:Disable() else self:Enable() end
    self:Restyle()
  end
  button:SetScript("OnEnter", function(self) self.hovered = true; self:Restyle() end)
  button:SetScript("OnLeave", function(self) self.hovered = nil; self:Restyle() end)
  button:SetScript("OnClick", function(self)
    if self.disabled then return end
    PlaySound(852)
    onClick(self)
  end)
  button:Restyle()
  return button
end

-- A pill that is on or off; on shows a check before its label.
function Studio.Chip(parent, label, onClick)
  local chip = CreateFrame("Button", nil, parent)
  chip:SetHeight(24)
  chip.round = Studio.Round(chip, 12)
  chip.check = chip:CreateTexture(nil, "OVERLAY")
  chip.check:SetSize(12, 12)
  chip.check:SetPoint("LEFT", 10, 0)
  Studio.Glyph(chip.check, "check")
  chip.text = Studio.Label(chip, 12, "body")
  chip.text:SetText(label)
  function chip:SetOn(on)
    self.on = on and true or false
    self.check:SetShown(self.on)
    self.text:ClearAllPoints()
    self.text:SetPoint("LEFT", self.on and 26 or 14, 0)
    self:SetWidth((self.text:GetStringWidth() or 60) + (self.on and 40 or 28))
    self:Restyle()
  end
  function chip:Restyle()
    local C = Studio.C
    if self.on then
      self.round:SetFill(C.raised); self.round:SetEdge(C.bronze)
      self.check:SetVertexColor(unpack(Kit.TextSelected)); Tint(self.text, Kit.TextHighlight)
    else
      self.round:SetFill(nil); self.round:SetEdge(self.hovered and Kit.TextNormal or Kit.BorderIdle)
      Tint(self.text, self.hovered and Kit.TextNormal or Kit.TextDisabled)
    end
    if self.locked then self:SetAlpha(.7) else self:SetAlpha(1) end
  end
  chip:SetScript("OnEnter", function(self) self.hovered = true; self:Restyle() end)
  chip:SetScript("OnLeave", function(self) self.hovered = nil; self:Restyle() end)
  chip:SetScript("OnClick", function(self)
    if self.locked then return end
    PlaySound(852)
    onClick(self)
  end)
  chip:SetOn(false)
  return chip
end

---------------------------------------------------------------------
-- Text box
---------------------------------------------------------------------
-- Commits on Enter (or losing focus); Escape puts the old text back.
function Studio.Edit(parent, width, height, onCommit, numeric)
  local box = CreateFrame("EditBox", nil, parent)
  box:SetSize(width, height or 24)
  box:SetAutoFocus(false)
  box:SetFontObject(Kit.ArtStyle == "studio" and Studio.Font(12, "body") or Kit.GetFont(12))
  box:SetTextInsets(8, 6, 0, 0)
  box:SetJustifyH(numeric and "CENTER" or "LEFT")
  if numeric then box:SetTextInsets(2, 2, 0, 0) end
  box.round = Studio.Round(box, 4)
  function box:Restyle()
    self.round:SetFill(Kit.InsetColor)
    self.round:SetEdge(self:HasFocus() and Kit.BorderFocus or Kit.BorderIdle)
    self:SetTextColor(unpack(Kit.TextHighlight))
  end
  function box:SetValue(text)
    self.committed = text or ""
    if not self:HasFocus() then self:SetText(self.committed) end
  end
  local function Commit(self)
    local text = self:GetText()
    if text ~= self.committed then onCommit(self, text) end
  end
  box:SetScript("OnEnterPressed", function(self) Commit(self); self:ClearFocus() end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(self.committed or ""); self:ClearFocus() end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText(); self:Restyle() end)
  box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); self:Restyle() end)
  box:Restyle()
  return box
end

---------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------
-- The settings rows' slider in small: a pill rail with a one-pixel edge, the accent
-- up to the value and a round knob with a hard pixel of shadow (Studio.Pill,
-- Studio.Knob). onChange(value, final) fires while dragging (final false) and once
-- on release (final true).
local RAIL_H, KNOB = 6, 14

function Studio.Slider(parent, width, lo, hi, step, onChange)
  local slider = CreateFrame("Frame", nil, parent)
  slider:SetSize(width, 16)
  slider.lo, slider.hi, slider.step = lo, hi, step

  local rail = CreateFrame("Frame", nil, slider)
  rail:SetPoint("LEFT")
  rail:SetPoint("RIGHT")
  rail:SetHeight(RAIL_H)
  slider.rail = rail
  slider.track = Studio.Pill(rail, "BACKGROUND")

  local fillFrame = CreateFrame("Frame", nil, rail)
  fillFrame:SetPoint("TOPLEFT")
  fillFrame:SetPoint("BOTTOMLEFT")
  slider.fillFrame = fillFrame
  slider.fill = Studio.Pill(fillFrame, "ARTWORK")

  local knobHost = CreateFrame("Frame", nil, slider)
  knobHost:SetAllPoints()
  knobHost:SetFrameLevel(rail:GetFrameLevel() + 3)
  slider.knob = Studio.Knob(knobHost)

  -- The knob travels half its width in from each end, so it never hangs past the rail.
  local function Place(self)
    local h, px = Studio.Snap(rail, RAIL_H, true)
    local k = Studio.Snap(rail, KNOB, true)
    rail:SetHeight(h)
    self.track:Layout(h, px)
    self.fill:Layout(h, px)
    self.knob:Layout(k, px)
    local w = self:GetWidth() or width
    local at = k / 2 + (w - k) * (self.value - self.lo) / math.max(1e-6, self.hi - self.lo)
    fillFrame:SetWidth(math.max(h, at))
    self.fill:SetShown(self.value > self.lo)
    self.knob.texture:ClearAllPoints()
    self.knob.texture:SetPoint("CENTER", self, "LEFT", at, 0)
  end
  function slider:SetValue(value)
    value = min(self.hi, max(self.lo, tonumber(value) or self.lo))
    if self.step and self.step > 0 then value = floor((value - self.lo) / self.step + .5) * self.step + self.lo end
    self.value = value
    Place(self)
  end
  function slider:Restyle()
    Place(self)
    self.track:SetColors(Kit.InsetColor, Kit.BorderIdle)
    self.fill:SetColors(Kit.TextSelected)
    self.knob:SetColor(Kit.TextHighlight)
    self.knob:SetLip(true)
  end
  slider:SetScript("OnSizeChanged", function(self) if self.value then Place(self) end end)
  local function FromCursor(self)
    local x = GetCursorPosition()
    local scale, left, w = self:GetEffectiveScale(), self:GetLeft(), self:GetWidth()
    if not (x and scale and left and w and w > 0) then return end
    return self.lo + min(1, max(0, (x / scale - left) / w)) * (self.hi - self.lo)
  end
  slider:EnableMouse(true)
  slider:SetHitRectInsets(-6, -6, -6, -6)
  slider:SetScript("OnMouseDown", function(self)
    if self.onStart then self.onStart() end
    self:SetScript("OnUpdate", function(s)
      local value = FromCursor(s)
      if value then s:SetValue(value); onChange(s.value, false) end
    end)
  end)
  slider:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
    onChange(self.value, true)
  end)
  slider:SetValue(lo)
  slider:Restyle()
  return slider
end

---------------------------------------------------------------------
-- Switch
---------------------------------------------------------------------
-- The same pill and knob as a settings row's toggle (Studio.SwitchArt).
function Studio.Switch(parent, onToggle)
  local switch = CreateFrame("Button", nil, parent)
  local art = Studio.SwitchArt(switch)
  switch.art = art
  switch.knob = art.knob
  function switch:SetOn(on, animate)
    self.on = on and true or false
    art:SetOn(self.on, animate)
  end
  function switch:Restyle() art:Restyle() end
  switch:SetScript("OnClick", function(self)
    PlaySound(self.on and 857 or 856)
    -- slides now; the page's redraw that follows sets the same value and leaves it be
    self:SetOn(not self.on, true)
    onToggle(self, self.on)
  end)
  switch:SetScript("OnEnter", function() art.hovered = true; art:Restyle() end)
  switch:SetScript("OnLeave", function() art.hovered = nil; art:Restyle() end)
  switch:SetOn(false)
  return switch
end

---------------------------------------------------------------------
-- Swatch
---------------------------------------------------------------------
-- A rounded colour. SetSelected draws the gold ring.
function Studio.Swatch(parent, width, height, radius)
  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetSize(width, height)
  swatch.round = Studio.Round(swatch, radius or 4, true, nil, true)
  function swatch:SetColour(c)
    self.colour = c
    if c then self.round:SetFill(c, 1) else self.round:SetFill(nil) end
    self:Restyle()
  end
  function swatch:SetSelected(selected) self.selected = selected; self:Restyle() end
  function swatch:Restyle()
    if self.selected then
      self.round:SetEdge(Kit.TextSelected)
    elseif self.hovered then
      self.round:SetEdge(Kit.TextHighlight, .7)
    else
      self.round:SetEdge({ 0, 0, 0 }, .5)
    end
  end
  swatch:HookScript("OnEnter", function(self) self.hovered = true; self:Restyle() end)
  swatch:HookScript("OnLeave", function(self) self.hovered = nil; self:Restyle() end)
  return swatch
end

---------------------------------------------------------------------
-- Bare dropdown
---------------------------------------------------------------------
-- A box that opens the kit's shared list. onPick(key) runs on a choice.
function Studio.Dropdown(parent, width, onPick)
  local box = CreateFrame("Button", nil, parent)
  box:SetSize(width, 26)
  box.round = Studio.Round(box, 4)
  local chevron = box:CreateTexture(nil, "OVERLAY")
  chevron:SetSize(12, 12)
  chevron:SetPoint("RIGHT", -7, 0)
  Studio.Glyph(chevron, "chevron")
  local text = Studio.Label(box, 13, "body")
  text:SetPoint("LEFT", 10, 0)
  text:SetPoint("RIGHT", chevron, "LEFT", -4, 0)
  local owner = { box = box, list = {}, order = {} }
  box.owner, box.text, box.chevron = owner, text, chevron
  function owner:SetValue(key)
    self.value = key
    text:SetText(key ~= nil and self.list[key] and tostring(self.list[key]) or "")
  end
  function owner:Fire(key) onPick(key) end
  function box:SetList(list, order)
    owner.list = list or {}
    owner.order = {}
    if order then
      for i, key in ipairs(order) do owner.order[i] = key end
    else
      for key in pairs(owner.list) do owner.order[#owner.order + 1] = key end
      table.sort(owner.order, function(a, b) return tostring(owner.list[a]) < tostring(owner.list[b]) end)
    end
    owner:SetValue(owner.value)
  end
  function box:SetValue(key) owner:SetValue(key) end
  function box:Restyle()
    self.round:SetFill(Kit.InsetColor)
    self.round:SetEdge(self.hovered and Kit.TextHighlight or Kit.BorderIdle, self.hovered and .6 or 1)
    Tint(text, self.dim and Kit.TextDisabled or Kit.TextHighlight)
    chevron:SetVertexColor(unpack(Kit.TextSelected))
  end
  box:SetScript("OnEnter", function(self) self.hovered = true; self:Restyle() end)
  box:SetScript("OnLeave", function(self) self.hovered = nil; self:Restyle() end)
  box:SetScript("OnClick", function() PlaySound(852); Controls.OpenList(owner) end)
  box:Restyle()
  return box
end

---------------------------------------------------------------------
-- Colour button
---------------------------------------------------------------------
-- A swatch that opens Blizzard's colour picker. getter() returns r, g, b, a;
-- setter(r, g, b, a) runs while picking; finish() once the picker closes.
function Studio.ColourButton(parent, width, height, getter, setter, finish)
  local swatch = Studio.Swatch(parent, width, height, 3)
  function swatch:Update() self:SetColour({ getter() }) end
  swatch:SetScript("OnClick", function(self)
    local picker = ColorPickerFrame
    if not (picker and picker.SetupColorPickerAndShow) then return end
    picker:Hide()
    local r, g, b, a = getter()
    local ready = false
    local function changed()
      if not ready then return end
      local nr, ng, nb = picker:GetColorRGB()
      setter(nr, ng, nb, a)
      self:SetColour({ nr, ng, nb, a })
    end
    picker:SetupColorPickerAndShow({
      r = r, g = g, b = b, opacity = a, hasOpacity = false,
      swatchFunc = changed,
      cancelFunc = function() setter(r, g, b, a); self:SetColour({ r, g, b, a }) end,
      extraInfo = ns,
    })
    ready = true
    if finish then picker:HookScript("OnHide", function() if ready then ready = false; finish() end end) end
  end)
  return swatch
end
