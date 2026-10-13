-- ShareChat.lua - shares a setup through chat. "Share in Chat" puts [ABCS: Name] in your
-- chat box for you to send; anyone else with the addon sees it as a link. Clicking the
-- link asks its owner's addon for the setup with addon messages, and what comes back
-- opens in the import preview on the Share page, where nothing changes until Import.
--
-- Only plain text goes through chat: the game strips addon links from what players
-- send, so each client turns the text into a link of its own. The setup itself is the
-- share string Share.lua makes, in pieces small enough for one addon message each.
-- Addon messages are restricted in some content (instances in combat, encounters); a
-- request then says so instead of waiting, and an owner who cannot answer stays quiet.
local _, ns = ...
local P = ns.P
local L = P.L

local PREFIX     = "AzUICP"            -- addon message prefix
local LINK_ADDON = "AzUI_Color_Picker" -- |Haddon:AzUI_Color_Picker:share:<owner>:<name>|h
local PIECE      = 220                 -- characters of share string per message (255 at most)
local MAX_PIECES = 200                 -- the most one setup may take
local MAX_OFFERS = 5                   -- setups you offered, kept for links still in chat
local MAX_NAME   = 32
local WAIT_TIME  = 12                  -- seconds without a piece before giving up
local SEND_GAP   = 0.2                 -- seconds between pieces going out
local RETRY_GAP  = 1                   -- after the game says to slow down
local REPEAT_GAP = 5                   -- one answer per player and setup in this time
local LINK_COLOUR = "ff4fc3f7"

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) or false end

-- A name for a link: no brackets, colons, bars or tabs, not too long.
local function CleanName(text)
  if type(text) ~= "string" then return end
  text = strtrim((text:gsub("[%c|%[%]:]", ""):gsub("%s+", " ")))
  if text == "" then return end
  return text:sub(1, MAX_NAME)
end
P.CleanShareName = CleanName

function P.DefaultShareName()
  local name = UnitName and UnitName("player")
  return CleanName(string.format(L["%s's setup"], P.Accessible(name) or "ABCS")) or "ABCS"
end

-- Players by name only on your realm, Name-Realm on another, as the game compares them.
local function Short(name)
  if type(name) ~= "string" then return end
  if Ambiguate then return Ambiguate(name, "none") end
  return name
end

local function IsMe(name)
  local me = UnitName and UnitName("player")
  return name ~= nil and Short(name) == Short(me)
end

---------------------------------------------------------------------
-- WHAT YOU OFFER
---------------------------------------------------------------------
local function Offers() return P.DB.global.chatShares end

local function FindOffer(name)
  for _, offer in ipairs(Offers()) do
    if offer.name == name then return offer end
  end
end

-- Puts [ABCS: name] in the chat box: the one you are typing in, or a new one.
local function IntoChat(text)
  local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
  if insert then
    local ok, done = pcall(insert, text)
    if ok and done then return true end
  end
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open then return pcall(open, text) and true or false end
  return false
end

-- Offers the parts ticked on the Share page under `name`, and puts its link in chat.
-- Returns the text that went into chat, or nil and why not.
function P.OfferInChat(name)
  name = CleanName(name) or P.DefaultShareName()
  local text, err = P.Export(P.shareParts)
  if not text then return nil, err end
  if math.ceil(#text / PIECE) > MAX_PIECES then return nil, L["That setup is too big to send through chat. Make a share string instead."] end
  local offers = Offers()
  for i = #offers, 1, -1 do
    if offers[i].name == name then table.remove(offers, i) end
  end
  table.insert(offers, 1, { name = name, text = text, time = time and time() or 0 })
  for i = #offers, MAX_OFFERS + 1, -1 do offers[i] = nil end
  local tag = "[ABCS: " .. name .. "]"
  if not IntoChat(tag) then return nil, L["There is no chat box to put the link in."] end
  return tag
end

---------------------------------------------------------------------
-- SENDING
---------------------------------------------------------------------
-- Pieces wait in one queue and go out a little apart; when the game says to slow down,
-- the same piece goes again a second later.
local queue = {}
local sender = CreateFrame("Frame")
sender:Hide()
local waitFor = 0

local RESULT_OK, RESULT_THROTTLE, RESULT_CHANNEL_THROTTLE = 0, 3, 8

local function Send(message, target)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, "WHISPER", target)
  if not ok then return false end
  if result == true or result == nil or result == RESULT_OK then return true end
  if result == RESULT_THROTTLE or result == RESULT_CHANNEL_THROTTLE then return "later" end
  return false
