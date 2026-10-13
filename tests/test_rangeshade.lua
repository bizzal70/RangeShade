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
    IsHarmfulAction = function(slot) return SPELLS[slot] and SPELLS[slot][3] or false end,
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
check(#rows == 3, "the options have three controls")
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
