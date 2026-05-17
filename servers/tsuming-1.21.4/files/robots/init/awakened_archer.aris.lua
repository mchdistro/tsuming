local attr = aris.init.geckolib.entity_attr()
attr:max_health(1000000)
attr:armor(1000000)
attr:movement_speed(0)
attr:follow_range(2048)

local function register_vfx(key, width, height)
    aris.init.geckolib.create_entity(key, width or 0.1, height or 0.1, attr)
end

local vfx_entities = {
    "vfx_first_hit_impact",
    "vfx_awakened_arrow_impact",
    "vfx_awakened_arrow",
    "vfx_shot_charging",
    "vfx_earthquake_rupture_1",
    "vfx_earthquake_rupture_2",
    "vfx_earthquake_rupture_3",
    "vfx_earthquake_rupture_4",
    "vfx_earthquake_rupture_5",
    "vfx_rubbles",
    "vfx_volley_of_arrow",
    "piercing_skyfall",
    "vfx_shot_of_destruction",
    "vfx_sod_rubble",
    "evasive_shot_arrows",
}

for i = 1, 8 do
    vfx_entities[#vfx_entities + 1] = "evasive_shot_" .. i
end

for i = 1, 8 do
    vfx_entities[#vfx_entities + 1] = "quick_dash_vfx_" .. i
end

for _, key in ipairs(vfx_entities) do
    register_vfx(key, 0.1, 0.1)
end
