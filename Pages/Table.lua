-- Pages/Table.lua - the option table every page adds to (one source for the ABCS
-- window, the classic Ace3 window and Blizzard's Settings), and what the pages share.
-- Each page of it is a file of its own in Pages/; Options.lua does the rest.
local addonName, ns = ...
local P = ns.P
local L = P.L

local function DB() return P.DB end

StaticPopupDialogs["AZUI_RESET_CONFIRM"] = {
  text    = L["This will reset all settings and delete your presets and pet colours in the current profile. Are you sure?"],
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
  OnAccept = function() DB():ResetProfile() end, -- OnProfileReset does the rest
}

---------------------------------------------------------------------
-- OPTIONS TABLE
---------------------------------------------------------------------
local opts = { name = addonName, type = "group", childGroups = "tree", args = {} }
P.options = opts

-- What only the ABCS window needs to know about an option: hidden there, or how it
-- knows it was changed and puts it back. Kept beside the table, because
-- AceConfigRegistry refuses option keys it does not know.
local panelMeta = setmetatable({}, { __mode = "k" })
ns.PanelMeta = panelMeta
local function ForPanel(option, meta) panelMeta[option] = meta; return option end
P.ForPanel = ForPanel

function P.GetColour(c) return c[1], c[2], c[3], c[4] or 1 end

opts.args.ver = { type = "description", name = "|cff999999Version " .. P.VERSION, order = 0 }
opts.args.openPanel = ForPanel({
  type = "execute", name = L["Open the ABCS window"], order = 0.5,
  desc = L["The ABCS window has a pet gallery with portraits and models, and search across every setting."],
  func = function() if ns.OpenPanel then ns.OpenPanel() end end,
}, { hidden = true })
