-- The pet gallery on the Hunter Pets page of the AzUI window.
--
-- From the AzUI Feature Plan: every pet as a card with its portrait, name, family
-- and colour, the one that is out wearing a badge; filters for call slots and the
-- stable plus a search; and a detail panel for the selected pet with its model
-- turning slowly beside its colour and effect.
--
-- Portraits and models come from the displayID Blizzard's stable reports for each
-- pet (C_StableInfo PetInfo.displayID), the same way Blizzard_StableUI draws them.
-- A pet remembered before this version, or one Forever's stable reports without a
-- displayID, falls back to its icon until the stable is read again.
--
-- One control in Renderer.lua's sense: the page lays it out after the option rows.
local _, ns = ...

local Kit = ns.OptionsKit
local Controls = Kit.Controls
local Core = ns.Core
if not (Controls and Core) then return end

local L = ns.L
local floor, max, min = math.floor, math.max, math.min
local ipairs, unpack = ipairs, unpack
local string_find, string_lower = string.find, string.lower

local Gallery = { filter = "all", query = "" }
Kit.PetGallery = Gallery

local CARD_W, CARD_H, GAP = 136, 156, 10
local PORTRAIT = 60
local FILTER_H = 34
local DETAIL_H = 214
local MODEL_W = 200
local PAD = 14

local RAINBOW = {
  { .91, .25, .18 }, { .91, .78, .18 }, { .24, .75, .33 }, { .23, .55, .88 }, { .77, .27, .78 },
}

local function Text(parent, size, outline)
  local text = parent:CreateFontString(nil, "OVERLAY")
  text:SetFontObject(Kit.GetFont(size, outline))
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  return text
end

local function SetColour(fontstring, colour)
  fontstring:SetTextColor(colour[1], colour[2], colour[3])
end

-- A small button on the addon's button border, for the chips and the detail actions.
local function SmallButton(parent, width, onClick)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, 24)
  button.backdrop = Kit.CreateBackdrop(button, Kit.ButtonBackdrop)
  button.text = Text(button, 12)
  button.text:SetPoint("LEFT", 8, 0)
  button.text:SetPoint("RIGHT", -8, 0)
  button.text:SetJustifyH("CENTER")
  button.Restyle = function(self)
    self.backdrop:SetBackdropColor(unpack(Kit.BackdropColor))
    local border = self.selected and Kit.BorderFocus or self.hovered and not self.disabled and Kit.BorderHover or Kit.BorderIdle
    Kit.SetBorderColor(self.backdrop, border)
    SetColour(self.text, self.disabled and Kit.TextDisabled or self.selected and Kit.TextSelected
      or self.hovered and Kit.TextHighlight or Kit.TextNormal)
  end
  button.SetDisabled = function(self, disabled)
    self.disabled = disabled and true or false
    if self.disabled then self:Disable() else self:Enable() end
    self:Restyle()
  end
  button:SetScript("OnEnter", function(self)
    self.hovered = true
    self:Restyle()
    if self.tooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(self.tooltip, Kit.TextNormal[1], Kit.TextNormal[2], Kit.TextNormal[3], true)
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function(self) self.hovered = nil; self:Restyle(); GameTooltip:Hide() end)
  button:SetScript("OnClick", function(self)
    if self.disabled then return end
    PlaySound(852)
    onClick(self)
  end)
  return button
end

-- A portrait from the pet's display, or its icon when there is none.
local function SetPortrait(texture, pet)
  if pet.displayID and SetPortraitTextureFromCreatureDisplayID then
    SetPortraitTextureFromCreatureDisplayID(texture, pet.displayID)
    texture:SetTexCoord(1, 0, 0, 1) -- facing into the card, as Blizzard's stable flips it
  else
    texture:SetTexture(pet.icon or Core.icon)
    texture:SetTexCoord(unpack(Core.iconCoords))
  end
end

