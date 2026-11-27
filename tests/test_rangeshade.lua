-- The game's side: action buttons, and what it reports about each slot.
HAS_RANGE = {}   -- slot -> whether the action has a range at all
IN_RANGE = {}    -- slot -> true, false, or nil when there is no target
USABILITY = {}   -- slot -> { usable, notEnoughMana }
SECRET = {}      -- stands for a value the client withholds in combat
issecretvalue = function(value) return value == SECRET end
-- slot -> { spell id, reach in yards, harmful }; like this client, the game
-- calls a melee ability "in range" however far away the target is.
SPELLS = {}
TARGET = nil     -- nil, or { hostile = bool, near = whether within duelling distance }
DISTANCE_CHECKS = 0
UnitExists = function(unit) return unit == "target" and TARGET ~= nil end
UnitCanAttack = function() return TARGET ~= nil and TARGET.hostile end
CheckInteractDistance = function() DISTANCE_CHECKS = DISTANCE_CHECKS + 1; return TARGET.near end
GetActionInfo = function(slot) local s = SPELLS[slot]; if s then return "spell", s[1] end end
C_Spell = { GetSpellInfo = function(id)
    for _, s in pairs(SPELLS) do if s[1] == id then return { name = "Spell " .. id, maxRange = s[2] } end end
end }
C_ActionBar = {
    -- Like the real client, it refuses to answer without its second argument.
    IsHarmfulAction = function(slot, useNeutral)
        if useNeutral == nil then
            error("bad argument #2 to '?' (Usage: local isHarmful = C_ActionBar.IsHarmfulAction(actionID, useNeutral))")
        end
        if BREAK_MELEE then error("something this client does differently") end
        return SPELLS[slot] and SPELLS[slot][3] or false
    end,
    HasRangeRequirements = function(slot) return HAS_RANGE[slot] or false end,
    IsActionInRange = function(slot) return IN_RANGE[slot] end,
    IsUsableAction = function(slot)
        local state = USABILITY[slot]
        if state then return state[1], state[2] end
        return true, false
    end,
}

local function makeButton(name, slot)
    local button = CreateFrame("Button", name)
    button.action = slot
    button.icon = button:CreateTexture()
    -- The game recolours the icon whenever usability changes.
    button.UpdateUsable = function(self) self.icon:SetVertexColor(1, 1, 1) end
    return button
end
for i = 1, 12 do makeButton("ActionButton" .. i, i) end
makeButton("MultiBar5Button3", 150)
makeButton("MultiBarLeftButton1", 0)   -- an empty button

local ns = LoadAddon(ADDON_DIR, "RangeShade")
local function check(cond, what) if not cond then error("CHECK FAILED: " .. what, 2) end; io.write("pass  ", what, "\n") end
local function colour(button) local c = button.icon.__color; return c and ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) or "untouched" end
local RED, SOFT, WHITE, BLUE, GREY = "0.90 0.15 0.15", "1.00 0.50 0.50", "1.00 1.00 1.00", "0.50 0.50 1.00", "0.40 0.40 0.40"

Fire("ADDON_LOADED", "RangeShade"); Fire("PLAYER_LOGIN")
local tick = TICKERS[1]
check(type(tick) == "function" and ns.db.enabled and ns.db.strength == "strong", "it starts checking at login, with default settings")

HAS_RANGE[1], IN_RANGE[1] = true, false
HAS_RANGE[2], IN_RANGE[2] = true, true
HAS_RANGE[150], IN_RANGE[150] = true, false
IN_RANGE[3] = false   -- no range requirement, so the answer means nothing
tick()
check(colour(ActionButton1) == RED, "a button whose action cannot reach the target is shaded red")
check(colour(MultiBar5Button3) == RED, "on the extra action bars too")
check(colour(ActionButton2) == "untouched" and colour(ActionButton3) == "untouched" and colour(MultiBarLeftButton1) == "untouched", "buttons in range, without a range, or empty are left alone")

