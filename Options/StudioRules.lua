-- StudioRules.lua - the Rules page as the AzUI Feature Plan draws it: one row per
-- rule that reads as a sentence.
--
--   ⋮⋮  [on]  When [In combat] [value]  show [colour] [Pulse]  on [Health bar]  🔈 Try  •  +  ✕
--              and  [In a raid] [value]  ✕                       (a second condition)
--
-- Drag a row by its handle to change which rule wins. A rule that is off is dimmed;
-- the one showing now wears a gold dot. + adds a second condition, which must be true
-- as well; it gets a line of its own. Clicking "When" or "and" turns that condition
-- around ("When not"). Try shows the rule on your bars for a few seconds; the speaker
-- picks a sound the rule plays when it starts.
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

local ROW_H, ROW_GAP, LINE_H = 46, 8, 34
local HEAD_H, FOOT_H = 74, 30
-- Every condition has a picture in the Studio art pack; a role has one per role.
-- Without the pack a row shows the game's own icon for its condition.
local ROLE_ICONS = { TANK = "role-tank", HEALER = "role-healer", DAMAGER = "role-damager" }
local PACK_ICONS = {
  combat = true, threat = true, casting = true, group = true, instance = true, mythicplus = true, delve = true,
  zone = true, mounted = true, flying = true, vehicle = true, resting = true, stealth = true, dead = true,
  pet = true, warmode = true, time = true, spec = true, aura = true,
  role = function(value) return ROLE_ICONS[value] or "role-damager" end,
}

local function RuleList() return P.DB.profile.rules end

local function Changed()
  P.RulesChanged()
end

