# Translating

AzUI Color Picker follows your game client's language. Deutsch, Français, Español (España and México), Português (Brasil), Italiano, Русский, 한국어, 简体中文 and 繁體中文 are in, and every text the addon shows is translated. They are first versions: if a line reads oddly to a native speaker, a correction is very welcome.

## Translating on CurseForge

The translations live on the addon's CurseForge project, under **Localization**. Pick your language, find the English phrase and type or correct its translation there; no account on GitHub is needed. The next release picks your work up by itself.

Keep these as they are, in the same number: `%d`, `%s` and `%.1f` (numbers and names the addon fills in), colour codes such as `|cff999999` and `|r`, `!AZUI1!`, and `[AzUI: ` in the Share in Chat help, which is what the addon looks for in chat.

A phrase with no translation shows in English, so a language can be partial and nothing breaks.

## How the files work

Each language is one file in `Locales/`, such as `Locales/deDE.lua`. The English text is the key, and a line gives its translation:

```lua
T["Health Bar"] = "Lebensleiste"
```

When the addon is packaged, the packager fills each file from CurseForge in place of its `--@localization(...)@` line, and leaves out the copy kept in the repository (between `--@do-not-package@` and `--@end-do-not-package@`). The copy is what the addon uses while developing, and what the tests check.

## For the maintainer: keeping CurseForge in step

New or changed English texts reach translators only once they are imported. Before a release:

1. From the addon folder, run `lua Tools/ExportLocales.lua`. It writes `Tools/CurseForge/enUS.lua` (every phrase the addon shows) and one file per language with the translations in `Locales/`.
2. On CurseForge, under **Localization → Import**, import `enUS.lua` into English, then each language file into its language, as a **Lua Additive Table** with the table name `T`. Choose to keep existing translations, so work done on CurseForge is not overwritten.
3. Release as usual. A release made before the import ships the texts CurseForge does not have in English.

To bring CurseForge's translations back into the repository, export them from **Localization → Export** in the same format and paste them over the copy between the markers.

## Corrections on GitHub

A pull request on `Locales/<language>.lua` still works: change only the text on the right of the `=`, keep the key on the left exactly as it is, and the maintainer imports it into CurseForge before the next release.

## Checking it

The tests check every translation on each pull request: that each key is still a text the addon shows, and that the `%` codes and colour codes survived. To run the check yourself, from the addon folder with Lua 5.1:

```
lua Tools/TestLocales.lua
```

It also lists, for each language, any text that has no translation yet.

## Names to keep

Use the names the game uses in your language for game terms (Power bar, Raid, Specialization, Tank and so on), so the addon reads like the game. Names of addons (AzeriteUI, ElvUI, Z-Perl, PitBull 4, oUF) are not translated.
