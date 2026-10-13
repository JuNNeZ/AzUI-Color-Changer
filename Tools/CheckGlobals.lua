-- Run from the addon directory: lua Tools/CheckGlobals.lua (Lua 5.1, with luac next to it).
-- The accidental-globals check CI runs with luacheck, for the local test loop, with
-- nothing to install: luac lists every global each file writes (SETGLOBAL), and any not
-- in .luacheckrc's `globals` fails. Reading globals is fine (the game API is thousands).
local Keys = dofile("Tools/LocaleKeys.lua")

-- luac: next to this lua, or on the path (luac5.1 on Linux)
local windows = package.config:sub(1, 1) == "\\"
local function Run(command)
  -- cmd.exe needs the whole line quoted once more when it starts with a quoted path
  local pipe = io.popen(windows and ('"' .. command .. '"') or command)
  local out = pipe:read("*a")
  pipe:close()
  return out
end
local function Quote(path) return '"' .. path .. '"' end

local candidates = {}
local interpreter = arg and arg[-1]
if interpreter then
  local folder = interpreter:match("^(.*)[/\\][^/\\]+$")
  if folder then
    candidates[#candidates + 1] = Quote(folder .. (windows and "\\luac.exe" or "/luac"))
    candidates[#candidates + 1] = Quote(folder .. "/luac5.1")
  end
end
candidates[#candidates + 1] = "luac5.1"
candidates[#candidates + 1] = "luac"
local luac
for _, candidate in ipairs(candidates) do
  if Run(candidate .. " -v 2>&1"):match("Lua 5%.1") then luac = candidate; break end
end
if not luac then
  print("CheckGlobals: no luac for Lua 5.1 found; skipped")
  os.exit(0)
end

-- The globals the addon sets on purpose
local config = {}
local chunk = assert(loadfile(".luacheckrc"))
setfenv(chunk, config)
chunk()
local allowed = {}
for _, name in ipairs(config.globals or {}) do allowed[name] = true end

-- Every file the addon loads: its own Lua files and the translations
local files, seen = {}, {}
for _, file in ipairs(Keys.Files()) do files[#files + 1] = file; seen[file] = true end
for line in io.lines("AzUI_Color_Picker.toc") do
  line = line:gsub("\r", ""):gsub("\\", "/")
  if line:match("^Locales/.*%.lua$") and not seen[line] then files[#files + 1] = line end
end
-- and any files named on the command line
for i = 1, #(arg or {}) do files[#files + 1] = arg[i] end

local problems, checked = {}, 0
for _, file in ipairs(files) do
  checked = checked + 1
  local listing = Run(luac .. " -p -l " .. Quote(file) .. " 2>&1")
  for lineNumber, name in listing:gmatch("%[(%d+)%]%s+SETGLOBAL%s+[^;]*;%s*([%w_]+)") do
    if not allowed[name] then problems[#problems + 1] = file .. ":" .. lineNumber .. ": sets the global " .. name end
  end
end

for _, problem in ipairs(problems) do print(problem) end
if #problems > 0 then
  print(#problems .. " accidental globals")
  os.exit(1)
end
print(checked .. " files checked, no accidental globals")
