-- A mock WoW client for the test scripts in Tools/ (Lua 5.1).
--
--   local Mock = dofile("Tools/Mock.lua")
--   local game = Mock.New({ forever = false, art = false })
--
-- Loads every file the TOC lists, in its order, with one shared namespace, and logs
-- in as a hunter with four pets. Frames record their scripts, colours and text;
-- hooksecurefunc really hooks; events are fired with game.fire.
local Mock = {}

function Mock.New(opts)
  opts = opts or {}
  local game = { frames = {}, events = {}, timers = {}, time = 0, state = {} }
  local frames, events = game.frames, game.events

  -------------------------------------------------------------------------
  -- Widgets
  -------------------------------------------------------------------------
  local Widget = {}
  local function NewWidget(kind, name, parent)
    local w = setmetatable({ kind = kind, name = name, parent = parent, shown = true, scripts = {},
      width = 600, height = 20, level = 1, text = "", points = {} }, Widget)
    frames[#frames + 1] = w
    return w
  end
  game.NewWidget = NewWidget
  local methods = {
    Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end,
    Hide = function(self) local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end,
    SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
    IsShown = function(self) return self.shown end,
    IsVisible = function(self) return self.shown end,
    SetScript = function(self, k, f) self.scripts[k] = f end,
    GetScript = function(self, k) return self.scripts[k] end,
    SetText = function(self, t) self.text = t end,
    GetText = function(self) return self.text end,
    GetStringHeight = function() return 13 end,
    GetStringWidth = function(self) return #tostring(self.text or "") * 6 end,
    SetWidth = function(self, v) self.width = v end,
    SetHeight = function(self, v) self.height = v end,
    SetSize = function(self, w, h) self.width, self.height = w, h end,
    GetWidth = function(self) return self.width end,
    GetHeight = function(self) return self.height end,
    GetCenter = function() return 100, 100 end,
    GetFrameLevel = function(self) return self.level end,
    SetFrameLevel = function(self, v) self.level = v end,
    CreateTexture = function(self) return NewWidget("Texture", nil, self) end,
    CreateMaskTexture = function(self) return NewWidget("MaskTexture", nil, self) end,
    CreateFontString = function(self) return NewWidget("FontString", nil, self) end,
    GetVerticalScrollRange = function() return 0 end,
    GetVerticalScroll = function() return 0 end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    GetParent = function(self) return self.parent end,
    GetName = function(self) return self.name end,
    GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
    HasFocus = function() return false end,
    GetEffectiveScale = function() return 1 end,
    GetObjectType = function(self) return self.kind end,
    Enable = function(self) self.disabled = false end,
    Disable = function(self) self.disabled = true end,
    GetStatusBarTexture = function(self) self.bar = self.bar or NewWidget("Texture", nil, self); return self.bar end,
    SetStatusBarColor = function(self, r, g, b, a) self.color = { r, g, b, a } end,
    GetStatusBarColor = function(self) local c = self.color or {}; return c[1], c[2], c[3], c[4] end,
    SetVertexColor = function(self, r, g, b, a) self.vertex = { r, g, b, a }; self.gradient = nil end,
    SetBlendMode = function(self, mode) self.blend = mode end,
    SetGradient = function(self, orientation, left, right) self.gradient = { left, right, orientation = orientation } end,
    SetChecked = function(self, v) self.checked = v end,
    GetChecked = function(self) return self.checked end,
    SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
    ClearAllPoints = function(self) self.points = {} end,
    SetDisplayInfo = function(self, id) self.displayID = id end,
    SetTexture = function(self, file) self.texture = file end,
    ClearModel = function(self) self.displayID = nil end,
    RegisterEvent = function(self, event)
      events[event] = events[event] or {}
      table.insert(events[event], self)
    end,
  }
  methods.RegisterUnitEvent = methods.RegisterEvent
  -- Methods start with a capital; anything else is a data field the code set itself.
  Widget.__index = function(_, key)
    if methods[key] then return methods[key] end
    if type(key) == "string" and key:match("^%u") then return function() end end
  end

  -------------------------------------------------------------------------
  -- The client
  -------------------------------------------------------------------------
  local env = setmetatable({}, { __index = _G })
  env._G = env
  game.env = env
  local state = game.state
  state.combat, state.mounted, state.resting, state.stealth, state.dead = false, false, false, false, false
  state.instance, state.spec, state.health = nil, 1, 1
  state.class = opts.class or "HUNTER"

  env.CreateFrame = function(kind, name, parent)
    local w = NewWidget(kind, name, parent)
    if name then env[name] = w end
    return w
  end
  env.CreateFont = function(name) return NewWidget("Font", name) end
  env.UIParent = NewWidget("Frame", "UIParent")
  env.UIParent.width, env.UIParent.height = 1920, 1080
  env.GameFontNormal = NewWidget("Font", "GameFontNormal")
  env.GameFontHighlightSmall = NewWidget("Font", "GameFontHighlightSmall")
  env.GameTooltip = NewWidget("GameTooltip", "GameTooltip")
  env.GameTooltip.lines = {}
  env.GameTooltip.AddLine = function(self, text) table.insert(self.lines, text) end
  env.ColorPickerFrame = NewWidget("Frame", "ColorPickerFrame")
  env.ColorPickerFrame.shown = false
  env.ColorPickerFrame.GetExtraInfo = function() return nil end
  env.UISpecialFrames = {}
  env.StaticPopupDialogs = {}
  game.popups = {}
  -- answers yes unless the test says otherwise
  env.StaticPopup_Show = function(key, text)
    table.insert(game.popups, { key = key, text = text })
    local dialog = env.StaticPopupDialogs[key]
    if dialog and game.answer ~= false then
      if dialog.OnAccept then dialog.OnAccept({ editBox = { GetText = function() return game.popupText or "" end } }) end
    elseif dialog and dialog.OnCancel then
      dialog.OnCancel()
    end
    return true
  end
  env.SlashCmdList = {}
  env.PlaySound = function() end
  env.GetCursorPosition = function() return 0, 0 end
  env.GetTime = function() return game.time end
  env.InCombatLockdown = function() return false end
  env.IsShiftKeyDown = function() return game.shift and true or false end
  env.issecretvalue = function(v) return type(v) == "table" and v.secret == true end
  env.strtrim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  env.tinsert = table.insert
  game.printed = {}
  env.print = function(...) table.insert(game.printed, table.concat({ ... }, " ")) end
  env.ReloadUI = function() end
  env.GetBuildInfo = function() return opts.forever and "1.60.1" or "12.1.0", "1", "", opts.forever and 16001 or 120100 end
  env.SAVE, env.CANCEL, env.YES, env.NO, env.ACCEPT = "Save", "Cancel", "Yes", "No", "Accept"
  env.RAID_CLASS_COLORS = {
    HUNTER = { r = .67, g = .83, b = .45, colorStr = "ffaad372" },
    MAGE = { r = .25, g = .78, b = .92, colorStr = "ff3fc7eb" },
  }
  env.LOCALIZED_CLASS_NAMES_MALE = { HUNTER = "Hunter", MAGE = "Mage" }
  env.UnitClass = function() return state.class == "HUNTER" and "Hunter" or "Mage", state.class, 3 end
  env.UnitExists = function(unit) return unit == "pet" and state.petOut ~= false end
  env.UnitName = function() return "Rex" end
  env.UnitCreatureFamily = function() return "Wolf", 1 end
  env.UnitAffectingCombat = function() return state.combat end
  env.UnitIsDeadOrGhost = function() return state.dead end
  env.IsMounted = function() return state.mounted end
  env.IsResting = function() return state.resting end
  env.IsStealthed = function() return state.stealth end
  env.IsInInstance = function() return state.instance ~= nil, state.instance or "none" end
  env.C_SpecializationInfo = {
    GetSpecialization = function() return state.spec end,
    GetNumSpecializationsForClassID = function() return 3 end,
    GetSpecializationInfo = function(i) return 250 + i, ({ "Beast Mastery", "Marksmanship", "Survival" })[i] end,
  }
  env.SetPortraitTextureFromCreatureDisplayID = function(texture, id) texture.portraitID = id end
  env.C_Timer = {
    After = function(_, f) table.insert(game.timers, f) end,
    NewTicker = function() return {} end,
  }
  env.C_AddOns = {
    GetAddOnMetadata = function(_, key)
      if key == "Version" then return "5.2.0" end
      if key == "X-AzUI-Client" and opts.forever and not opts.noMarker then return "Forever" end
    end,
    IsAddOnLoaded = function() return opts.art and true or false end,
  }
  env.C_Spell = {
    IsCurrentSpell = function(id) return id == 883 end,
    GetSpellTexture = function() return 132161 end,
  }
  -- hooksecurefunc on a table really hooks, so another addon's recolour can be tested
  env.hooksecurefunc = function(target, method, hook)
    if type(target) ~= "table" then return end
    local original = target[method]
    -- rawset: the real hooksecurefunc is secure and taints nothing, so the taint
    -- guard must not count it
    rawset(target, method, function(...)
      local results = { original(...) }
      hook(...)
      return unpack(results)
    end)
  end

  -- Health as a secret: the colour curve hands back a colour no Lua may read.
  if not opts.noCurves then
    env.CreateColor = function(r, g, b, a)
      return { r = r, g = g, b = b, a = a, GetRGBA = function(self) return self.r, self.g, self.b, self.a end }
    end
    env.C_CurveUtil = {
      CreateColorCurve = function()
        local curve = { points = {} }
        curve.AddPoint = function(self, x, colour) table.insert(self.points, { x, colour }) end
        return curve
      end,
    }
    env.UnitHealthPercent = function(_, _, curve)
      local low, high = curve.points[1][2], curve.points[2][2]
      local k = state.health
      local secret = { secret = true }
      -- a secret colour: GetRGBA hands back secrets the painter must pass on untouched
      return { GetRGBA = function()
        return setmetatable({ secret = true, v = low.r + (high.r - low.r) * k }, { __mul = function() error("maths on a secret") end }),
               setmetatable({ secret = true }, { __mul = function() error("maths on a secret") end }),
               setmetatable({ secret = true }, { __mul = function() error("maths on a secret") end }),
               secret
      end }
    end
  end

  -- Blizzard's encoder, as a reversible stand-in
  local store = {}
  local function DeepCopy(t) if type(t) ~= "table" then return t end local c = {} for k, v in pairs(t) do c[k] = DeepCopy(v) end return c end
  game.DeepCopy = DeepCopy
  env.C_EncodingUtil = {
    SerializeCBOR = function(value) store[#store + 1] = DeepCopy(value); return "cbor" .. #store end,
    DeserializeCBOR = function(text) local id = tonumber(text:match("^cbor(%d+)$")); if not id then error("bad cbor") end return DeepCopy(store[id]) end,
    CompressString = function(s) return "z" .. s end,
    DecompressString = function(s) if s:sub(1, 1) ~= "z" then error("bad deflate") end return s:sub(2) end,
    EncodeBase64 = function(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end,
    DecodeBase64 = function(s) if not s:match("^%x*$") then error("bad base64") end return (s:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)) end,
  }

  -- the stable
  local pets = {
    { petNumber = 11, slotID = 1, name = "Rex", familyName = "Wolf", specialization = "Tenacity", specID = 81, displayID = 1001, icon = 1 },
    { petNumber = 22, slotID = 2, name = "Mittens", familyName = "Cat", specialization = "Ferocity", specID = 74, displayID = 1002, icon = 2 },
    { petNumber = 33, slotID = 3, name = "Skye", familyName = "Bird of Prey", specialization = "Cunning", specID = 79, icon = 3 },
  }
  local stabled = { { petNumber = 77, slotID = 7, name = "Grumble", familyName = "Bear", specialization = "Tenacity", specID = 81, displayID = 1004, icon = 4 } }
  env.Constants = { PetConsts = { NUM_PET_SLOTS_HUNTER = 3 } }
  env.C_StableInfo = {
    GetStablePetInfo = function(slot) for _, p in ipairs(pets) do if p.slotID == slot then return p end end end,
    GetActivePetList = function() return pets end,
    GetStabledPetList = function() return stabled end,
    IsAtStableMaster = function() return false end,
  }

  -- Blizzard's own frames. A value an addon writes onto one of these taints Blizzard's
  -- code when it reads it back, so the guard records every field written that is not
  -- the mock's own bookkeeping; tests assert game.taint stays empty.
  game.taint = {}
  local MOCK_FIELDS = { color = true, vertex = true, gradient = true, points = true, width = true, height = true,
    shown = true, scripts = true, text = true, bar = true, texture = true, level = true, disabled = true }
  local function Guard(w)
    setmetatable(w, { __index = Widget.__index, __newindex = function(t, k, v)
      if not MOCK_FIELDS[k] then table.insert(game.taint, tostring(t.name) .. "." .. tostring(k)) end
      rawset(t, k, v)
    end })
    return w
  end
  -- Blizzard's update functions, run from an addon, compare secrets while tainted
  game.blizzardCalls = {}
  env.UnitFrameHealthBar_Update = function() table.insert(game.blizzardCalls, "UnitFrameHealthBar_Update") end
  env.UnitFrameManaBar_UpdateType = function() table.insert(game.blizzardCalls, "UnitFrameManaBar_UpdateType") end
  env.UnitPowerType = function() return 0, "MANA" end
  env.PowerBarColor = { [0] = { r = 0, g = 0, b = 1 } }
  env.PlayerFrame = NewWidget("Frame", "PlayerFrame")
  env.PlayerFrame.PlayerFrameContent = false -- the bars below are the older lookups
  env.PlayerFrame.healthbar = Guard(NewWidget("StatusBar", "PlayerFrameHealthBar"))
  env.PlayerFrame.manabar = Guard(NewWidget("StatusBar", "PlayerFrameManaBar"))
  env.PetFrame = NewWidget("Frame", "PetFrame")
  env.PetFrame.healthbar = Guard(NewWidget("StatusBar", "PetFrameHealthBar"))
  -- an AzeriteUI player frame with a JuNNeZ-style power bar, and its pet frame
  local function UnitFrame(name)
    local frame = NewWidget("Frame", name)
    frame.Health = NewWidget("StatusBar")
    frame.Health.Preview = NewWidget("StatusBar")
    frame.Power = NewWidget("StatusBar")
    frame.Power.FakeFill = NewWidget("Texture")
    env[name] = frame
    return frame
  end
  game.azPlayer = UnitFrame("AzeriteUnitFramePlayer")
  game.azPet = UnitFrame("AzeriteUnitFramePet")

  -- Ace3 stand-ins: enough for the addon, with real profiles
  local db
  local profiles = {}
  local function newDB(defaults)
    local callbacks = {}
    local function fire(name) for _, cb in ipairs(callbacks) do if cb[2] == name and cb[1][cb[3]] then cb[1][cb[3]](cb[1]) end end end
    local function profileFor(name)
      profiles[name] = profiles[name] or DeepCopy(defaults.profile)
      return profiles[name]
    end
    db = {
      current = "Default",
      char = DeepCopy(defaults.char), global = DeepCopy(defaults.global),
      RegisterCallback = function(owner, event, method) table.insert(callbacks, { owner, event, method }) end,
      GetCurrentProfile = function(self) return self.current end,
      GetProfiles = function() local list = {} for name in pairs(profiles) do list[#list + 1] = name end table.sort(list) return list end,
      SetProfile = function(self, name) self.current = name; self.profile = profileFor(name); fire("OnProfileChanged") end,
      CopyProfile = function(self, name) local copy = DeepCopy(profileFor(name)); for k in pairs(self.profile) do self.profile[k] = nil end; for k, v in pairs(copy) do self.profile[k] = v end; fire("OnProfileCopied") end,
      DeleteProfile = function(self, name) profiles[name] = nil end,
      ResetProfile = function(self) local fresh = DeepCopy(defaults.profile); for k in pairs(self.profile) do self.profile[k] = nil end; for k, v in pairs(fresh) do self.profile[k] = v end; fire("OnProfileReset") end,
    }
    db.profile = profileFor("Default")
    if opts.oldProfile then for k, v in pairs(opts.oldProfile) do db.profile[k] = v end end
    game.db = db
    return db
  end
  local libs = {
    ["AceConfig-3.0"] = { RegisterOptionsTable = function() end },
    ["AceConfigDialog-3.0"] = { OpenFrames = {}, AddToBlizOptions = function() end,
      Open = function(self, app) self.OpenFrames[app] = true end, Close = function(self, app) self.OpenFrames[app] = nil end },
    ["AceConfigRegistry-3.0"] = { NotifyChange = function() end },
    ["AceDB-3.0"] = { New = function(_, _, defaults) return newDB(defaults) end },
    ["AceAddon-3.0"] = { GetAddon = function() end },
    ["LibDataBroker-1.1"] = { NewDataObject = function(_, _, t) return t end },
    ["LibDBIcon-1.0"] = { IsRegistered = function() return false end, Register = function() end, Show = function() end, Hide = function() end },
  }
  game.libs = libs
  env.LibStub = function(name) return libs[name] end

  -------------------------------------------------------------------------
  -- Load what the TOC loads
  -------------------------------------------------------------------------
  local ns = {}
  game.ns = ns
  local tocName = opts.forever and "AzUI_Color_Picker_Camelot.toc" or "AzUI_Color_Picker.toc"
  local toc = assert(io.open(tocName, "r"))
  for line in toc:lines() do
    line = line:gsub("\r", "")
    if line:match("%.lua$") and not line:match("^Libs") and not line:match("^#") then
      local chunk = assert(loadfile((line:gsub("\\", "/"))))
      setfenv(chunk, env)
      chunk("AzUI_Color_Picker", ns)
    end
  end
  toc:close()
  game.P = ns.P

  function game.fire(event, ...)
    for _, frame in ipairs(events[event] or {}) do
      if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
  end
  function game.flush()
    while #game.timers > 0 do table.remove(game.timers, 1)() end
  end
  -- runs every top-level OnUpdate (the animator among them) for `seconds`
  function game.advance(seconds)
    local step = 1 / 60
    for _ = 1, math.floor(seconds / step + 0.5) do
      game.time = game.time + step
      for _, w in ipairs(frames) do
        if w.shown and w.scripts.OnUpdate and w.kind == "Frame" and not w.parent then w.scripts.OnUpdate(w, step) end
      end
    end
  end

  if opts.stable then opts.stable(env, game) end
  if not opts.noLogin then
    game.fire("ADDON_LOADED", "AzUI_Color_Picker")
    game.fire("PLAYER_ENTERING_WORLD")
    game.flush()
  end
  return game
end

return Mock
