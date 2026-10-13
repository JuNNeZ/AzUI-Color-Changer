-- The ABCS window.
--
-- Laid out the way AzeriteUI's own options window is (Options/Kit/Panel.lua in the
-- JuNNeZ Edition): a sculpted casing around a plain fill, a header with the addon's
-- name, one search box across the whole window, a rail of pages down the left, and
-- the page itself filling the rest under a heading. AceConfigDialog is not involved;
-- the option table is read by Config.lua and drawn by Renderer.lua, so the classic
-- window (/ahui classic) and this one always show the same settings.
--
-- The Hunter Pets page is the exception: its pets are drawn by PetGallery.lua.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Config, Renderer, Controls = Kit.Config, Kit.Renderer, Kit.Controls
local Core = ns.Core
if not (Config and Renderer and Controls and Core) then return end

local L = ns.L
local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local max, min = math.max, math.min
local unpack = unpack
local string_find, string_lower = string.find, string.lower

local Panel = {}
Kit.Panel = Panel

local APP = Core.appName

-- Options the addon keeps out of this window (pets, which the gallery draws).
local function HiddenHere(option)
  local meta = ns.PanelMeta and ns.PanelMeta[option]
  return meta and meta.hidden
end
local OPTIONS = Core.options

local DEFAULT_W, DEFAULT_H = 860, 640 -- Studio: 940 by 680, set when the window is built
local MIN_W, MIN_H = 720, 500
local RAIL_W = 190
local HEADER_H = 44
local SEARCH_H = 34
local FOOTER_H = 24
local PAGE_HEAD_H = 54
local RAIL_ROW_H = 30
local RESULT_H = 40
-- room right of the page for its scrollbar, and the bar's own width
local SCROLLBAR_ROOM, SCROLLBAR_W, THUMB_MIN = 24, 6, 28

local WINDOW_PAGE = "window"
local PETS_PAGE = "pets"

local frame, page, rail, contentScroll, pageContent
local resultsScroll, resultsContent
local railRows, resultRows = {}, {}
Panel.railRows = railRows -- for the tests

local function Settings()
  local db = Core.GetDB()
  return db and db.global.panel
end

local function Resolve(value, ...)
  if type(value) == "function" then
    local ok, result = pcall(value, ...)
    return ok and result or nil
  end
  return value
end

--------------------------------------------------------------------------
-- The window's own settings
--------------------------------------------------------------------------
-- Not addon settings, so they get a rail entry of their own at the bottom rather
-- than sitting among the colours. Drawn by the same renderer as everything else.
local windowOptions = {
  type = "group", name = L["Window"], args = {
    look = { type = "header", name = L["Appearance"], order = 1 },
    theme = {
      type = "select", name = L["Theme"], order = 2,
      desc = L["The colours this window is drawn in. Azerite matches AzeriteUI's own options window."],
      values = function() return (Kit.GetThemeChoices()) end,
      sorting = function() return select(2, Kit.GetThemeChoices()) end,
      get = function() return Settings().theme end,
      set = function(_, value)
        local before = Settings().theme
        Settings().theme = value
        if Kit.ArtStyle and Kit.ArtFor and Kit.ArtFor(value) ~= Kit.ArtStyle then
          -- Studio brings its own art, which is only swapped on a reload
          Kit.Confirm(L["This theme draws the window with different art. Reload now to see it?"], ReloadUI,
            function() Settings().theme = before; Panel:ApplyTheme(); Panel:Refresh() end)
          return
        end
        Panel:ApplyTheme()
      end,
    },
    opacity = {
      type = "range", name = L["Opacity"], order = 3, isPercent = true,
      desc = L["How solid the window is drawn. At 100% nothing behind it shows through."],
      min = Kit.MinOpacity, max = 1, step = 0.05,
      get = function() return Settings().opacity end,
      set = function(_, value) Settings().opacity = value; Panel:ApplyTheme() end,
    },
    scale = {
      type = "range", name = L["Scale"], order = 4, isPercent = true,
      desc = L["The size of the whole window."],
      min = 0.7, max = 1.3, step = 0.05,
      get = function() return Settings().scale end,
      set = function(_, value) Settings().scale = value; Panel:ApplyScale() end,
    },
    resetPosition = {
      type = "execute", name = L["Reset Position"], order = 5,
      desc = L["Put the window back in the middle of the screen at its first size."],
      func = function() Panel:ResetGeometry() end,
    },
    classicHead = { type = "header", name = L["Classic Window"], order = 10 },
    classic = {
      type = "toggle", name = L["Open the Classic Window"], order = 11,
      desc = L["/ahui and the minimap button open the previous Ace3 window instead of this one. /ahui classic always opens it."],
      get = function() return Settings().classic end,
      set = function(_, value) Settings().classic = value and true or false end,
    },
    openClassic = {
      type = "execute", name = L["Open Classic Window"], order = 12,
      desc = L["The previous Ace3 window, with the same settings."],
      func = function() Panel:Close(); Core.OpenClassic() end,
    },
  },
}

--------------------------------------------------------------------------
-- Pages
--------------------------------------------------------------------------
-- The rail lists the option table's top-level groups, then the window's own page.
local function GetPages()
  local pages = {}
  Config.ForEachChild(OPTIONS, OPTIONS, {}, APP, function(key, option, path)
    if option.type ~= "group" or HiddenHere(option) then return end
    pages[#pages + 1] = {
      key = key,
      label = Config.GetName(option, OPTIONS, path, APP) or key,
      desc = Config.GetDesc(option, OPTIONS, path, APP),
      icon = Config.GetMember("icon", option, OPTIONS, path, APP),
      iconCoords = Config.GetMember("iconCoords", option, OPTIONS, path, APP),
    }
  end)
  pages[#pages + 1] = {
    key = WINDOW_PAGE, label = L["Window"], window = true,
    desc = L["How this window looks, and the classic window."],
    icon = "Interface\\Buttons\\UI-OptionsButton",
  }
  return pages
end

local PAGE_DESC = {
  general  = L["Your own health bar: its colour, effects and presets."],
  rules    = L["Colours that take over while something is true: in combat, mounted, in a dungeon."],
  pets     = L["Every pet you have tamed, with its own colour and effect."],
  families = L["The colour each pet family, and each specialization, shows by default."],
  bars     = L["The pet frames and your power bar, cast bar and class resources."],
  profiles = L["Keep different settings per character or per specialization."],
  share    = L["Copy your setup as a line of text or a link in chat, or bring in someone else's."],
}

