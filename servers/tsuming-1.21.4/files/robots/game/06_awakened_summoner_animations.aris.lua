local function anim(key, trigger, animation)
    local raw = aris.game.geckolib.create_animation(key, trigger)
    raw:then_play(animation or trigger)
end

local function enable_idle(key)
    local ok, err = xpcall(function()
        aris.game.geckolib.enable_idle(key)
    end, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[06_awakened_summoner_animations:enable_idle] " .. tostring(key) .. " " .. tostring(err))
    end
end

anim("vfx_summon", "on")
anim("vfx_summon", "on2")

for i = 1, 7 do
    local blade = "soul_blades_" .. tostring(i)
    if i == 1 then
        anim(blade, "spawn")
    else
        anim(blade, "summon")
    end
    anim(blade, "idle")
    anim(blade, "left_slash")
    anim(blade, "right_slash2_up_slash1")
    anim(blade, "right_slash2_slash1_slash2")
    anim(blade, "duo_slash")
    anim(blade, "spin_sword")

    local axe = "axe_minion_" .. tostring(i)
    anim(axe, "spawn")
    anim(axe, "idle")
    if i == 1 then
        anim(axe, "walk")
    else
        anim(axe, "run")
    end
    anim(axe, "slash")
    anim(axe, "spin_slash")
    anim(axe, "despawn")
end

anim("soul_spear_vfx", "on")
anim("soul_fireball", "animation")
anim("soul_fire_breath", "loop")
anim("vfx_arrow", "shoot")
anim("vfx_arrow", "shoot_end")
anim("vfx_arrow", "shoot2")

anim("spirit_wolf", "idle")
anim("spirit_wolf", "walk")
anim("spirit_wolf", "scratch_left")
anim("spirit_wolf", "scratch_right")
anim("spirit_wolf", "bite")
anim("spirit_wolf", "leap_bite")
anim("spirit_wolf", "death")
enable_idle("spirit_wolf")

anim("spirit_dragon", "spawn")
anim("spirit_dragon", "idle")
anim("spirit_dragon", "walk")
anim("spirit_dragon", "shoot_fireball")
anim("spirit_dragon", "shoot_fireball3")
anim("spirit_dragon", "fire_breath")
anim("spirit_dragon", "despawn")
enable_idle("spirit_dragon")

anim("crossbow_minion", "spawn")
anim("crossbow_minion", "idle")
anim("crossbow_minion", "idle2")
anim("crossbow_minion", "walk")
anim("crossbow_minion", "shoot")
anim("crossbow_minion", "despawn")
