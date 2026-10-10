-- Run from the addon directory: lua Tools/LocaleKeys.lua [out]
-- Lists every L["..."] key the addon's own files use, sorted, one per line as a Lua
-- string. Tools/TestLocales.lua uses the same scan to check the translations.
local M = {}

-- Keys looked up through a variable rather than written as L["..."]
M.EXTRA = { "Ferocity", "Tenacity", "Cunning" } -- P.PET_SPECS, through L[P.specNames[id]]

-- The addon's own Lua files, in TOC order (libraries and locale files left out).
function M.Files()
  local files = {}
  for line in io.lines("AzUI_Color_Picker.toc") do
    line = line:gsub("\r", "")
    if line:match("%.lua$") and not line:match("^Libs") and not line:match("^Locales") then
      files[#files + 1] = (line:gsub("\\", "/"))
    end
  end
  return files
end

-- Every key, as the string it is at run time.
function M.Keys()
  local keys, seen = {}, {}
  local function add(value)
    if not seen[value] then seen[value] = true; keys[#keys + 1] = value end
  end
  for _, file in ipairs(M.Files()) do
    local source = assert(io.open(file)):read("*a")
    -- L["..."]: walked by hand, so an escaped quote inside does not end it
    local at = 1
    while true do
      local start = source:find('L%["', at)
      if not start then break end
      local i = start + 2 -- the opening quote
      while true do
        i = i + 1
        local c = source:sub(i, i)
        if c == "\\" then i = i + 1 elseif c == '"' or c == "" then break end
      end
      add(assert(loadstring("return " .. source:sub(start + 2, i)))())
      at = i + 1
    end
  end
  for _, key in ipairs(M.EXTRA) do add(key) end
  table.sort(keys)
  return keys
end

if arg and arg[0] and arg[0]:match("LocaleKeys%.lua$") then
  local out = arg[1] and assert(io.open(arg[1], "w")) or io.stdout
  for _, key in ipairs(M.Keys()) do out:write((string.format("%q", key):gsub("\\\n", "\\n")), "\n") end
  if out ~= io.stdout then out:close() end
end

return M
