local attr = aris.init.geckolib.entity_attr()
attr:max_health(1000000)
attr:armor(1000000)
attr:movement_speed(0)
attr:follow_range(2048)

local function register(key, width, height)
    aris.init.geckolib.create_entity(key, width or 0.1, height or 0.1, attr)
end

local entities = {
    "ancestor_hands",
    "constant_healing_beam_vfx",
    "constant_thunder_strike_vfx",
    "earthen_embrace",
    "echo_step",
    "guardian_totem",
    "hunter_totem",
    "nature_hands",
    "vertical_healing_beam_vfx",
}

for _, key in ipairs(entities) do
    register(key)
end

for i = 1, 7 do
    register("horizontal_thunder_strike_vfx_" .. tostring(i))
end

for i = 1, 8 do
    register("vertical_thunder_strike_vfx_" .. tostring(i))
end
