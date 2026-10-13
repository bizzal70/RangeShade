local addonName, ns = ...

-- Tints an action button's icon red while the action on it cannot reach the
-- current target. The game on its own only turns the small keybind text
-- red, which is easy to miss.
--
-- The buttons are checked a few times a second rather than through the
-- game's own range events: the check is cheap, and it does not depend on
-- which events this client sends or lets an addon read.

-- The standard action bars, twelve buttons each.
local BARS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton",
    "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local BUTTONS_PER_BAR = 12
local CHECK_SECONDS = 0.1

-- How strongly the icon is tinted.
ns.STRENGTHS = {
    { key = "strong", label = "Strong", color = { 0.90, 0.15, 0.15 } },
    { key = "soft", label = "Soft", color = { 1.00, 0.50, 0.50 } },
}

local defaults = {
    enabled = true,
    strength = "strong",
    -- Whether melee abilities are shaded too, using the rougher check
    -- described further down.
    melee = true,
}

-- The game's own icon colours, put back when a button is back in range.
local USABLE = { 1.0, 1.0, 1.0 }
local NO_MANA = { 0.5, 0.5, 1.0 }
local UNUSABLE = { 0.4, 0.4, 0.4 }

-- Newer clients keep these under C_ActionBar; older ones as plain functions.
local actionBar = C_ActionBar or {}
local HasRange = actionBar.HasRangeRequirements or ActionHasRange
local InRange = actionBar.IsActionInRange or IsActionInRange
local IsUsable = actionBar.IsUsableAction or IsUsableAction

local buttons = {}   -- every action button found, with its icon
local shaded = {}    -- button -> true while it is tinted red

function ns.Print(msg)
    print("|cffd9a066RangeShade|r: " .. tostring(msg))
end

-- A value the client may withhold in combat cannot be compared or tested.
local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

function ns.Strength()
    for _, strength in ipairs(ns.STRENGTHS) do
        if strength.key == ns.db.strength then return strength end
    end
    return ns.STRENGTHS[1]
end

---------------------------------------------------------------------------
-- Melee abilities
--
-- On this client the game does not measure melee abilities against the
-- target: it reports them as in range at any distance, so its own answer
-- never shades them. For those, the distance to the target is checked
-- separately. The only short distance the game will measure for an addon
-- is "close enough to duel", about ten yards, so a melee button clears a
-- little before the character is actually in reach.
---------------------------------------------------------------------------

-- An ability that reaches this far or less is a melee one.
local MELEE_REACH_YARDS = 5
-- CheckInteractDistance's index for the duelling distance, about 10 yards.
local DUEL_DISTANCE = 3

local meleeRefused = false   -- the client would not allow the distance check
local reachCache = {}        -- spell id -> its reach in yards, or false

-- How far a spell reaches, or nil if the client will not say.
local function SpellReach(spellID)
    local reach = reachCache[spellID]
    if reach == nil then
        reach = false
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
        if Usable(info) and Usable(info.maxRange) then
            reach = info.maxRange
        end
        reachCache[spellID] = reach
    end
    return reach or nil
end

-- Whether the action in a slot is an attack that has to be made from
-- melee reach.
local function IsMelee(slot)
    local harmful = actionBar.IsHarmfulAction and actionBar.IsHarmfulAction(slot)
    if not Usable(harmful) or not harmful then return false end
    local actionType, id = GetActionInfo(slot)
    if not Usable(actionType) or actionType ~= "spell" or not Usable(id) then return false end
    local reach = SpellReach(id)
    return reach ~= nil and reach <= MELEE_REACH_YARDS
end

-- Whether there is something to attack and it is too far away to hit.
local function TargetBeyondMelee()
    if meleeRefused then return false end
    local exists = UnitExists("target")
    if not Usable(exists) or not exists then return false end
    local hostile = UnitCanAttack("player", "target")
    if not Usable(hostile) or not hostile then return false end
    local near = CheckInteractDistance("target", DUEL_DISTANCE)
    return Usable(near) and near == false
end

-- Whether the action in a slot cannot reach the target.
local function OutOfRange(slot)
    if not Usable(slot) or slot == 0 then return false end
    local hasRange = HasRange(slot)
    if Usable(hasRange) and hasRange then
        local inRange = InRange(slot)
        -- nil means there is nothing to measure against (no target).
        if Usable(inRange) and (inRange == false or inRange == 0) then
            return true
        end
    end
    return ns.db.melee and IsMelee(slot) and TargetBeyondMelee()
end