ActionButton1:UpdateUsable()
check(colour(ActionButton1) == RED, "when the game recolours a shaded button, the shade goes straight back on")
ActionButton2:UpdateUsable()
check(colour(ActionButton2) == WHITE, "but a button in range keeps the game's colour")

IN_RANGE[1] = true
tick()
check(colour(ActionButton1) == WHITE, "coming back into range restores the normal colour")

IN_RANGE[1] = false; tick()
IN_RANGE[1] = nil; USABILITY[1] = { false, true }; tick()
check(colour(ActionButton1) == BLUE, "losing the target restores the game's out-of-mana colour where that applies")
IN_RANGE[1] = false; tick()
IN_RANGE[1] = nil; USABILITY[1] = { false, false }; tick()
check(colour(ActionButton1) == GREY, "or its unusable colour")
USABILITY[1] = nil

IN_RANGE[1] = 0; tick()
check(colour(ActionButton1) == RED, "an older client's 0 for out of range is understood")
IN_RANGE[1] = false

IN_RANGE[4], HAS_RANGE[4] = SECRET, true
tick()
check(colour(ActionButton4) == "untouched", "a range the client withholds is not guessed at")

HAS_RANGE[5], IN_RANGE[5] = true, false
ActionButton5.__shown = false
tick()
check(colour(ActionButton5) == "untouched", "a hidden button is not touched")

SlashCmdList.RANGESHADE("soft")
check(colour(ActionButton1) == SOFT and ns.db.strength == "soft", "/rangeshade soft lightens the shading at once")
SlashCmdList.RANGESHADE("strong")

SlashCmdList.RANGESHADE("off")
check(colour(ActionButton1) == WHITE and colour(MultiBar5Button3) == WHITE and not ns.db.enabled, "/rangeshade off removes the shading at once")
tick()
check(colour(ActionButton1) == WHITE, "and it stays off")
SlashCmdList.RANGESHADE("toggle")
check(colour(ActionButton1) == RED and ns.db.enabled, "/rangeshade toggle turns it back on")

