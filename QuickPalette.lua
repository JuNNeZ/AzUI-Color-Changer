-- QuickPalette.lua - right-click the minimap button for the everyday changes without
-- opening the full window: the colour you have, your presets as swatches, the effects,
-- pet colours on or off, and a way into the ABCS window.
--
-- Drawn in AzeriteUI's style when the options kit has its art, Blizzard's otherwise.
local _, ns = ...
local P = ns.P
local L = P.L

local WIDTH, PAD = 336, 14
local SWATCH_W, SWATCH_H, SWATCHES = 34, 24, 8
local CHIP_W, CHIP_H = 72, 22
-- the effect chips, four to a row, and the height of their rows
local EFFECT_ROWS = math.ceil(#P.EFFECTS / 4)
local EFFECTS_H = EFFECT_ROWS * CHIP_H + (EFFECT_ROWS - 1) * 6 + 12

local palette

local function Kit() return ns.OptionsKit end

local function Backdrop(frame, small)
  local kit = Kit()
  if kit and kit.ButtonBackdrop then
    frame:SetBackdrop(small and kit.ButtonBackdrop or kit.WindowBackdrop)
    frame:SetBackdropColor(unpack(small and kit.BackdropColor or kit.WindowColor))
    frame:SetBackdropBorderColor(unpack(kit.BorderIdle))
  else
    frame:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = small and 12 or 16, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(.05, .05, .06, .95)
    frame:SetBackdropBorderColor(.5, .5, .5, 1)
  end
end

local function Text(parent, size, r, g, b)
  local text = parent:CreateFontString(nil, "OVERLAY")
  local kit = Kit()
  if kit and kit.GetFont then text:SetFontObject(kit.GetFont(size)) else text:SetFontObject(size >= 13 and GameFontNormal or GameFontHighlightSmall) end
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  if r then text:SetTextColor(r, g, b) end
  return text
end

local function Tip(frame, title, line)
  frame:SetScript("OnEnter", function(self)
    if self.hover then self.hover:Show() end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(type(title) == "function" and title(self) or title, 1, 1, 1)
    if line then GameTooltip:AddLine(type(line) == "function" and line(self) or line, .8, .8, .8, true) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function(self)
    if self.hover then self.hover:Hide() end
    GameTooltip:Hide()
  end)
end

local function Chip(parent, width, label, onClick)
  local chip = CreateFrame("Button", nil, parent, "BackdropTemplate")
  chip:SetSize(width, CHIP_H)
  Backdrop(chip, true)
  chip.text = Text(chip, 11)
  chip.text:SetPoint("CENTER")
  chip.text:SetText(label)
  chip:SetScript("OnClick", function(self) PlaySound(852); onClick(self) end)
  return chip
end

local function Build()
  -- the same art as the ABCS window, chosen once
  local kit = Kit()
  if kit and kit.PrepareArt then kit.PrepareArt(P.DB.global.panel.theme) end
  palette = CreateFrame("Frame", "AzUIColorPickerQuickPalette", UIParent, "BackdropTemplate")
  palette:SetFrameStrata("DIALOG")
  palette:SetClampedToScreen(true)
  palette:EnableMouse(true)
  palette:SetWidth(WIDTH)
  palette:Hide()
  Backdrop(palette)
  tinsert(UISpecialFrames, "AzUIColorPickerQuickPalette")

  -- a click anywhere else closes it
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetFrameStrata("DIALOG")
  catcher:SetAllPoints(UIParent)
  catcher:RegisterForClicks("AnyUp")
  catcher:SetScript("OnClick", function() palette:Hide() end)
  catcher:Hide()
  palette:SetScript("OnShow", function(self)
    catcher:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1))
    catcher:Show()
  end)
  palette:SetScript("OnHide", function() catcher:Hide() end)

  -- current colour
  local current = palette:CreateTexture(nil, "ARTWORK")
  current:SetSize(36, 36)
  current:SetPoint("TOPLEFT", PAD, -PAD)
  palette.current = current
  local name = Text(palette, 15, 1, 1, 1)
  name:SetPoint("TOPLEFT", current, "TOPRIGHT", 12, -2)
  name:SetPoint("RIGHT", -PAD, 0)
  palette.name = name
  local detail = Text(palette, 11, .7, .7, .7)
  detail:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
  detail:SetPoint("RIGHT", -PAD, 0)
  palette.detail = detail

  -- presets
  local presetsLabel = Text(palette, 10, .6, .6, .6)
  presetsLabel:SetPoint("TOPLEFT", current, "BOTTOMLEFT", 0, -14)
  presetsLabel:SetText(L["PRESETS"])
  palette.presetsLabel = presetsLabel
  palette.swatches = {}
  for i = 1, SWATCHES do
    local swatch = CreateFrame("Button", nil, palette, "BackdropTemplate")
    swatch:SetSize(SWATCH_W, SWATCH_H)
    swatch:SetPoint("TOPLEFT", presetsLabel, "BOTTOMLEFT", (i - 1) * (SWATCH_W + 4), -6)
    swatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    swatch.fill = swatch:CreateTexture(nil, "ARTWORK")
    swatch.fill:SetPoint("TOPLEFT", 2, -2)
    swatch.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch:SetScript("OnClick", function(self) PlaySound(852); P.LoadPreset(self.preset) end)
    Tip(swatch, function(self) return self.preset end, L["Click to use this preset."])
    palette.swatches[i] = swatch
  end
  local noPresets = Text(palette, 11, .6, .6, .6)
  noPresets:SetPoint("TOPLEFT", presetsLabel, "BOTTOMLEFT", 0, -10)
  noPresets:SetText(L["No presets yet. Save one from the ABCS window."])
  palette.noPresets = noPresets

  -- effects, four to a row
  local effectsLabel = Text(palette, 10, .6, .6, .6)
  effectsLabel:SetPoint("TOPLEFT", presetsLabel, "BOTTOMLEFT", 0, -(SWATCH_H + 18))
  effectsLabel:SetText(L["EFFECT"])
  palette.chips = {}
  for i, key in ipairs(P.EFFECTS) do
    local chip = Chip(palette, CHIP_W, P.EFFECT_VALUES[key]:gsub(" %(test%)", ""), function(self)
      local question = P.EffectConfirm(self.effect)
      if question and P.DB.profile.effect ~= self.effect then
        StaticPopupDialogs.AZUI_QUICK_CONFIRM = {
          text = question, button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
          preferredIndex = 3, OnAccept = function() P.SetEffect(self.effect) end,
        }
        StaticPopup_Show("AZUI_QUICK_CONFIRM")
      else
        P.SetEffect(self.effect)
      end
    end)
    chip.effect = key
    local column, row = (i - 1) % 4, math.floor((i - 1) / 4)
    chip:SetPoint("TOPLEFT", effectsLabel, "BOTTOMLEFT", column * (CHIP_W + 6), -6 - row * (CHIP_H + 6))
    Tip(chip, P.EFFECT_VALUES[key], P.EFFECT_HELP[key])
    palette.chips[i] = chip
  end

  -- pet colours
  local pets = CreateFrame("CheckButton", nil, palette, "UICheckButtonTemplate")
  pets:SetSize(24, 24)
  pets:SetPoint("TOPLEFT", effectsLabel, "BOTTOMLEFT", -4, -EFFECTS_H)
  pets:SetScript("OnClick", function() P.HandleSlash("pets") end)
  local petsText = Text(palette, 12, 1, 1, 1)
  petsText:SetPoint("LEFT", pets, "RIGHT", 2, 0)
  petsText:SetText(L["Pet colours"])
  palette.pets = pets

  local rule = palette:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 1, 1, .12)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", pets, "BOTTOMLEFT", 4, -8)
  rule:SetPoint("RIGHT", -PAD, 0)

  local open = CreateFrame("Button", nil, palette)
  open:SetSize(170, 20)
  open:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -6)
  local openText = Text(open, 13, 1, .82, 0)
  openText:SetPoint("LEFT")
  openText:SetText(L["Open the ABCS window…"])
  open:SetScript("OnClick", function() palette:Hide(); P.ToggleWindow() end)
  local hint = Text(palette, 10, .5, .5, .5)
  hint:SetPoint("RIGHT", palette, "RIGHT", -PAD, 0)
  hint:SetPoint("TOP", open, "TOP", 0, -4)
  hint:SetJustifyH("RIGHT")
  hint:SetText(L["Shift-click: next preset"])

  palette:SetHeight(PAD + 36 + 14 + 12 + SWATCH_H + 18 + 12 + EFFECTS_H + 24 + 8 + 26 + PAD)
