AWAKENED_HUD = AWAKENED_HUD or {}
AWAKENED_HUD.classes = AWAKENED_HUD.classes or {}
AWAKENED_HUD.active_class = AWAKENED_HUD.active_class or {}
AWAKENED_HUD.started = AWAKENED_HUD.started or false

local SEND_INTERVAL_TICKS = 5

local function uuid(player)
    return player:get_uuid()
end

local function send_packet(player, class_id, payload)
    local packet = aris.game.networking.create_s2c_packet_builder("skill_cooldown_hud")
    packet:append_string("weapon", class_id or "")
    packet:append_string("payload", payload or "")
    aris.game.networking.send_s2c_packet(player, packet)
end

local function build_payload(player, class_def)
    local id = uuid(player)
    local now_tick = class_def.get_tick()
    local parts = {}

    for _, skill in ipairs(class_def.skills) do
        local until_tick = class_def.cooldowns[id .. ":" .. skill.key] or 0
        local remain = until_tick - now_tick
        if remain < 0 then
            remain = 0
        end
        parts[#parts + 1] = skill.id .. "," .. tostring(remain) .. "," .. tostring(skill.cooldown)
    end

    return table.concat(parts, ";")
end

function AWAKENED_HUD.register_class(class_id, has_weapon, cooldowns, skills, get_tick)
    AWAKENED_HUD.classes[class_id] = {
        id = class_id,
        has_weapon = has_weapon,
        cooldowns = cooldowns,
        skills = skills,
        get_tick = get_tick,
    }
end

function AWAKENED_HUD.hide(player)
    local id = uuid(player)
    if AWAKENED_HUD.active_class[id] ~= nil then
        AWAKENED_HUD.active_class[id] = nil
        send_packet(player, "", "")
    end
end

function AWAKENED_HUD.send_state(player, class_def)
    AWAKENED_HUD.active_class[uuid(player)] = class_def.id
    send_packet(player, class_def.id, build_payload(player, class_def))
end

function AWAKENED_HUD.sync_skill(player, class_id)
    local class_def = AWAKENED_HUD.classes[class_id]
    if class_def == nil then
        return
    end
    AWAKENED_HUD.send_state(player, class_def)
end

function AWAKENED_HUD.update_player_weapon(player)
    local id = uuid(player)
    for _, class_def in pairs(AWAKENED_HUD.classes) do
        if class_def.has_weapon(player) then
            if AWAKENED_HUD.active_class[id] ~= class_def.id then
                AWAKENED_HUD.send_state(player, class_def)
            end
            return
        end
    end

    AWAKENED_HUD.hide(player)
end

function AWAKENED_HUD.poll_weapons()
    aris.game.iter_players(function(player)
        AWAKENED_HUD.update_player_weapon(player)
    end)
end

function AWAKENED_HUD.start_loop()
    if AWAKENED_HUD.started then
        return
    end
    AWAKENED_HUD.started = true

    while true do
        AWAKENED_HUD.poll_weapons()
        task_sleep(SEND_INTERVAL_TICKS * 50)
    end
end