-- The rail's own icons (Media\Studio\glyph-page-*, drawn by Tools\MakeStudioArt.py):
-- one line drawing per page, muted, gold when the page is open. The game's icons
-- the option table names were each a different style and colour, and read as noise.
local PAGE_GLYPH = {
  general = "page-health", rules = "page-rules", pets = "page-pets", families = "page-families",
  bars = "page-bars", profiles = "page-profiles", share = "page-share", [WINDOW_PAGE] = "page-window",
}

--------------------------------------------------------------------------
-- Search
--------------------------------------------------------------------------
-- Every setting on every page, by name and help text, plus every remembered pet.
local function BuildIndex()
  local index = {}
  local function walk(group, path, pageKey, pageLabel, section)
    Config.ForEachChild(group, OPTIONS, path, APP, function(key, option, childPath)
      local meta = ns.PanelMeta and ns.PanelMeta[option]
      -- drawn by a Studio page rather than as a row, but still a setting to find
      if HiddenHere(option) and not (meta and meta.studio) then return end
      local name = Config.GetName(option, OPTIONS, childPath, APP)
      if option.type == "group" then
        walk(option, childPath, pageKey, pageLabel, type(name) == "string" and name ~= "" and name or section)
      elseif option.type ~= "header" and option.type ~= "description" and type(name) == "string" then
        local desc = Config.GetDesc(option, OPTIONS, childPath, APP)
        index[#index + 1] = {
          page = pageKey, label = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""),
          where = section and (pageLabel .. " · " .. section) or pageLabel,
          text = string_lower(name .. " " .. (type(desc) == "string" and desc or "")),
        }
      end
    end)
  end
  for _, info in ipairs(GetPages()) do
    if info.window then
      walk(windowOptions, {}, info.key, info.label)
    else
      walk(OPTIONS.args[info.key], { info.key }, info.key, info.label)
    end
  end
  for _, entry in ipairs(Core.GetKnownPets()) do
    local pet = entry.pet
    local family = Core.FamilyName(pet) or ""
    index[#index + 1] = {
      page = PETS_PAGE, pet = entry.number, label = pet.name or "?",
      where = L["Hunter Pets"] .. (family ~= "" and (" · " .. family) or ""),
      text = string_lower((pet.name or "") .. " " .. family .. " " .. (pet.specialization or "")),
    }
  end
  return index
end

--------------------------------------------------------------------------
-- Rail
--------------------------------------------------------------------------
-- The open page is a key pressed up out of the rail, as AdvancedHotkeyOverlaySystem
-- draws it: a keycap in the raised colour, its icon gold. Hovering lifts a page half
-- way. The same in every look, where it used to be a gold edge outside Studio.
local function Raised()
  if Kit.ArtStyle == "studio" then return Kit.Studio.C.raised end
  local b = Kit.BackdropColor
  return { math.min(1, b[1] * 1.45 + .02), math.min(1, b[2] * 1.45 + .02), math.min(1, b[3] * 1.45 + .02), 1 }
end

local function StyleRailRow(row)
  local selected = Panel.selected == row.key
  if row.glyph then
    local c = selected and Kit.TextSelected or row.hovered and Kit.TextHighlight or Kit.TextDisabled
    row.icon:SetVertexColor(c[1], c[2], c[3])
  else
    row.icon:SetVertexColor(1, 1, 1)
  end
  row.round:SetFill((selected or row.hovered) and Raised() or nil, selected and 1 or .5)
  row.round:SetEdge(selected and Kit.BorderIdle or nil)
  local colour = selected and Kit.TextSelected or row.hovered and Kit.TextHighlight or Kit.TextNormal
  row.text:SetTextColor(colour[1], colour[2], colour[3])
  row.dot:SetVertexColor(unpack(Kit.TextSelected))
end