end

sender:SetScript("OnUpdate", function(self, elapsed)
  waitFor = waitFor - elapsed
  if waitFor > 0 then return end
  local item = queue[1]
  if not item then self:Hide(); return end
  local sent = Send(item.message, item.target)
  if sent == "later" then
    waitFor = RETRY_GAP
    return
  end
  table.remove(queue, 1)
  if not sent then
    -- the rest of that answer cannot reach them either
    for i = #queue, 1, -1 do if queue[i].target == item.target then table.remove(queue, i) end end
  end
  waitFor = SEND_GAP
  if #queue == 0 then self:Hide() end
end)

local MAX_QUEUE = 2 * MAX_PIECES

local function Queue(message, target)
  if #queue >= MAX_QUEUE then return end
  queue[#queue + 1] = { message = message, target = target }
  sender:Show()
end

local lastAnswer = {}

local function Answer(target, name)
  local key = Short(target) .. "\t" .. name
  local now = GetTime()
  if lastAnswer[key] and now - lastAnswer[key] < REPEAT_GAP then return end
  lastAnswer[key] = now
  local offer = FindOffer(name)
  if not offer then return Queue("N\t" .. name, target) end
  local text = offer.text
  local total = math.ceil(#text / PIECE)
  for i = 1, total do
    Queue("D\t" .. name .. "\t" .. i .. "\t" .. total .. "\t" .. text:sub((i - 1) * PIECE + 1, i * PIECE), target)
  end
end

---------------------------------------------------------------------
-- FETCHING
---------------------------------------------------------------------
local pending = {} -- [owner \t name] = { owner, name, pieces, total, got, last }

local function PendingKey(owner, name) return Short(owner) .. "\t" .. name end

local function GiveUp(key, message)
  local request = pending[key]
  if not request then return end
  pending[key] = nil
  P.Print(string.format(message, request.owner, request.name))
end

local function WatchRequest(key, request)
  local token = {}
  request.token = token
  C_Timer.After(WAIT_TIME, function()
    if pending[key] ~= request or request.token ~= token then return end
    GiveUp(key, L["No answer from %s about \"%s\". They may be offline, or not have ABCS."])
  end)
end

-- Asks `owner` for the setup they offered as `name`. Your own opens straight away.
function P.RequestShare(owner, name)
  name = CleanName(name)
  if not (name and owner) then return false end
  if IsMe(owner) then
    local offer = FindOffer(name)
    if not offer then
      P.Print(string.format(L["You no longer offer \"%s\"."], name))
      return false
    end
    P.ShowImport(offer.text, Short(owner))
    return true
  end
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    P.Print(L["This game client cannot send addon messages."])
    return false
  end
  if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
    P.Print(L["Addon messages are restricted here. Try again out of combat, or after the encounter."])
    return false
  end
  local key = PendingKey(owner, name)
  local request = { owner = Short(owner), target = owner, name = name, pieces = {}, got = 0 }
  pending[key] = request
  Queue("Q\t" .. name, owner)
  P.Print(string.format(L["Asking %s for \"%s\"..."], request.owner, name))
  WatchRequest(key, request)
  return true
end

local function Received(request, key)
  pending[key] = nil
  local text = table.concat(request.pieces)
  local data, err = P.Decode(text)
  if not data then
    P.Print(string.format(L["The setup from %s could not be read: %s"], request.owner, tostring(err)))
    return
  end
  P.ShowImport(text, request.owner)
end

local function Piece(owner, name, index, total, payload)
  local key = PendingKey(owner, name)
  local request = pending[key]
  index, total = tonumber(index), tonumber(total)
  if not (request and index and total and payload) then return end
  if total < 1 or total > MAX_PIECES or index < 1 or index > total or (request.total and request.total ~= total) then
    return GiveUp(key, L["The setup from %s about \"%s\" came in damaged."])
  end
  request.total = total
  if not request.pieces[index] then
    request.pieces[index] = payload
    request.got = request.got + 1
  end
  WatchRequest(key, request)
  if request.got == total then Received(request, key) end
end

local function OnAddonMessage(_, prefix, message, channel, from)
  if Secret(prefix) or Secret(message) or Secret(channel) or Secret(from) then return end
  if prefix ~= PREFIX or channel ~= "WHISPER" or type(message) ~= "string" or type(from) ~= "string" then return end
  local kind, rest = message:match("^(%a)\t(.*)$")
  if kind == "Q" then
    local name = CleanName(rest)
    if name then Answer(from, name) end
  elseif kind == "D" then
    local name, index, total, payload = rest:match("^([^\t]+)\t(%d+)\t(%d+)\t(.*)$")
    if name then Piece(from, name, index, total, payload) end
  elseif kind == "N" then
    local name = CleanName(rest)
    if name then GiveUp(PendingKey(from, name), L["%s no longer offers \"%s\"."]) end
  end
end

---------------------------------------------------------------------
-- LINKS IN CHAT
---------------------------------------------------------------------
-- Chat that can carry a link, and whose author can be whispered back.
local CHAT_EVENTS = {
  "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
}

-- [ABCS: Name] as a link to the setup `owner` offered.
function P.ShareLink(owner, name)
  return "|c" .. LINK_COLOUR .. "|Haddon:" .. LINK_ADDON .. ":share:" .. owner .. ":" .. name
    .. "|h[ABCS: " .. name .. "]|h|r"
end

local function Linked(owner, message)
  return (message:gsub("%[ABCS: ([^%]|]+)%]", function(name)
    local clean = CleanName(name)
    if not clean then return nil end
    return P.ShareLink(owner, clean)
  end))
end

-- Chat filters run inside Blizzard's chat code; a message the game keeps secret (chat
-- in some restricted content) is left as it is.
local function Filter(_, event, message, author, ...)
  if Secret(message) or Secret(author) or type(message) ~= "string" or type(author) ~= "string" then return false end
  if not message:find("[ABCS: ", 1, true) then return false end
  -- a whisper you sent shows the other player as its author; the setup is yours
  local owner = author
  if event == "CHAT_MSG_WHISPER_INFORM" then
    local me = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    owner = realm and (me .. "-" .. realm) or me
  end
  if owner:find(":", 1, true) or owner == "" then return false end
  return false, Linked(owner, message), author, ...
end
P.ShareChatFilter = Filter

-- "addon:AzUI_Color_Picker:share:<owner>:<name>", from a click on the link
function P.OnShareLink(link)
  if type(link) ~= "string" or Secret(link) then return false end
  local owner, name = link:match("^addon:" .. LINK_ADDON .. ":share:([^:]+):(.+)$")
  if not owner then return false end
  return P.RequestShare(owner, name)
end

local function HookLinks()
  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link) P.OnShareLink(link) end, P)
  elseif type(SetItemRef) == "function" then
    hooksecurefunc("SetItemRef", function(link) P.OnShareLink(link) end)
  end
end

local function AddFilters()
  local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  if not add then return end
  for _, event in ipairs(CHAT_EVENTS) do pcall(add, event, Filter) end
end

P.On("CHAT_MSG_ADDON", OnAddonMessage)

P.OnInitialize(function()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
  AddFilters()
  HookLinks()
end)
