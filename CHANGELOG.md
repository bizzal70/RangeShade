# RangeShade

## 0.3.2

- **A ready ability keeps glowing until you use it,** in case you missed the flash: a soft, slow pulse over the button. It pauses for the moment of the global cooldown after each cast (the ability can't be used then anyway) and comes straight back; it stops when you use that ability or the fight ends. Switch it off with `/rangeshade glow` or in the options.

## 0.3.1

- **Works on the controller layout's buttons too.** RangeShade used to look only at the standard action bars by name, so the round buttons of the game's controller layout (and other bar addons' buttons) were neither shaded nor flashed. It now finds any button that holds an action.
- `/rangeshade find` says how many buttons it is watching; `/rangeshade flash test` flashes every button on screen at once so you can see the flash; `/rangeshade debug` now also counts cooldowns seen.

## 0.3.0

- **Flashes a button when its ability is ready again:** when an ability comes off cooldown, its button gives two quick bright pulses, so you see it's ready without watching the swirl. In fights only by default; switch it to always or off in the options or with `/rangeshade flash`.
- The short global cooldown every spell shares never flashes, only real cooldowns (two seconds or more). This works even where the game hides cooldown lengths from addons in a fight: RangeShade times the swirl itself.
- Pairs well with the game's own "Show Numbers for Cooldowns" (Options > Action Bars), which counts the seconds down on the swirl.

## 0.2.4

- **Controller:** when a fight starts, B goes straight back to its usual job, even with a RangeShade window open (it used to stay on closing the window until the fight ended). It closes the window again once the fight is over.

## 0.2.3

- **Controller:** the B button now closes RangeShade's window, like the X and Escape. While one is open, B closes it; once it is closed, B does whatever you have it set to again.

## 0.2.2

- First release on CurseForge. No changes to how the addon works.

## 0.2.1

- Fixed an error on every check ("bad argument #2 to IsHarmfulAction") that 0.2.0 raised in game and that stopped all shading.
- If the melee check ever hits a problem again, it switches itself off with one message; ordinary range shading carries on.

## 0.2.0

- Melee abilities are now shaded too, using a separate distance check, because the game reports them as in range at any distance. Can be turned off.
- `/rangeshade debug` lists what the game reports for each button.

## 0.1.0

- First version: shades action buttons red while their action cannot reach the target.