---------------------------------------------------------------------
-- A row
---------------------------------------------------------------------
-- A value list and a box to type one in, for the first (which = 1) or second condition.
local function ValueControls(row, which)
  local valueKey = which == 1 and "value" or "value2"
  local function rule() return RuleList()[row.index] end
  local function condition() return P.CONDITIONS[rule()[which == 1 and "condition" or "condition2"]] end
  local box = Studio.Edit(row, 110, 26, function(_, text)
    local c = condition()
    if Kit.Controls and Kit.Controls.CloseDropdown then Kit.Controls.CloseDropdown() end
    if c and c.input then rule()[valueKey] = c.input.parse(text, rule()[valueKey]); Changed() end
  end)
  -- names to pick from as you type (a buff's): the part after the last comma is looked up
  box:HookScript("OnTextChanged", function(self, userInput)
    local c = condition()
    local Controls = Kit.Controls
    if not (userInput and c and c.input and c.input.suggest and Controls and Controls.OpenList) then return end
    local text = P.PlainSeparators(self:GetText() or "")
    local head, last = text:match("^(.*,)%s*([^,]*)$")
    if not head then head, last = "", text end
    last = strtrim(last)
    local names = #last >= 2 and c.input.suggest(last) or {}
    if #names == 0 then
      if Controls.IsDropdownOpen() then Controls.CloseDropdown() end
      return
    end
    local list = {}
    for _, name in ipairs(names) do list[name] = name end
    -- a new owner each time, so the list follows the typing instead of closing
    Controls.OpenList({
      box = self, list = list, order = names,
      SetValue = function() end,
      Fire = function(_, name)
        local chosen = (head ~= "" and (head .. " ") or "") .. name
        self:SetText(chosen)
        rule()[valueKey] = c.input.parse(chosen, rule()[valueKey])
        self:ClearFocus()
        Changed()
      end,
    })
  end)
  Studio.Tooltip(box,
    function() local c = condition(); return c and c.input and c.input.label end,
    function() local c = condition(); return c and c.input and c.input.help end)
  local list = Studio.Dropdown(row, 110, function(key)
    rule()[valueKey] = key
    Changed()
  end)
  return list, box
end

-- "When" / "When not", "and" / "and not": a word that turns its condition around.
local function NotToggle(row, which)
  local key = which == 1 and "negate" or "negate2"
  local button = CreateFrame("Button", nil, row)
  button:SetHeight(22)
  button.text = Studio.Label(button, 12, "body", Kit.TextDisabled)
  button.text:SetPoint("LEFT")
  local function Colour(self)
    local colour = self.hovered and Kit.TextHighlight or (self.negate and Kit.TextSelected or Kit.TextDisabled)
    self.text:SetTextColor(colour[1], colour[2], colour[3])
  end
  function button:Set(negate)
    self.negate = negate and true or false
    local word = which == 1 and L["When"] or L["and"]
    self.text:SetText(negate and (word .. " " .. L["not"]) or word)
    self:SetWidth(math.max(28, (self.text:GetStringWidth() or 30) + 6))
    Colour(self)
  end
  button:SetScript("OnEnter", function(self) self.hovered = true; Colour(self) end)
  button:SetScript("OnLeave", function(self) self.hovered = nil; Colour(self) end)
  button:SetScript("OnClick", function()
    local rule = RuleList()[row.index]
    rule[key] = not rule[key] or nil
    Changed()
  end)
  Studio.Tooltip(button, L["Turn it around"], L["Click to show the rule while this is not true, such as not in a group."])
  return button
end

local function CreateRow(control, index)
  local row = CreateFrame("Frame", nil, control.frame)
  row:SetHeight(ROW_H)
  row.round = Studio.Round(row, 6)

  row.grip = CreateFrame("Button", nil, row)
  row.grip:SetSize(16, 24)
  row.grip:SetPoint("TOPLEFT", 10, -(ROW_H - 24) / 2)
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

  -- the condition's icon: the Studio art pack's picture, or the game's own icon
  if Studio.Pack and Studio.Pack.conditions then
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
  end
  row.when = NotToggle(row, 1)
  row.condition = Studio.Dropdown(row, 140, function(key) P.SetRuleCondition(RuleList()[row.index], 1, key) end)
  row.condition:SetList(P.CONDITION_VALUES, P.CONDITION_SORTING)
  -- a value picked from a list, or typed in (a buff's spell, a zone's name)
  row.value, row.spell = ValueControls(row, 1)

  row.show = Studio.Label(row, 12, "body", Kit.TextDisabled)
  row.show:SetText(L["show"])
  row.colour = Studio.ColourButton(row, 40, 24,
    function() return unpack(RuleList()[row.index].color) end,
    function(r, g, b, a) RuleList()[row.index].color = { r, g, b, a or 1 }; P.Repaint() end,
    function() P.RefreshOptions() end)
  Studio.Tooltip(row.colour, L["Colour"], L["Click to pick this rule's colour."])
  -- the other colour, while the rule's effect has one (Two-tone, Gradient, Flow)
  row.colour2 = Studio.ColourButton(row, 24, 24,
    function() local c = RuleList()[row.index].color2 or P.DB.profile.secondColor; return c[1], c[2], c[3], 1 end,
    function(r, g, b) RuleList()[row.index].color2 = { r, g, b, 1 }; P.Repaint() end,
    function() P.RefreshOptions() end)
  Studio.Tooltip(row.colour2, L["Second Colour"], L["The other colour of Two-tone, and the far end of Gradient and Flow. Until you pick one, the Second Colour on the Health Bar page is used."])
  row.effect = Studio.Dropdown(row, 104, function(key)
    local function apply() RuleList()[row.index].effect = key; P.UpdateAnimator(); Changed() end
    local question = P.EffectConfirm(key)
    if question then Kit.Confirm(question, apply) else apply() end
  end)
  -- rules can also be coloured by your health
  row.effect:SetList(P.RULE_EFFECT_VALUES, P.RULE_EFFECTS)

  row.on = Studio.Label(row, 12, "body", Kit.TextDisabled)
  row.on:SetText(L["on"])
  row.target = Studio.Dropdown(row, 150, function(key)
    RuleList()[row.index].target = key
    Changed()
  end)
  row.target:SetList(P.RULE_TARGETS, P.RULE_TARGET_SORTING)

  local function GlyphButton(glyph, onClick)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(20, 20)
    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    Studio.Glyph(texture, glyph)
    button.texture = texture
    button:SetScript("OnEnter", function() texture:SetVertexColor(1, 1, 1) end)
    button:SetScript("OnLeave", function() texture:SetVertexColor(unpack(Studio.C.faint)) end)
    button:SetScript("OnClick", onClick)
    return button
  end

  row.delete = GlyphButton("cross", function()
    Kit.Confirm(L["Delete this rule?"], function() P.DeleteRule(row.index) end)
  end)
  row.delete:SetPoint("TOPRIGHT", -10, -(ROW_H - 20) / 2)
  row.cross = row.delete.texture

  -- a second condition that must be true as well
  row.addCondition = GlyphButton("plus", function() P.SetRuleCondition(RuleList()[row.index], 2, "combat") end)
  row.addCondition:SetPoint("RIGHT", row.delete, "LEFT", -6, 0)
  Studio.Tooltip(row.addCondition, L["Add a second condition"],
    L["The rule then shows only while both are true, such as in a raid and in combat."])

  row.live = row:CreateTexture(nil, "OVERLAY")
  row.live:SetSize(8, 8)
  Studio.Circle(row.live)
  row.live:SetPoint("RIGHT", row.addCondition, "LEFT", -8, 0)

  -- show it now, for a few seconds, wherever you are
  row.try = Studio.Button(row, 26, 22, "", function() P.TryRule(RuleList()[row.index]) end)
  row.try:SetIcon("play")
  row.try:SetPoint("RIGHT", row.live, "LEFT", -8, 0)
  Studio.Tooltip(row.try, L["Try this rule"], L["Shows the rule on its bars for five seconds, whether or not it would match now."])

  -- a sound when it starts: a speaker that opens the list of sounds
  row.sound = Studio.Dropdown(row, 26, function(key) P.SetRuleSound(RuleList()[row.index], key) end)
  row.sound:SetList(P.RULE_SOUND_VALUES, P.RULE_SOUND_ORDER)
  row.sound.text:Hide()
  row.sound.chevron:Hide()
  row.speaker = row.sound:CreateTexture(nil, "OVERLAY")
  row.speaker:SetSize(16, 16)
  row.speaker:SetPoint("CENTER")
  row.sound:SetPoint("RIGHT", row.try, "LEFT", -6, 0)
  Studio.Tooltip(row.sound, L["Sound"], function()
    local rule = RuleList()[row.index]
    local sound = rule and P.RULE_SOUNDS[rule.sound or "none"]
    return (sound and sound.label or "") .. "\n" .. L["A sound when the rule starts showing. It plays on the Master channel, so it is heard with sound effects off."]
  end)

  -- the second condition's line
  row.also = NotToggle(row, 2)
  row.condition2 = Studio.Dropdown(row, 140, function(key) P.SetRuleCondition(RuleList()[row.index], 2, key) end)
  row.condition2:SetList(P.CONDITION_VALUES, P.CONDITION_SORTING)
  row.value2, row.spell2 = ValueControls(row, 2)
  row.removeCondition = GlyphButton("cross", function() P.SetRuleCondition(RuleList()[row.index], 2, "none") end)
  Studio.Tooltip(row.removeCondition, L["Remove the second condition"])
  row.removeCondition.texture:SetVertexColor(unpack(Studio.C.faint))

  control.rows[index] = row
  return row
end

-- Which value controls and second-line parts a row shows.
local function ShowParts(row)
  row.value:SetShown(row.hasValue and not row.input)
  row.spell:SetShown(row.hasValue and row.input or false)
  local second = row.second
  for _, part in ipairs({ row.also, row.condition2, row.removeCondition }) do part:SetShown(second) end
  row.value2:SetShown(second and row.hasValue2 and not row.input2 or false)
  row.spell2:SetShown(second and row.hasValue2 and row.input2 or false)
  row.addCondition:SetShown(not second)
end

-- Lays a row out across `width`, giving the dropdowns what the labels leave.
local function LayoutRow(row, width)
  local hasValue = row.hasValue
  -- "When" and "and" share one width, so both conditions start in one column
  local words = math.max(row.when:GetWidth() or 28, row.second and row.also:GetWidth() or 0)
  row.when:SetWidth(words)
  row.also:SetWidth(words)
  local fixed = 10 + 16 + 8 + 36 + 12   -- grip, switch
    + (row.when:GetWidth() or 36) + 6   -- "When" / "When not"
    + 8 + 38                            -- "show"
    + 40 + 8 + (row.hasSecond and 28 or 0) -- colour, and the second colour
    + 8 + 20                            -- "on"
    + 8 + 26 + 6 + 26 + 8 + 8 + 8 + 20 + 6 + 20 + 10 -- sound, Try, live dot, +, delete
  local free = max(300, width - fixed - (hasValue and 8 or 0) - (row.icon and 24 or 0))
  local cond = floor(free * (hasValue and .27 or .38))
  local value = hasValue and floor(free * .22) or 0
  local effect = floor(free * .22)
  local target = free - cond - value - effect
  local middle = -(ROW_H / 2) -- the first line's centre

  row.when:ClearAllPoints()
  if row.icon then
    row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", row.switch, "RIGHT", 10, 0)
    row.when:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  else
    row.when:SetPoint("LEFT", row.switch, "RIGHT", 12, 0)
  end
  row.condition:SetWidth(cond)
  row.condition:ClearAllPoints(); row.condition:SetPoint("LEFT", row.when, "RIGHT", 6, 0)
  local after = row.condition
  local box = row.input and row.spell or row.value
  if hasValue then
    box:SetWidth(value)
    box:ClearAllPoints(); box:SetPoint("LEFT", row.condition, "RIGHT", 8, 0)
    after = box
  end
  ShowParts(row)
  row.show:ClearAllPoints(); row.show:SetPoint("LEFT", after, "RIGHT", 8, 0)
  row.colour:ClearAllPoints(); row.colour:SetPoint("LEFT", row.show, "LEFT", 38, 0)
  row.colour2:SetShown(row.hasSecond or false)
  row.colour2:ClearAllPoints(); row.colour2:SetPoint("LEFT", row.colour, "RIGHT", 4, 0)
  row.effect:SetWidth(effect)
  row.effect:ClearAllPoints(); row.effect:SetPoint("LEFT", row.hasSecond and row.colour2 or row.colour, "RIGHT", 8, 0)
  row.on:ClearAllPoints(); row.on:SetPoint("LEFT", row.effect, "RIGHT", 8, 0)
  row.target:SetWidth(target)
  row.target:ClearAllPoints(); row.target:SetPoint("LEFT", row.on, "LEFT", 20, 0)
  row.grip:ClearAllPoints(); row.grip:SetPoint("LEFT", row, "TOPLEFT", 10, middle)

  -- the second line, under the first condition
  if not row.second then return end
  row.also:ClearAllPoints(); row.also:SetPoint("TOPLEFT", row.when, "BOTTOMLEFT", 0, -(LINE_H - 22))
  row.condition2:SetWidth(cond)
  row.condition2:ClearAllPoints(); row.condition2:SetPoint("LEFT", row.condition, "LEFT", 0, -LINE_H)
  local after2 = row.condition2
  if row.hasValue2 then
    local box2 = row.input2 and row.spell2 or row.value2
    box2:SetWidth(max(value, floor(free * .22)))
    box2:ClearAllPoints(); box2:SetPoint("LEFT", row.condition2, "RIGHT", 8, 0)
    after2 = box2
  end
  row.removeCondition:ClearAllPoints(); row.removeCondition:SetPoint("LEFT", after2, "RIGHT", 8, 0)
end

-- One condition's value controls, filled from the rule.
local function FillValue(list, box, condition, value)
  local input = condition and condition.input
  if input then
    box:SetValue(value ~= nil and input.format(value) or "")
  elseif condition and condition.hasValue then
    list:SetList(condition.values(), condition.sorting)
    list:SetValue(value)
  end
  return condition and condition.hasValue or false, input ~= nil
end

local function FillRow(row, index, rule)
  row.index = index
  local condition = P.CONDITIONS[rule.condition]
  row.switch:SetOn(rule.enabled)
  row.when:Set(rule.negate)
  row.condition:SetValue(rule.condition)
  row.hasValue, row.input = FillValue(row.value, row.spell, condition, rule.value)
  if row.icon then
    local pack = PACK_ICONS[rule.condition]
    -- a buff rule shows its buff's own icon, which says which buff it is
    local spell = rule.condition == "aura" and condition and condition.icon and condition.icon(rule.value)
    if spell then
      row.icon:SetTexture(spell)
      row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      row.icon:SetVertexColor(1, 1, 1)
    elseif pack then
      row.icon:SetTexture(Studio.PackMedia("condition-" .. (type(pack) == "function" and pack(rule.value) or rule.condition)))
      row.icon:SetTexCoord(0, 1, 0, 1)
      row.icon:SetVertexColor(unpack(Kit.TextSelected))
    else
      -- the game's own icon, in its own colours (a buff shows the spell's)
      local icon = condition and condition.icon and condition.icon(rule.value)
      row.icon:SetTexture(icon or 134400)
      row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      row.icon:SetVertexColor(1, 1, 1)
    end
  end
  row.second = rule.condition2 ~= nil
  if row.second then
    row.also:Set(rule.negate2)
    row.condition2:SetValue(rule.condition2)
    row.hasValue2, row.input2 = FillValue(row.value2, row.spell2, P.CONDITIONS[rule.condition2], rule.value2)
  end
  row.rowHeight = row.second and ROW_H + LINE_H or ROW_H
  row:SetHeight(row.rowHeight)
  ShowParts(row)
  row.colour:Update()
  row.hasSecond = P.UsesSecondColour(rule.effect)
  row.colour2:Update()
  row.effect:SetValue(rule.effect)
  row.target:SetValue(rule.target)
  row.live:SetShown(P.RuleShowing(rule))
  -- the speaker: gold when the rule has a sound, muted and faint when it has none
  local loud = rule.sound ~= nil
  Studio.Glyph(row.speaker, loud and "speaker" or "speaker-mute")
  row.speaker:SetVertexColor(unpack(loud and Kit.TextSelected or Studio.C.faint))
  row.speaker:SetAlpha(loud and 1 or .7)
  row.sound:SetValue(rule.sound or "none")
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
  control.examples = Studio.Button(frame, 170, 28, L["Add example rules"], function() P.AddExampleRules() end)
  control.examples:SetIcon("section-packs")
  control.examples:SetPoint("RIGHT", control.add, "LEFT", -10, 0)
  Studio.Tooltip(control.examples, L["Add example rules"],
    L["Five rules many players use, added switched off: grey while dead, a red pulse in combat, violet in stealth, gold in raids and green while resting."])
  Studio.Tooltip(control.add, L["Add Rule"], L["Adds a rule at the bottom of the list. Drag it up to let it win over the others."])
  -- ready-made rules, one at a time, added switched off
  local recipes = Studio.Dropdown(frame, 270, function(key)
    P.AddRuleRecipe(key)
    control.recipes:SetValue(nil)
    control.recipes.text:SetText(L["Add a ready-made rule…"])
  end)
  recipes:SetList(P.RULE_RECIPE_VALUES, P.RULE_RECIPE_ORDER)
  recipes:SetValue(nil)
  recipes.text:SetText(L["Add a ready-made rule…"])
  recipes.dim = true
  recipes:SetPoint("TOPRIGHT", control.add, "BOTTOMRIGHT", 0, -6)
  Studio.Tooltip(recipes, L["Ready-made rules"], L["Adds the rule you pick at the bottom of the list, switched off. Try it, then switch it on."])
  control.recipes = recipes

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
  for _, row in ipairs(control.rows) do
    if row:IsShown() then
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", control.frame, "TOPLEFT", 0, -y)
      row:SetWidth(width)
      LayoutRow(row, width)
      y = y + (row.rowHeight or ROW_H) + ROW_GAP
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
    row.addCondition.texture:SetVertexColor(unpack(C.faint))
    row.removeCondition.texture:SetVertexColor(unpack(C.faint))
    row.live:SetVertexColor(unpack(Kit.TextSelected))
    row.switch:Restyle()
    for _, box in ipairs({ row.condition, row.value, row.effect, row.target, row.spell, row.condition2, row.value2, row.spell2, row.sound }) do
      box:Restyle()
    end
    row.try:Restyle()
    row.when:Set(row.when.negate)
    row.also:Set(row.also.negate)
  end
  control.add:Restyle()
  control.examples:Restyle()
  control.recipes:Restyle()
end
