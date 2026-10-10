-- luacheck config: catches accidental globals, the bug that is easy to ship in a
-- WoW addon and hard to see. Reading the game's globals is fine (there are thousands),
-- so only writing them is checked.
std = "lua51"
max_line_length = false

exclude_files = {
  "Libs/**",
  "Tools/**",
  ".claude/**",
  ".codex/**",
}

-- Only the 1xx warnings (globals) are checked; the rest is style.
ignore = {
  "113", -- reading a global: the game API
  "2..", -- unused variables
  "3..", -- unused values
  "4..", -- shadowing
  "5..", -- control flow
  "6..", -- whitespace and formatting
}

-- The globals this addon sets on purpose.
globals = {
  "SLASH_AZCOLORPICKER1",
  "SlashCmdList",
  "StaticPopupDialogs",
  "UISpecialFrames",
  "AzUIColorPicker_Binding",
  "BINDING_HEADER_AZUICOLORPICKER",
  "BINDING_NAME_AZUICOLORPICKER_OPEN",
  "BINDING_NAME_AZUICOLORPICKER_RAINBOW",
  "BINDING_NAME_AZUICOLORPICKER_PULSE",
  "BINDING_NAME_AZUICOLORPICKER_NEXT",
  "BINDING_NAME_AZUICOLORPICKER_PETS",
}
