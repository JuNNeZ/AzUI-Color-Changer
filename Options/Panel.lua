-- The AzUI window.
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

local WINDOW_PAGE = "window"
local PETS_PAGE = "pets"

local frame, page, rail, contentScroll, pageContent
local resultsScroll, resultsContent
local railRows, resultRows = {}, {}

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
  bars     = L["Blizzard's pet frame and your power bar."],
  profiles = L["Keep different settings per character or per specialization."],
  share    = L["Copy your setup as a line of text, or bring in someone else's."],
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
local function StyleRailRow(row)
  local selected = Panel.selected == row.key
  if row.round then
    -- Studio: a rounded raised fill under the selected page, gold text
    local C = Kit.Studio.C
    row.round:SetFill((selected or row.hovered) and C.raised or nil, selected and 1 or .55)
    row.round:SetEdge(nil)
    row.edge:Hide()
    row.highlight:Hide()
    local colour = selected and Kit.TextSelected or row.hovered and Kit.TextHighlight or Kit.TextNormal
    row.text:SetTextColor(colour[1], colour[2], colour[3])
    return
  end
  row.edge:SetShown(selected)
  row.edge:SetVertexColor(unpack(Kit.TextSelected))
  row.highlight:SetShown(selected or row.hovered)
  row.highlight:SetVertexColor(1, 1, 1, selected and .06 or .03)
  local colour = selected and Kit.TextSelected or row.hovered and Kit.TextHighlight or Kit.TextNormal
  row.text:SetTextColor(colour[1], colour[2], colour[3])
end

local function CreateRailRow(index)
  local row = CreateFrame("Button", nil, rail)
  row:SetHeight(RAIL_ROW_H)

  local highlight = row:CreateTexture(nil, "BACKGROUND")
  highlight:SetTexture(Kit.GetMedia("plain"))
  highlight:SetAllPoints()
  row.highlight = highlight

  if Kit.ArtStyle == "studio" then row.round = Kit.Studio.Round(row, 6) end

  local edge = row:CreateTexture(nil, "ARTWORK")
  edge:SetTexture(Kit.GetMedia("plain"))
  edge:SetWidth(3)
  edge:SetPoint("TOPLEFT")
  edge:SetPoint("BOTTOMLEFT")
  row.edge = edge

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("LEFT", row, "LEFT", 12, 0)
  row.icon = icon

  local text = row:CreateFontString(nil, "OVERLAY")
  text:SetFontObject(Kit.GetFont(13))
  text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  row.text = text

  row:SetScript("OnClick", function(self)
    PlaySound(852)
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
    local pad = Kit.ArtStyle == "studio" and 8 or 0
    row:SetPoint("TOPLEFT", rail, "TOPLEFT", pad, -offset - pad)
    row:SetPoint("RIGHT", rail, "RIGHT", -6 - pad, 0)
    row.key = info.key
    row.text:SetText(info.label)
    row.icon:SetTexture(Resolve(info.icon) or Core.icon)
    local coords = Resolve(info.iconCoords)
    if type(coords) == "table" then row.icon:SetTexCoord(unpack(coords)) else row.icon:SetTexCoord(0, 1, 0, 1) end
    StyleRailRow(row)
    row:Show()
    offset = offset + RAIL_ROW_H + 2
  end
  for index = #self.pages + 1, #railRows do railRows[index]:Hide() end
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
  self.pageTitle:SetTextColor(unpack(Kit.TextSelected))
  self.pageDesc:SetTextColor(unpack(Kit.TextNormal))
  local border = Kit.BorderIdle
  self.railEdge:SetVertexColor(border[1], border[2], border[3], .6)
  self.railEdge:SetShown(not self.windowRound) -- in Studio the rail is a card of its own
  self.headRule:SetVertexColor(border[1], border[2], border[3], .6)
  for _, row in ipairs(railRows) do StyleRailRow(row) end
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

  frame:SetScript("OnHide", function()
    if Controls.CloseDropdown then Controls.CloseDropdown() end
    if Controls.CloseColor then Controls.CloseColor() end
    if Kit.PetGallery then Kit.PetGallery:OnHide() end
    if Kit.StudioHealth then Kit.StudioHealth:OnHide() end
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
  elseif ns.HasAzeriteArt then
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
    title:SetText(L["AzUI Studio"])
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
    title:SetText(Kit.Studio and Kit.Studio.WindowTitle() or "AzUI")
    -- AzUI's own mark beside "AzUI Azerite" too, from the Studio art pack
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
  search:SetScript("OnEscapePressed", function() Panel:ClearSearch() end)
  search:SetScript("OnEnterPressed", function(self)
    local first = resultRows[1]
    if Panel.searching and first and first:IsShown() then Panel:OpenResult(first.result) else self:ClearFocus() end
  end)
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
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, FOOTER_H + 10)
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
      Core.Print(L["The AzUI window could not be built, so the classic window opened instead:"] .. " " .. tostring(err))
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
