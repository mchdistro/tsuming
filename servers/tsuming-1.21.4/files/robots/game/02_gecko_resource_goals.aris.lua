local passive_mobs = {
    "black_shroomhead",
    "brown_shroomhead",
    "cinder_moth",
    "crimson_shroomhead",
    "fog_lizard_brown",
    "fog_lizard_green",
    "lava_crab",
    "nm_jellyfish_blue",
    "nm_jellyfish_fusion",
    "nm_jellyfish_golden",
    "nm_jellyfish_orange",
    "nm_jellyfish_pink",
    "nm_jellyfish_white",
    "nm_mandrake",
    "red_shroomhead",
    "volcanic_gecko",
    "volcanic_raptor",
    "volcanic_raptor_adult",
    "warped_shroomhead",
    "wild_boar_brown",
    "wild_boar_grey",

    "aquamarine",
    "bronze",
    "cocoon",
    "diamond",
    "emerald",
    "garnet",
    "gnut",
    "gold",
    "harmony_hare",
    "iron",
    "lapis",
    "mystic_stag",
    "obsidian",
    "poison_targe",
    "redstone",
    "ruby",
    "sapphire",
    "snowball_spirit",
    "the_soulrot",
}

local hostile_mobs = {
    "demon_wolf_black",
    "demon_wolf_grey",
    "ice_golem",
    "minotaur",
    "nm_rat_albino",
    "nm_rat_brown",
    "nm_rat_grey",
    "plague_rat_black",
    "plague_rat_brown",
    "plague_rat_grey",
    "plague_rat_red",
    "plague_rat_white",
    "poison",
    "poison_mobs",
    "poison_mobs_eng",
    "poison_overload",
    "slime_elite_am",
    "slime_elite_hw_am",
    "slime_mage_am",
    "slime_mage_hw_am",
    "slime_ranger_am",
    "slime_ranger_hw_am",
    "slime_warrior_am",
    "slime_warrior_hw_am",
    "toro_type02",
    "tulf_no008",
    "tulf_no008_minion",
    "yeti",

    "ashen_azalea",
    "cerberus",
    "eccogboundicarosphinx",
    "ec-leviathan",
    "ec-leviathan_seg",
    "em_dskeleton_archer",
    "em_dskeleton_footman",
    "em_dskeleton_halberdier",
    "em_dskeleton_swordman",
    "em_dskeleton_tank",
    "em_dskeleton_variations",
    "em_dskeleton_warrior",
    "em_dskeleton_wizard",
    "ent_guardian",
    "ent_king",
    "ent_minion",
    "ent_sorcerer",
    "ent_warrior",
    "frostmite",
    "frozen_blaze",
    "ice_knight",
    "ice_knight-minion-shield",
    "ice_knight-minion-spear",
    "ice_knight-minion-sword",
    "ice_witch",
    "iceologer",
    "lurking_lily",
    "malevolent_moss",
    "nectar_spider",
    "nocsy_dragon",
    "nocsy_dragon_saddled_version",
    "poisonous_bloom",
    "rootling",
    "undead_ice_warrior",
    "vivid_viper",
    "whispering_willow",
    "whispering_wisteria",
}

local water_mobs = {
    "ectusoteuthis",
    "haunted_swordfish",
    "marlin",
    "sailfish",
    "sunken_swordfish",
    "swordfish",

    "beluga",
    "black_angler_fish",
    "deep_angler_fish",
    "ecabyssosaurus",
    "ecamonite",
    "ecaquilolamna",
    "ecaquilolamnababy",
    "ecarchelon",
    "ecatopodentatus",
    "ecbabyaquilolamna",
    "ecbabyelasmosaurus",
    "ecbabymosasaurus",
    "ecbabyophthalmosaurus",
    "ecbabyplesiosaurus",
    "ecbabyshastasaurus",
    "eccartornychus",
    "ecclidastes",
    "eccoelacanth",
    "ecdunkleosteus",
    "ecdunkleosteusbaby",
    "ecelasmosaurus",
    "ecelasmosaurusbaby",
    "ecichtyosaurus",
    "ecleedsichthys",
    "ecleviathan",
    "ecleviathanbaby",
    "ecliopleurodon",
    "ecliopleurodonbaby",
    "ecmosasaurus",
    "ecmosasaurusbaby",
    "ecophthalmosaurus",
    "ecplesiosaurus",
    "ecplesiosaurusbaby",
    "ecseascorpion",
    "ecshastasaurus",
    "ecshastasaurusbaby",
    "greatwhale",
    "narwhal",
    "octopus",
    "red_angler_fish",
}

local function safe_add_goal(entity, priority, goal)
    if goal ~= nil then
        entity:add_goal_selector(priority, goal)
    end
end

local function safe_add_target(entity, priority, goal)
    if goal ~= nil then
        entity:add_target_selector(priority, goal)
    end
end

local function register_passive(key)
    local ok, err = xpcall(function()
        aris.game.geckolib.add_entity_goal_registry(key, function(entity)
        safe_add_goal(entity, 0, aris.game.geckolib.goal.float(entity))
        safe_add_goal(entity, 4, aris.game.geckolib.goal.water_avoiding_random_stroll(entity, 1.0))
        safe_add_goal(entity, 5, aris.game.geckolib.goal.look_at_player(entity, 8.0))
        safe_add_goal(entity, 6, aris.game.geckolib.goal.random_look_around(entity))
        end)
    end, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[02_gecko_resource_goals] passive:" .. tostring(key) .. " " .. tostring(err))
    end
end

local function register_hostile(key)
    local ok, err = xpcall(function()
        aris.game.geckolib.add_entity_goal_registry(key, function(entity)
        safe_add_goal(entity, 0, aris.game.geckolib.goal.float(entity))
        safe_add_goal(entity, 1, aris.game.geckolib.goal.melee_attack(entity, 1.2, true))
        safe_add_goal(entity, 3, aris.game.geckolib.goal.water_avoiding_random_stroll(entity, 0.9))
        safe_add_goal(entity, 4, aris.game.geckolib.goal.look_at_player(entity, 12.0))
        safe_add_goal(entity, 5, aris.game.geckolib.goal.random_look_around(entity))
        safe_add_target(entity, 1, aris.game.geckolib.goal.hurt_by_target(entity))
        safe_add_target(entity, 2, aris.game.geckolib.goal.nearest_attackable_player(entity, true))
        end)
    end, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[02_gecko_resource_goals] hostile:" .. tostring(key) .. " " .. tostring(err))
    end
end

local function register_water(key)
    local ok, err = xpcall(function()
        aris.game.geckolib.add_entity_goal_registry(key, function(entity)
        safe_add_goal(entity, 0, aris.game.geckolib.goal.try_find_water(entity))
        safe_add_goal(entity, 1, aris.game.geckolib.goal.random_stroll(entity, 1.0))
        safe_add_goal(entity, 2, aris.game.geckolib.goal.look_at_player(entity, 10.0))
        safe_add_goal(entity, 3, aris.game.geckolib.goal.random_look_around(entity))
        end)
    end, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[02_gecko_resource_goals] water:" .. tostring(key) .. " " .. tostring(err))
    end
end

for _, key in ipairs(passive_mobs) do
    register_passive(key)
end

for _, key in ipairs(hostile_mobs) do
    register_hostile(key)
end

for _, key in ipairs(water_mobs) do
    register_water(key)
end
