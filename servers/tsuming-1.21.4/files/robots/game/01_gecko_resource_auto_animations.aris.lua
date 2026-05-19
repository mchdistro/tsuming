local idle_walk = {
    "black_shroomhead",
    "brown_shroomhead",
    "cinder_moth",
    "crimson_shroomhead",
    "fog_lizard_brown",
    "fog_lizard_green",
    "haunted_swordfish",
    "ice_golem",
    "lava_crab",
    "marlin",
    "nm_jellyfish_blue",
    "nm_jellyfish_fusion",
    "nm_jellyfish_golden",
    "nm_jellyfish_orange",
    "nm_jellyfish_pink",
    "nm_jellyfish_white",
    "nm_mandrake",
    "nm_rat_albino",
    "nm_rat_brown",
    "nm_rat_grey",
    "plague_rat_black",
    "plague_rat_brown",
    "plague_rat_grey",
    "plague_rat_red",
    "plague_rat_white",
    "poison",
    "poison_overload",
    "red_shroomhead",
    "sailfish",
    "slime_elite_am",
    "slime_elite_hw_am",
    "slime_mage_am",
    "slime_mage_hw_am",
    "slime_ranger_am",
    "slime_ranger_hw_am",
    "slime_warrior_am",
    "slime_warrior_hw_am",
    "sunken_swordfish",
    "swordfish",
    "toro_type02",
    "tulf_no008",
    "tulf_no008_minion",
    "volcanic_raptor",
    "volcanic_raptor_adult",
    "warped_shroomhead",
    "wild_boar_brown",
    "wild_boar_grey",
    "yeti",

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

local idle_walk_run = {
    "demon_wolf_black",
    "demon_wolf_grey",
    "minotaur",
    "volcanic_gecko",
}

local idle_only = {
    "sleeping_minotaur",
    "slime_elite_hw_vfx",
    "slime_elite_vfx",
    "slime_mage_hw_vfx",
    "slime_mage_vfx",
    "yeti_ice_block",
    "poison_9mm",
    "poison_mobs",
    "poison_skill3",
    "poison_spawn",
}

local flying_or_special = {
    "ectusoteuthis",
    "ectusoteuthisink",
    "ground_with_roots",
    "toxic_cloud",
    "tulf_no008_thundrbolt",
    "vfx_shroomhead_black_fart",
    "vfx_shroomhead_fart",
    "vfx_shroomhead_glow_fart",
    "slime_death_hw_vfx",
    "slime_death_vfx",
    "poison_over_skill3",
    "poison_over_skill5",
}

local function safe_register(label, key, fn)
    local ok, err = xpcall(fn, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[01_gecko_resource_auto_animations] " .. label .. ":" .. tostring(key) .. " " .. tostring(err))
    end
end

for _, key in ipairs(idle_walk) do
    safe_register("idle_walk", key, function()
        aris.game.geckolib.enable_idle(key)
        aris.game.geckolib.enable_walk(key)
        aris.game.geckolib.enable_attack(key)
    end)
end

for _, key in ipairs(idle_walk_run) do
    safe_register("idle_walk_run", key, function()
        aris.game.geckolib.enable_run(key)
        aris.game.geckolib.enable_attack(key)
    end)
end

for _, key in ipairs(idle_only) do
    safe_register("idle_only", key, function()
        aris.game.geckolib.enable_idle(key)
    end)
end

for _, key in ipairs(flying_or_special) do
    safe_register("special", key, function()
        aris.game.geckolib.enable_idle(key)
    end)
end
