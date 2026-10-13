# RangeShade

Shades action bar buttons red when your target is out of range. One addon, one repository: `bizzal70/RangeShade`.

## Workflow

- **No local `.git`.** GitHub holds all history. Publish with `tools\Publish.ps1 -Message "..."`, which uses a throwaway temp clone and runs the tests first.
- **Layout:** the addon's own files (`RangeShade.toc`, `Core.lua`, `Options.lua`) sit at the top of the project, because that is what the release packager expects. `tests/`, `tools/` and `.github/` are development-only and are left out of the released zip by `.pkgmeta`.
- **Testing in game:** `tools\Link-Addon.ps1` junctions this folder into the client's `Interface\AddOns` as `RangeShade`. Edits are live after `/reload`; a new file or a TOC change needs a full client restart.
- **Client install:** `C:\Program Files (x86)\World of Warcraft\_classic_beta_\` (`WowB.exe`). Expect a different flavor folder after launch (reported for 2026-11-04); pass `-Flavor` to the link script then.
- **Tests:** `python tests/run.py` runs the addon in real Lua 5.1 (the `lupa` pip package) against a fake WoW API in `tests/wow_stub.lua`, loading the files the TOC lists. The tests run before every publish and again on GitHub. They prove the addon's own logic only; whether the real client behaves like the stub can only be checked in game. `tests/wow_stub.lua` is a copy of the one in the GatherTrail project and is free to drift.
- **Releases:** a tag starting with `v` runs `.github/workflows/release.yml`, which uses the BigWigs packager. CurseForge and Wago uploads are skipped until their project IDs are in the TOC and their tokens are in the repository secrets. The packager recognises this client: a trial release on 2026-10-13 built `RangeShade-vX.Y.Z-forever.zip` as game version 1.60.1, containing only the addon's files. The uploads to CurseForge and Wago themselves have not been tried.

## How it works

- Polls the standard action buttons ten times a second (`IsActionInRange` / `HasRangeRequirements` / `IsUsableAction`, under `C_ActionBar` where present) and tints `button.icon`. It polls rather than using `ACTION_RANGE_CHECK_UPDATE` so it does not depend on which events this client sends.
- Hooks each button's `UpdateUsable` to re-tint at once, and restores the game's own colours (white, out-of-mana blue, unusable grey) itself rather than calling Blizzard's update.
- Melee: the game reports melee abilities as in range at any distance on this client (seen in game 2026-10-13: ranged shots shaded, Raptor Strike did not). An action counts as melee if `C_ActionBar.IsHarmfulAction` is true and its spell's `maxRange` is 5 or less; it is shaded when `CheckInteractDistance("target", 3)` (duelling distance, about 10 yards) says a hostile target is not near. Whether that rule matches what the game reports for real melee abilities is unverified; `/rangeshade debug` prints the facts per button. If the client blocks `CheckInteractDistance`, the addon hears `ADDON_ACTION_FORBIDDEN` / `_BLOCKED` and stops asking.
- Ordinary range shading was confirmed working in game on 2026-10-13.

## Client facts

Everything below, unless marked verified, comes from community sources during the beta (Warcraft Wiki, GitHub ports, fan guides), not from Blizzard docs. Builds change. Verify in game before relying on any of it.

- Local client was 1.60.1.70338 on 2026-10-11 (read from `WowB.exe`).
- TOC: `## Interface: 16001` (verified in game on build 70338).
- TOC flavor suffix is `_Forever.toc` or `_Camelot.toc`. The TOC `[Game]` variable expands to `Camelot`. Game type for `AllowLoadGameType` is `forever` / `camelot`.
- The client is Retail-based: Midnight 12.x API and UI architecture, not the Classic API. Port from Retail code.
- `WOW_PROJECT_ID` is `18` on build 70338 (verified in game 2026-10-11, along with interface 16001, by a starter addon since removed). Community guides written against earlier builds say it is 1 (`WOW_PROJECT_MAINLINE`); that is out of date, so Retail code gated on `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` will not run here. The name of the constant for 18 is not yet known. Prefer testing for the specific API you need over branching on either number.
- Lua 5.1: no `goto`, no `//`, no bitwise operators (use `bit.band` etc.), no `require`. The TOC is the module loader. Start files with `local addonName, ns = ...`.
- Removed globals: `GetItemInfo`, `GetSpellInfo`, `UnitAura`/`UnitBuff`/`UnitDebuff`, `GetTalentInfo`, `GetNumTalentTabs`, `CombatLogGetCurrentEventInfo`, `InterfaceOptionsFrame_OpenToCategory`. Use `C_Item`, `C_Spell`, `C_UnitAuras`, `C_Traits`, and the `Settings` API.
- `C_Spell.GetSpellInfo` returns a table. Item and spell data can be nil until cached.
- Registering an event that does not exist throws and aborts the file. Wrap speculative `RegisterEvent` calls in `pcall`.
- Secret values (Midnight combat restrictions) are active. In combat, `UnitHealth`, aura data, and some names and booleans can be secret: arithmetic, comparison, and printing fail. Guard with `issecretvalue`, and pass values straight to widgets (`StatusBar:SetValue`, `Cooldown:SetCooldownFromDurationObject`) instead of doing Lua math. Combat-log parsing is not available.
- Check `InCombatLockdown()` before touching protected frames and defer to `PLAYER_REGEN_ENABLED`.
- SavedVariables: initialise in `ADDON_LOADED`. Early beta builds reportedly wrote them but did not read them back; on build 70338 they are read back (confirmed in game 2026-10-11).