-- The strip under a card: the pet's colour, a rainbow, or a dashed "nothing".
local function PaintStrip(strip, number, pet)
  local mode, effect = Core.PetMode(number), Core.PetEffect(number)
  local colour = Core.PetColour(number, pet)
  local rainbow = effect == "rainbow" and mode ~= "off"
  for index, piece in ipairs(strip.pieces) do
    if rainbow then
      piece:SetColorTexture(unpack(RAINBOW[index]))
    elseif colour and mode ~= "off" then
      piece:SetColorTexture(colour[1], colour[2], colour[3], 1)
    else
      piece:SetColorTexture(.3, .3, .3, index % 2 == 1 and .9 or .2)
    end
  end
end

-- The gallery's height changes with the filter and the selection, and the page
-- below the panel's scroll frame has to know.
local function Relayout()
  local panel = Kit.Panel
  if panel and panel.page and panel:IsShown() then
    panel.page:Layout()
  elseif Gallery.control then
    Gallery.control:Measure(Gallery.width)
  end
end

local function Matches(entry)
  local pet = entry.pet
  if Gallery.filter == "active" and not Core.IsActiveSlot(pet) then return false end
  if Gallery.filter == "stabled" and Core.IsActiveSlot(pet) then return false end
  if Gallery.query == "" then return true end
  local text = string_lower((pet.name or "") .. " " .. (Core.FamilyName(pet) or "") .. " " .. (pet.specialization or ""))
  return string_find(text, Gallery.query, 1, true) ~= nil
end

--------------------------------------------------------------------------
-- Cards
--------------------------------------------------------------------------
local cards = {}

local function StyleCard(card)
  local selected = card.number == Gallery.selected
  card.backdrop:SetBackdropColor(unpack(Kit.InsetColor))
  Kit.SetBorderColor(card.backdrop, selected and Kit.BorderFocus or card.hovered and Kit.BorderHover or Kit.BorderIdle)
  SetColour(card.name, selected and Kit.TextSelected or Kit.TextHighlight)
  SetColour(card.sub, Kit.TextDisabled)
  card.ring:SetVertexColor(unpack(selected and Kit.TextSelected or Kit.BorderIdle))
end

local function CreateCard(parent, index)
  local card = CreateFrame("Button", nil, parent)
  card:SetSize(CARD_W, CARD_H)
  card.backdrop = Kit.CreateBackdrop(card, Kit.InsetBackdrop)

  local ring = card:CreateTexture(nil, "BORDER")
  ring:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  ring:SetSize(PORTRAIT + 6, PORTRAIT + 6)
  ring:SetPoint("TOP", 0, -12)
  card.ring = ring

  local portrait = card:CreateTexture(nil, "ARTWORK")
  portrait:SetSize(PORTRAIT, PORTRAIT)
  portrait:SetPoint("CENTER", ring)
  local mask = card:CreateMaskTexture()
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(portrait)
  portrait:AddMaskTexture(mask)
  card.portrait = portrait

  local badge = CreateFrame("Frame", nil, card, "BackdropTemplate")
  badge:SetSize(38, 16)
  badge:SetPoint("TOPLEFT", 6, -6)
  badge:SetBackdrop({ bgFile = Kit.GetMedia("plain") })
  badge:SetBackdropColor(.35, .27, .07, .95)
  local badgeText = Text(badge, 10, true)
  badgeText:SetPoint("CENTER")
  badgeText:SetText(L["OUT"])
  badgeText:SetTextColor(1, .82, 0)
  card.badge = badge

  local name = Text(card, 13)
  name:SetPoint("TOP", ring, "BOTTOM", 0, -8)
  name:SetPoint("LEFT", 8, 0)
  name:SetPoint("RIGHT", -8, 0)
  name:SetJustifyH("CENTER")
  card.name = name

  local sub = Text(card, 11)
  sub:SetPoint("TOP", name, "BOTTOM", 0, -3)
  sub:SetPoint("LEFT", 8, 0)
  sub:SetPoint("RIGHT", -8, 0)
  sub:SetJustifyH("CENTER")
  card.sub = sub

  local strip = CreateFrame("Frame", nil, card)
  strip:SetHeight(8)
  strip:SetPoint("BOTTOMLEFT", 14, 12)
  strip:SetPoint("BOTTOMRIGHT", -14, 12)
  strip.pieces = {}
  for i = 1, #RAINBOW do
    strip.pieces[i] = strip:CreateTexture(nil, "ARTWORK")
  end
  strip:SetScript("OnSizeChanged", function(self, width)
    local each = width / #self.pieces
    for i, piece in ipairs(self.pieces) do
      piece:ClearAllPoints()
      piece:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * each, 0)
      piece:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", (i - 1) * each, 0)
      piece:SetWidth(each)
    end
  end)
  card.strip = strip

  card:SetScript("OnEnter", function(self)
    self.hovered = true
    StyleCard(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.pet.name or "?", unpack(Kit.TextHighlight))
    GameTooltip:AddLine(Core.PetSummary(self.number, self.pet), Kit.TextNormal[1], Kit.TextNormal[2], Kit.TextNormal[3], true)
    GameTooltip:Show()
  end)
  card:SetScript("OnLeave", function(self) self.hovered = nil; StyleCard(self); GameTooltip:Hide() end)
  card:SetScript("OnClick", function(self)
    PlaySound(852)
    Gallery:Select(self.number)
    Gallery:Update()
    Relayout()
  end)

  cards[index] = card
  return card
