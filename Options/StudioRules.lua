-- StudioRules.lua - the Rules page as the AzUI Feature Plan draws it: one row per
-- rule that reads as a sentence.
--
--   ⋮⋮  [on]  When [In combat] [value]  show [colour] [Pulse]  on [Health bar]  ✕
--
-- Drag a row by its handle to change which rule wins. A rule that is off is dimmed;
-- the one showing now wears a gold dot.
local _, ns = ...
local Kit = ns.OptionsKit
local Studio = Kit.Studio
local P = ns.P
if not (Studio and Studio.Button and P) then return end

local L = ns.L
local max, floor = math.max, math.floor
local unpack = unpack

local Rules = {}
Kit.StudioRules = Rules

local ROW_H, ROW_GAP = 46, 8
local HEAD_H, FOOT_H = 40, 30

local function RuleList() return P.DB.profile.rules end

local function Changed()
  P.RulesChanged()
end

---------------------------------------------------------------------
-- A row
---------------------------------------------------------------------
local function CreateRow(control, index)
  local row = CreateFrame("Frame", nil, control.frame)
  row:SetHeight(ROW_H)
  row.round = Studio.Round(row, 6)

  row.grip = CreateFrame("Button", nil, row)
  row.grip:SetSize(16, 24)
  row.grip:SetPoint("LEFT", 10, 0)
  local grip = row.grip:CreateTexture(nil, "ARTWORK")
  grip:SetAllPoints()
  Studio.Glyph(grip, "grip")
  row.gripTexture = grip
  row.grip:RegisterForDrag("LeftButton")
  row.grip:SetScript("OnDragStart", function() control.dragging = row.index; row:SetAlpha(.4) end)
  row.grip:SetScript("OnDragStop", function()
    local from = control.dragging
    control.dragging = nil
    row:SetAlpha(1)
    for _, other in ipairs(control.rows) do
      if other:IsShown() and other ~= row and other:IsMouseOver() then P.PlaceRule(from, other.index); return end
    end
  end)
  Studio.Tooltip(row.grip, L["Drag to reorder"], L["The first rule that matches wins for each bar."])

  row.switch = Studio.Switch(row, function(_, on)
    RuleList()[row.index].enabled = on
    Changed()
  end)
  row.switch:SetPoint("LEFT", row.grip, "RIGHT", 8, 0)

  -- the condition's icon, from the Studio art pack when it is installed
  if Studio.Pack and Studio.Pack.conditions then
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
  end
  row.when = Studio.Label(row, 12, "body", Kit.TextDisabled)
  row.when:SetText(L["When"])
  row.condition = Studio.Dropdown(row, 140, function(key)
    local rule = RuleList()[row.index]
    rule.condition = key
    rule.value = (key == "spec" and P.Specialization()) or (key == "instance" and "any") or nil
    Changed()
  end)
  row.condition:SetList(P.CONDITION_VALUES, P.CONDITION_SORTING)
  row.value = Studio.Dropdown(row, 110, function(key)
    RuleList()[row.index].value = key
    Changed()
  end)

  row.show = Studio.Label(row, 12, "body", Kit.TextDisabled)
  row.show:SetText(L["show"])
  row.colour = Studio.ColourButton(row, 40, 24,
    function() return unpack(RuleList()[row.index].color) end,
    function(r, g, b, a) RuleList()[row.index].color = { r, g, b, a or 1 }; P.Repaint() end,
    function() P.RefreshOptions() end)
  Studio.Tooltip(row.colour, L["Colour"], L["Click to pick this rule's colour."])
  row.effect = Studio.Dropdown(row, 104, function(key)
    local function apply() RuleList()[row.index].effect = key; P.UpdateAnimator(); Changed() end
    local question = P.EffectConfirm(key)
    if question then Kit.Confirm(question, apply) else apply() end
  end)
  row.effect:SetList(P.EFFECT_VALUES, P.EFFECTS)

  row.on = Studio.Label(row, 12, "body", Kit.TextDisabled)
  row.on:SetText(L["on"])
  row.target = Studio.Dropdown(row, 150, function(key)
    RuleList()[row.index].target = key
    Changed()
  end)
  row.target:SetList(P.RULE_TARGETS, P.RULE_TARGET_SORTING)

  row.delete = CreateFrame("Button", nil, row)
  row.delete:SetSize(20, 20)
  row.delete:SetPoint("RIGHT", -10, 0)
  local cross = row.delete:CreateTexture(nil, "ARTWORK")
  cross:SetAllPoints()
  Studio.Glyph(cross, "cross")
  row.cross = cross
  row.delete:SetScript("OnEnter", function() cross:SetVertexColor(1, 1, 1) end)
  row.delete:SetScript("OnLeave", function() cross:SetVertexColor(unpack(Studio.C.faint)) end)
  row.delete:SetScript("OnClick", function()
    Kit.Confirm(L["Delete this rule?"], function() P.DeleteRule(row.index) end)
  end)

  row.live = row:CreateTexture(nil, "OVERLAY")
  row.live:SetSize(8, 8)
  Studio.Circle(row.live)
  row.live:SetPoint("RIGHT", row.delete, "LEFT", -8, 0)

  control.rows[index] = row
  return row
