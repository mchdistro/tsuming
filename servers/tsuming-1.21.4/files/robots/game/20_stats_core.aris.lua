depends_on("00_lunajson_loader.aris")

STATS = STATS or {}
STATS.cache = STATS.cache or {}
STATS.dirty = STATS.dirty or {}

STATS.damage_formula = {
    multiplier = 50,
    divisor = 30,
    offset_inside = 1,
    flat_bonus = 2,
}

STATS.defaults = {
    points = 0,
    str = 0,
    agi = 0,
    int = 0,
    vit = 0,
    luk = 0,
}

STATS.max_per_stat = 999
STATS.order = { "str", "agi", "int", "vit", "luk" }
STATS.definitions = {
    str = { display = "힘", description = "물리 데미지, 방어력, 대장장이 제작 확률" },
    agi = { display = "민첩", description = "원거리 데미지, 회피율" },
    int = { display = "지능", description = "마법 데미지, 연금술 제작 확률" },
    vit = { display = "체력", description = "최대 체력, 체력 재생" },
    luk = { display = "운", description = "요리/제작 성공 확률, 아이템 드랍률 증가" },
}
STATS.damage_type_to_stat = {
    physical = "str",
    ranged = "agi",
    magic = "int",
}

function STATS.clone_defaults()
    return {
        points = STATS.defaults.points,
        str = STATS.defaults.str,
        agi = STATS.defaults.agi,
        int = STATS.defaults.int,
        vit = STATS.defaults.vit,
        luk = STATS.defaults.luk,
    }
end

function STATS.player_uuid(player)
    if player == nil then return "" end
    return tostring(player:get_uuid())
end

function STATS.player_name(player)
    if player == nil then return "" end
    return tostring(player:get_name())
end

function STATS.message(player, text)
    if player ~= nil then
        player:send_message_text(text)
    else
        aris.log_info(text)
    end
end

function STATS.is_admin(player)
    return player == nil or player:is_op()
end

function STATS.require_admin(player)
    if STATS.is_admin(player) then return true end
    STATS.message(player, "[스탯] 관리자 권한이 필요합니다.")
    return false
end

function STATS.is_valid_stat(stat)
    return STATS.definitions[stat] ~= nil
end

function STATS.normalize(stats)
    stats = stats or {}
    for key, value in pairs(STATS.defaults) do
        if type(stats[key]) ~= "number" then
            stats[key] = value
        end
        if stats[key] < 0 then
            stats[key] = 0
        end
    end
    return stats
end

function STATS.get_by_uuid(uuid)
    if STATS.cache[uuid] == nil then
        STATS.cache[uuid] = STATS.clone_defaults()
    end
    return STATS.normalize(STATS.cache[uuid])
end

function STATS.get(player)
    return STATS.get_by_uuid(STATS.player_uuid(player))
end

function STATS.mark_dirty(uuid)
    STATS.dirty[uuid] = true
end

function STATS.build_payload(player)
    local uuid = STATS.player_uuid(player)
    local stats = STATS.get_by_uuid(uuid)
    return JSON.encode({
        uuid = uuid,
        name = STATS.player_name(player),
        points = stats.points,
        str = stats.str,
        agi = stats.agi,
        int = stats.int,
        vit = stats.vit,
        luk = stats.luk,
    })
end

function STATS.send_sync(player)
    if player == nil then return end
    aris.log_info("[stats] send_sync -> " .. STATS.player_name(player))
    local packet = aris.game.networking.create_s2c_packet_builder("stats_sync")
    packet:append_string("payload", STATS.build_payload(player))
    aris.game.networking.send_s2c_packet(player, packet)
end

function STATS.add_stat_point(player, stat)
    if player == nil then return false, "플레이어를 찾을 수 없습니다." end
    if not STATS.is_valid_stat(stat) then return false, "알 수 없는 스탯입니다: " .. tostring(stat) end

    local uuid = STATS.player_uuid(player)
    local stats = STATS.get_by_uuid(uuid)
    if stats.points <= 0 then return false, "사용 가능한 스탯 포인트가 없습니다." end
    if stats[stat] >= STATS.max_per_stat then return false, "해당 스탯은 이미 최대치입니다." end

    stats.points = stats.points - 1
    stats[stat] = stats[stat] + 1
    STATS.mark_dirty(uuid)
    STATS.send_sync(player)
    return true, STATS.definitions[stat].display .. " +1"
end

function STATS.set_points(player, amount, sync)
    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end
    local uuid = STATS.player_uuid(player)
    local stats = STATS.get_by_uuid(uuid)
    stats.points = amount
    STATS.mark_dirty(uuid)
    if sync then
        STATS.send_sync(player)
    end
end

function STATS.add_points(player, amount, sync)
    amount = tonumber(amount) or 0
    local stats = STATS.get(player)
    STATS.set_points(player, stats.points + amount, sync)
end

function STATS.set_stat(player, stat, amount, sync)
    if not STATS.is_valid_stat(stat) then return false, "알 수 없는 스탯입니다: " .. tostring(stat) end
    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end
    if amount > STATS.max_per_stat then amount = STATS.max_per_stat end
    local uuid = STATS.player_uuid(player)
    local stats = STATS.get_by_uuid(uuid)
    stats[stat] = amount
    STATS.mark_dirty(uuid)
    if sync then
        STATS.send_sync(player)
    end
    return true, STATS.definitions[stat].display .. " = " .. tostring(amount)
end

function STATS.add_stat(player, stat, amount, sync)
    local stats = STATS.get(player)
    return STATS.set_stat(player, stat, (stats[stat] or 0) + (tonumber(amount) or 0), sync)
end

function STATS.reset(player, sync)
    local uuid = STATS.player_uuid(player)
    STATS.cache[uuid] = STATS.clone_defaults()
    STATS.mark_dirty(uuid)
    if sync then
        STATS.send_sync(player)
    end
end

function STATS.summary(player)
    local stats = STATS.get(player)
    return "포인트=" .. tostring(stats.points)
        .. " 힘=" .. tostring(stats.str)
        .. " 민첩=" .. tostring(stats.agi)
        .. " 지능=" .. tostring(stats.int)
        .. " 체력=" .. tostring(stats.vit)
        .. " 운=" .. tostring(stats.luk)
end

function STATS.calc_damage_bonus_percent(stat_value)
    stat_value = tonumber(stat_value) or 0
    return STATS.damage_formula.multiplier
        * (math.log((stat_value / STATS.damage_formula.divisor) + STATS.damage_formula.offset_inside) / math.log(10))
        + STATS.damage_formula.flat_bonus
end

function STATS.apply_damage_bonus(base_damage, stat_value)
    local bonus_percent = STATS.calc_damage_bonus_percent(stat_value)
    return base_damage * (1 + bonus_percent / 100)
end

function STATS.calculate_skill_damage(player_or_uuid, damage_type, base_damage)
    local uuid = type(player_or_uuid) == "string" and player_or_uuid or STATS.player_uuid(player_or_uuid)
    local stat = STATS.damage_type_to_stat[damage_type]
    if stat == nil then return base_damage end
    local stats = STATS.get_by_uuid(uuid)
    return STATS.apply_damage_bonus(base_damage, stats[stat] or 0)
end
