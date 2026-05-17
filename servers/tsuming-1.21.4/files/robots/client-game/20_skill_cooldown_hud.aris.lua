local ICON_SIZE = 64
local ICON_GAP = 4
local SLOT_COUNT = 6
local START_X = 758
local START_Y = 844
local OVERLAY_ALPHA = 155
local TEXT_COLOR = 0xFFFFFFFF
local TEXT_SCALE = 2.5

local icon_paths = {
    archer = {
        blasting_combo = "skill_hud/archer/icon_blasting_combo.png",
        evasive_shot = "skill_hud/archer/icon_evasive_shot.png",
        volley_of_arrows = "skill_hud/archer/icon_volley_of_arrows.png",
        piercing_skyfall = "skill_hud/archer/icon_piercing_skyfall.png",
        rapid_arrows = "skill_hud/archer/icon_rapid_arrows.png",
        shot_of_destruction = "skill_hud/archer/icon_shot_of_destruction.png",
    },
    assassin = {
        lethal_combo = "skill_hud/assassin/icon_lethal_combo.png",
        ravaging_dash = "skill_hud/assassin/icon_ravaging_dash.png",
        death_bloom = "skill_hud/assassin/icon_death_bloom.png",
        shadowquake = "skill_hud/assassin/icon_shadowquake.png",
        crimson_arc = "skill_hud/assassin/icon_crimson_arc.png",
        last_dance = "skill_hud/assassin/icon_last_dance.png",
    },
    warrior = {
        brutal_combo = "skill_hud/warrior/icon_brutal_combo.png",
        berserkers_leap = "skill_hud/warrior/icon_berserkers_leap.png",
        relentless_whirlwind = "skill_hud/warrior/icon_relentless_whirlwind.png",
        bloodbound_barrier = "skill_hud/warrior/icon_bloodbound_barrier.png",
        vicious_strike = "skill_hud/warrior/icon_vicious_strike.png",
        strike_of_fury = "skill_hud/warrior/icon_strike_of_fury.png",
    },
    mage = {
        sorcery_combo = "skill_hud/mage/icon_sorcery_combo.png",
        teleport_strike = "skill_hud/mage/icon_teleport_strike.png",
        blazing_barrage = "skill_hud/mage/icon_blazing_barrage.png",
        cryo_prison = "skill_hud/mage/icon_cryo_prison.png",
        hailpiercer = "skill_hud/mage/icon_hailpiercer.png",
        meteor_of_doom = "skill_hud/mage/icon_meteor_of_doom.png",
    },
    summoner = {
        soul_combo = "skill_hud/summoner/icon_soul_combo.png",
        blade_wheel = "skill_hud/summoner/icon_blade_wheel.png",
        soul_spear = "skill_hud/summoner/icon_soul_spear.png",
        summoners_command = "skill_hud/summoner/icon_summoners_command.png",
        summon_minion = "skill_hud/summoner/icon_summon_minion.png",
        summon_dragon = "skill_hud/summoner/icon_summon_dragon.png",
    },
    shaman = {
        stance_switch = "skill_hud/shaman/icon_stance_switch.png",
        primal_combo = "skill_hud/shaman/icon_primal_combo.png",
        echo_step = "skill_hud/shaman/icon_echo_step.png",
        ritual_totem = "skill_hud/shaman/icon_ritual_totem.png",
        earthen_embrace = "skill_hud/shaman/icon_earthen_embrace.png",
        ancestral_hands = "skill_hud/shaman/icon_ancestral_hands.png",
    },
}

local image_cache = {}
local hud = nil
local root = nil
local slots = {}
local visible = false
local current_skills = {}