-- "/rangeshade debug": what the game says about each button's action, to
-- work out why a button is or is not shaded.
local function PrintDebug(buttons)
    local function Show(value)
        if value == nil then return "nil" end
        if not Usable(value) then return "(withheld)" end
        return tostring(value)
    end
    ns.Print(("Target beyond melee: %s. Melee check refused by the game: %s."):format(
        tostring(TargetBeyondMelee()), tostring(meleeRefused)))
    local shown = 0
    for _, entry in ipairs(buttons) do
        local button = entry.button
        local slot = button.action
        if Usable(slot) and slot ~= 0 and button:IsVisible() then
            local actionType, id = GetActionInfo(slot)
            if Usable(actionType) then
                shown = shown + 1
                local name, reach = "?", nil
                if actionType == "spell" and Usable(id) then
                    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
                    name = Usable(info) and Usable(info.name) and info.name or "?"
                    reach = SpellReach(id)
                end
                ns.Print(("%s: %s %s \"%s\" reach=%s hasRange=%s inRange=%s harmful=%s melee=%s shaded=%s"):format(
                    button:GetName() or "?", actionType, Show(id), name, Show(reach),
                    Show(HasRange(slot)), Show(InRange(slot)),
                    Show(actionBar.IsHarmfulAction and actionBar.IsHarmfulAction(slot)),
                    tostring(IsMelee(slot)), tostring(OutOfRange(slot))))
            end
        end
    end
    if shown == 0 then
        ns.Print("No action buttons with anything on them were found.")
    end
end

local function Tint(icon, color)
    icon:SetVertexColor(color[1], color[2], color[3])
end

-- Puts back the colour the game would have given the icon.
local function Restore(icon, slot)
    local color = USABLE
    if Usable(slot) and slot ~= 0 then
        local usable, noMana = IsUsable(slot)
        if Usable(usable) and not usable then
            color = (Usable(noMana) and noMana) and NO_MANA or UNUSABLE
        end
    end
    Tint(icon, color)
end

local function Check()
    local enabled = ns.db.enabled
    local red = ns.Strength().color
    for _, entry in ipairs(buttons) do
        local button = entry.button
        local slot = button.action
        if enabled and button:IsVisible() and OutOfRange(slot) then
            shaded[button] = true
            Tint(entry.icon, red)
        elseif shaded[button] then
            shaded[button] = nil
            Restore(entry.icon, slot)
        end
    end
end

ns.Check = Check

local function FindButtons()
    for _, bar in ipairs(BARS) do
        for index = 1, BUTTONS_PER_BAR do
            local button = _G[bar .. index]
            local icon = button and (button.icon or _G[bar .. index .. "Icon"])
            if button and icon then
                buttons[#buttons + 1] = { button = button, icon = icon }
                -- The game recolours an icon whenever the action's usability
                -- changes. Tint it again straight away so it does not flash.
                if button.UpdateUsable then
                    hooksecurefunc(button, "UpdateUsable", function(self)
                        if shaded[self] then
                            Tint(icon, ns.Strength().color)
                        end
                    end)
                end
            end
        end
    end
end

SLASH_RANGESHADE1 = "/rangeshade"
SLASH_RANGESHADE2 = "/rshade"
SlashCmdList.RANGESHADE = function(msg)
    local command = (msg or ""):lower():match("^%s*(%S*)")
    if command == "" or command == "options" then
        ns.ToggleOptions()
        return
    elseif command == "on" then
        ns.db.enabled = true
    elseif command == "off" then
        ns.db.enabled = false
    elseif command == "toggle" then
        ns.db.enabled = not ns.db.enabled
    elseif command == "strong" or command == "soft" then
        ns.db.strength = command
    elseif command == "melee" then
        ns.db.melee = not ns.db.melee
        ns.Print("Melee abilities are " .. (ns.db.melee and "shaded too." or "left alone."))
    elseif command == "debug" then
        PrintDebug(buttons)
        return
    else
        ns.Print("/rangeshade - open the options")
        ns.Print("/rangeshade on, off or toggle - shade out-of-range buttons, or leave them alone")
        ns.Print("/rangeshade strong or soft - how red the shading is")
        ns.Print("/rangeshade melee - whether melee abilities are shaded too")
        ns.Print("/rangeshade debug - list what the game reports for each button, to diagnose shading")
        return
    end
    Check()
    ns.Print(ns.db.enabled and ("Out-of-range buttons are shaded red (%s)."):format(ns.Strength().label:lower())
        or "Out-of-range buttons are left as the game shows them.")
    ns.RefreshOptions()
end

-- Entry in the minimap's addon list.
function RangeShade_OnAddonCompartmentClick()
    ns.ToggleOptions()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loaded, blockedFunction)
    if event == "ADDON_LOADED" then
        if loaded ~= addonName then return end
        RangeShadeDB = RangeShadeDB or {}
        for key, value in pairs(defaults) do
            if RangeShadeDB[key] == nil then
                RangeShadeDB[key] = value
            end
        end
        ns.db = RangeShadeDB
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        FindButtons()
        C_Timer.NewTicker(CHECK_SECONDS, Check)
    elseif loaded == addonName and Usable(blockedFunction) and blockedFunction:find("CheckInteractDistance", 1, true) then
        -- The client refused the melee distance check. Stop asking, so it
        -- does not complain again; everything else carries on.
        if not meleeRefused then
            meleeRefused = true
            ns.Print("The game does not let addons measure melee distance here, so melee abilities are not shaded.")
        end
    end
end)
pcall(frame.RegisterEvent, frame, "ADDON_ACTION_FORBIDDEN")
pcall(frame.RegisterEvent, frame, "ADDON_ACTION_BLOCKED")
