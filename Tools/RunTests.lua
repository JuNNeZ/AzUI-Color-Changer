-- Run from the addon directory: lua Tools/RunTests.lua (Lua 5.1).
-- Every check CI runs, in its order: accidental globals, then each suite and each
-- window mode. Prints one line per run and a total; exits 1 if anything failed.
local RUNS = {
  { "Tools/CheckGlobals.lua" },
  { "Tools/TestClients.lua" },
  { "Tools/TestPanel.lua" },
  { "Tools/TestPanel.lua", "art" },
  { "Tools/TestPanel.lua", "plain" },
  { "Tools/TestPanel.lua", "stock" },
  { "Tools/TestPanel.lua", "aui6" },
  { "Tools/TestFeatures.lua" },
  { "Tools/TestStudio.lua" },
  { "Tools/TestFrames.lua" },
  { "Tools/TestRules.lua" },
  { "Tools/TestEngine.lua" },
  { "Tools/TestChat.lua" },
  { "Tools/TestLocales.lua" },
}

local windows = package.config:sub(1, 1) == "\\"
local lua = arg and arg[-1] or "lua"
if lua:find(" ") then lua = '"' .. lua .. '"' end

local failed, checks = 0, 0
for _, run in ipairs(RUNS) do
  local command = lua .. " " .. table.concat(run, " ") .. " 2>&1"
  local pipe = io.popen(windows and ('"' .. command .. '"') or command)
  local out = pipe:read("*a")
  pipe:close()
  -- every suite ends with "<n> ... passed" (or "no accidental globals") when it got through
  local last
  for line in out:gmatch("[^\n]+") do last = line end
  last = (last or ""):gsub("\r", "")
  local ok = last:find("passed", 1, true) or last:find("no accidental globals", 1, true)
  local name = table.concat(run, " ")
  if ok then
    if last:find("passed", 1, true) then checks = checks + (tonumber(last:match("^(%d+)")) or 0) end
    print(string.format("ok    %-32s %s", name, last))
  else
    failed = failed + 1
    print(string.format("FAIL  %-32s", name))
    -- the failure and where it was, without the whole traceback
    for line in out:gmatch("[^\n]+") do
      if line:find("%.lua:%d+:") or line:find("FAILED", 1, true) then print("      " .. line:gsub("\r", "")) break end
    end
  end
end

print(string.rep("-", 60))
if failed > 0 then
  print(failed .. " of " .. #RUNS .. " runs failed")
  os.exit(1)
end
print(string.format("all %d runs passed, %d checks", #RUNS, checks))
