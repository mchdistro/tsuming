-- 플레이어 이모트 모델 본 -> 갑옷 BoneType 매핑 (set_emote_bone = ArmorBoneRegistry)
-- 모든 이모트(idle/walk/run/dash/스킬 등)에 대해 등록해야 모션 중 갑옷이 깨지지 않음.
-- 플레이어 모델 본: only_body(몸통)/h_head(머리)/right_arm/left_arm/right_leg/left_leg
-- 주의: 플레이어 모델엔 별도 발 본이 없어 발(boots)은 다리 본으로 매핑하지 않음(다리 덮어쓰기 방지).

local emotes = {
    boss_archer = { "idle_prebattle", "start_combat", "idle", "walk", "run", "base", "dash_front", "dash_left", "dash_right", "dash_back", "flinch", "ambush", "c1", "c2", "c3", "c4", "c5", "evasive_shot", "volley_of_arrow1", "volley_of_arrow1_2", "piercing_skyfall", "rapid_arrows1", "rapid_arrows1_2", "shot_of_destruction", "death", "misc.idle", "move.walk" },
    boss_assassin = { "animation", "idle_prebattle", "start_combat", "idle", "walk", "run", "flinch", "dash_front", "dash_left", "dash_right", "dash_back", "deadly_calm", "lc1", "lc2-afterlc1", "lc2", "lc3", "lc4", "ravaging_dash", "death_bloom", "shadowquake", "shadowquake_appear", "crimson_arc", "last_dance_spin_loop", "last_dance", "death", "misc.idle", "move.walk" },
    boss_mage = { "base", "idle_prebattle", "start_combat", "idle", "walk", "run", "flinch", "dash_front", "dash_left", "dash_right", "dash_back", "mana_barrier", "c1", "c2", "c2_3", "c3", "c4", "teleport_strike", "blazing_barrage1", "blazing_barrage2", "cryo_prison", "hailpiercer1", "hailpiercer1_2", "meteor_of_doom", "death", "misc.idle", "move.walk" },
    boss_shaman = { "base", "idle", "prebattle_idle", "enter_battle", "walk", "run", "flinch", "dash_front", "dash_left", "dash_right", "dash_back", "death", "life_link", "thunder_c1", "thunder_c2", "thunder_c3", "life_beam", "entering_spirit_form", "floating_spirit_form_idle", "floating_spirit_form_move", "getting_out", "hunter_totem", "guardian_totem", "earthen_embrace", "thunderous_hand_1", "thunderous_hand_2", "idle_to_floating_thunderous", "floating_thunderous_idle", "floating_thunderous_landing", "natural_hands_start", "natural_hands_idle", "natural_hands_end", "misc.idle", "move.walk" },
    boss_summoner = { "base", "prebattle_idle", "enter_battle", "idle", "walk", "run", "flinch", "dash_front", "dash_left", "dash_right", "dash_back", "death", "spirit_wolf", "soul_c1", "soul_c2", "soul_c3", "soul_c4", "blade_wheel", "summon_axe_minion", "summon_crossbow_minion", "soul_spear", "summon_dragon", "misc.idle", "move.walk" },
    boss_warrior = { "idle_prebattle", "start_combat", "idle", "walk", "run", "bulwark_instinct", "c1", "c2", "c3", "c4", "c5", "berserker_leap", "relentless_whirlwind_spin", "relentless_whirlwind_pierce", "bloodbound_barrier", "vicious_strike", "strike_of_fury_1", "strike_of_fury_2", "dash_front", "dash_left", "dash_right", "dash_back", "flinch", "death", "misc.idle", "move.walk" },
}

local bone_map = {
    { "h_head", "head" },
    { "only_body", "body" },
    { "right_arm", "right_arm" },
    { "left_arm", "left_arm" },
    { "right_leg", "right_leg" },
    { "left_leg", "left_leg" },
}

for emote_file, names in pairs(emotes) do
    for _, emote_name in ipairs(names) do
        for _, m in ipairs(bone_map) do
            aris.game.client.geckolib.emote.set_emote_bone(emote_file, emote_name, m[1], m[2])
        end
    end
end
