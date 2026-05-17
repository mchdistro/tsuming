local function anim(key, trigger, animation)
    local raw = aris.game.geckolib.create_animation(key, trigger)
    raw:then_play(animation or trigger)
end

anim("big_fireball_charge", "animation")

anim("cryo_prison", "animation")
anim("cryo_prison", "crystal_the_enemy")
anim("cryo_prison_cage", "crystal_the_enemy")

anim("fireball", "animation")
anim("fireball", "animation2")
anim("fireball", "animation3")
anim("fireball", "animation4")

anim("fireball_explosion", "animation")
anim("fireball_explosion", "animation2")
for i = 1, 8 do
    anim("fireball_explosion_" .. tostring(i), "animation")
    anim("fireball_explosion_" .. tostring(i), "animation2")
    anim("fireball_explosion_" .. tostring(i), "animation3")
    anim("fireball_explosion_" .. tostring(i), "animation4")
end

anim("glacial_spike", "animation")

anim("hailpiercer", "ice_spike_o")
anim("hailpiercer", "ice_spike")
anim("hailpiercer", "ice_spike2")
anim("hailpiercer_inhale_breath", "animation")
anim("hailpiercer_inhale_breath", "animation2")

anim("magic_fire_circle", "animation")
anim("magic_fire_circle", "animation2")
anim("magic_fire_circle", "animation3")
anim("magic_fire_circle", "animation4")
anim("magic_fire_circle", "animation5")
anim("magic_fire_circle", "animation6")
anim("magic_fire_circle", "animation7")

anim("meteor_of_doom", "charge_meteor")
anim("meteor_of_doom", "meteor_impact")
anim("meteor_of_doom_cross", "meteor_impact")

for i = 1, 8 do
    local key = "thunder_strike_" .. tostring(i)
    anim(key, "animation")
    anim(key, "animation2")
    anim(key, "animation3")
    anim(key, "animation4")
end

for i = 1, 10 do
    anim("thunder_teleport_" .. tostring(i), "animation")
    anim("thunder_explosion_" .. tostring(i), "animation")
end
