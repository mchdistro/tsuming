local attr = aris.init.geckolib.entity_attr()
attr:max_health(1856794)
attr:armor(1000000)
attr:movement_speed(0)
attr:follow_range(2048)

local function register_vfx(key, width, height)
    aris.init.geckolib.create_entity(key, width or 0.1, height or 0.1, attr)
end

local vfx_entities = {
    "fireball",
    "fireball_explosion",
    "big_fireball_charge",
    "glacial_spike",
    "cryo_prison",
    "cryo_prison_cage",
    "hailpiercer_inhale_breath",
    "hailpiercer",
    "magic_fire_circle",
    "meteor_of_doom",
    "meteor_of_doom_cross",
}

for i = 1, 8 do
    vfx_entities[#vfx_entities + 1] = "fireball_explosion_" .. i
    vfx_entities[#vfx_entities + 1] = "thunder_strike_" .. i
end

for i = 1, 10 do
    vfx_entities[#vfx_entities + 1] = "thunder_teleport_" .. i
    vfx_entities[#vfx_entities + 1] = "thunder_explosion_" .. i
end

for _, key in ipairs(vfx_entities) do
    register_vfx(key, 0.1, 0.1)
end