local function split(input, sep)
    local out = {}
    if input == nil or input == "" then
        return out
    end
    for part in string.gmatch(input, "([^" .. sep .. "]+)") do
        out[#out + 1] = part
    end
    return out
end

local function image_for(class_id, skill_id)
    local key = class_id .. ":" .. skill_id
    if image_cache[key] == nil then
        local class_icons = icon_paths[class_id]
        if class_icons == nil or class_icons[skill_id] == nil then
            return nil
        end
        image_cache[key] = aris.client.load_image(class_icons[skill_id])
    end
    return image_cache[key]
end

local function set_visible(next_visible)
    if next_visible == visible then
        return
    end
    visible = next_visible
    if visible then
        hud:open_hud()
    else
        hud:close_hud()
    end
end

local function update_slot(slot, skill)
    if skill == nil then
        slot.overlay:set_height(0)
        slot.text:set_text("")
        return
    end

    if skill.total <= 0 or skill.remain <= 0 then
        slot.overlay:set_height(0)
        slot.text:set_text("")
        return
    end

    local ratio = skill.remain / skill.total
    if ratio > 1 then
        ratio = 1
    end
    local overlay_h = math.floor(ICON_SIZE * ratio + 0.5)
    slot.overlay:set_y(ICON_SIZE - overlay_h)
    slot.overlay:set_height(overlay_h)
    slot.text:set_text(string.format("%.1f", skill.remain / 20))
end

local function refresh_slots()
    if slots[1] == nil then
        return
    end
    for i = 1, SLOT_COUNT do
        update_slot(slots[i], current_skills[i])
    end
end

local function create_hud_once()
    if hud ~= nil then
        return
    end

    hud = aris.game.client.create_hud()
    root = aris.client.create_component()
    root:set_x(START_X)
    root:set_y(START_Y)
    hud:add_child(root)

    for i = 1, SLOT_COUNT do
        local slot = aris.client.create_component()
        slot:set_x((i - 1) * (ICON_SIZE + ICON_GAP))
        slot:set_y(0)
        root:add_child(slot)

        local icon = aris.client.create_image_renderer(aris.client.load_image("skill_hud/archer/icon_blasting_combo.png"))
        icon:set_width(ICON_SIZE)
        icon:set_height(ICON_SIZE)
        slot:add_child(icon)

        local overlay = aris.client.create_color_renderer(0, 0, 0, OVERLAY_ALPHA)
        overlay:set_width(ICON_SIZE)
        overlay:set_height(0)
        slot:add_child(overlay)

        local text = aris.client.create_default_text_renderer("", TEXT_COLOR)
        text:set_x(19)
        text:set_y(24)
        text:set_scale(TEXT_SCALE)
        slot:add_child(text)

        slots[i] = {
            icon = icon,
            overlay = overlay,
            text = text,
        }
    end
end

local function parse_payload(class_id, payload)
    local parsed = {}
    for _, part in ipairs(split(payload, ";")) do
        local fields = split(part, ",")
        local skill_id = fields[1]
        if skill_id ~= nil then
            parsed[#parsed + 1] = {
                id = skill_id,
                remain = tonumber(fields[2]) or 0,
                total = tonumber(fields[3]) or 0,
            }
        end
    end
    return parsed
end

local function apply_payload(class_id, payload)
    create_hud_once()

    if class_id == nil or class_id == "" or payload == nil or payload == "" then
        current_skills = {}
        refresh_slots()
        set_visible(false)
        return
    end

    current_skills = parse_payload(class_id, payload)
    for i, skill in ipairs(current_skills) do
        local img = image_for(class_id, skill.id)
        if img ~= nil and slots[i] ~= nil then
            slots[i].icon:set_image(img)
        end
    end
    refresh_slots()
    set_visible(true)
end

aris.game.client.hook.add_s2c_packet_handler("skill_cooldown_hud", function(packet)
    apply_payload(packet.weapon or "", packet.payload or "")
end)

aris.game.client.hook.add_tick_hook(function()
    local changed = false
    for _, skill in ipairs(current_skills) do
        if skill.remain ~= nil and skill.remain > 0 then
            skill.remain = skill.remain - 1
            if skill.remain < 0 then
                skill.remain = 0
            end
            changed = true
        end
    end
    if changed then
        refresh_slots()
    end
end)
