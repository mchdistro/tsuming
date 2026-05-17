local function anim(key, trigger, animation)
    local raw = aris.game.geckolib.create_animation(key, trigger)
    raw:then_play(animation or trigger)
end

anim("ancestor_hands", "attack1")
anim("ancestor_hands", "attack2")
anim("ancestor_hands", "attack3")

anim("constant_healing_beam_vfx", "on")
anim("constant_thunder_strike_vfx", "on")
anim("earthen_embrace", "animation")
anim("nature_hands", "animation")
anim("vertical_healing_beam_vfx", "animation")

anim("echo_step", "dash_front")
anim("echo_step", "dash_back")
anim("echo_step", "dash_left")
anim("echo_step", "dash_right")

anim("guardian_totem", "idle")
anim("guardian_totem", "spawn")
anim("guardian_totem", "hit")
anim("guardian_totem", "despawn")

anim("hunter_totem", "idle")
anim("hunter_totem", "spawn")
anim("hunter_totem", "hit")
anim("hunter_totem", "despawn")

for i = 1, 7 do
    anim("horizontal_thunder_strike_vfx_" .. tostring(i), "animation")
end

for i = 1, 8 do
    anim("vertical_thunder_strike_vfx_" .. tostring(i), "animation")
end
