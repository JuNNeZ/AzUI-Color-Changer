local _, ns = ...
local Kit = ns.OptionsKit
local Controls = Kit.Controls

-- Only JuNNeZ Edition ships the options window's glyph sheet; with any other
-- AzeriteUI (or none) the glyphs come from Blizzard's own icons.
if not ns.HasAzeriteMedia("options-glyphs") then
  Kit.SetGlyph = function(texture, name)
    local icons = {
      check = "Interface\\Buttons\\UI-CheckBox-Check",
      chevron = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
      cross = "Interface\\Buttons\\UI-StopButton",
      search = "Interface\\Common\\UI-Searchbox-Icon",
      revert = "Interface\\Buttons\\UI-RefreshButton",
      gem = "Interface\\COMMON\\Indicator-Yellow",
      grip = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
      dash = "Interface\\Buttons\\UI-MinusButton-Up",
    }
    texture:SetTexture(icons[name] or "Interface\\Buttons\\UI-CheckBox-Check")
    texture:SetTexCoord(0, 1, 0, 1)
  end
end

if not ns.HasAzeriteArt then
  -- Stock textures have no Azerite atlas cells, shadows or cropped bar bodies.
  Kit.DrawSize = function(body) return body end
  for _, spec in ipairs({ Kit.Trough, Kit.Fill }) do
    spec.left, spec.mid, spec.right = { 0, .1, 0, 1 }, { .1, .9, 0, 1 }, { .9, 1, 0, 1 }
  end
  -- Blizzard's tooltip border is thin and sits on the window's own edge.
  Kit.WindowOutset = { left = 3, right = 3, top = 3, bottom = 3 }
  Kit.WindowCasing = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 }
  Kit.WindowCasingColor = { .6, .6, .6, 1 }
end

-- The renderer can recycle a row only after the native picker has closed.
Controls.IsColorOpen = function()
  return ColorPickerFrame and ColorPickerFrame:IsShown() and ColorPickerFrame:GetExtraInfo() == ns
end
Controls.CloseColor = function()
  if Controls.IsColorOpen() then ColorPickerFrame:OnCancel() end
end

Controls.CreateColor = function(parent)
  local control = Controls.CreateButton(parent)
  control.kind = "color"
  local swatch = control.box:CreateTexture(nil, "ARTWORK")
  swatch:SetSize(30, 16)
  swatch:SetPoint("LEFT", control.box, "LEFT", 8, 0)
  control.swatch = swatch
  control.text:SetPoint("LEFT", control.box, "LEFT", 44, 0)
  control.SetValue = function(self, r, g, b, a)
    self.r, self.g, self.b, self.a = r or 1, g or 1, b or 1, a or 1
    swatch:SetColorTexture(self.r, self.g, self.b, self.a)
    self:SetText(string.format("#%02X%02X%02X  %d%%", math.floor(self.r * 255 + .5), math.floor(self.g * 255 + .5), math.floor(self.b * 255 + .5), math.floor(self.a * 100 + .5)))
  end
  control.box:SetScript("OnClick", function()
    if control.disabled then return end
    local picker = ColorPickerFrame
    picker:Hide()
    local r, g, b, a = control.r, control.g, control.b, control.a
    -- Capture the binding, never a pooled row's future callback.
    local callback = control.callback
    local function apply(red, green, blue, alpha)
      control:SetValue(red, green, blue, alpha)
      if callback then callback(control, red, green, blue, alpha) end
    end
    local ready = false
    local function changed()
      if not ready then return end
      local red, green, blue = picker:GetColorRGB()
      apply(red, green, blue, control.hasAlpha and picker:GetColorAlpha() or a)
    end
    picker:SetupColorPickerAndShow({
      r = r, g = g, b = b, opacity = a, hasOpacity = control.hasAlpha,
      swatchFunc = changed, opacityFunc = changed,
      cancelFunc = function() apply(r, g, b, a) end, extraInfo = ns,
    })
    ready = true
  end)
  control:SetValue(1, 1, 1, 1)
  return control
end

local create = Controls.Create
Controls.Create = function(parent, kind, ...)
  if kind == "color" then return Controls.CreateColor(parent) end
  return create(parent, kind, ...)
end
