local animations = {
    black_shroomhead = { "idle", "walk", "capsmack", "fart", "hurt", "hurt2", "death" },
    brown_shroomhead = { "idle", "walk", "capsmack", "fart", "hurt", "hurt2", "death" },
    cinder_moth = { "idle", "walk", "flutter", "death" },
    crimson_shroomhead = { "idle", "walk", "capsmack", "fart", "hurt", "hurt2", "death" },
    demon_wolf_black = { "idle", "walk", "run", "leap", "stepback", "bite", "death" },
    demon_wolf_grey = { "idle", "walk", "run", "leap", "stepback", "bite", "death" },
    ectusoteuthis = { "swimming", "swimmingdownloop", "swimmingdown", "swimmingdownend", "swimmingup", "swimminguploop", "swimmingupend", "attstart", "attloop", "inkbomb", "attend", "swimatt1", "dinograbstart", "dinograbloop", "dinograbend", "grabvictim2", "grabvictim1", "grabvictim3", "grabvictim4", "dying", "body", "swimeat", "swimatt2" },
    ectusoteuthisink = { "waiting", "loop" },
    fog_lizard_brown = { "idle", "walk", "leap", "gas", "death" },
    fog_lizard_green = { "idle", "walk", "leap", "gas", "death" },
    ground_with_roots = { "fly", "death" },
    haunted_swordfish = { "idle", "walk", "stab", "death" },
    ice_golem = { "idle", "walk", "attack_left", "attack_right", "stomp", "pull", "roar", "death" },
    lava_crab = { "idle", "walk", "attack", "interact", "death" },
    marlin = { "idle", "walk", "stab", "death" },
    minotaur = { "idle", "walk", "run", "minotaur_rush", "double_attack", "attack_horns", "impact", "throws_the_ground", "hurt_1", "hurt_2", "stun", "death" },
    nm_jellyfish_blue = { "idle", "walk", "death" },
    nm_jellyfish_fusion = { "idle", "walk", "death" },
    nm_jellyfish_golden = { "idle", "walk", "death" },
    nm_jellyfish_orange = { "idle", "walk", "death" },
    nm_jellyfish_pink = { "idle", "walk", "death" },
    nm_jellyfish_white = { "idle", "walk", "death" },
    nm_mandrake = { "idle", "idle_standing", "walk", "pick", "death" },
    nm_rat_albino = { "idle", "walk", "bite", "death" },
    nm_rat_brown = { "idle", "walk", "bite", "death" },
    nm_rat_grey = { "idle", "walk", "bite", "death" },
    plague_rat_black = { "idle", "walk", "bite", "leap", "death" },
    plague_rat_brown = { "idle", "walk", "bite", "leap", "death" },
    plague_rat_grey = { "idle", "walk", "bite", "leap", "death" },
    plague_rat_red = { "idle", "walk", "bite", "leap", "death" },
    plague_rat_white = { "idle", "walk", "bite", "leap", "death" },
    poison = { "idle", "walk", "skill1", "skill2", "skill3", "skill4", "skill5", "skill6", "spawn", "death" },
    poison_9mm = { "idle" },
    poison_mobs = { "idle", "skill1", "spawn", "death" },
    poison_overload = { "idle", "walk", "skill1", "skill2", "skill3", "skill4", "skill5", "spawn", "death" },
    poison_over_skill3 = { "spawn" },
    poison_over_skill5 = { "spawn" },
    poison_skill3 = { "idle" },
    poison_spawn = { "spawn", "idle" },
    red_shroomhead = { "idle", "walk", "capsmack", "fart", "hurt", "hurt2", "death" },
    sailfish = { "idle", "walk", "stab", "death" },
    sleeping_minotaur = { "idle", "awakening" },
    slime_death_hw_vfx = { "state1", "state2", "small", "spawn" },
    slime_death_vfx = { "state1", "state2", "small", "spawn" },
    slime_elite_am = { "a", "idle_m", "idle", "walk", "atk", "ability", "bones", "death" },
    slime_elite_hw_am = { "idle", "walk", "atk", "ability", "bones", "death" },
    slime_elite_hw_vfx = { "idle" },
    slime_elite_vfx = { "idle" },
    slime_mage_am = { "a", "idle_m", "idle", "walk", "atk", "ability" },
    slime_mage_hw_am = { "idle", "walk", "atk", "ability" },
    slime_mage_hw_vfx = { "idle" },
    slime_mage_vfx = { "idle" },
    slime_ranger_am = { "a", "idle_m", "idle", "walk", "atk", "ability", "arrows" },
    slime_ranger_hw_am = { "idle", "walk", "atk", "ability", "arrows" },
    slime_warrior_am = { "a", "idle_m", "idle", "walk", "atk" },
    slime_warrior_hw_am = { "idle", "walk", "atk" },
    sunken_swordfish = { "idle", "walk", "stab", "death" },
    swordfish = { "idle", "walk", "stab", "death" },
    toro_type02 = { "idle", "walk", "left_stomp", "right_stomp", "right_heavy_punch", "left_heavy_punch", "left_quick_punch", "right_quick_punch", "left_side_strike", "right_side_strike", "drift_back", "artillery", "left_quick_artillery", "right_quick_artillery", "death" },
    toxic_cloud = { "spawn" },
    tulf_no008 = { "idle", "walk", "fly_idle", "hurt1", "hurt2", "meleeattack_0", "meleeattack_1", "large_attack_right", "large_attack_left", "onground_electric", "summon", "blind", "spin_start", "spin", "spin_end", "on", "spawn_idle", "spawn_start", "spawn", "death" },
    tulf_no008_minion = { "idle", "walk", "shoot", "spawn", "death" },
    tulf_no008_thundrbolt = { "pos1", "pos2" },
    vfx_shroomhead_black_fart = { "spawn" },
    vfx_shroomhead_fart = { "spawn" },
    vfx_shroomhead_glow_fart = { "spawn" },
    volcanic_gecko = { "idle", "walk", "run", "backflip", "death" },
    volcanic_raptor = { "spawn", "idle", "walk", "peck", "death" },
    volcanic_raptor_adult = { "spawn", "idle", "walk", "peck", "fire", "kick", "claws", "call", "death" },
    warped_shroomhead = { "idle", "walk", "capsmack", "fart", "hurt", "hurt2", "death" },
    wild_boar_brown = { "idle", "walk", "run", "charge", "tusk_attack", "stab", "death" },
    wild_boar_grey = { "idle", "walk", "run", "charge", "tusk_attack", "stab", "death" },
    yeti = { "idle", "walk", "run", "attack", "run_charge", "charge_attack", "throw", "roar", "sleep", "wake_up", "death" },
    yeti_ice_block = { "idle" },
}

local function register_animation(entity_key, name)
    local ok, err = xpcall(function()
        local raw = aris.game.geckolib.create_animation(entity_key, name)
        raw:then_play(name)
    end, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[00_gecko_resource_animations] " .. tostring(entity_key) .. ":" .. tostring(name) .. " " .. tostring(err))
    end
end

for entity_key, names in pairs(animations) do
    for _, name in ipairs(names) do
        register_animation(entity_key, name)
    end
end
