-- Share.lua - turns your setup, or the parts you tick, into one line of text to paste
-- in Discord or a guide, and reads one back.
--
-- Blizzard's own encoder does the work, so no library is added:
--   C_EncodingUtil.SerializeCBOR -> CompressString -> EncodeBase64, behind "!AZUI1!".
-- CBOR is data only, and every field is type-checked and size-capped on import, so a
-- string can only ever set colours, effects, names and rules.
local _, ns = ...
local P = ns.P
local L = P.L

local PREFIX = "!AZUI1!"
local MAX_TEXT = 200000 -- characters of import string
local MAX_PRESETS, MAX_PETS, MAX_FAMILIES, MAX_RULES = 200, 500, 200, 50
local MAX_NAME = 48

P.SHARE_PARTS = { "colour", "presets", "pets", "families", "rules" }
P.SHARE_PART_NAMES = {
  colour = L["Your colour and effect"], presets = L["Presets"], pets = L["Pet colours"],
  families = L["Family and specialization colours"], rules = L["Rules"],
}
-- What to include in an export; every part to begin with.
P.shareParts = { colour = true, presets = true, pets = true, families = true, rules = true }

function P.CanShare()
  local E = C_EncodingUtil
  return E and E.SerializeCBOR and E.DeserializeCBOR and E.CompressString and E.DecompressString
    and E.EncodeBase64 and E.DecodeBase64 and true or false
end

local function CopyColours(source, keep)
  local out = {}
  for key, colour in pairs(source) do
    if keep == nil or keep(key) then out[key] = P.CopyColour(colour) end
  end
  return out
end

---------------------------------------------------------------------
-- EXPORT
---------------------------------------------------------------------
function P.BuildExport(parts)
  local p = P.DB.profile
  local data = { v = 1 }
  if parts.colour then
    data.color, data.effect, data.secondColor = P.CopyColour(p.color), p.effect, P.CopyColour(p.secondColor)
    data.lowHealthColour = P.CopyColour(p.lowHealthColour)
  end
  if parts.presets then data.presets = CopyColours(p.presets) end
  if parts.pets then
    data.pets = {}
    for number, settings in pairs(p.pets) do
      data.pets[number] = { mode = settings.mode, effect = settings.effect, color = settings.color and P.CopyColour(settings.color) }
    end
  end
  if parts.families then
    data.families = CopyColours(p.familyColours)
    data.specs = CopyColours(p.specColours)
  end
  if parts.rules then
    data.rules = {}
    for i, rule in ipairs(p.rules) do data.rules[i] = P.SanitizeRule(rule) end
  end
  return data
end

-- Returns the string, or nil and why not.
function P.Export(parts)
  if not P.CanShare() then return nil, L["This game client cannot make share strings."] end
  local ok, text = pcall(function()
    local E = C_EncodingUtil
    return PREFIX .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(P.BuildExport(parts or P.shareParts))))
  end)
  if not ok then return nil, L["The share string could not be made."] end
  return text
end

---------------------------------------------------------------------
-- IMPORT
---------------------------------------------------------------------
local function CleanName(name)
  if type(name) ~= "string" then return end
  name = strtrim((name:gsub("[%c|]", "")))
  if name == "" then return end
  return name:sub(1, MAX_NAME)
end

