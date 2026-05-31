local attr = aris.init.geckolib.entity_attr()
attr:max_health(1856794)
attr:armor(1000000)
attr:movement_speed(0)
attr:follow_range(2048)

local function register_vfx(key)
    aris.init.geckolib.create_entity(key, 0.1, 0.1, attr)
end

local vfx_entities = {
    "vfx_dusk_cut",
    "vfx_dusk_dagger",
    "vfx_dusk_dagger_circle",
    "vfx_dusk_dash",
    "vfx_dusk_downslash",
    "vfx_dusk_shockwave_slash",
    "vfx_dusk_shuriken",
    "vfx_dusk_spinning_blades",
    "vfx_pulse",
}

for i = 1, 9 do
    vfx_entities[#vfx_entities + 1] = "vfx_dusk_dash_impact_" .. i
    vfx_entities[#vfx_entities + 1] = "vfx_dusk_pierce_" .. i
end

for i = 1, 7 do
    vfx_entities[#vfx_entities + 1] = "vfx_dusk_slash_" .. i
    vfx_entities[#vfx_entities + 1] = "vfx_dusk_spin_" .. i
end

for i = 1, 5 do
    vfx_entities[#vfx_entities + 1] = "vfx_shadow_figure_" .. i
end

for _, key in ipairs(vfx_entities) do
    register_vfx(key)
end
