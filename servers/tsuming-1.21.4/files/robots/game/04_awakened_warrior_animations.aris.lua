local function register(key, trigger, animation)
    local ok, err = xpcall(function()
        local raw = aris.game.geckolib.create_animation(key, trigger)
        raw:then_play(animation or trigger)
    end, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[04_awakened_warrior_animations] " .. tostring(key) .. ":" .. tostring(trigger) .. " " .. tostring(err))
    end
end

local brutal = {
    "slash_left",
    "slash_right",
    "slash_left_diag",
    "slash_right_diag",
    "pierce",
    "spin",
    "spin_loop",
    "strike",
    "slash_up",
    "slash_up2",
}

for i = 1, 8 do
    local key = "brutal_combo_" .. tostring(i)
    for _, anim in ipairs(brutal) do
        register(key, anim, anim)
    end

    local whirl = "relentless_whirlwind_" .. tostring(i)
    register(whirl, "spin", "spin")
    register(whirl, "back_step", "back_step")
    register(whirl, "dash_pierce", "dash_pierce")
    register(whirl, "spin2", "spin2")
end

for i = 1, 13 do
    register("berserker_leap_" .. tostring(i), "animation", "animation")
    register("vicious_strike_" .. tostring(i), "animation", "animation")

    local sof = "strike_of_fury_" .. tostring(i)
    register(sof, "charge_sword", "charge_sword")
    register(sof, "sword_idle", "sword_idle")
    register(sof, "sword_slash1", "sword_slash1")
    register(sof, "sword_slash2", "sword_slash2")
    register(sof, "sword_jump", "sword_jump")
    register(sof, "sword_stomp", "sword_stomp")
    register(sof, "floor_crack", "floor_crack")
end

for i = 1, 5 do
    register("vfx_earthquake_rupture_" .. tostring(i), "skill", "skill")
    register("vfx_earthquake_rupture_" .. tostring(i), "skill2", "skill2")
    register("vfx_earthquake_rupture_" .. tostring(i), "skill3", "skill3")
    register("vfx_earthquake_rupture_" .. tostring(i), "death", "death")
end

register("vfx_rubbles", "skill", "skill")
register("vfx_rubbles", "skill2", "skill2")
register("bloodbound_barrier", "animation", "animation")
register("bloodbound_barrier", "idle_bloodbound_barrier", "idle_bloodbound_barrier")
register("bloodbound_barrier", "hit", "hit")
register("vicious_strike_charge", "charge", "charge")

local ok, err = xpcall(function()
    aris.game.geckolib.enable_idle("bloodbound_barrier")
end, debug ~= nil and debug.traceback or tostring)
if not ok then
    aris.log_error("[04_awakened_warrior_animations:enable_idle] bloodbound_barrier " .. tostring(err))
end
