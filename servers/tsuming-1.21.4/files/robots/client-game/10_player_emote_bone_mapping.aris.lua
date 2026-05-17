local emotes = {
    boss_archer = {
        "ambush",
        "c1",
        "c2",
        "c3",
        "c4",
        "evasive_shot",
        "volley_of_arrow1",
        "piercing_skyfall",
        "rapid_arrows1",
        "shot_of_destruction",
    },
    boss_assassin = {
        "deadly_calm",
        "lc1",
        "lc2",
        "lc3",
        "lc4",
        "ravaging_dash",
        "death_bloom",
        "shadowquake",
        "shadowquake_appear",
        "crimson_arc",
        "last_dance",
    },
    boss_warrior = {
        "bulwark_instinct",
        "c1",
        "c2",
        "c3",
        "c4",
        "c5",
        "berserker_leap",
        "relentless_whirlwind_spin",
        "bloodbound_barrier",
        "vicious_strike",
        "strike_of_fury_1",
    },
    boss_mage = {
        "mana_barrier",
        "c1",
        "c2",
        "c3",
        "c4",
        "teleport_strike",
        "blazing_barrage1",
        "cryo_prison",
        "hailpiercer1",
        "meteor_of_doom",
    },
    boss_summoner = {
        "spirit_wolf",
        "soul_c1",
        "soul_c2",
        "soul_c3",
        "soul_c4",
        "blade_wheel",
        "summon_axe_minion",
        "summon_crossbow_minion",
        "soul_spear",
        "summon_dragon",
    },
    boss_shaman = {
        "life_link",
        "thunder_c1",
        "thunder_c2",
        "thunder_c3",
        "life_beam",
        "dash_front",
        "hunter_totem",
        "guardian_totem",
        "earthen_embrace",
        "thunderous_hand_1",
        "natural_hands_start",
    },
}

local bone_map = {
    { "h_head", "head" },
    { "only_body", "body" },
    { "right_arm", "right_arm" },
    { "left_arm", "left_arm" },
    { "right_leg", "right_leg" },
    { "left_leg", "left_leg" },
    { "right_leg", "right_foot" },
    { "left_leg", "left_foot" },
}

for emote_file, names in pairs(emotes) do
    for _, emote_name in ipairs(names) do
        for _, mapping in ipairs(bone_map) do
            aris.game.client.geckolib.emote.set_emote_bone(emote_file, emote_name, mapping[1], mapping[2])
        end
    end
end
