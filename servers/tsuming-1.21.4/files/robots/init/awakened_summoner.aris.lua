local attr = aris.init.geckolib.entity_attr()
attr:max_health(1856794)
attr:armor(1000000)
attr:movement_speed(0)
attr:follow_range(2048)

local function register(key, width, height)
    aris.init.geckolib.create_entity(key, width or 0.1, height or 0.1, attr)
end

local entities = {
    vfx_summon = { 0.1, 0.1 },
    soul_spear_vfx = { 0.1, 0.1 },
    soul_fireball = { 0.1, 0.1 },
    soul_fire_breath = { 0.1, 0.1 },
    vfx_arrow = { 0.1, 0.1 },
    spirit_wolf = { 0.8, 0.9 },
    spirit_dragon = { 2.2, 2.4 },
    crossbow_minion = { 0.8, 1.6 },
}

for key, size in pairs(entities) do
    register(key, size[1], size[2])
end

for i = 1, 7 do
    register("soul_blades_" .. tostring(i), 0.1, 0.1)
    register("axe_minion_" .. tostring(i), 0.8, 1.6)
end
