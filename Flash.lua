local addonName, ns = ...

-- Flashes an action button when its ability comes off cooldown, so you see
-- at a glance that it's ready again: two quick bright pulses over the icon.
--
-- In a fight the game may not tell addons how long a cooldown is, so this
-- never reads it. Instead it notes, on its own clock, when a button's
-- cooldown swirl starts and when it finishes (the swirl's own "done"
-- moment). A cooldown that lasted under two seconds was only the global
-- cooldown every spell shares, and doesn't flash; anything longer does.

local MIN_COOLDOWN = 2.0

-- When to flash: in fights only (the default), always, or never.
ns.FLASH_MODES = {
    { key = "combat", label = "In fights" },
    { key = "always", label = "Always" },
    { key = "off", label = "Off" },
}

function ns.FlashMode()
    local key = ns.db and ns.db.flash or "combat"
    for _, mode in ipairs(ns.FLASH_MODES) do
        if mode.key == key then return mode end
    end
    return ns.FLASH_MODES[1]
end

ns.flashes = 0   -- how many flashes have played (for the tests and debug)

-- Two quick bright pulses over a button, made once, ahead of any fight.
local function MakeFlash(button)
    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 0.95, 0.6, 1)
    if glow.SetBlendMode then glow:SetBlendMode("ADD") end
    glow:SetAlpha(0)
    local group = glow:CreateAnimationGroup()
    local order = 0
    for _ = 1, 2 do
        local up = group:CreateAnimation("Alpha")
        up:SetFromAlpha(0); up:SetToAlpha(0.75); up:SetDuration(0.12)
        order = order + 1; up:SetOrder(order)
        local down = group:CreateAnimation("Alpha")
        down:SetFromAlpha(0.75); down:SetToAlpha(0); down:SetDuration(0.28)
        order = order + 1; down:SetOrder(order)
    end
    return group
end

local function InFight()
    if InCombatLockdown and InCombatLockdown() then return true end
    local fighting = UnitAffectingCombat and UnitAffectingCombat("player")
    return fighting == true
end

-- A button's cooldown swirl: by the usual names, or any Cooldown child.
function ns.CooldownOf(button)
    local name = button.GetName and button:GetName()
    local cooldown = rawget(button, "cooldown") or rawget(button, "Cooldown") or (name and _G[name .. "Cooldown"])
    if cooldown then return cooldown end
    if button.GetChildren then
        local ok, children = pcall(function() return { button:GetChildren() } end)
        for _, child in ipairs(ok and children or {}) do
            local okType, isCooldown = pcall(child.IsObjectType, child, "Cooldown")
            if okType and isCooldown then return child end
        end
    end
end

ns.cooldownStarts, ns.cooldownsDone = 0, 0
local flashes = {}   -- button -> its flash, for /rangeshade flash test

-- Plays every watched button's flash now; returns how many.
function ns.FlashTest()
    local count = 0
    for button, flash in pairs(flashes) do
        if button:IsVisible() then
            flash:Stop()
            flash:Play()
            count = count + 1
        end
    end
    return count
end

-- Watches one action button's cooldown swirl.
function ns.WatchCooldown(button)
    local cooldown = ns.CooldownOf(button)
    if not cooldown or cooldown.rangeShadeWatched then return end
    cooldown.rangeShadeWatched = true
    local flash = MakeFlash(button)
    flashes[button] = flash
    local started
    local function Start()
        if not started then
            started = GetTime()
            ns.cooldownStarts = ns.cooldownStarts + 1
        end
    end
    for _, method in ipairs({ "SetCooldown", "SetCooldownFromDurationObject", "SetCooldownDuration" }) do
        if type(cooldown[method]) == "function" then pcall(hooksecurefunc, cooldown, method, Start) end
    end
    if type(cooldown.Clear) == "function" then
        pcall(hooksecurefunc, cooldown, "Clear", function() started = nil end)
    end
    cooldown:HookScript("OnCooldownDone", function()
        local since = started
        started = nil
        ns.cooldownsDone = ns.cooldownsDone + 1
        if not since or not ns.db then return end
        local mode = ns.FlashMode().key
        if mode == "off" or (mode == "combat" and not InFight()) then return end
        if GetTime() - since < MIN_COOLDOWN then return end
        if not button:IsVisible() then return end
        flash:Stop()
        flash:Play()
        ns.flashes = ns.flashes + 1
    end)
end