end

local function FillCard(card, entry, current)
  local number, pet = entry.number, entry.pet
  card.number, card.pet = number, pet
  SetPortrait(card.portrait, pet)
  card.badge:SetShown(current and current.number == number)
  card.name:SetText(pet.name or "?")
  local mode, effect = Core.PetMode(number), Core.PetEffect(number)
  local family = Core.FamilyName(pet) or L["Unknown family"]
  local extra = mode == "off" and L["no colour"] or (effect ~= "static" and Core.effectValues[effect]) or nil
  card.sub:SetText(extra and (family .. " · " .. extra) or family)
  PaintStrip(card.strip, number, pet)
  StyleCard(card)
end

--------------------------------------------------------------------------
-- The detail panel
--------------------------------------------------------------------------
local function BuildDetail(parent)
  local detail = CreateFrame("Frame", nil, parent)
  detail:SetHeight(DETAIL_H)
  detail.backdrop = Kit.CreateBackdrop(detail, Kit.InsetBackdrop)

  -- The model, turning slowly; drag to turn it yourself.
  local stage = CreateFrame("Frame", nil, detail)
  stage:SetSize(MODEL_W, DETAIL_H - 20)
  stage:SetPoint("TOPLEFT", 10, -10)
  local stageBg = stage:CreateTexture(nil, "BACKGROUND")
  stageBg:SetAllPoints()
  stageBg:SetColorTexture(0, 0, 0, .45)
  detail.stageBg = stageBg

  local model = CreateFrame("PlayerModel", nil, stage)
  model:SetAllPoints()
  model:EnableMouse(true)
  model.facing = 0.4
  model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
  model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
  model:SetScript("OnUpdate", function(self, elapsed)
    if self.dragX then
      local x = GetCursorPosition()
      self.facing = self.facing + (x - self.dragX) * 0.012
      self.dragX = x
    else
      self.facing = self.facing + elapsed * 0.35
    end
    self:SetFacing(self.facing)
  end)
  detail.model = model

  local fallback = stage:CreateTexture(nil, "ARTWORK")
  fallback:SetSize(96, 96)
  fallback:SetPoint("CENTER")
  detail.fallback = fallback

  local hint = Text(stage, 10)
  hint:SetPoint("BOTTOMLEFT", 6, 5)
  hint:SetText(L["Drag to turn"])
  detail.hint = hint

  -- Name, summary and the pet's own settings.
  local column = CreateFrame("Frame", nil, detail)
  column:SetPoint("TOPLEFT", stage, "TOPRIGHT", 6, 0)
  column:SetPoint("BOTTOMRIGHT", -6, 10)
  detail.column = column

  local name = Text(column, 18, true)
  name:SetPoint("TOPLEFT", 14, -2)
  name:SetPoint("RIGHT", -10, 0)
  detail.name = name

  local summary = Text(column, 12)
  summary:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
  summary:SetPoint("RIGHT", -10, 0)
  summary:SetWordWrap(true)
  summary:SetHeight(30)
  summary:SetJustifyV("TOP")
  detail.summary = summary

  local mode = Controls.CreateDropdown(column)
  mode:SetLabel(L["Colour"])
  mode:SetCallback(function(_, value) Core.SetPetMode(Gallery.selected, value) end)
  local colour = Controls.Create(column, "color")
  colour:SetLabel(L["Own Colour"])
  colour.hasAlpha = true
  colour:SetCallback(function(_, r, g, b, a)
    Core.SetPetColour(Gallery.selected, r, g, b, a)
    Gallery.dirty = true -- the cards catch up when the picker closes
  end)
  local effect = Controls.CreateDropdown(column)
  effect:SetLabel(L["Effect"])
  effect:SetCallback(function(_, value)
    local number = Gallery.selected
    local question = Core.EffectConfirm and Core.EffectConfirm(value)
    if question and Kit.Confirm then
      Kit.Confirm(question, function() Core.SetPetEffect(number, value) end, function() Gallery:Update() end)
    else
      Core.SetPetEffect(number, value)
    end
  end)
  detail.rows = { mode, colour, effect }
  local top = 58
  for _, row in ipairs(detail.rows) do
    row.frame:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -top)
    row.frame:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, -top)
    row.frame:Show()
    top = top + row:GetHeight()
  end

  local reset = SmallButton(column, 90, function() Core.ResetPet(Gallery.selected) end)
  reset.text:SetText(L["Reset"])
  reset.tooltip = L["Go back to the family colour with no effect."]
  reset:SetPoint("TOPLEFT", column, "TOPLEFT", 14, -top - 6)
  local family = SmallButton(column, 210, function() Core.CopyToFamily(Gallery.selected) end)
  family:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  family.tooltip = L["Make this pet's colour the colour of its whole family under Pet Families."]
  detail.reset, detail.family = reset, family

  detail.Restyle = function(self)
    self.backdrop:SetBackdropColor(unpack(Kit.BackdropColor))
    Kit.SetBorderColor(self.backdrop, Kit.BorderIdle)
    SetColour(self.name, Kit.TextSelected)
    SetColour(self.summary, Kit.TextNormal)
    SetColour(self.hint, Kit.TextDisabled)
    for _, row in ipairs(self.rows) do row:Restyle() end
    self.reset:Restyle()
    self.family:Restyle()
  end

  return detail
