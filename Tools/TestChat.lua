-- Run from the addon directory: lua Tools/TestChat.lua (Lua 5.1).
-- Sharing a setup through chat: two clients, Alice and Bob, each a Tools/Mock.lua game.
-- Alice puts [AzUI: ...] in chat, Bob's chat shows it as a link, a click asks Alice's
-- addon for it with addon messages, and it opens in Bob's import preview.
local Mock = dofile("Tools/Mock.lua")
local checks = 0
local function check(value, message)
  if not value then error("FAILED: " .. message, 2) end
  checks = checks + 1
end

local function Client(name)
  local game = Mock.New({})
  game.env.UnitName = function(unit) if unit == "player" then return name end return "Rex" end
  game.name = name .. "-MockRealm"
  return game
end
local alice, bob = Client("Alice"), Client("Bob")
local A, B = alice.P, bob.P

-- One encoder for both, as both run the same game: a share string Alice makes is one
-- Bob can read. Each string carries some padding, so a setup takes several pieces.
local store = {}
for _, game in ipairs({ alice, bob }) do
  local E = game.env.C_EncodingUtil
  E.SerializeCBOR = function(value) store[#store + 1] = alice.DeepCopy(value); return "cbor" .. #store .. ":" .. string.rep("x", 900) end
  E.DeserializeCBOR = function(text)
    local id = tonumber(text:match("^cbor(%d+):"))
    if not id then error("bad cbor") end
    return alice.DeepCopy(store[id])
  end
end

-- Hands every addon message one client sent to the other, as the server would.
local function Deliver(from, to)
  local sent = from.addonSent
  from.addonSent = {}
  for _, m in ipairs(sent) do
    check(m.prefix == "AzUICP" and m.channel == "WHISPER" and #m.message <= 255, "an addon message fits the rules: " .. m.message:sub(1, 40))
    to.fire("CHAT_MSG_ADDON", m.prefix, m.message, "WHISPER", from.name)
  end
  return #sent
end
-- Runs a client's sender for a while, so its queued pieces go out.
local function Run(game, seconds) game.advance(seconds or 5) end
local function Printed(game, text)
  for _, line in ipairs(game.printed) do if line:find(text, 1, true) then return true end end
  return false
end

check(alice.prefixes.AzUICP and bob.prefixes.AzUICP, "both clients register the addon message prefix")

---------------------------------------------------------------------------
-- Offering
---------------------------------------------------------------------------
local p = alice.db.profile
p.color = { 0.2, 0.7, 0.3, 1 }
p.presets["Moss"] = { 0.1, 0.4, 0.1, 1 }
local tag = A.OfferInChat("Raid: [night] | team")
check(tag == "[AzUI: Raid night team]", "the link name loses brackets, colons and bars: " .. tostring(tag))
check(alice.chatBox[1] == tag, "and goes into a new chat box")
alice.chatOpen = true
A.OfferInChat()
check(alice.chatBox[2] == "[AzUI: Alice's setup]", "with no name it goes under your character's")
check(#alice.db.global.chatShares == 2 and alice.db.global.chatShares[1].name == "Alice's setup", "offers are kept, newest first")
for i = 1, 6 do A.OfferInChat("Setup " .. i) end
check(#alice.db.global.chatShares == 5, "five at most")
A.OfferInChat("Raid night team")
A.OfferInChat("Raid night team")
local same = 0
for _, offer in ipairs(alice.db.global.chatShares) do if offer.name == "Raid night team" then same = same + 1 end end
check(alice.db.global.chatShares[1].name == "Raid night team" and same == 1 and #alice.db.global.chatShares == 5,
  "offering a name again replaces the old offer")

---------------------------------------------------------------------------
-- The link in chat
---------------------------------------------------------------------------
local line = bob.chat("CHAT_MSG_PARTY", "come see " .. tag .. " now", alice.name)
check(line:find("|Haddon:AzUI_Color_Picker:share:Alice-MockRealm:Raid night team|h[AzUI: Raid night team]|h", 1, true),
  "Bob's chat shows the text as a link to Alice's setup: " .. line)
check(line:find("^come see ") and line:find(" now$"), "the rest of the line is left as it is")
check(bob.chat("CHAT_MSG_PARTY", "no link here", alice.name) == "no link here", "other lines are left alone")
check(bob.chat("CHAT_MSG_PARTY", { secret = true }, alice.name).secret, "a line the game keeps secret is not touched")
local inform = alice.chat("CHAT_MSG_WHISPER_INFORM", tag, "Bob-MockRealm")
check(inform:find("share:Alice-MockRealm:", 1, true), "a whisper you sent links to your own setup, not the other player's")

---------------------------------------------------------------------------
-- Fetching it
---------------------------------------------------------------------------
local link = line:match("|H(addon:[^|]+)|h")
bob.clickLink(link)
check(Printed(bob, "Asking Alice for \"Raid night team\""), "a click asks the link's owner")
Run(bob)
check(Deliver(bob, alice) == 1, "with one addon message")
Run(alice, 20)
local pieces = Deliver(alice, bob)
check(pieces > 1, "the answer comes in pieces: " .. pieces)
local imported, _, from = B.ImportPending()
check(imported and imported.presets and imported.presets["Moss"] and from == "Alice", "it opens in Bob's import preview, from Alice")
check(bob.db.profile.presets["Moss"] == nil, "and nothing changes until Bob imports")
local preview = bob.P.options.args.share.args.preview.name()
check(preview:find("From Alice, importing will change:", 1, true), "the preview says who it is from")
check(bob.ns.OptionsKit.Panel:IsShown(), "the window opens on the Share page")

-- a request again later is answered; straight after another it is not answered twice
bob.clickLink(link); Run(bob); Deliver(bob, alice)
bob.clickLink(link); Run(bob); Deliver(bob, alice)
Run(alice, 20)
check(Deliver(alice, bob) == pieces, "a request straight after another gets no second answer")
alice.clickLink(link) -- Alice's own link opens without a message
check(#alice.addonSent == 0 and select(1, A.ImportPending()) ~= nil, "your own link opens straight away")
-- a request that is never answered
bob.clickLink(link); Run(bob)
bob.addonSent = {}
bob.flush() -- the wait for an answer runs out
check(Printed(bob, "No answer from Alice"), "the asker gives up after a while")

---------------------------------------------------------------------------
-- When it cannot work
---------------------------------------------------------------------------
bob.printed = {}
bob.chatLockdown = true
bob.clickLink(link)
check(Printed(bob, "Addon messages are restricted here"), "during chat lockdown the click says so")
check(#bob.addonSent == 0, "and sends nothing")
bob.chatLockdown = false

-- a setup no longer offered
bob.clickLink("addon:AzUI_Color_Picker:share:Alice-MockRealm:Gone")
Run(bob); Deliver(bob, alice); Run(alice); Deliver(alice, bob)
check(Printed(bob, "Alice no longer offers \"Gone\""), "an owner without that setup says so")

-- the game asks to slow down: the same piece goes again a second later
alice.advance(6) -- past the gap for repeated requests
local tries = 0
alice.addonResult = function() tries = tries + 1; if tries <= 3 then return 3 end return 0 end
bob.clickLink(link); Run(bob); Deliver(bob, alice)
Run(alice, 30)
check(tries > 3 and Deliver(alice, bob) == pieces, "throttled pieces are sent again, and all of them arrive")
alice.addonResult = nil

-- pieces that do not add up
bob.printed = {}
bob.clickLink("addon:AzUI_Color_Picker:share:Alice-MockRealm:Moss")
bob.fire("CHAT_MSG_ADDON", "AzUICP", "D\tMoss\t5\t3\tabc", "WHISPER", alice.name)
check(Printed(bob, "came in damaged"), "a piece past the end is refused")
bob.fire("CHAT_MSG_ADDON", "AzUICP", "D\tMoss\t1\t1\tabc", "WHISPER", alice.name)
check(select(1, B.ImportPending()) ~= nil, "and a piece nobody asked for does nothing")
bob.fire("CHAT_MSG_ADDON", { secret = true }, "x", "WHISPER", alice.name)
bob.fire("CHAT_MSG_ADDON", "OtherAddon", "Q\tMoss", "WHISPER", alice.name)
check(true, "secret or foreign addon messages are ignored")

-- the Share page
local args = alice.P.options.args.share.args
check(args.chatName.get() == "Alice's setup", "the link name starts as your character's")
args.chatName.set(nil, "  Mythic+ [push]  ")
check(args.chatName.get() == "Mythic+ push", "and is cleaned as you type it")
alice.chatBox = {}
args.chatBtn.func()
check(alice.chatBox[1] == "[AzUI: Mythic+ push]", "Share in Chat puts it in chat")

-- Pasting a share string in the AzUI window's import box, without the check in its corner
do
  local text = bob.P.Export(bob.P.shareParts)
  bob.ns.OpenPanel("share")
  local Panel = bob.ns.OptionsKit.Panel
  local box
  for _, control in ipairs(Panel.page:GetControls()) do
    if control.multiline and control.label and tostring(control.label.text):find("Paste", 1, true) then box = control end
  end
  check(box, "the Share page has its paste box")
  box.edit:SetFocus()
  box.edit:SetText(text)
  box.edit.scripts.OnTextChanged(box.edit, true)
  check(select(3, B.ImportPending()) == "Alice", "nothing is taken while you are still typing")
  -- the window redraws its page (a rule changed, a pet was called) before the text is taken
  bob.P.RefreshOptions()
  local again
  for _, control in ipairs(Panel.page:GetControls()) do
    if control.multiline and control.label and tostring(control.label.text):find("Paste", 1, true) then again = control end
  end
  check(again == box and box.edit:GetText() == text, "a redraw keeps the same box, and the text you pasted in it")
  bob.flush()
  local data, err, from = B.ImportPending()
  check(data and not err and from == nil, "a moment after pasting, the string is in the preview, as your own")
  local apply = bob.P.options.args.share.args.apply
  check(not apply.disabled(), "and Import can be pressed")
  box.edit:SetText("nonsense")
  box.edit.scripts.OnEditFocusLost(box.edit)
  check(select(2, B.ImportPending()), "leaving the box takes what is in it, too")
end

check(#alice.taint == 0 and #bob.taint == 0, "nothing written onto Blizzard's frames")
print(checks .. " chat checks passed")