end

function P.RefreshQuickPalette()
  if not (palette and palette:IsShown()) then return end
  local p = P.DB.profile
  local colour, effect, source = P.ChannelSource("player")
  colour = colour or p.color
  palette.current:SetColorTexture(colour[1], colour[2], colour[3], 1)
  palette.name:SetText(P.selectedPreset or L["Your colour"])
  local detail = P.Hex(colour) .. " · " .. P.EFFECT_VALUES[effect or "static"]
  if source == "rule" then detail = detail .. " · " .. L["from a rule"]
  elseif source == "pet" then detail = detail .. " · " .. L["from your pet"]
  elseif source == "health" then detail = L["coloured by your health"] end
  palette.detail:SetText(detail)

  local names = P.SortedPresetNames()
  for i, swatch in ipairs(palette.swatches) do
    local name = names[i]
    swatch.preset = name
    if name then
      local c = p.presets[name]
      swatch.fill:SetColorTexture(c[1], c[2], c[3], 1)
      local selected = name == P.selectedPreset
      swatch:SetBackdropBorderColor(selected and 1 or 0, selected and .82 or 0, 0, selected and 1 or .6)
      swatch:Show()
    else
      swatch:Hide()
    end
  end
  palette.noPresets:SetShown(#names == 0)

  local kit = Kit()
  for _, chip in ipairs(palette.chips) do
    local selected = chip.effect == p.effect
    if kit and kit.BorderFocus then
      chip:SetBackdropBorderColor(unpack(selected and kit.BorderFocus or kit.BorderIdle))
      chip.text:SetTextColor(unpack(selected and kit.TextSelected or kit.TextNormal))
    else
      chip:SetBackdropBorderColor(selected and 1 or .5, selected and .82 or .5, selected and 0 or .5, 1)
      chip.text:SetTextColor(selected and 1 or .85, selected and .82 or .85, selected and 0 or .85)
    end
  end
  palette.pets:SetChecked(p.petColouring and true or false)
end

function P.ToggleQuickPalette(anchor)
  if not palette then Build() end
  if palette:IsShown() then palette:Hide(); return end
  palette:ClearAllPoints()
  if anchor and anchor.GetCenter and anchor:GetCenter() then
    -- open towards the middle of the screen
    local x, y = anchor:GetCenter()
    local right, top = x > UIParent:GetWidth() / 2, y > UIParent:GetHeight() / 2
    palette:SetPoint((top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT"), anchor,
      (top and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT"), 0, 0)
  else
    palette:SetPoint("CENTER")
  end
  palette:Show()
  P.RefreshQuickPalette()
end

function P.GetQuickPalette() return palette end
