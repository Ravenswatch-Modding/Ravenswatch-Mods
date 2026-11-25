local R = require "rsmm"

if not (R.stat and R.stat.enable_writes and R.stat.modify
        and R.entity and R.entity.ready and R.on
        and R.config and R.config.get and R.config.on_change
        and R.schedule and R.schedule.next_main) then
    R.log("[double-movement-speed] This mod needs a newer RSMM loader with stat, config, and scheduling support.")
    return
end

R.stat.enable_writes()

local initialized = false
local applying = false
local starting_speed = nil
local applied_percent = nil

local function configured_percent()
    local value = tonumber(R.config.get("target_percent", 200)) or 200
    return math.max(25, math.min(500, math.floor(value + 0.5)))
end

local function modify_bonus(bonus)
    if applying then return false end
    applying = true
    local ok = R.stat.modify("move_speed", bonus, -1)
    applying = false
    return ok
end

local function set_target_percent(target)
    if not initialized or applying then return end
    local bonus = starting_speed * (target - applied_percent) / 100
    if math.abs(bonus) < 0.000001 then
        applied_percent = target
        return
    end

    -- This runs on the main thread. Use a permanent additive game modifier so
    -- the setting composes with the game's own speed modifiers.
    if not modify_bonus(bonus) then return end

    applied_percent = target
    R.log(("[double-movement-speed] Movement speed set to %d%% of starting speed."):format(target))
end

R.on("*", function(ev)
    if initialized or applying or not ev or ev.source ~= "gameplay" then return end
    if not R.entity.ready() then return end

    local current = R.stat.get("move_speed")
    if type(current) ~= "number" or current <= 0 then return end

    starting_speed = current
    applied_percent = 100
    local target = configured_percent()
    local bonus = starting_speed * (target - 100) / 100
    if math.abs(bonus) < 0.000001 then
        initialized = true
        applied_percent = target
        return
    end
    if not modify_bonus(bonus) then return end
    initialized = true
    applied_percent = target
    R.log(("[double-movement-speed] Movement speed set to %d%% of starting speed."):format(target))
end)

-- Config edits made while the game is open are picked up by R.config and queued
-- back onto the main thread before changing the live game stat.
R.config.on_change("target_percent", function()
    if not initialized then return end
    R.schedule.next_main(function()
        set_target_percent(configured_percent())
    end)
end)
