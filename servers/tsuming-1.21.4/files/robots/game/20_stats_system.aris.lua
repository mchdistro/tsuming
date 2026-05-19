depends_on("00_lunajson_loader.aris")

local STAT_DAMAGE_FORMULA = {
    multiplier = 50,
    divisor = 30,
    offset_inside = 1,
    flat_bonus = 2,
}

local STAT_DEFAULTS = {
    points = 0,
    str = 0,
    agi = 0,
    int = 0,
    vit = 0,
    luk = 0,
}

local STAT_MAX_PER_STAT = 999

local STAT_ORDER = { "str", "agi", "int", "vit", "luk" }

local STAT_DEFINITIONS = {
    str = { display = "힘", description = "물리 데미지, 방어력, 대장장이 제작 확률" },
    agi = { display = "민첩", description = "원거리 데미지, 회피율" },
    int = { display = "지능", description = "마법 데미지, 연금술 제작 확률" },
    vit = { display = "체력", description = "최대 체력, 체력 재생" },
    luk = { display = "운", description = "요리/제작 성공 확률, 아이템 드랍률 증가" },
}

local DAMAGE_TYPE_TO_STAT = {
    physical = "str",
    ranged = "agi",
    magic = "int",
}

STATS = STATS or {}
STATS.cache = STATS.cache or {}
STATS.dirty = STATS.dirty or {}

local function clone_defaults()
    return {
        points = STAT_DEFAULTS.points,
        str = STAT_DEFAULTS.str,
        agi = STAT_DEFAULTS.agi,
        int = STAT_DEFAULTS.int,
        vit = STAT_DEFAULTS.vit,
        luk = STAT_DEFAULTS.luk,
    }
end

local function player_uuid(player)
    if player == nil then return "" end
    return tostring(player:get_uuid())
end

local function player_name(player)
    if player == nil then return "" end
    return tostring(player:get_name())
end

local function message(player, text)
    if player ~= nil then
        player:send_message_text(text)
    else
        aris.log_info(text)
    end
end

local function is_admin(player)
    return player == nil or player:is_op()
end

local function require_admin(player)
    if is_admin(player) then return true end
    message(player, "[스탯] 관리자 권한이 필요합니다.")
    return false
end

local function is_valid_stat(stat)
    return STAT_DEFINITIONS[stat] ~= nil
end

local function normalize_stats(stats)
    stats = stats or {}
    for key, value in pairs(STAT_DEFAULTS) do
        if type(stats[key]) ~= "number" then
            stats[key] = value
        end
        if stats[key] < 0 then
            stats[key] = 0
        end
    end
    return stats
end

local function get_stats_by_uuid(uuid)
    if STATS.cache[uuid] == nil then
        STATS.cache[uuid] = clone_defaults()
    end
    return normalize_stats(STATS.cache[uuid])
end

local function get_stats(player)
    return get_stats_by_uuid(player_uuid(player))
end

local function mark_dirty(uuid)
    STATS.dirty[uuid] = true
end

local function build_payload(player)
    local uuid = player_uuid(player)
    local stats = get_stats_by_uuid(uuid)
    return JSON.encode({
        uuid = uuid,
        name = player_name(player),
        points = stats.points,
        str = stats.str,
        agi = stats.agi,
        int = stats.int,
        vit = stats.vit,
        luk = stats.luk,
    })
end

local function send_sync(player)
    if player == nil then return end
    local packet = aris.game.networking.create_s2c_packet_builder("stats_sync")
    packet:append_string("payload", build_payload(player))
    aris.game.networking.send_s2c_packet(player, packet)
end

local function add_stat_point(player, stat)
    if player == nil then return false, "플레이어를 찾을 수 없습니다." end
    if not is_valid_stat(stat) then return false, "알 수 없는 스탯입니다: " .. tostring(stat) end

    local uuid = player_uuid(player)
    local stats = get_stats_by_uuid(uuid)
    if stats.points <= 0 then return false, "사용 가능한 스탯 포인트가 없습니다." end
    if stats[stat] >= STAT_MAX_PER_STAT then return false, "해당 스탯은 이미 최대치입니다." end

    stats.points = stats.points - 1
    stats[stat] = stats[stat] + 1
    mark_dirty(uuid)
    send_sync(player)
    return true, STAT_DEFINITIONS[stat].display .. " +1"
end

local function set_points(player, amount)
    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end
    local uuid = player_uuid(player)
    local stats = get_stats_by_uuid(uuid)
    stats.points = amount
    mark_dirty(uuid)
    send_sync(player)
end

local function add_points(player, amount)
    amount = tonumber(amount) or 0
    local stats = get_stats(player)
    set_points(player, stats.points + amount)
end