end

-- Lays a row out across `width`, giving the dropdowns what the labels leave.
local function LayoutRow(row, width, hasValue)
  local fixed = 10 + 16 + 8 + 34 + 12   -- grip, switch
    + 36 + 8                            -- "When"
    + 8 + 38                            -- "show"
    + 40 + 8                            -- colour
    + 8 + 20                            -- "on"
    + 8 + 8 + 8 + 20 + 10               -- live dot, delete
  local free = max(300, width - fixed - (hasValue and 8 or 0) - (row.icon and 24 or 0))
  local cond = floor(free * (hasValue and .27 or .38))
  local value = hasValue and floor(free * .22) or 0
  local effect = floor(free * .22)
  local target = free - cond - value - effect

  row.when:ClearAllPoints()
  if row.icon then
    row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", row.switch, "RIGHT", 10, 0)
    row.when:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  else
    row.when:SetPoint("LEFT", row.switch, "RIGHT", 12, 0)
  end
  row.condition:SetWidth(cond)
  row.condition:ClearAllPoints(); row.condition:SetPoint("LEFT", row.when, "LEFT", 36, 0)
  local after = row.condition
  if hasValue then
    row.value:SetWidth(value)
    row.value:ClearAllPoints(); row.value:SetPoint("LEFT", row.condition, "RIGHT", 8, 0)
    after = row.value
  end
  row.value:SetShown(hasValue)
  row.show:ClearAllPoints(); row.show:SetPoint("LEFT", after, "RIGHT", 8, 0)
  row.colour:ClearAllPoints(); row.colour:SetPoint("LEFT", row.show, "LEFT", 38, 0)
  row.effect:SetWidth(effect)
  row.effect:ClearAllPoints(); row.effect:SetPoint("LEFT", row.colour, "RIGHT", 8, 0)
  row.on:ClearAllPoints(); row.on:SetPoint("LEFT", row.effect, "RIGHT", 8, 0)
  row.target:SetWidth(target)
  row.target:ClearAllPoints(); row.target:SetPoint("LEFT", row.on, "LEFT", 20, 0)
end

local function FillRow(row, index, rule)
  row.index = index
  local condition = P.CONDITIONS[rule.condition]
  row.switch:SetOn(rule.enabled)
  row.condition:SetValue(rule.condition)
  if row.icon then
    row.icon:SetTexture(Studio.PackMedia("condition-" .. rule.condition))
    row.icon:SetVertexColor(unpack(Kit.TextSelected))
  end
  row.hasValue = condition and condition.hasValue or false
  row.value:SetShown(row.hasValue)
  if row.hasValue then
    row.value:SetList(condition.values(), rule.condition == "instance" and P.INSTANCE_SORTING or nil)
    row.value:SetValue(rule.value)
  end
  row.colour:Update()
  row.effect:SetValue(rule.effect)
  row.target:SetValue(rule.target)
  local live = P.ActiveRule("player") == rule or P.ActiveRule("pet") == rule
  row.live:SetShown(live)
  row:SetAlpha(rule.enabled and 1 or .55)
end