end

local function FillDetail(detail, entry)
  local number, pet = entry.number, entry.pet
  detail.name:SetText(pet.name or "?")
  detail.summary:SetText((Core.PetSummary(number, pet):gsub("\n", "  ·  ")))

  if pet.displayID then
    if detail.model.displayID ~= pet.displayID then
      detail.model:ClearModel()
      detail.model:SetDisplayInfo(pet.displayID)
      detail.model.displayID = pet.displayID
    end
    detail.model:Show()
    detail.fallback:Hide()
    detail.hint:Show()
  else
    detail.model:ClearModel()
    detail.model.displayID = nil
    detail.model:Hide()
    detail.fallback:SetTexture(pet.icon or Core.icon)
    detail.fallback:SetTexCoord(unpack(Core.iconCoords))
    detail.fallback:Show()
    detail.hint:Hide()
  end

  local mode, rows = Core.PetMode(number), detail.rows
  local off = mode == "off"
  rows[1]:SetList(Core.modeValues, Core.modeSorting)
  rows[1]:SetValue(mode)
  rows[1]:SetDisabled(false)
  if not (Controls.IsColorOpen and Controls.IsColorOpen()) then
    local colour = Core.PetColour(number, pet) or Core.GetDB().profile.color
    rows[2]:SetValue(colour[1], colour[2], colour[3], colour[4] or 1)
  end
  rows[2]:SetDisabled(off)
  rows[3]:SetList(Core.effectValues, Core.effectSorting)
  rows[3]:SetValue(Core.PetEffect(number))
  rows[3]:SetDisabled(off)

  local familyName = Core.FamilyName(pet)
  detail.family.text:SetText(L["Use for all"] .. " " .. (familyName or L["of this family"]))
  detail.family:SetDisabled(off or not pet.familyID)
  detail.reset:SetDisabled(false)
  detail:Restyle()