local function set_stat(player, stat, amount)
    if not is_valid_stat(stat) then return false, "알 수 없는 스탯입니다: " .. tostring(stat) end
    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end
    if amount > STAT_MAX_PER_STAT then amount = STAT_MAX_PER_STAT end
    local uuid = player_uuid(player)
    local stats = get_stats_by_uuid(uuid)
    stats[stat] = amount
    mark_dirty(uuid)
    send_sync(player)
    return true, STAT_DEFINITIONS[stat].display .. " = " .. tostring(amount)
end

local function add_stat(player, stat, amount)
    local stats = get_stats(player)
    return set_stat(player, stat, (stats[stat] or 0) + (tonumber(amount) or 0))
end

local function reset_stats(player)
    local uuid = player_uuid(player)
    STATS.cache[uuid] = clone_defaults()
    mark_dirty(uuid)
    send_sync(player)
end

local function stats_summary(player)
    local stats = get_stats(player)
    return "포인트=" .. tostring(stats.points)
        .. " 힘=" .. tostring(stats.str)
        .. " 민첩=" .. tostring(stats.agi)
        .. " 지능=" .. tostring(stats.int)
        .. " 체력=" .. tostring(stats.vit)
        .. " 운=" .. tostring(stats.luk)
end

function STATS.calc_damage_bonus_percent(stat_value)
    stat_value = tonumber(stat_value) or 0
    return STAT_DAMAGE_FORMULA.multiplier
        * (math.log((stat_value / STAT_DAMAGE_FORMULA.divisor) + STAT_DAMAGE_FORMULA.offset_inside) / math.log(10))
        + STAT_DAMAGE_FORMULA.flat_bonus
end

function STATS.apply_damage_bonus(base_damage, stat_value)
    local bonus_percent = STATS.calc_damage_bonus_percent(stat_value)
    return base_damage * (1 + bonus_percent / 100)
end

function STATS.calculate_skill_damage(player_or_uuid, damage_type, base_damage)
    local uuid = type(player_or_uuid) == "string" and player_or_uuid or player_uuid(player_or_uuid)
    local stat = DAMAGE_TYPE_TO_STAT[damage_type]
    if stat == nil then return base_damage end
    local stats = get_stats_by_uuid(uuid)
    return STATS.apply_damage_bonus(base_damage, stats[stat] or 0)
end

aris.game.hook.add_c2s_packet_handler("stats_open_request", function(player, packet)
    send_sync(player)
end)

aris.game.hook.add_c2s_packet_handler("stats_add_point", function(player, packet)
    local ok, text = add_stat_point(player, packet.stat or "")
    message(player, ok and ("[스탯] " .. text) or ("[스탯] " .. text))
end)

aris.game.hook.register_endpoint("stats_open", function(player, args)
    send_sync(player)
end)

aris.game.hook.register_endpoint("stats_info_self", function(player, args)
    message(player, "[스탯] " .. stats_summary(player))
end)

aris.game.hook.register_endpoint("stats_info_player", function(player, args)
    local target = args.player
    message(player, "[스탯] " .. player_name(target) .. " " .. stats_summary(target))
end)

aris.game.hook.register_endpoint("stats_point_add", function(player, args)
    if not require_admin(player) then return end
    add_points(args.player, args.amount)
    message(player, "[스탯] " .. player_name(args.player) .. " 포인트 추가: " .. tostring(args.amount))
end)

aris.game.hook.register_endpoint("stats_point_set", function(player, args)
    if not require_admin(player) then return end
    set_points(args.player, args.amount)
    message(player, "[스탯] " .. player_name(args.player) .. " 포인트 설정: " .. tostring(args.amount))
end)

aris.game.hook.register_endpoint("stats_point_take", function(player, args)
    if not require_admin(player) then return end
    add_points(args.player, -(tonumber(args.amount) or 0))
    message(player, "[스탯] " .. player_name(args.player) .. " 포인트 차감: " .. tostring(args.amount))
end)

for _, stat_key in ipairs(STAT_ORDER) do
    aris.game.hook.register_endpoint("stats_stat_add_" .. stat_key, function(player, args)
        if not require_admin(player) then return end
        local ok, text = add_stat(args.player, stat_key, args.amount)
        message(player, "[스탯] " .. player_name(args.player) .. " " .. text)
    end)

    aris.game.hook.register_endpoint("stats_stat_set_" .. stat_key, function(player, args)
        if not require_admin(player) then return end
        local ok, text = set_stat(args.player, stat_key, args.amount)
        message(player, "[스탯] " .. player_name(args.player) .. " " .. text)
    end)
end

aris.game.hook.register_endpoint("stats_reset", function(player, args)
    if not require_admin(player) then return end
    reset_stats(args.player)
    message(player, "[스탯] " .. player_name(args.player) .. " 스탯 초기화")
end)