-- melee abilities: the game says "in range" whatever the distance
SPELLS[7] = { 2973, 5, true }     -- a melee strike
SPELLS[8] = { 133, 35, true }     -- a ranged spell, in range
SPELLS[9] = { 1459, 0, false }    -- a buff: no reach, not an attack
SPELLS[10] = { 1449, 0, true }    -- a point-blank attack with no reach at all
for slot = 7, 10 do HAS_RANGE[slot], IN_RANGE[slot] = true, true end
HAS_RANGE[9], IN_RANGE[9] = false, nil
tick()
check(colour(ActionButton7) == "untouched", "with no target, a melee button is left alone")
TARGET = { hostile = true, near = false }
tick()
check(colour(ActionButton7) == RED, "a melee ability is shaded when the target is beyond melee, though the game calls it in range")
check(colour(ActionButton10) == RED, "so is an attack with no reach of its own")
check(colour(ActionButton8) == "untouched" and colour(ActionButton9) == "untouched", "a ranged spell in range and a buff are not")
TARGET.near = true
tick()
check(colour(ActionButton7) == WHITE, "closing to melee clears it")
TARGET = { hostile = false, near = false }
tick()
check(colour(ActionButton7) == WHITE, "a friendly target is never out of melee")
TARGET = { hostile = true, near = false }; tick()
SlashCmdList.RANGESHADE("melee")
tick()
check(colour(ActionButton7) == WHITE and not ns.db.melee, "/rangeshade melee turns melee shading off")
SlashCmdList.RANGESHADE("melee"); tick()
check(colour(ActionButton7) == RED, "and back on")
SlashCmdList.RANGESHADE("debug")
check(PRINTED[#PRINTED]:find("ActionButton", 1, true) ~= nil or PRINTED[#PRINTED - 1]:find("ActionButton", 1, true) ~= nil, "/rangeshade debug lists what the game reports for each button")
-- the client refuses the distance check
Fire("ADDON_ACTION_FORBIDDEN", "RangeShade", "CheckInteractDistance()")
local checksBefore = DISTANCE_CHECKS
tick()
check(colour(ActionButton7) == WHITE and DISTANCE_CHECKS == checksBefore, "if the game refuses the melee check, it is not asked again and melee buttons clear")
check(colour(ActionButton1) == RED, "while ordinary range shading carries on")
TARGET = nil

-- options window
SlashCmdList.RANGESHADE("")
check(RangeShadeOptions:IsShown(), "/rangeshade opens the options")
local rows = {}
for _, f in ipairs(Frames()) do
    if rawget(f, "Refresh") and f.__scripts.OnClick then rows[#rows + 1] = f end
end
check(#rows == 7, "the options have seven controls")
rows[1].__scripts.OnClick(rows[1])
check(not ns.db.enabled and colour(ActionButton1) == WHITE, "the first switches shading off, taking effect at once")
rows[1].__scripts.OnClick(rows[1])
rows[2].__scripts.OnClick(rows[2])
check(not ns.db.melee, "the second switches melee shading")
rows[2].__scripts.OnClick(rows[2])
rows[3].__scripts.OnClick(rows[3])
check(ns.db.strength == "soft" and colour(ActionButton1) == SOFT, "the third changes the strength, taking effect at once")
rows[3].__scripts.OnClick(rows[3])
check(ns.db.strength == "strong", "and comes back round")
RangeShade_OnAddonCompartmentClick()
check(not RangeShadeOptions:IsShown(), "the minimap addon list entry toggles the options")
SlashCmdList.RANGESHADE("help")

-- a part of the game's API behaving unexpectedly must not stop everything
-- (a second copy of the addon, loaded last so it does not disturb the tests above)
SlashCmdList.RANGESHADE("off")
RangeShadeDB = nil
local ns3 = LoadAddon(ADDON_DIR, "RangeShade")
TARGET = { hostile = true, near = false }
Fire("ADDON_LOADED", "RangeShade"); Fire("PLAYER_LOGIN")
local tick3 = TICKERS[#TICKERS]
BREAK_MELEE = true
local printedBefore = #PRINTED
tick3(); tick3()
check(colour(ActionButton1) == RED and colour(MultiBar5Button3) == RED, "if the melee check hits a problem, ordinary range shading still works")
local complaints = 0
for i = printedBefore + 1, #PRINTED do if PRINTED[i]:find("switched itself off", 1, true) then complaints = complaints + 1 end end
check(complaints == 1, "and the problem is reported once, not on every check")
BREAK_MELEE = false
TARGET = nil

-- The controller's B button closes the addon's windows while they are shown.
do
    local bound = {}
    SetOverrideBinding = function(owner, _, key, command) bound[owner] = { key = key, command = command } end
    ClearOverrideBindings = function(owner) bound[owner] = nil end
    local w = CreateFrame("Frame", "PadCloseTestWindow", UIParent)
    w.HookScript = function(self, event, fn)
        local previous = self.__scripts[event]
        self.__scripts[event] = previous and function(...) previous(...); fn(...) end or fn
    end
    w:Hide()
    ns.CloseWithPadB(w, "PadCloseTestWindow")
    w:Show(); w.__scripts.OnShow(w)
    check(bound[w] and bound[w].key == "PAD2" and bound[w].command == "CLICK PadCloseTestWindowPadClose:LeftButton",
        "while a window is shown, the controller's B button is set to close it")
    w.padClose.__scripts.OnClick(w.padClose)
    check(not w:IsShown(), "pressing B closes it")
    w.__scripts.OnHide(w)
    check(bound[w] == nil, "and B gets its usual job back once it is closed")
end

-- When a fight starts, B is handed back at once, even with the window open.
do
    local bound = {}
    SetOverrideBinding = function(owner, _, key) bound[owner] = key end
    ClearOverrideBindings = function(owner) bound[owner] = nil end
    local w = CreateFrame("Frame", "PadFightTestWindow", UIParent)
    w.HookScript = function(self, event, fn)
        local previous = self.__scripts[event]
        self.__scripts[event] = previous and function(...) previous(...); fn(...) end or fn
    end
    w.GetName = function() return "PadFightTestWindow" end
    w:Hide()
    ns.CloseWithPadB(w, "PadFightTestWindow")
    w:Show(); w.__scripts.OnShow(w)
    check(bound[w] == "PAD2", "with the window open, B closes it")
    Fire("PLAYER_REGEN_DISABLED")
    check(bound[w] == nil, "when a fight starts, B is handed back at once")
    Fire("PLAYER_REGEN_ENABLED")
    check(bound[w] == "PAD2", "and borrowed again once the fight is over")
    w:Hide(); w.__scripts.OnHide(w)
end

-- Flashing when an ability comes off cooldown.
do
    local ns = ns3   -- the addon as loaded the second time (after the reload test)
    local FIGHTING = false
    UnitAffectingCombat = function() return FIGHTING end
    InCombatLockdown = function() return FIGHTING end
    local button = CreateFrame("Button", "FlashTestButton")
    button.cooldown = CreateFrame("Cooldown", "FlashTestButtonCooldown", button)
    rawset(button, "IsVisible", function() return true end)
    ns.WatchCooldown(button)
    local cd = button.cooldown
    local before = ns.flashes
    check(ns.db.flash == "combat", "flashing starts on, for fights")
    -- In a fight, a real cooldown ends: flash.
    FIGHTING = true
    cd:SetCooldown(SECRET, SECRET)   -- the lengths may be withheld; never read
    NOW = NOW + 8
    cd.__scripts.OnCooldownDone(cd)
    check(ns.flashes == before + 1, "a real cooldown ending in a fight flashes the button")
    -- The global cooldown alone: no flash.
    cd:SetCooldown(SECRET, SECRET)
    NOW = NOW + 1.5
    cd.__scripts.OnCooldownDone(cd)
    check(ns.flashes == before + 1, "the short global cooldown doesn't flash")
    -- Set again while it's still running: still timed from the start.
    cd:SetCooldown(SECRET, SECRET)
    NOW = NOW + 1
    cd:SetCooldown(SECRET, SECRET)
    NOW = NOW + 1.5
    cd.__scripts.OnCooldownDone(cd)
    check(ns.flashes == before + 2, "timed from when the cooldown first started")
    -- Out of a fight: not by default; always flashes; off never.
    FIGHTING = false
    cd:SetCooldown(1, 30); NOW = NOW + 30; cd.__scripts.OnCooldownDone(cd)
    check(ns.flashes == before + 2, "out of a fight, no flash by default")
    SlashCmdList.RANGESHADE("flash")
    check(ns.db.flash == "always", "/rangeshade flash switches to always")
    cd:SetCooldown(1, 30); NOW = NOW + 30; cd.__scripts.OnCooldownDone(cd)
    check(ns.flashes == before + 3, "and then it flashes out of fights too")
    SlashCmdList.RANGESHADE("flash")
    FIGHTING = true
    cd:SetCooldown(1, 30); NOW = NOW + 30; cd.__scripts.OnCooldownDone(cd)
    check(ns.db.flash == "off" and ns.flashes == before + 3, "and off never flashes")
    SlashCmdList.RANGESHADE("flash")
    check(ns.db.flash == "combat", "and round again to fights only")
    -- A cooldown cleared early (reset) doesn't flash later on a stale start.
    cd:SetCooldown(1, 30); cd:Clear(); NOW = NOW + 30
    cd.__scripts.OnCooldownDone(cd)
    check(ns.flashes == before + 3, "a cleared cooldown doesn't flash")
    FIGHTING = false
end

-- Buttons found by what they are: the controller layout's round buttons.
do
    local ns = ns3
    local ALL = {}
    local pad = CreateFrame("CheckButton", "GamepadActionButton7")
    pad.action = 30
    pad.icon = pad:CreateTexture()
    local swirl = CreateFrame("Cooldown", nil, pad)
    rawset(pad, "GetChildren", function() return swirl end)
    rawset(swirl, "IsObjectType", function(_, kind) return kind == "Cooldown" end)
    rawset(pad, "IsObjectType", function(_, kind) return kind == "CheckButton" end)
    rawset(pad, "IsVisible", function() return true end)
    local plain = CreateFrame("Frame", "NotAButton")
    rawset(plain, "IsObjectType", function() return false end)
    ALL = { pad, plain }
    EnumerateFrames = function(after)
        if after == nil then return ALL[1] end
        for i, f in ipairs(ALL) do if f == after then return ALL[i + 1] end end
    end
    SlashCmdList.RANGESHADE("find")
    check(PRINTED[#PRINTED]:find("and 1 other action buttons (", 1, true) and PRINTED[#PRINTED]:find("GamepadActionButton7", 1, true),
        "a controller-layout button holding an action is found: " .. PRINTED[#PRINTED])
    SlashCmdList.RANGESHADE("find")
    check(PRINTED[#PRINTED]:find("and 1 other", 1, true), "and only once, however often it looks")
    -- Its swirl is watched: a real cooldown in a fight flashes it.
    local before = ns.flashes
    InCombatLockdown = function() return true end
    swirl:SetCooldown(1, 10)
    NOW = NOW + 10
    swirl.__scripts.OnCooldownDone(swirl)
    check(ns.flashes == before + 1, "and its cooldown flashes it when ready")
    SlashCmdList.RANGESHADE("flash test")
    check(PRINTED[#PRINTED]:find("Flashed ", 1, true), "/rangeshade flash test flashes the buttons now: " .. PRINTED[#PRINTED])
    InCombatLockdown = function() return false end
    EnumerateFrames = nil
end

-- The glow that stays until the ability is used.
do
    local ns = ns3
    local FIGHTING = true
    InCombatLockdown = function() return FIGHTING end
    UnitAffectingCombat = function() return FIGHTING end
    local button = CreateFrame("Button", "GlowTestButton")
    button.cooldown = CreateFrame("Cooldown", "GlowTestButtonCooldown", button)
    rawset(button, "IsVisible", function() return true end)
    ns.WatchCooldown(button)
    local cd = button.cooldown
    ns.db.flash = "combat"
    check(ns.db.glow, "the glow starts on")
    -- Its own cooldown ends in a fight: flash, then glow.
    cd:SetCooldown(1, 10); NOW = NOW + 10; cd.__scripts.OnCooldownDone(cd)
    check(ns.glowing[button], "a ready ability keeps glowing")
    -- Another spell cast: the global cooldown pauses it, then it's back.
    cd:SetCooldown(1, 1.5); NOW = NOW + 1.5; cd.__scripts.OnCooldownDone(cd)
    check(ns.glowing[button], "the global cooldown from another cast doesn't end it")
    -- The ability itself used: its own cooldown runs; the glow is over until it ends.
    cd:SetCooldown(1, 10); NOW = NOW + 10; cd.__scripts.OnCooldownDone(cd)
    check(ns.glowing[button], "(ready again after its own cooldown: glowing again)")
    cd:SetCooldown(1, 10)
    check(ns.glowing[button], "(paused while its cooldown runs)")
    -- Fight over: every glow stops.
    FIGHTING = false
    Fire("PLAYER_REGEN_ENABLED")
    check(not ns.glowing[button], "the glow stops when the fight ends")
    -- Switched off.
    FIGHTING = true
    SlashCmdList.RANGESHADE("glow")
    cd:SetCooldown(1, 10); NOW = NOW + 10; cd.__scripts.OnCooldownDone(cd)
    check(not ns.glowing[button] and not ns.db.glow, "/rangeshade glow switches it off (the flash stays)")
    SlashCmdList.RANGESHADE("glow")
    FIGHTING = false
    InCombatLockdown = function() return false end
end

-- The flash test shows the glow too, then stops it.
do
    local ns = ns3
    AFTERS = {}
    SlashCmdList.RANGESHADE("flash test")
    local timers = AFTERS; AFTERS = {}
    for _, fn in ipairs(timers) do fn() end
    check(next(ns.glowing) == nil, "the flash test's glow stops after a few seconds")
end

-- The minimap button.
do
    local ns = ns3
    local button = RangeShadeMinimapButton
    Fire("PLAYER_LOGIN")
    check(button and button:IsShown() and ns.db.minimapButton, "a minimap button shows by default")
    SlashCmdList.RANGESHADE("button")
    check(not button:IsShown() and not ns.db.minimapButton, "/rangeshade button hides it")
    SlashCmdList.RANGESHADE("button")
    check(button:IsShown(), "and shows it again")
end

-- 0.4.0: melee refused in a fight, the red border, bindings.
do
    -- A fresh copy (earlier tests deliberately broke the melee check of
    -- the others, which switches it off for their session).
    BREAK_MELEE = false
    local ns = LoadAddon(ADDON_DIR, "RangeShade")
    Fire("ADDON_LOADED", "RangeShade")
    Fire("PLAYER_LOGIN")
    ns.db.enabled, ns.db.strength = true, "strong"
    ActionButton11.__shown, ActionButton12.__shown = true, true
    local FIGHTING = false
    InCombatLockdown = function() return FIGHTING end
    -- A melee button on the first bar, target far away.
    SPELLS[11] = { 401, 5, true }
    HAS_RANGE[11], IN_RANGE[11] = false, nil
    TARGET = { hostile = true, near = false }
    ns.db.melee = true
    Fire("ACTIONBAR_SLOT_CHANGED", 11)
    ns.Check()
    check(ns.Check and ActionButton11.icon.__color and ActionButton11.icon.__color[1] > 0.8, "out of a fight, a far melee target shades a melee button")
    -- In a fight the game refuses the check.
    FIGHTING = true
    local said = #PRINTED
    Fire("ADDON_ACTION_BLOCKED", "RangeShade", "CheckInteractDistance()")
    check(PRINTED[#PRINTED]:find("shaded only out of fights", 1, true), "a refusal in a fight says melee is shaded only out of fights")
    local checks = DISTANCE_CHECKS
    ns.Check()
    check(DISTANCE_CHECKS == checks, "and it stops asking during the fight")
    FIGHTING = false
    Fire("PLAYER_REGEN_ENABLED")
    ns.Check()
    check(DISTANCE_CHECKS > checks, "after the fight it measures again")
    FIGHTING = true
    checks = DISTANCE_CHECKS
    ns.Check()
    check(DISTANCE_CHECKS == checks, "and in later fights it doesn't try (no repeated errors)")
    FIGHTING = false
    -- Asked once per pass, however many melee buttons.
    SPELLS[12] = { 402, 5, true }
    Fire("ACTIONBAR_SLOT_CHANGED", 12)
    checks = DISTANCE_CHECKS
    ns.Check()
    check(DISTANCE_CHECKS == checks + 1, "the distance is measured once per pass, not per button")
    -- The red border.
    check(not ns.db.border, "the red border starts off")
    SlashCmdList.RANGESHADE("border")
    ns.Check()
    check(ns.borders[ActionButton11] and ns.borders[ActionButton11]:IsShown(), "/rangeshade border adds a red border to shaded buttons")
    TARGET = { hostile = true, near = true }
    ns.Check()
    check(not ns.borders[ActionButton11]:IsShown(), "and it goes when the target is in reach")
    SlashCmdList.RANGESHADE("border")
    TARGET = nil
    SPELLS[11], SPELLS[12] = nil, nil
    -- Bindings and the welcome line.
    check(type(RangeShade_ToggleOptions) == "function" and type(RangeShade_Toggle) == "function", "key bindings for the options and for shading on/off")
    -- (Several copies of the addon are loaded in these tests, each with its
    -- own settings, so each may say it once; the point is: never twice.)
    Fire("PLAYER_ENTERING_WORLD")
    said = #PRINTED
    Fire("PLAYER_ENTERING_WORLD")
    local again = 0
    for i = said + 1, #PRINTED do if PRINTED[i]:find("out-of-range buttons turn red", 1, true) then again = again + 1 end end
    check(again == 0, "the welcome line isn't repeated")
end