local function CreateRailRow(index)
  local row = CreateFrame("Button", nil, rail)
  row:SetHeight(RAIL_ROW_H)
  row.round = Kit.Studio.Round(row, 6, nil, nil, true, true)

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("LEFT", row, "LEFT", 12, 1) -- centred on the keycap face, above its lip
  row.icon = icon

  -- a gem on a page holding settings that differ from their defaults
  local dot = row:CreateTexture(nil, "OVERLAY")
  dot:SetSize(8, 8)
  dot:SetPoint("RIGHT", row, "RIGHT", -8, 1)
  Kit.SetGlyph(dot, "gem")
  dot:Hide()
  row.dot = dot

  local text = row:CreateFontString(nil, "OVERLAY")
  text:SetFontObject(Kit.GetFont(13))
  text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  text:SetPoint("RIGHT", row, "RIGHT", -20, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  row.text = text

  row:SetScript("OnClick", function(self)
    PlaySound(852)
    Panel:ClearKeyboardFocus()
    Panel:ClearSearch()
    Panel:SelectPage(self.key)
  end)
  row:SetScript("OnEnter", function(self) self.hovered = true; StyleRailRow(self) end)
  row:SetScript("OnLeave", function(self) self.hovered = nil; StyleRailRow(self) end)

  railRows[index] = row
  return row
end

function Panel:BuildRail()
  self.pages = GetPages()
  local offset, gapDone = 4, false
  for index, info in ipairs(self.pages) do
    local row = railRows[index] or CreateRailRow(index)
    -- The window's own page sits apart from the addon's pages.
    if info.window and not gapDone then offset, gapDone = offset + 14, true end
    row:ClearAllPoints()
    local pad = Kit.ArtStyle == "studio" and 8 or 4
    row:SetPoint("TOPLEFT", rail, "TOPLEFT", pad, -offset - pad)
    row:SetPoint("RIGHT", rail, "RIGHT", -6 - pad, 0)
    row.key = info.key
    row.text:SetText(info.label)
    row.glyph = PAGE_GLYPH[info.key]
    if row.glyph then
      Kit.Studio.Glyph(row.icon, row.glyph)
    else
      row.icon:SetTexture(Resolve(info.icon) or Core.icon)
      local coords = Resolve(info.iconCoords)
      if type(coords) == "table" then row.icon:SetTexCoord(unpack(coords)) else row.icon:SetTexCoord(0, 1, 0, 1) end
    end
    StyleRailRow(row)
    row:Show()
    offset = offset + RAIL_ROW_H + 2
  end
  for index = #self.pages + 1, #railRows do railRows[index]:Hide() end
  self:UpdateCounts()
end

-- The gems beside the pages and the tally under the title. Counting asks every
-- setting for its value twice, so it runs when the window opens or a page redraws,
-- not while it is merely shown.
function Panel:UpdateCounts()
  local Defaults = Kit.Defaults
  local total, first = 0, nil
  self.changedByPage = {}
  for index, info in ipairs(self.pages or {}) do
    local changed = 0
    if Defaults and not info.window then
      local ok, count = pcall(Defaults.CountModified, OPTIONS, { info.key })
      changed = ok and count or 0
    end
    local row = railRows[index]
    self.changedByPage[info.key] = changed
    if row and row.dot then row.dot:SetShown(changed > 0) end
    if changed > 0 and not first then first = info.key end
    total = total + changed
  end
  self.firstChanged = first
  if not self.count then return end
  self.count:SetShown(total > 0)
  self.count.text:SetText(total == 1 and L["1 setting changed"] or string.format(L["%d settings changed"], total))
  self.count:SetWidth(self.count.text:GetStringWidth() + 18)
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------
function Panel:SelectPage(key)
  local info
  for _, candidate in ipairs(self.pages or {}) do
    if candidate.key == key then info = candidate end
  end
  info = info or (self.pages and self.pages[1])
  if not info then return end
  if Controls.CloseDropdown then Controls.CloseDropdown() end
  if Controls.CloseColor then Controls.CloseColor() end

  local changed = self.selected ~= info.key
  self.selected = info.key
  for _, row in ipairs(railRows) do if row:IsShown() then StyleRailRow(row) end end

  self.pageTitle:SetText(info.label)
  self.pageDesc:SetText(PAGE_DESC[info.key] or (type(info.desc) == "string" and info.desc) or info.label)

  local extras = {}
  if info.key == PETS_PAGE and Kit.PetGallery then extras[1] = Kit.PetGallery:GetControl(pageContent) end
  -- Drawn first, above the page's remaining option rows
  if info.key == "general" and Kit.StudioHealth then extras[1] = Kit.StudioHealth:GetControl(pageContent) end
  if info.key == "rules" and Kit.StudioRules then extras[1] = Kit.StudioRules:GetControl(pageContent) end

  if info.window then
    page:Show(windowOptions, {}, extras)
  else
    page:Show(OPTIONS, { info.key }, extras)
  end
  page:Restyle()
  if changed then contentScroll:SetVerticalScroll(0) end
  contentScroll.scrollbar:Update()
end

-- Re-reads the open page, keeping its scroll position.
function Panel:Refresh()
  if not (frame and frame:IsShown()) or self.searching then return end
  -- A row with its colour picker or list open would be recycled under it.
  if (Controls.IsColorOpen and Controls.IsColorOpen()) or (Controls.IsDropdownOpen and Controls.IsDropdownOpen()) then
    self.pendingRefresh = true
    return
  end
  self.pendingRefresh = nil
  local scroll = contentScroll:GetVerticalScroll()
  self:BuildRail()
  self:SelectPage(self.selected)
  contentScroll:SetVerticalScroll(min(scroll, contentScroll:GetVerticalScrollRange()))
  contentScroll.scrollbar:Update()
end

-- Settings change in bursts (a pet summoned refreshes several things at once), so
-- the page is redrawn once on the next frame rather than once per change.
ns.OnOptionsChanged = function()
  if not (frame and frame:IsShown()) or Panel.refreshQueued then return end
  Panel.refreshQueued = true
  C_Timer.After(0, function()
    Panel.refreshQueued = nil
    Panel:Refresh()
  end)
end

--------------------------------------------------------------------------
-- Search results
--------------------------------------------------------------------------
local function CreateResultRow(index)
  local row = CreateFrame("Button", nil, resultsContent)
  row:SetHeight(RESULT_H)
  local highlight = row:CreateTexture(nil, "BACKGROUND")
  highlight:SetTexture(Kit.GetMedia("plain"))
  highlight:SetAllPoints()
  highlight:SetVertexColor(1, 1, 1, .04)
  highlight:Hide()
  row.highlight = highlight
  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetFontObject(Kit.GetFont(13))
  label:SetPoint("TOPLEFT", 14, -6)
  label:SetPoint("RIGHT", -12, 0)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  row.label = label
  local where = row:CreateFontString(nil, "OVERLAY")
  where:SetFontObject(Kit.GetFont(11))
  where:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
  where:SetPoint("RIGHT", -12, 0)
  where:SetJustifyH("LEFT")
  where:SetWordWrap(false)
  row.where = where
  row:SetScript("OnEnter", function(self) self.highlight:Show() end)
  row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
  row:SetScript("OnClick", function(self) Panel:OpenResult(self.result) end)
  resultRows[index] = row
  return row
end

function Panel:ShowResults(query)
  query = string_lower(strtrim(query or ""))
  if query == "" then return self:ClearSearch() end
  self.searching = true
  contentScroll:Hide()
  resultsScroll:Show()

  local matches = {}
  for _, entry in ipairs(BuildIndex()) do
    if string_find(entry.text, query, 1, true) then matches[#matches + 1] = entry end
  end

  for index, result in ipairs(matches) do
    local row = resultRows[index] or CreateResultRow(index)
    row.result = result
    row.label:SetText(result.label)
    row.label:SetTextColor(unpack(Kit.TextHighlight))
    row.where:SetText(result.where)
    row.where:SetTextColor(unpack(Kit.TextDisabled))
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", resultsContent, "TOPLEFT", 0, -(index - 1) * RESULT_H)
    row:SetPoint("RIGHT", resultsContent, "RIGHT", 0, 0)
    row:Show()
  end
  for index = #matches + 1, #resultRows do resultRows[index]:Hide() end
  resultsContent:SetHeight(max(1, #matches * RESULT_H))
  resultsScroll:SetVerticalScroll(0)
  resultsScroll.scrollbar:Update()

  self.pageTitle:SetText(L["Search"])
  self.pageDesc:SetText(#matches == 0 and L["Nothing matches that."]
    or (#matches == 1 and L["1 match. Click it to go to its page."] or (#matches .. " " .. L["matches. Click one to go to its page."])))
end

function Panel:OpenResult(result)
  if not result then return end
  self:ClearSearch(true)
  if result.pet and Kit.PetGallery then Kit.PetGallery:Select(result.pet, true) end
  self:SelectPage(result.page)
end

function Panel:ClearSearch(keepText)
  if not frame then return end
  self.searching = nil
  resultsScroll:Hide()
  contentScroll:Show()
  if not keepText then
    self.searchBox:SetText("")
    self.searchBox.placeholder:Show()
  end
  self.searchBox:ClearFocus()
  if self.selected then self:SelectPage(self.selected) end
end

--------------------------------------------------------------------------
-- The keyboard
--------------------------------------------------------------------------
-- As in JuNNeZ Edition: the window never listens to the keyboard until asked.
-- A shown frame with the keyboard on gets every key you press, so a window that
-- did that while merely open would eat W, A, S and D. The ring starts when you
-- click into the search box and ends on Escape, a mouse click, closing, or combat
-- (where an addon may not hand keys back to the game).
--
-- Tab and Shift-Tab walk search -> pages -> the page's settings. Up and Down stay
-- in the group they are in. Enter or Space does what a click does, Left and Right
-- step a list or a slider, and a letter or a digit searches.
local KEY_CONSUMED = { TAB = true, UP = true, DOWN = true, LEFT = true, RIGHT = true, ENTER = true, SPACE = true, ESCAPE = true }
local TYPED = {}
for i = 1, 26 do TYPED[string.char(64 + i)] = string.char(96 + i) end
for i = 0, 9 do TYPED[tostring(i)] = tostring(i) end

local function PageControls()
  return page and page:GetControls() or {}
end

-- Everything the ring can stop on, in the order Tab walks it.
local function FocusStops()
  local stops = { { kind = "search" } }
  for index, row in ipairs(railRows) do
    if row:IsShown() then stops[#stops + 1] = { kind = "rail", index = index } end
  end
  for index, control in ipairs(PageControls()) do
    -- a heading is not a stop, and nor is a Studio card: it takes the mouse
    if control.SetFocused and control.frame:IsShown() and control.kind ~= "header" and control.kind ~= "description" then
      stops[#stops + 1] = { kind = "control", index = index }
    end
  end
  return stops
end

local function Unmark()
  for _, control in ipairs(PageControls()) do
    if control.SetFocused and control.focused then control:SetFocused(false) end
  end
  for _, row in ipairs(railRows) do if row.focusEdge then row.focusEdge:Hide() end end
end

local function ReleaseHost(host)
  if host and host.EnableKeyboard then
    host:EnableKeyboard(false)
    host:SetScript("OnKeyDown", nil)
  end
end

function Panel:ClearKeyboardFocus()
  local was = self.keyboard
  self.keyboard = nil
  Unmark()
  ReleaseHost(self.keyboardHost)
  self.keyboardHost = nil
  return was ~= nil
end

function Panel:SetKeyboardFocus(at)
  if InCombatLockdown() then return self:ClearKeyboardFocus() end
  local stops = FocusStops()
  at = min(#stops, max(1, at or 1))
  local stop = stops[at]
  Unmark()
  self.keyboard = at

  local host
  if stop.kind == "search" then
    -- the box gets what is typed itself; its Tab is its own script
    self.searchBox:SetFocus()
  elseif stop.kind == "rail" then
    local row = railRows[stop.index]
    host = row
    self.searchBox:ClearFocus()
    if not row.focusEdge then
      local edge = row:CreateTexture(nil, "OVERLAY")
      edge:SetTexture(Kit.GetMedia("plain"))
      edge:SetWidth(2)
      edge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -1, -3)
      edge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 3)
      row.focusEdge = edge
    end
    row.focusEdge:SetVertexColor(unpack(Kit.TextSelected))
    row.focusEdge:Show()
  else
    local control = PageControls()[stop.index]
    host = control.frame
    self.searchBox:ClearFocus()
    control:SetFocused(true)
    -- a row you cannot see is not focus, it is a mark somewhere off screen
    local top, rowTop = pageContent:GetTop(), control.frame:GetTop()
    if top and rowTop then
      local offset, height = top - rowTop, contentScroll:GetHeight() or 0
      local scroll, range = contentScroll:GetVerticalScroll() or 0, contentScroll:GetVerticalScrollRange() or 0
      local rowHeight = control.frame:GetHeight() or 40
      local want = scroll
      if offset < scroll then want = offset elseif offset + rowHeight > scroll + height then want = offset + rowHeight - height end
      contentScroll:SetVerticalScroll(min(range, max(0, want)))
    end
  end

  -- only the frame the ring is on listens, and it hands back what it does not use
  if self.keyboardHost ~= host then ReleaseHost(self.keyboardHost) end
  self.keyboardHost = host
  if host and host.EnableKeyboard then
    host:EnableKeyboard(true)
    host:SetScript("OnKeyDown", function(_, key) Panel:OnKey(key) end)
  end
  return true
end

function Panel:MoveKeyboardFocus(delta)
  local stops = FocusStops()
  local at = (self.keyboard or 1) + delta
  if at < 1 then at = #stops elseif at > #stops then at = 1 end
  return self:SetKeyboardFocus(at)
end

function Panel:GetKeyboardFocus()
  local stop = self.keyboard and FocusStops()[self.keyboard]
  if stop then return stop.kind, stop.index end
end

function Panel:OnKey(key)
  local host = self.keyboardHost
  if not host then return false end
  if InCombatLockdown() then self:ClearKeyboardFocus(); return false end
  -- set first, so no early return below can swallow a key the game wants
  if host.SetPropagateKeyboardInput then host:SetPropagateKeyboardInput(not (KEY_CONSUMED[key] or TYPED[key])) end

  local kind, index = self:GetKeyboardFocus()
  if not kind then return false end
  if key == "ESCAPE" then self:ClearKeyboardFocus(); return true end
  if key == "TAB" then self:MoveKeyboardFocus(IsShiftKeyDown() and -1 or 1); return true end
  if key == "UP" or key == "DOWN" then
    local wanted = self.keyboard + (key == "DOWN" and 1 or -1)
    local stop = FocusStops()[wanted]
    if stop and stop.kind == kind then self:SetKeyboardFocus(wanted) end
    return true
  end
  if kind == "rail" and (key == "ENTER" or key == "SPACE") then
    local row = railRows[index]
    if row and row.key then
      PlaySound(852)
      self:ClearSearch()
      self:SelectPage(row.key)
      self:SetKeyboardFocus(self.keyboard)
    end
    return true
  end
  if kind == "control" then
    local control = PageControls()[index]
    if not control then return false end
    if key == "ENTER" or key == "SPACE" then
      local at = self.keyboard
      control:Activate()
      -- a box with a caret is typing now, not walking; its own Enter and Escape finish
      if control.typeBox and control.typeBox:HasFocus() then self:ClearKeyboardFocus()
      elseif self.keyboard then self:SetKeyboardFocus(at) end
      return true
    end
    if key == "LEFT" or key == "RIGHT" then
      local at = self.keyboard
      control:Nudge(key == "RIGHT" and 1 or -1)
      if self.keyboard then self:SetKeyboardFocus(at) end
      return true
    end
  end
  -- a letter or a digit searches, wherever the ring is
  local typed = TYPED[key]
  if typed then
    self.searchBox:SetText(IsShiftKeyDown() and key or typed)
    self.searchBox.placeholder:Hide()
    self:SetKeyboardFocus(1)
    self:ShowResults(self.searchBox:GetText())
    return true
  end
  return false
end

--------------------------------------------------------------------------
-- Scrollbar
--------------------------------------------------------------------------
-- Every page has one when it is longer than the window, so nobody takes the part
-- they can see for all there is. A rounded track beside the page with a thumb
-- sized to how much of it is in view, in the accent; drag the thumb, click the
-- track to turn a page, or use the wheel as before. While there is more below, the
-- page's foot fades out over a small chevron. A page that fits shows neither.
Panel.scrollbars = {}

local function StyleScrollbar(bar)
  local accent = Kit.TextSelected
  bar.track:SetFill(Kit.InsetColor)
  bar.track:SetEdge(Kit.BorderIdle)
  bar.thumbRound:SetFill(accent, (bar.hovered or bar.dragging) and 1 or .7)
  bar.thumbRound:SetEdge(nil)
  local solid = Kit.WindowColor
  if CreateColor then
    bar.fade:SetGradient("VERTICAL", CreateColor(solid[1], solid[2], solid[3], .95), CreateColor(solid[1], solid[2], solid[3], 0))
  elseif bar.fade.SetGradientAlpha then
    bar.fade:SetGradientAlpha("VERTICAL", solid[1], solid[2], solid[3], .95, solid[1], solid[2], solid[3], 0)
  end
  bar.more:SetVertexColor(accent[1], accent[2], accent[3])
end

local function Scrollbar(scroll)
  local bar = CreateFrame("Button", nil, frame)
  bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
  bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
  bar:SetWidth(SCROLLBAR_ROOM - 8)
  bar.scroll = scroll
  scroll.scrollbar = bar

  local track = CreateFrame("Frame", nil, bar)
  track:SetWidth(SCROLLBAR_W)
  track:SetPoint("TOP", bar, "TOP", 0, -2)
  track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 2)
  bar.trackFrame = track
  bar.track = Kit.Studio.Round(track, 3, nil, nil, true)

  local thumb = CreateFrame("Button", nil, track)
  thumb:SetWidth(SCROLLBAR_W)
  thumb:SetFrameLevel(track:GetFrameLevel() + 2)
  bar.thumb = thumb
  bar.thumbRound = Kit.Studio.Round(thumb, 3, nil, "ARTWORK", true)
  -- a wider grip than the thumb is drawn
  thumb:SetHitRectInsets(-5, -5, 0, 0)

  -- the page's foot, fading out while there is more below
  local fadeHost = CreateFrame("Frame", nil, frame)
  fadeHost:SetPoint("BOTTOMLEFT", scroll, "BOTTOMLEFT", 0, 0)
  fadeHost:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
  fadeHost:SetHeight(30)
  fadeHost:SetFrameLevel(scroll:GetFrameLevel() + 20)
  fadeHost:EnableMouse(false)
  local fade = fadeHost:CreateTexture(nil, "OVERLAY")
  fade:SetTexture(Kit.GetMedia("plain"))
  fade:SetAllPoints()
  bar.fade, bar.fadeHost = fade, fadeHost
  local more = fadeHost:CreateTexture(nil, "OVERLAY", nil, 1)
  more:SetSize(14, 14)
  more:SetPoint("BOTTOM", fadeHost, "BOTTOM", 0, 2)
  Kit.SetGlyph(more, "chevron")
  bar.more = more

  function bar:Update()
    local range = scroll:GetVerticalScrollRange() or 0
    local height = scroll:GetHeight() or 0
    if range < 1 or height <= 0 then
      self:Hide()
      fadeHost:Hide()
      return
    end
    self:Show()
    local trackH = track:GetHeight() or 0
    if trackH <= 0 then trackH = height - 4 end
    local thumbH = max(THUMB_MIN, trackH * height / (height + range))
    local at = min(1, max(0, (scroll:GetVerticalScroll() or 0) / range))
    self.range, self.travel = range, max(1, trackH - thumbH)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", track, "TOP", 0, -at * (trackH - thumbH))
    fadeHost:SetShown(at < .999)
  end

  -- dragging the thumb: the page follows the cursor, a track's height to a page's
  local function CursorY() return select(2, GetCursorPosition()) / thumb:GetEffectiveScale() end
  thumb:SetScript("OnMouseDown", function()
    bar.dragging = { y = CursorY(), scroll = scroll:GetVerticalScroll() or 0 }
    StyleScrollbar(bar)
    thumb:SetScript("OnUpdate", function()
      local drag = bar.dragging
      if not drag then return end
      local moved = drag.y - CursorY()
      scroll:SetVerticalScroll(min(bar.range, max(0, drag.scroll + moved * bar.range / bar.travel)))
    end)
  end)
  local function StopDrag()
    bar.dragging = nil
    thumb:SetScript("OnUpdate", nil)
    StyleScrollbar(bar)
  end
  thumb:SetScript("OnMouseUp", StopDrag)
  thumb:SetScript("OnHide", StopDrag)

  -- a click on the track turns a page towards it
  bar:SetScript("OnClick", function()
    local range = scroll:GetVerticalScrollRange() or 0
    if range <= 0 then return end
    local top = thumb:GetTop()
    local below = top and CursorY() < top
    local step = (scroll:GetHeight() or 0) * .9
    local now = scroll:GetVerticalScroll() or 0
    scroll:SetVerticalScroll(min(range, max(0, now + (below and step or -step))))
  end)
  bar:EnableMouseWheel(true)
  bar:SetScript("OnMouseWheel", function(_, delta)
    local wheel = scroll:GetScript("OnMouseWheel")
    if wheel then wheel(scroll, delta) end
  end)

  local function Hover(on) bar.hovered = on; StyleScrollbar(bar) end
  for _, region in ipairs({ bar, thumb }) do
    region:HookScript("OnEnter", function() Hover(true) end)
    region:HookScript("OnLeave", function() Hover(false) end)
  end

  scroll:HookScript("OnVerticalScroll", function() bar:Update() end)
  scroll:HookScript("OnScrollRangeChanged", function() bar:Update() end)
  scroll:HookScript("OnSizeChanged", function() bar:Update() end)
  scroll:HookScript("OnShow", function() bar:Update() end)
  scroll:HookScript("OnHide", function() bar:Hide(); fadeHost:Hide() end)

  Panel.scrollbars[#Panel.scrollbars + 1] = bar
  StyleScrollbar(bar)
  bar:Update()
  return bar
end

--------------------------------------------------------------------------
-- Theme, scale and position
--------------------------------------------------------------------------
function Panel:ApplyTheme()
  local settings = Settings()
  Kit.SetOpacity(settings and settings.opacity or 1)
  Kit.SetTheme(settings and settings.theme or "azerite")
  if not frame then return end
  if self.windowRound then
    local C, opacity = Kit.Studio.C, Kit.GetOpacity()
    self.windowRound:SetFill(Kit.WindowColor)
    self.windowRound:SetEdge(C.bronze)
    self.railRound:SetFill(C.rail, opacity)
    self.railRound:SetEdge(C.line, opacity)
  else
    frame:SetBackdropColor(unpack(Kit.WindowColor))
    self.casing:SetBackdropBorderColor(unpack(Kit.WindowCasingColor))
  end
  self.searchBackdrop:SetBackdropColor(unpack(Kit.InsetColor))
  Kit.SetBorderColor(self.searchBackdrop, self.searchBox:HasFocus() and Kit.BorderFocus or Kit.BorderIdle)
  self.searchBox:SetTextColor(unpack(Kit.TextHighlight))
  self.searchBox.placeholder:SetTextColor(unpack(Kit.TextDisabled))
  self.title:SetTextColor(unpack(self.windowRound and Kit.TextSelected or Kit.TextHighlight))
  self.version:SetTextColor(unpack(Kit.TextDisabled))
  self.footerText:SetTextColor(unpack(Kit.TextDisabled))
  self.count.text:SetTextColor(unpack(Kit.TextNormal))
  self.count.gem:SetVertexColor(unpack(Kit.TextSelected))
  self.pageTitle:SetTextColor(unpack(Kit.TextSelected))
  self.pageDesc:SetTextColor(unpack(Kit.TextNormal))
  local border = Kit.BorderIdle
  self.railEdge:SetVertexColor(border[1], border[2], border[3], .6)
  self.railEdge:SetShown(not self.windowRound) -- in Studio the rail is a card of its own
  self.headRule:SetVertexColor(border[1], border[2], border[3], .6)
  for _, row in ipairs(railRows) do StyleRailRow(row) end
  for _, bar in ipairs(self.scrollbars) do StyleScrollbar(bar) end
  page:Restyle()
  if Kit.PetGallery then Kit.PetGallery:Restyle() end
  if Kit.StudioHealth then Kit.StudioHealth:Restyle() end
  if Kit.StudioRules then Kit.StudioRules:Restyle() end
end

function Panel:ApplyScale()
  local settings = Settings()
  if frame then frame:SetScale(settings and settings.scale or 1) end
end

local function SaveGeometry()
  local settings = Settings()
  if not (frame and settings) then return end
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  settings.geometry = {
    point = point, relativePoint = relativePoint, x = x, y = y,
    width = frame:GetWidth(), height = frame:GetHeight(),
  }
end

function Panel:ResetGeometry()
  local settings = Settings()
  if settings then settings.geometry = nil end
  if not frame then return end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetSize(DEFAULT_W, DEFAULT_H)
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------
local function Build()
  local name = "AzUIColorPickerPanel"
  frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  frame:Hide()
  frame:SetSize(DEFAULT_W, DEFAULT_H)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, MIN_H) end
  tinsert(UISpecialFrames, name) -- Escape closes it
  local studio = Kit.ArtStyle == "studio"
  local azerite = Kit.ArtStyle == "azerite"
  local casing
  if studio then
    -- Studio: a rounded window with a bronze edge, lifted off the world by a soft shadow
    Kit.Studio.Shadow(frame, 22)
    Panel.windowRound = Kit.Studio.Round(frame, 10, true)
  else
    frame:SetBackdrop(Kit.WindowFill)
    local outset = Kit.WindowOutset
    frame:SetClampRectInsets(-outset.left, outset.right, outset.top, -outset.bottom)
    -- The casing is drawn above everything in the window, as AzeriteUI's is.
    casing = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    casing:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset.left, outset.top)
    casing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset.right, -outset.bottom)
    casing:SetBackdrop(Kit.WindowCasing)
    casing:EnableMouse(false)
    casing:SetFrameLevel(frame:GetFrameLevel() + 30)
    Panel.casing = casing
  end

  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:SetScript("OnEvent", function() Panel:ClearKeyboardFocus() end)
  frame:SetScript("OnHide", function()
    if Controls.CloseDropdown then Controls.CloseDropdown() end
    if Controls.CloseColor then Controls.CloseColor() end
    if Kit.PetGallery then Kit.PetGallery:OnHide() end
    if Kit.StudioHealth then Kit.StudioHealth:OnHide() end
    Panel:ClearKeyboardFocus()
    SaveGeometry()
  end)

  -- Header -------------------------------------------------------------
  local header = CreateFrame("Frame", nil, frame)
  header:SetHeight(HEADER_H)
  header:SetPoint("TOPLEFT", 8, -8)
  header:SetPoint("TOPRIGHT", -8, -8)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() frame:StartMoving() end)
  header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SaveGeometry() end)

  local logo = header:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(Core.icon)
  logo:SetTexCoord(unpack(Core.iconCoords))
  logo:SetSize(30, 30)
  logo:SetPoint("LEFT", 6, 0)

  local close
  if studio then
    close = CreateFrame("Button", nil, header)
    close:SetSize(24, 24)
    local cross = close:CreateTexture(nil, "ARTWORK")
    cross:SetSize(18, 18)
    cross:SetPoint("CENTER")
    Kit.Studio.Glyph(cross, "cross")
    cross:SetVertexColor(unpack(Kit.Studio.C.muted))
    close:SetScript("OnEnter", function() cross:SetVertexColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() cross:SetVertexColor(unpack(Kit.Studio.C.muted)) end)
  elseif ns.HasAzeriteMedia("options-close") then
    close = CreateFrame("Button", nil, header)
    close:SetSize(26, 26)
    local size = Kit.DrawSize(26, "options_close")
    local normal = close:CreateTexture(nil, "ARTWORK")
    normal:SetTexture(Kit.GetMedia("options-close"))
    normal:SetSize(size, size)
    normal:SetPoint("CENTER")
    local bright = close:CreateTexture(nil, "OVERLAY")
    bright:SetTexture(Kit.GetMedia("options-close-bright"))
    bright:SetSize(size, size)
    bright:SetPoint("CENTER")
    bright:Hide()
    close:SetScript("OnEnter", function() bright:Show() end)
    close:SetScript("OnLeave", function() bright:Hide() end)
  else
    close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
  end
  close:SetPoint("RIGHT", header, "RIGHT", -4, 0)
  close:SetScript("OnClick", function() Panel:Close() end)

  local version = header:CreateFontString(nil, "OVERLAY")
  version:SetFontObject(Kit.GetFont(12))
  version:SetPoint("RIGHT", close, "LEFT", -10, 0)
  version:SetText(Core.version ~= "" and ("v" .. Core.version) or "")
  Panel.version = version

  local title = header:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(studio and Kit.Studio.Font(20, "display") or Kit.GetFont(18, true))
  title:SetPoint("LEFT", logo, "RIGHT", 10, 1)
  title:SetPoint("RIGHT", version, "LEFT", -10, 0)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  if studio then
    title:SetText(L["ABCS Studio"])
    logo:SetSize(24, 24)
    local pack = Kit.Studio.Pack or {}
    if pack.logo then
      logo:SetTexture(Kit.Studio.PackMedia("logo"))
      logo:SetTexCoord(0, 1, 0, 1)
      logo:SetSize(28, 28)
    end
    if pack.corners then
      -- bronze filigree on each corner, drawn once as the top-left and mirrored
      local holder = CreateFrame("Frame", nil, frame)
      holder:SetAllPoints()
      holder:SetFrameLevel(frame:GetFrameLevel() + 40)
      holder:EnableMouse(false)
      for _, corner in ipairs({ { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 },
                                { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 } }) do
        local art = holder:CreateTexture(nil, "OVERLAY")
        art:SetTexture(Kit.Studio.PackMedia("corner"))
        art:SetSize(40, 40)
        art:SetPoint(corner[1], -3 * (corner[1]:find("LEFT") and 1 or -1), 3 * (corner[1]:find("TOP") and 1 or -1))
        art:SetTexCoord(corner[2], corner[3], corner[4], corner[5])
      end
    end
  else
    title:SetText(Kit.Studio and Kit.Studio.WindowTitle() or "ABCS")
    -- ABCS's own mark beside "ABCS Azerite" too, from the Studio art pack
    if Kit.Studio and Kit.Studio.Pack and Kit.Studio.Pack.logo then
      logo:SetTexture(Kit.Studio.PackMedia("logo"))
      logo:SetTexCoord(0, 1, 0, 1)
      logo:SetSize(28, 28)
    end
  end
  Panel.title = title

  -- Search -------------------------------------------------------------
  local searchRow = CreateFrame("Frame", nil, frame)
  searchRow:SetHeight(SEARCH_H)
  searchRow:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  searchRow:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)

  local search = CreateFrame("EditBox", nil, searchRow)
  search:SetHeight(24)
  search:SetPoint("LEFT", searchRow, "LEFT", 8, 0)
  search:SetWidth(RAIL_W + 120)
  search:SetAutoFocus(false)
  search:SetFontObject(Kit.GetFont(12))
  search:SetTextInsets(22, 6, 0, 0)
  Panel.searchBox = search
  Panel.searchBackdrop = Kit.CreateBackdrop(search, Kit.InsetBackdrop, 2)

  local glyph = search:CreateTexture(nil, "OVERLAY")
  glyph:SetSize(14, 14)
  glyph:SetPoint("LEFT", 5, 0)
  Kit.SetGlyph(glyph, "search")
  glyph:SetVertexColor(unpack(Kit.TextDisabled))

  local placeholder = search:CreateFontString(nil, "ARTWORK")
  placeholder:SetFontObject(Kit.GetFont(12))
  placeholder:SetPoint("LEFT", 22, 0)
  placeholder:SetText(L["Search settings and pets"])
  search.placeholder = placeholder

  search:SetScript("OnTextChanged", function(self, userInput)
    placeholder:SetShown(self:GetText() == "")
    if userInput then Panel:ShowResults(self:GetText()) end
  end)
  search:SetScript("OnEscapePressed", function() Panel:ClearKeyboardFocus(); Panel:ClearSearch() end)
  search:SetScript("OnTabPressed", function()
    if InCombatLockdown() then return end
    Panel.keyboard = Panel.keyboard or 1
    Panel:MoveKeyboardFocus(IsShiftKeyDown() and -1 or 1)
  end)
  search:SetScript("OnEnterPressed", function(self)
    local first = resultRows[1]
    if Panel.searching and first and first:IsShown() then Panel:OpenResult(first.result) else self:ClearFocus() end
  end)
  -- how many settings differ from their defaults; a click opens the first page with one
  local count = CreateFrame("Button", nil, searchRow)
  count:SetHeight(20)
  count:SetPoint("RIGHT", searchRow, "RIGHT", -8, 0)
  local countGem = count:CreateTexture(nil, "OVERLAY")
  countGem:SetSize(8, 8)
  countGem:SetPoint("LEFT", 0, 0)
  Kit.SetGlyph(countGem, "gem")
  local countText = count:CreateFontString(nil, "OVERLAY")
  countText:SetFontObject(Kit.GetFont(12))
  countText:SetPoint("LEFT", countGem, "RIGHT", 6, 0)
  count.text, count.gem = countText, countGem
  count:SetScript("OnClick", function()
    if Panel.firstChanged then PlaySound(852); Panel:ClearSearch(); Panel:SelectPage(Panel.firstChanged) end
  end)
  count:SetScript("OnEnter", function(self)
    self.text:SetTextColor(unpack(Kit.TextHighlight))
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine(L["Changed from default"], unpack(Kit.TextSelected))
    GameTooltip:AddLine(L["Pages with a gem hold settings you have changed. Click to open the first. The arrow on a setting puts it back."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  count:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(Kit.TextNormal)); GameTooltip:Hide() end)
  count:Hide()
  Panel.count = count

  search:SetScript("OnEditFocusGained", function() Kit.SetBorderColor(Panel.searchBackdrop, Kit.BorderFocus) end)
  search:SetScript("OnEditFocusLost", function() Kit.SetBorderColor(Panel.searchBackdrop, Kit.BorderIdle) end)

  -- Rail ---------------------------------------------------------------
  rail = CreateFrame("Frame", nil, frame)
  rail:SetWidth(RAIL_W)
  rail:SetPoint("TOPLEFT", searchRow, "BOTTOMLEFT", 6, -6)
  rail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, FOOTER_H + 10)

  if studio then
    -- Studio: the rail is a rounded panel of its own
    Panel.railRound = Kit.Studio.Round(rail, 8)
  end

  local railEdge = rail:CreateTexture(nil, "ARTWORK")
  railEdge:SetTexture(Kit.GetMedia("plain"))
  railEdge:SetWidth(1)
  railEdge:SetPoint("TOPRIGHT")
  railEdge:SetPoint("BOTTOMRIGHT")
  Panel.railEdge = railEdge

  -- Page ---------------------------------------------------------------
  local pageHead = CreateFrame("Frame", nil, frame)
  pageHead:SetHeight(PAGE_HEAD_H)
  pageHead:SetPoint("TOPLEFT", rail, "TOPRIGHT", 14, 0)
  pageHead:SetPoint("RIGHT", frame, "RIGHT", -16, 0)

  local pageTitle = pageHead:CreateFontString(nil, "OVERLAY")
  pageTitle:SetFontObject(studio and Kit.Studio.Font(20, "display") or Kit.GetFont(18, true))
  pageTitle:SetPoint("TOPLEFT", 2, -4)
  pageTitle:SetPoint("RIGHT")
  pageTitle:SetJustifyH("LEFT")
  pageTitle:SetWordWrap(false)
  Panel.pageTitle = pageTitle

  local pageDesc = pageHead:CreateFontString(nil, "OVERLAY")
  pageDesc:SetFontObject(Kit.GetFont(12))
  pageDesc:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -5)
  pageDesc:SetPoint("RIGHT")
  pageDesc:SetJustifyH("LEFT")
  pageDesc:SetWordWrap(false)
  Panel.pageDesc = pageDesc

  local headRule = pageHead:CreateTexture(nil, "ARTWORK")
  headRule:SetTexture(Kit.GetMedia("plain"))
  headRule:SetHeight(1)
  headRule:SetPoint("BOTTOMLEFT", 0, 2)
  headRule:SetPoint("BOTTOMRIGHT", 0, 2)
  Panel.headRule = headRule

  local function Scroller(step)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", pageHead, "BOTTOMLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR_ROOM, FOOTER_H + 10)
    scroll:SetClipsChildren(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(600, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      local range = self:GetVerticalScrollRange()
      if range <= 0 then return end
      self:SetVerticalScroll(min(range, max(0, self:GetVerticalScroll() - delta * step)))
    end)
    Scrollbar(scroll)
    return scroll, child
  end

  contentScroll, pageContent = Scroller(50)
  contentScroll:SetScript("OnSizeChanged", function(_, width)
    if not width or width <= 0 then return end
    pageContent:SetWidth(width)
    -- wrapped text and the gallery's columns follow the page's width
    if page and page.width ~= width then page:Layout() end
  end)
  page = Renderer:CreatePage(pageContent)
  Panel.page = page
  -- a setting changed on the page: bring the gems and the tally up to date
  local refresh = page.Refresh
  page.Refresh = function(self, ...)
    refresh(self, ...)
    if not Panel.searching then Panel:UpdateCounts() end
    if Panel.keyboard and Panel.keyboardHost then Panel:SetKeyboardFocus(Panel.keyboard) end
  end

  resultsScroll, resultsContent = Scroller(RESULT_H)
  resultsScroll:SetScript("OnSizeChanged", function(_, width)
    if width and width > 0 then resultsContent:SetWidth(width) end
  end)
  resultsScroll:Hide()

  -- Footer -------------------------------------------------------------
  local footer = CreateFrame("Frame", nil, frame)
  footer:SetHeight(FOOTER_H)
  footer:SetPoint("BOTTOMLEFT", 14, 8)
  footer:SetPoint("BOTTOMRIGHT", -28, 8)

  local footerText = footer:CreateFontString(nil, "OVERLAY")
  footerText:SetFontObject(Kit.GetFont(11))
  footerText:SetPoint("LEFT")
  footerText:SetPoint("RIGHT")
  footerText:SetJustifyH("LEFT")
  footerText:SetWordWrap(false)
  footerText:SetText(L["Changes apply as you make them.  /ahui classic opens the previous window."])
  Panel.footerText = footerText

  local resizer = CreateFrame("Button", nil, frame)
  resizer:SetSize(16, 16)
  resizer:SetPoint("BOTTOMRIGHT", -6, 6)
  resizer:SetFrameLevel((casing or frame):GetFrameLevel() + (casing and 1 or 40))
  resizer:RegisterForDrag("LeftButton")
  resizer:SetScript("OnDragStart", function() frame:StartSizing("BOTTOMRIGHT") end)
  resizer:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SaveGeometry() end)
  local grip = resizer:CreateTexture(nil, "OVERLAY")
  grip:SetAllPoints()
  Kit.SetGlyph(grip, "grip")
  grip:SetVertexColor(.5, .5, .5)
  resizer:SetScript("OnEnter", function() grip:SetVertexColor(unpack(Kit.TextSelected)) end)
  resizer:SetScript("OnLeave", function() grip:SetVertexColor(.5, .5, .5) end)

  -- A colour picked or a list closed while a refresh was held back.
  frame:SetScript("OnUpdate", function()
    if Panel.pendingRefresh and not (Controls.IsColorOpen and Controls.IsColorOpen())
      and not (Controls.IsDropdownOpen and Controls.IsDropdownOpen()) then
      Panel:Refresh()
    end
  end)

  local geometry = Settings() and Settings().geometry
  if geometry then
    frame:SetSize(max(MIN_W, geometry.width or DEFAULT_W), max(MIN_H, geometry.height or DEFAULT_H))
    if geometry.point and geometry.x and geometry.y then
      frame:ClearAllPoints()
      frame:SetPoint(geometry.point, UIParent, geometry.relativePoint or geometry.point, geometry.x, geometry.y)
    end
  end
end

--------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------
function Panel:Open(key)
  if not Core.GetDB() then return false end
  if not frame then
    if Kit.PrepareArt then Kit.PrepareArt(Settings() and Settings().theme) end
    if Kit.ArtStyle == "studio" then DEFAULT_W, DEFAULT_H = 940, 680 end
    local ok, err = pcall(Build)
    if not ok then
      frame = nil
      Core.Print(L["The ABCS window could not be built, so the classic window opened instead:"] .. " " .. tostring(err))
      return false
    end
  end
  self:ApplyScale()
  self:ApplyTheme()
  self:BuildRail()
  frame:Show()
  frame:Raise()
  if self.searching then self:ClearSearch() end
  self:SelectPage(key or self.selected or (self.pages[1] and self.pages[1].key))
  return true
end

function Panel:Close()
  if frame then frame:Hide() end
end

function Panel:IsShown()
  return frame and frame:IsShown() or false
end

function Panel:Toggle()
  if self:IsShown() then self:Close() else self:Open() end
end
