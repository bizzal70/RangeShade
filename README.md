# RangeShade

Shades action bar buttons red when your target is out of range. An addon for World of Warcraft: Forever (client 1.60.x).

## What it does

When an ability cannot reach your target, World of Warcraft only turns the small keybind text on its button red. RangeShade tints the whole icon red, so it is obvious at a glance.

It covers the eight standard action bars. When a button is back in range it gets the game's normal colour back, including the blue out-of-mana tint and the grey unusable one.

## Options

Type `/rangeshade` to open the options, or use the addon's entry in the minimap's addon list.

| Setting | What it does | Command |
|---|---|---|
| Shade out-of-range buttons red | Turns the addon on or off | `/rangeshade on`, `off`, `toggle` |
| Melee abilities too | Also shades melee attacks (see below) | `/rangeshade melee` |
| Shading | Strong or soft red | `/rangeshade strong`, `soft` |

## Melee abilities

On the Forever client the game reports melee abilities as "in range" however far away the target is, so RangeShade measures the distance for those itself. The shortest distance the game will measure for an addon is about 10 yards, so a melee button clears a little before you are actually close enough to hit.

## Known limits

- The pet bar and stance bar are not covered.
- During combat the game restricts what addons may read. Where it will not report range, a button is left unshaded.
- `/rangeshade debug` lists what the game reports for each button, which helps explain why one is or is not shaded.

## More from this author

Other small addons for World of Warcraft: Forever, all free:

- **[GatherTrail](https://github.com/bizzal70/GatherTrail)** remembers ore, herbs, fishing pools, skinning spots, chests and rares across all your characters, and guides you back to the best spots.
- **[MouseTip](https://www.curseforge.com/wow/addons/mousetip)** shows tooltips at your mouse cursor.
- **[VendorMate](https://github.com/bizzal70/VendorMate)** sells junk and repairs at vendors, and warns when your gear is wearing out.
- **[AltBoard](https://github.com/bizzal70/AltBoard)** shows all your characters at a glance: level, gold, rested and where you left them.

## Installing

Copy this folder into `World of Warcraft\_classic_beta_\Interface\AddOns\` as `RangeShade`, restart the game, and enable RangeShade on the character select screen.

## Developing

- `tools\Link-Addon.ps1` links this folder into the game's AddOns folder, so edits are live after `/reload`.
- `python tests/run.py` runs the tests (`pip install lupa` once). They run the addon in real Lua 5.1 against a fake of the game's API.
- `tools\Publish.ps1 -Message "..."` runs the tests and pushes to GitHub. GitHub runs the tests again on every push.

## Releasing

`tools\Publish.ps1 -Message "Release x.y.z" -Tag vx.y.z` publishes and tags. The tag makes GitHub package the addon and attach the zip to a GitHub release.

To also upload to CurseForge and Wago, two things are needed once:

1. Create the project on each site, then add its ID to `RangeShade.toc`:
   `## X-Curse-Project-ID: 123456` and `## X-Wago-ID: abc123`.
2. Create an upload token on each site and add it to this repository's secrets (Settings, Secrets and variables, Actions) as `CF_API_KEY` and `WAGO_API_TOKEN`.

Before each release: raise `## Version:` in `RangeShade.toc` and add the version to `CHANGELOG.md`.

## Licence

MIT. See `LICENSE`.
