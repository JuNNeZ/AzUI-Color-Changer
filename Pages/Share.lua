-- Pages/Share.lua - the Share page: export and import strings, and links in chat.
local addonName, ns = ...
local P = ns.P
local L = P.L
local opts, panelMeta, ForPanel, GetColour = P.options, ns.PanelMeta, P.ForPanel, P.GetColour

local function DB() return P.DB end

---------------------------------------------------------------------
-- SHARE PAGE
---------------------------------------------------------------------
local exportText, importText, importData, importError = "", "", nil, nil
local importFrom -- who a setup fetched through a chat link came from
local chatName   -- the name your next chat link goes under; your character's by default

-- Opens the Share page in whichever window you use.
function P.OpenSharePage()
  local dialog = P.AceConfigDialog
  if dialog.OpenFrames and dialog.OpenFrames[addonName] then
    if dialog.SelectGroup then dialog:SelectGroup(addonName, "share") end
  elseif P.ToggleWindow then
    P.ToggleWindow("share")
  end
  P.RefreshOptions()
end

-- Puts a share string in the import box, with its preview, and shows it. `from` names
-- the player it came from.
function P.ShowImport(text, from)
  importText = text or ""
  importData, importError = P.Decode(importText)
  importFrom = from
  P.OpenSharePage()
end

function P.ImportPending() return importData, importError, importFrom end

local shareArgs = {
  help = {
    type = "description", order = 1,
    name = L["Turn your setup, or just the parts you tick, into one line of text to paste in Discord or a guide. Paste one below to bring someone else's in."],
  },
  unavailable = {
    type = "description", order = 2,
    name = "|cffff6060" .. L["This game client cannot make or read share strings."] .. "|r",
    hidden = function() return P.CanShare() end,
  },
  exportH = { type = "header", name = L["Export"], order = 10 },
  exportBtn = {
    type = "execute", name = L["Make Share String"], order = 20,
    desc = L["Makes a string of the parts ticked above. Select it and press Ctrl+C to copy it."],
    func = function()
      local text, err = P.Export(P.shareParts)
      exportText = text or ""
      if err then P.Print(err) end
    end,
    disabled = function() return not P.CanShare() end,
  },
  exportBox = {
    type = "input", name = L["Share String"], order = 21, multiline = 4, width = "full",
    get = function() return exportText end,
    set = function() end,
    disabled = function() return exportText == "" end,
  },
  chatH = { type = "header", name = L["Share in Chat"], order = 25 },
  chatHelp = {
    type = "description", order = 26,
    name = L["Puts [AzUI: name] in your chat box for you to send. Anyone with AzUI Color Picker sees it as a link; clicking it fetches the parts ticked above from you and shows what they would change before anything is imported. Your last five links keep working after you log out, whenever you are online to answer."],
  },
  chatName = {
    type = "input", name = L["Link Name"], order = 27,
    desc = L["The name your link shows in chat. A new link with the same name replaces the old one."],
    get = function() return chatName or P.DefaultShareName() end,
    set = function(_, v) chatName = P.CleanShareName(v) end,
  },
  chatBtn = {
    type = "execute", name = L["Share in Chat"], order = 28,
    desc = L["Puts the link in your chat box. Send it to say, party, raid, guild or a whisper."],
    func = function()
      local tag, err = P.OfferInChat(chatName)
      if not tag then P.Print(err) end
    end,
    disabled = function() return not P.CanShare() end,
  },
  importH = { type = "header", name = L["Import"], order = 30 },
  importBox = {
    type = "input", name = L["Paste a Share String"], order = 31, multiline = 4, width = "full",
    get = function() return importText end,
    set = function(_, v)
      v = v or ""
      -- a pasted string is your own; one fetched from chat keeps who it came from
      if v ~= importText then importFrom = nil end
      importText = v
      importData, importError = P.Decode(importText)
    end,
    disabled = function() return not P.CanShare() end,
  },
  preview = {
    type = "description", order = 32,
    name = function()
      if importError then return "|cffff6060" .. importError .. "|r" end
      if not importData then return "" end
      local head = importFrom and string.format(L["From %s, importing will change:"], importFrom) or L["Importing will change:"]
      return head .. "\n• " .. table.concat(P.DescribeImport(importData), "\n• ")
    end,
    hidden = function() return not importData and not importError end,
  },
  apply = {
    type = "execute", name = L["Import"], order = 33,
    desc = L["Apply the string to your current profile. Presets and pet colours with the same names are replaced; rules are replaced as a list."],
    confirm = function() return L["Import these settings into your current profile?"] end,
    func = function()
      if not importData then return end
      P.ApplyImport(importData)
      importText, importData, importError, importFrom = "", nil, nil, nil
      P.Print(L["Imported."])
    end,
    disabled = function() return not importData end,
  },
}
for index, part in ipairs(P.SHARE_PARTS) do
  shareArgs["part_" .. part] = {
    type = "toggle", name = P.SHARE_PART_NAMES[part], order = 10 + index * 0.1,
    get = function() return P.shareParts[part] end,
    set = function(_, v) P.shareParts[part] = v and true or false end,
  }
end
opts.args.share = {
  type = "group", name = L["Share"], order = 7, args = shareArgs,
  icon = "Interface\\Icons\\INV_Letter_15", iconCoords = P.ICON_COORDS,
}
