-- 직업 갑옷 세트 등록 (Aris geckolib armor)
-- 에셋: resourcepack assets/aris/{geo,textures,animations}/armor/, items/, models/item/, equipment/aris_armor.json
-- 아이템 ID: aris:<class>_<piece>   (예: aris:archer_helmet)

-- 공통 설정
local ANIMATION       = "armor"                  -- animations/armor/armor.animation.json
local EQUIPMENT_ASSET = "aris_armor"             -- equipment/aris_armor.json
local REPAIR_TAG      = "aris:repairs_no_armor"  -- 수리 불가 (기본)

-- ============================================================
-- 세트별 수치 (다이아 갑옷 기준 기본값 — 세트마다 따로 조정 가능)
--   boots = 부츠 포함 여부
--   defense/durability/toughness/knockback 전부 세트별 독립
-- ============================================================
local SETS = {
    {
        name = "archer",
        boots = false,
        base_durability      = 33,
        helmet_defense       = 3,
        chestplate_defense   = 8,
        leggings_defense     = 6,
        boots_defense        = 3,
        body_defense         = 11,
        enchantment_value    = 10,
        toughness            = 2.0,
        knockback_resistance = 0.0,
    },
    {
        name = "assassin",
        boots = true,  -- 암살자만 부츠 보유
        base_durability      = 33,
        helmet_defense       = 3,
        chestplate_defense   = 8,
        leggings_defense     = 6,
        boots_defense        = 3,
        body_defense         = 11,
        enchantment_value    = 10,
        toughness            = 2.0,
        knockback_resistance = 0.0,
    },
    {
        name = "mage",
        boots = false,
        base_durability      = 33,
        helmet_defense       = 3,
        chestplate_defense   = 8,
        leggings_defense     = 6,
        boots_defense        = 3,
        body_defense         = 11,
        enchantment_value    = 10,
        toughness            = 2.0,
        knockback_resistance = 0.0,
    },
    {
        name = "shaman",
        boots = false,
        base_durability      = 33,
        helmet_defense       = 3,
        chestplate_defense   = 8,
        leggings_defense     = 6,
        boots_defense        = 3,
        body_defense         = 11,
        enchantment_value    = 10,
        toughness            = 2.0,
        knockback_resistance = 0.0,
    },
    {
        name = "summoner",
        boots = false,
        base_durability      = 33,
        helmet_defense       = 3,
        chestplate_defense   = 8,
        leggings_defense     = 6,
        boots_defense        = 3,
        body_defense         = 11,
        enchantment_value    = 10,
        toughness            = 2.0,
        knockback_resistance = 0.0,
    },
    {
        name = "warrior",
        boots = false,
        base_durability      = 33,
        helmet_defense       = 3,
        chestplate_defense   = 8,
        leggings_defense     = 6,
        boots_defense        = 3,
        body_defense         = 11,
        enchantment_value    = 10,
        toughness            = 2.0,
        knockback_resistance = 0.0,
    },
}

local function make_props(c)
    local p = aris.init.armor.armor_props()
    p:set_base_durability(c.base_durability)
    p:set_helmet_defense(c.helmet_defense)
    p:set_chestplate_defense(c.chestplate_defense)
    p:set_leggings_defense(c.leggings_defense)
    p:set_boots_defense(c.boots_defense)
    p:set_body_defense(c.body_defense)
    p:set_enchantment_value(c.enchantment_value)
    p:set_toughness(c.toughness)
    p:set_knockback_resistance(c.knockback_resistance)
    p:set_animation(ANIMATION)
    p:set_equipment_asset(EQUIPMENT_ASSET)
    p:set_repair_tag(REPAIR_TAG)
    -- texture는 비워두면 세트 이름을 그대로 사용 (archer -> textures/armor/archer.png)
    return p
end

for _, c in ipairs(SETS) do
    aris.init.armor.create_armor_set(c.name, make_props(c), c.boots)
end