end

--------------------------------------------------------------------------
-- The control
--------------------------------------------------------------------------
local FILTERS = { "all", "active", "stabled" }

function Gallery:GetControl(parent)
  if self.control then return self.control end
  local control = { kind = "gallery" }
  self.control = control

  local frame = CreateFrame("Frame", nil, parent)
  control.frame = frame

  -- Filters and search
  local strip = CreateFrame("Frame", nil, frame)
  strip:SetHeight(FILTER_H)
  strip:SetPoint("TOPLEFT", PAD, -6)
  strip:SetPoint("TOPRIGHT", -12, -6)
  control.chips = {}
  for index, key in ipairs(FILTERS) do
    local chip = SmallButton(strip, 118, function(self)
      Gallery.filter = self.key
      Gallery:Update()
      Relayout()
    end)
    chip.key = key
    chip:SetPoint("LEFT", strip, "LEFT", (index - 1) * 124, 0)
    control.chips[index] = chip
  end

  local search = CreateFrame("EditBox", nil, strip)
  search:SetSize(170, 22)
  search:SetPoint("RIGHT", strip, "RIGHT", -2, 0)
  search:SetAutoFocus(false)
  search:SetFontObject(Kit.GetFont(12))
  search:SetTextInsets(8, 6, 0, 0)
  control.searchBackdrop = Kit.CreateBackdrop(search, Kit.InsetBackdrop, 2)
  local placeholder = Text(search, 12)
  placeholder:SetPoint("LEFT", 8, 0)
  placeholder:SetText(L["Find a pet…"])
  search:SetScript("OnTextChanged", function(self, userInput)
    placeholder:SetShown(self:GetText() == "")
    if not userInput then return end
    Gallery.query = string_lower(strtrim(self:GetText()))
    Gallery:Update()
    Relayout()
  end)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); Gallery.query = ""; Gallery:Update(); Relayout() end)
  search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  control.search, control.placeholder = search, placeholder

  control.detail = BuildDetail(frame)
  control.detail:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -8)
  control.detail:SetPoint("RIGHT", frame, "RIGHT", -12, 0)

  -- an illustration above the empty-state text, from the Studio art pack
  local Studio = Kit.Studio
  if Studio and Studio.Pack and Studio.Pack.emptyPets then
    control.emptyArt = frame:CreateTexture(nil, "ARTWORK")
    control.emptyArt:SetTexture(Studio.PackMedia("empty-pets"))
    control.emptyArt:SetSize(256, 128)
  end
  local empty = Text(frame, 12)
  empty:SetWordWrap(true)
  empty:SetJustifyV("TOP")
  empty:SetHeight(32)
  control.empty = empty

  -- The cards catch up once a colour picker has closed.
  frame:SetScript("OnUpdate", function()
    if Gallery.dirty and not (Controls.IsColorOpen and Controls.IsColorOpen()) then
      Gallery.dirty = nil
      Gallery:Update()
    end
  end)

  control.Update = function() Gallery:Update() end

  control.Measure = function(self, width)
    Gallery.width = width
    local usable = max(CARD_W, (width or 0) - PAD - 12)
    local columns = max(1, floor((usable + GAP) / (CARD_W + GAP)))
    local cardWidth = floor((usable - GAP * (columns - 1)) / columns)
    local top = 6 + FILTER_H + 8
    if self.detail:IsShown() then top = top + DETAIL_H + 12 end
    if self.emptyArt then
      self.emptyArt:SetShown(self.empty:IsShown())
      if self.empty:IsShown() then
        self.emptyArt:ClearAllPoints()
        self.emptyArt:SetPoint("TOP", frame, "TOP", 0, -top)
        top = top + 136
      end
    end
    if self.empty:IsShown() then
      self.empty:ClearAllPoints()
      self.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
      self.empty:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
      top = top + 40
    end
    for index = 1, Gallery.shown or 0 do
      local card = cards[index]
      local column, row = (index - 1) % columns, floor((index - 1) / columns)
      card:SetWidth(cardWidth)
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + column * (cardWidth + GAP), -top - row * (CARD_H + GAP))
    end
    local rows = floor(((Gallery.shown or 0) + columns - 1) / columns)
    self.height = top + rows * (CARD_H + GAP) + 6
    frame:SetHeight(self.height)
    return self.height
  end

  control.GetHeight = function(self) return self.height or 200 end
  control.Restyle = function() Gallery:Restyle() end
  control.SetLabel = function() end
  control.SetHelp = function() end
  control.SetDisabled = function() end
  control.SetModified = function() end
  control.SetCallback = function() end
  control.SetOnRevert = function() end

  return control
