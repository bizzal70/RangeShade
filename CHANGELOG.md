# RangeShade

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