local function Count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- Only what this version understands survives, each checked and capped.
local function Sanitize(data)
  if type(data) ~= "table" or data.v ~= 1 then return end
  local clean = {}
  if data.color ~= nil then
    clean.color = P.SanitizeColour(data.color)
    clean.effect = P.IsEffect(data.effect) and data.effect or "static"
    clean.secondColor = P.SanitizeColour(data.secondColor)
    clean.lowHealthColour = P.SanitizeColour(data.lowHealthColour)
  end
  if type(data.presets) == "table" then
    clean.presets = {}
    for name, colour in pairs(data.presets) do
      name, colour = CleanName(name), P.SanitizeColour(colour)
      if name and colour and Count(clean.presets) < MAX_PRESETS then clean.presets[name] = colour end
    end
  end
  if type(data.pets) == "table" then
    clean.pets = {}
    for number, settings in pairs(data.pets) do
      number = tonumber(number)
      if number and number > 0 and type(settings) == "table" and Count(clean.pets) < MAX_PETS then
        local mode = (settings.mode == "family" or settings.mode == "custom" or settings.mode == "off") and settings.mode or "family"
        clean.pets[number] = {
          mode = mode, color = P.SanitizeColour(settings.color),
          effect = P.IsEffect(settings.effect) and settings.effect or "static",
        }
      end
    end
  end
  if type(data.families) == "table" then
    clean.families = {}
    for id, colour in pairs(data.families) do
      id, colour = tonumber(id), P.SanitizeColour(colour)
      if id and colour and Count(clean.families) < MAX_FAMILIES then clean.families[id] = colour end
    end
  end
  if type(data.specs) == "table" then
    clean.specs = {}
    for id, colour in pairs(data.specs) do
      id, colour = tonumber(id), P.SanitizeColour(colour)
      if id and P.specNames[id] and colour then clean.specs[id] = colour end
    end
  end
  if type(data.rules) == "table" then
    clean.rules = {}
    for i = 1, math.min(#data.rules, MAX_RULES) do
      clean.rules[#clean.rules + 1] = P.SanitizeRule(data.rules[i])
    end
  end
  return clean
end

-- Returns the checked data, or nil and why not.
function P.Decode(text)
  if not P.CanShare() then return nil, L["This game client cannot read share strings."] end
  if type(text) ~= "string" then return nil, L["Paste a share string first."] end
  text = text:gsub("%s", "")
  if text == "" then return nil, L["Paste a share string first."] end
  if #text > MAX_TEXT then return nil, L["That string is too long to be an AzUI share string."] end
  if text:sub(1, #PREFIX) ~= PREFIX then return nil, L["That is not an AzUI share string. They start with !AZUI1!"] end
  local ok, data = pcall(function()
    local E = C_EncodingUtil
    return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(text:sub(#PREFIX + 1))))
  end)
  if not ok or type(data) ~= "table" then return nil, L["That share string is damaged or incomplete."] end
  local clean = Sanitize(data)
  if not clean then return nil, L["That share string is from a newer version of AzUI Color Picker."] end
  return clean
end

-- What an import would change, one line per part.
function P.DescribeImport(data)
  local p, lines = P.DB.profile, {}
  if data.color then
    lines[#lines + 1] = L["Your colour"] .. " " .. P.Hex(data.color) .. ", " .. L["effect"] .. " " .. P.EFFECT_VALUES[data.effect]
  end
  if data.presets then
    local count, replaced = 0, {}
    for name in pairs(data.presets) do
      count = count + 1
      if p.presets[name] then replaced[#replaced + 1] = name end
    end
    local line = count .. " " .. (count == 1 and L["preset"] or L["presets"])
    if #replaced > 0 then
      table.sort(replaced)
      line = line .. " (" .. #replaced .. " " .. L["replace yours:"] .. " " .. table.concat(replaced, ", ") .. ")"
    end
    lines[#lines + 1] = line
  end
  if data.pets then
    local count = Count(data.pets)
    lines[#lines + 1] = count .. " " .. (count == 1 and L["pet colour"] or L["pet colours"])
  end
  if data.families then
    local count = Count(data.families) + Count(data.specs or {})
    lines[#lines + 1] = count .. " " .. (count == 1 and L["family or specialization colour"] or L["family and specialization colours"])
  end
  if data.rules then
    local count = #data.rules
    lines[#lines + 1] = count .. " " .. (count == 1 and L["rule"] or L["rules"])
      .. (#p.rules > 0 and (" (" .. L["replaces your"] .. " " .. #p.rules .. ")") or "")
  end
  if #lines == 0 then lines[1] = L["Nothing to import."] end
  return lines
end

function P.ApplyImport(data)
  local p = P.DB.profile
  P.StartFade()
  if data.color then
    p.color = data.color
    p.effect = data.effect
    if data.secondColor then p.secondColor = data.secondColor end
    if data.lowHealthColour then p.lowHealthColour = data.lowHealthColour end
    P.ResetHealthCurves()
  end
  for name, colour in pairs(data.presets or {}) do p.presets[name] = colour end
  for number, settings in pairs(data.pets or {}) do p.pets[number] = settings end
  for id, colour in pairs(data.families or {}) do p.familyColours[id] = colour end
  for id, colour in pairs(data.specs or {}) do p.specColours[id] = colour end
  if data.rules then p.rules = data.rules end
  P.UpdatePetColour()
  P.RulesChanged()
end