---------------------------------------------------------------------
-- The control
---------------------------------------------------------------------
function Rules:GetControl(parent)
  if self.control then return self.control end
  local control = { kind = "studio", first = true, rows = {} }
  self.control = control
  local frame = CreateFrame("Frame", nil, parent)
  control.frame = frame

  control.hint = Studio.Label(frame, 12, "body", Kit.TextDisabled)
  control.hint:SetPoint("TOPLEFT", 2, -12)
  control.hint:SetText(L["First matching rule wins · drag to reorder"])
  control.add = Studio.Button(frame, 110, 28, L["+ Add rule"], function() P.AddRule() end, "gold")
  control.add:SetPoint("TOPRIGHT", -2, -4)
  control.examples = Studio.Button(frame, 150, 28, L["Add example rules"], function() P.AddExampleRules() end)
  control.examples:SetPoint("RIGHT", control.add, "LEFT", -10, 0)
  Studio.Tooltip(control.examples, L["Add example rules"],
    L["Five rules many players use, added switched off: grey while dead, a red pulse in combat, violet in stealth, gold in raids and green while resting."])
  Studio.Tooltip(control.add, L["Add Rule"], L["Adds a rule at the bottom of the list. Drag it up to let it win over the others."])

  control.empty = Studio.Label(frame, 13, "body", Kit.TextDisabled)
  control.empty:SetWordWrap(true)
  control.empty:SetText(L["No rules yet. A rule shows its colour while something is true: in combat, mounted, in a dungeon and so on."])
  if Studio.Pack and Studio.Pack.emptyRules then
    control.emptyArt = frame:CreateTexture(nil, "ARTWORK")
    control.emptyArt:SetTexture(Studio.PackMedia("empty-rules"))
    control.emptyArt:SetSize(256, 128)
  end
  control.footer = Studio.Label(frame, 12, "body", Kit.TextDisabled)
  control.footer:SetText(L["No rule matches → pet colour → your own colour"])

  control.Update = function() Rules:Update() end
  control.Measure = function(c, width) return Rules:Layout(width) end
  control.GetHeight = function(c) return c.height or 200 end
  control.Restyle = function() Rules:Restyle() end
  for _, method in ipairs({ "SetLabel", "SetHelp", "SetDisabled", "SetModified", "SetCallback", "SetOnRevert" }) do
    control[method] = function() end
  end
  return control
end

function Rules:Update()
  local control = self.control
  if not control or not P.DB then return end
  local rules = RuleList()
  for index, rule in ipairs(rules) do
    local row = control.rows[index] or CreateRow(control, index)
    FillRow(row, index, rule)
    row:Show()
  end
  for index = #rules + 1, #control.rows do control.rows[index]:Hide() end
  control.empty:SetShown(#rules == 0)
  self:Restyle()
end

function Rules:Layout(width)
  local control = self.control
  width = max(560, (width or 600) - 12)
  local y = HEAD_H
  for index, row in ipairs(control.rows) do
    if row:IsShown() then
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", control.frame, "TOPLEFT", 0, -y)
      row:SetWidth(width)
      LayoutRow(row, width, row.hasValue)
      y = y + ROW_H + ROW_GAP
    end
  end
  if control.emptyArt then
    control.emptyArt:SetShown(control.empty:IsShown())
    if control.empty:IsShown() then
      control.emptyArt:ClearAllPoints()
      control.emptyArt:SetPoint("TOP", control.frame, "TOP", 0, -y)
      y = y + 136
    end
  end
  if control.empty:IsShown() then
    control.empty:ClearAllPoints()
    control.empty:SetPoint("TOPLEFT", control.frame, "TOPLEFT", 2, -y - 6)
    control.empty:SetWidth(width)
    y = y + 44
  end
  control.footer:ClearAllPoints()
  control.footer:SetPoint("TOPLEFT", control.frame, "TOPLEFT", 2, -y - 6)
  control.height = y + FOOT_H + 10
  control.frame:SetHeight(control.height)
  return control.height
end

function Rules:Restyle()
  local control = self.control
  if not control then return end
  local C = Studio.C
  for _, row in ipairs(control.rows) do
    row.round:SetFill(Kit.BackdropColor)
    row.round:SetEdge(C.line)
    row.gripTexture:SetVertexColor(unpack(C.faint))
    row.cross:SetVertexColor(unpack(C.faint))
    row.live:SetVertexColor(unpack(Kit.TextSelected))
    row.switch:Restyle()
    for _, box in ipairs({ row.condition, row.value, row.effect, row.target }) do box:Restyle() end
  end
  control.add:Restyle()
  control.examples:Restyle()
end