end

function Gallery:Select(number, clearFilters)
  self.selected = number
  -- a pet opened from the window's search is shown whatever the filters were
  if clearFilters then
    self.filter, self.query = "all", ""
    if self.control then self.control.search:SetText("") end
  end
end

function Gallery:Update()
  local control = self.control
  if not control then return end
  local all, current = Core.GetKnownPets(), Core.GetCurrentPet()

  -- The pet that is out, or the first one, until you pick another.
  local valid = false
  for _, entry in ipairs(all) do if entry.number == self.selected then valid = true end end
  if not valid then
    self.selected = current and current.number or (all[1] and all[1].number)
  end

  local counts, shown, selectedEntry = { all = #all, active = 0, stabled = 0 }, 0, nil
  for _, entry in ipairs(all) do
    local key = Core.IsActiveSlot(entry.pet) and "active" or "stabled"
    counts[key] = counts[key] + 1
    if entry.number == self.selected then selectedEntry = entry end
    if Matches(entry) then
      shown = shown + 1
      local card = cards[shown] or CreateCard(control.frame, shown)
      FillCard(card, entry, current)
      card:Show()
    end
  end
  for index = shown + 1, #cards do cards[index]:Hide() end
  self.shown = shown

  local labels = {
    all = L["All"],
    active = Core.isForever and L["Current pet"] or L["Call slots"],
    stabled = L["Stabled"],
  }
  for _, chip in ipairs(control.chips) do
    chip.text:SetText(labels[chip.key] .. " (" .. counts[chip.key] .. ")")
    chip.selected = self.filter == chip.key
    chip:Restyle()
  end

  if selectedEntry then
    FillDetail(control.detail, selectedEntry)
    control.detail:Show()
  else
    control.detail:Hide()
  end

  local message
  if #all == 0 then
    message = Core.IsHunter()
      and L["No pets known yet. Call your pets, or visit a stable master to list every pet in your stable."]
      or L["Hunter pets appear here when you play a Hunter."]
  elseif shown == 0 then
    message = L["No pet matches. Try All, or clear the search."]
  end
  control.empty:SetText(message or "")
  control.empty:SetShown(message ~= nil)
  -- with no pets at all, the search and filters have nothing to work on
  for _, chip in ipairs(control.chips) do chip:SetShown(#all > 0) end
  control.search:SetShown(#all > 0)
  self:Restyle()
end

function Gallery:Restyle()
  local control = self.control
  if not control then return end
  control.searchBackdrop:SetBackdropColor(unpack(Kit.InsetColor))
  Kit.SetBorderColor(control.searchBackdrop, Kit.BorderIdle)
  control.search:SetTextColor(unpack(Kit.TextHighlight))
  SetColour(control.placeholder, Kit.TextDisabled)
  SetColour(control.empty, Kit.TextNormal)
  for _, chip in ipairs(control.chips) do chip:Restyle() end
  for index = 1, self.shown or 0 do StyleCard(cards[index]) end
  if control.detail:IsShown() then control.detail:Restyle() end
end

-- A model left loaded behind a closed window still costs memory.
function Gallery:OnHide()
  if self.control then
    self.control.detail.model:ClearModel()
    self.control.detail.model.displayID = nil
  end
end
