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
local pulseOf = {}   -- button -> its glow, for /rangeshade flash test

-- Plays every watched button's flash now, then a few seconds of the glow;
-- returns how many.
function ns.FlashTest()
    local count = 0
    for button, flash in pairs(flashes) do
        if button:IsVisible() then
            flash:Stop()
            flash:Play()
            count = count + 1
        end
    end
    if ns.db and ns.db.glow then
        for button in pairs(flashes) do ns.glowing[button] = true end
        C_Timer.After(1, function()
            for button in pairs(flashes) do if ns.glowing[button] and pulseOf[button] then pulseOf[button]:Play() end end
        end)
        C_Timer.After(6, function() ns.StopAllGlows() end)
    end
    return count
end

-- After the flash: a soft, slow pulse that keeps going until the ability
-- is used (its own cooldown starts) or the fight ends, in case the flash
-- was missed. It pauses during the short global cooldown, when the
-- ability can't be used anyway, and comes back after.
local function MakePulse(button)
    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 0.85, 0.3, 1)
    if glow.SetBlendMode then glow:SetBlendMode("ADD") end
    glow:SetAlpha(0)
    local group = glow:CreateAnimationGroup()
    if group.SetLooping then group:SetLooping("BOUNCE") end
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.12); fade:SetToAlpha(0.5); fade:SetDuration(0.7)
    return group
end

ns.glowing = {}        -- button -> true while it glows (or is paused for the global cooldown)
local stoppers = {}    -- button -> a function that ends its glow
-- How long a glow lasts out of a fight (with flashing set to "always").
local OUT_OF_FIGHT_GLOW = 30

function ns.StopAllGlows()
    for _, stop in pairs(stoppers) do stop() end
end

-- Watches one action button's cooldown swirl.
function ns.WatchCooldown(button)
    local cooldown = ns.CooldownOf(button)
    if not cooldown or cooldown.rangeShadeWatched then return end
    cooldown.rangeShadeWatched = true
    local flash = MakeFlash(button)
    flashes[button] = flash
    local pulse = MakePulse(button)
    pulseOf[button] = pulse
    local paused = false
    local function StopGlow()
        ns.glowing[button], paused = nil, false
        pulse:Stop()
    end
    stoppers[button] = StopGlow
    local function StartGlow()
        if not (ns.db and ns.db.glow) then return end
        ns.glowing[button], paused = true, false
        pulse:Play()
        if not InFight() then
            -- Out of a fight it doesn't stay on forever.
            C_Timer.After(OUT_OF_FIGHT_GLOW, function()
                if ns.glowing[button] and not InFight() then StopGlow() end
            end)
        end
    end
    -- The glow starts once the flash has played.
    if flash.SetScript then
        flash:SetScript("OnFinished", function() if ns.glowing[button] and not paused then pulse:Play() end end)
    end
    local started
    local function Start()
        if not started then
            started = GetTime()
            ns.cooldownStarts = ns.cooldownStarts + 1
        end
        -- A cooldown started: pause the glow until we know whether it's
        -- only the global cooldown (comes back) or the ability was used.
        if ns.glowing[button] and not paused then
            paused = true
            pulse:Stop()
        end
    end
    for _, method in ipairs({ "SetCooldown", "SetCooldownFromDurationObject", "SetCooldownDuration" }) do
        if type(cooldown[method]) == "function" then pcall(hooksecurefunc, cooldown, method, Start) end
    end
    if type(cooldown.Clear) == "function" then
        pcall(hooksecurefunc, cooldown, "Clear", function()
            started = nil
            if ns.glowing[button] and paused then
                paused = false
                pulse:Play()
            end
        end)
    end
    cooldown:HookScript("OnCooldownDone", function()
        local since = started
        started = nil
        ns.cooldownsDone = ns.cooldownsDone + 1
        if not since or not ns.db then return end
        if GetTime() - since < MIN_COOLDOWN then
            -- Only the global cooldown: a paused glow comes back.
            if ns.glowing[button] and paused then
                paused = false
                pulse:Play()
            end
            return
        end
        -- Its own cooldown ran out: the ability was used, so any old glow
        -- is over, and it's ready again.
        StopGlow()
        local mode = ns.FlashMode().key
        if mode == "off" or (mode == "combat" and not InFight()) then return end
        if not button:IsVisible() then return end
        flash:Stop()
        flash:Play()
        ns.flashes = ns.flashes + 1
        StartGlow()
    end)
end

-- A fight over: every glow stops (the next fight starts fresh).
local fightWatcher = CreateFrame("Frame")
fightWatcher:SetScript("OnEvent", function() ns.StopAllGlows() end)
pcall(fightWatcher.RegisterEvent, fightWatcher, "PLAYER_REGEN_ENABLED")
