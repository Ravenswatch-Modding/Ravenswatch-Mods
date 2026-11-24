local R = require "rsmm"
if R.damage and R.damage.enable and R.damage.on then
    R.damage.enable()

    -- TEMP seedfuse measurement, one bite at a time: the marks are
    -- R.schedule timers (game clock), so the burst's "marks=" tells which band
    -- it landed in (2 = 1.5 s fuse, 6 = 2.5 s, 8 = the 3 s inline fallback).
    -- Delete this whole block once measured.
    local fuse_gen, fuse_marks, fuse_last, fuse_burst_seen, fuse_target = 0, 0, 0, false, nil
    local FUSE_MARKS = { 1.45, 1.55, 1.65, 1.75, 2.45, 2.55, 2.65, 2.75, 3.2 }

    R.damage.on(function(hit)
        if not (hit.is_local and hit.is_enemy ~= false) then return end
        if hit.damage_kind == "power" and hit.target then
            local gen = fuse_gen + 1
            fuse_gen, fuse_marks, fuse_last, fuse_burst_seen = gen, 0, 0, false
            fuse_target = hit.target
            R.log(string.format("seedfuse BITE #%d target=%s", gen, tostring(hit.target)))
            if gen > 2 then return end
            for _, secs in ipairs(FUSE_MARKS) do
                R.schedule.after(secs, function()
                    if fuse_gen ~= gen then return end
                    fuse_marks, fuse_last = fuse_marks + 1, secs
                    R.log(string.format("seedfuse mark %.2f bite=#%d marks=%d burst_seen=%s",
                        secs, gen, fuse_marks, tostring(fuse_burst_seen)))
                end)
            end
        elseif hit.damage_kind == "special" and hit.target then
            fuse_burst_seen = true
            R.log(string.format("seedfuse BURST bite=#%d marks=%d last=%.2f target=%s same=%s",
                fuse_gen, fuse_marks, fuse_last, tostring(hit.target),
                tostring(hit.target == fuse_target)))
        end
    end)
end

-- TEMP test-only: grant 100000 XP at run start — delete before release.
if R.xp and R.xp.arm and R.xp.grant and R.stat and R.stat.enable_writes then
    R.xp.arm()
    R.stat.enable_writes()
    local xp_granted = false
    local function try_grant(tries)
        if xp_granted or tries <= 0 then return end
        R.schedule.next_main(function()
            if xp_granted then return end
            if R.xp.grant(100000) then
                xp_granted = true
                R.log("[xp-test] granted 100000 XP")
            else
                R.schedule.after(1.0, function() try_grant(tries - 1) end)
            end
        end)
    end
    R.on("run:start", function()
        xp_granted = false
        R.schedule.after(1.0, function() try_grant(10) end)
    end)
    R.on("run:end", function() xp_granted = true end)
end
