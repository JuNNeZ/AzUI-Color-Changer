-- StudioPack.lua - the optional AzUI Studio art pack.
--
-- Hand-drawn art that goes beyond the generated shapes in Media\Studio, briefed in
-- Tools\AssetBrief. WoW cannot ask whether a file exists, so each piece is used only
-- once it is switched on here, after its files are in Media\StudioPack:
--
--   logo        logo.tga                  64x64    the mark beside "AzUI Studio"
--   corners     corner.tga                64x64    bronze filigree, top-left corner;
--                                                  mirrored for the other three
--   conditions  condition-<key>.tga       64x64    one per rule condition: combat,
--                                                  mounted, resting, stealth, dead,
--                                                  spec, instance from the brief;
--                                                  the rest, and role-tank, -healer
--                                                  and -damager, drawn by
--                                                  Tools\MakeConditionIcons.py
--   emptyRules  empty-rules.tga           256x128  shown when there are no rules
--   emptyPets   empty-pets.tga            256x128  shown when no pets are known
--
-- All are 32-bit TGA. The shapes the code tints (conditions) are white on
-- transparent; the others are drawn in their own colours.
local _, ns = ...
local Studio = ns.OptionsKit and ns.OptionsKit.Studio
if not Studio then return end

Studio.Pack = {
  logo       = true,
  corners    = true,
  conditions = true,
  emptyRules = true,
  emptyPets  = true,
}

function Studio.PackMedia(name)
  return "Interface\\AddOns\\AzUI_Color_Picker\\Media\\StudioPack\\" .. name .. ".tga"
end
