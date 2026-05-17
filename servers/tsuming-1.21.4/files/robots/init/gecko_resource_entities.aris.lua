local default_attr = aris.init.geckolib.entity_attr()
default_attr:max_health(20)
default_attr:attack_damage(2)
default_attr:armor(0)
default_attr:movement_speed(0.25)
default_attr:follow_range(16)

local vfx_attr = aris.init.geckolib.entity_attr()
vfx_attr:max_health(1000000)
vfx_attr:armor(1000000)
vfx_attr:movement_speed(0)
vfx_attr:follow_range(2048)

local entity_sizes = {
    black_shroomhead = { 1.0, 2.5 },
    brown_shroomhead = { 1.0, 2.5 },
    cinder_moth = { 2.0, 3.5 },
    crimson_shroomhead = { 1.0, 3.5 },
    demon_wolf_black = { 2.0, 2.5 },
    demon_wolf_grey = { 2.0, 2.5 },
    ectusoteuthis = { 6.0, 6.5 },
    ectusoteuthisink = { 5.5, 11.0 },
    fog_lizard_brown = { 2.5, 2.5 },
    fog_lizard_green = { 2.5, 2.5 },
    ground_with_roots = { 2.0, 2.5 },
    haunted_swordfish = { 2.5, 2.5 },
    ice_golem = { 3.0, 6.5 },
    lava_crab = { 1.5, 2.5 },
    marlin = { 2.5, 2.5 },
    minotaur = { 1.5, 5.5 },
    nm_jellyfish_blue = { 1.0, 2.5 },
    nm_jellyfish_fusion = { 1.0, 2.5 },
    nm_jellyfish_golden = { 1.0, 2.5 },
    nm_jellyfish_orange = { 1.0, 2.5 },
    nm_jellyfish_pink = { 1.0, 2.5 },
    nm_jellyfish_white = { 1.0, 2.5 },
    nm_mandrake = { 1.0, 2.5 },
    nm_rat_albino = { 1.5, 1.5 },
    nm_rat_brown = { 1.5, 1.5 },
    nm_rat_grey = { 1.5, 1.5 },
    plague_rat_black = { 3.0, 2.5 },
    plague_rat_brown = { 3.0, 2.5 },
    plague_rat_grey = { 3.0, 2.5 },
    plague_rat_red = { 3.0, 2.5 },
    plague_rat_white = { 3.0, 2.5 },
    poison = { 6.0, 3.5 },
    poison_mobs = { 1.5, 4.5 },
    poison_mobs_eng = { 1.0, 4.5 },
    poison_overload = { 6.0, 22.0 },
    red_shroomhead = { 1.0, 2.5 },
    sailfish = { 2.5, 2.5 },
    sleeping_minotaur = { 2.5, 4.5 },
    slime_elite_am = { 2.0, 3.5 },
    slime_elite_hw_am = { 2.0, 3.5 },
    slime_mage_am = { 1.5, 2.5 },
    slime_mage_hw_am = { 1.5, 2.5 },
    slime_ranger_am = { 1.5, 2.5 },
    slime_ranger_hw_am = { 1.5, 2.5 },
    slime_warrior_am = { 2.0, 2.5 },
    slime_warrior_hw_am = { 2.0, 2.5 },
    sunken_swordfish = { 2.5, 2.5 },
    swordfish = { 2.5, 2.5 },
    toro_type02 = { 4.5, 12.0 },
    tulf_no008 = { 6.0, 9.5 },
    tulf_no008_minion = { 2.5, 3.5 },
    volcanic_gecko = { 1.5, 1.5 },
    volcanic_raptor = { 3.0, 3.5 },
    volcanic_raptor_adult = { 3.5, 4.5 },
    warped_shroomhead = { 1.0, 2.5 },
    wild_boar_brown = { 2.0, 2.5 },
    wild_boar_grey = { 2.0, 2.5 },
    yeti = { 2.0, 5.5 },
}

local vfx_entities = {
    "slime_death_hw_vfx",
    "slime_death_vfx",
    "slime_elite_vfx",
    "slime_mage_hw_vfx",
    "slime_mage_vfx",
    "toxic_cloud",
    "tulf_no008_thundrbolt",
    "vfx_shroomhead_black_fart",
    "vfx_shroomhead_fart",
    "vfx_shroomhead_glow_fart",
    "yeti_ice_block",
    "poison_9mm",
    "poison_over_skill3",
    "poison_over_skill5",
    "poison_skill3",
    "poison_spawn",
    "poison_target",
}

for key, size in pairs(entity_sizes) do
    aris.init.geckolib.create_entity(key, size[1], size[2], default_attr)
end

for _, key in ipairs(vfx_entities) do
    aris.init.geckolib.create_entity(key, 0.1, 0.1, vfx_attr)
end
