depends_on("22_stats_storage.aris")

aris.game.hook.on_player_join_server(function(player)
    STATS.load_player(player)
    STATS.send_sync(player)
end)

aris.game.hook.on_player_leave_server(function(player)
    STATS.flush_player(player)
    STATS.unload_player(player)
end)

aris.hook.on_engine_dispose(function()
    STATS.flush_dirty()
end)

aris.game.hook.add_c2s_packet_handler("stats_open_request", function(player, packet)
    STATS.load_player(player)
    STATS.send_sync(player)
end)

aris.game.hook.add_c2s_packet_handler("stats_add_point", function(player, packet)
    local ok, text = STATS.add_stat_point(player, packet.stat or "")
    STATS.message(player, "[스탯] " .. text)
end)

aris.game.hook.register_endpoint("stats_open", function(player, args)
    aris.log_info("[stats] /stat endpoint called")
    STATS.send_sync(player)
end)

aris.game.hook.register_endpoint("stats_info_self", function(player, args)
    STATS.message(player, "[스탯] " .. STATS.summary(player))
end)

aris.game.hook.register_endpoint("stats_info_player", function(player, args)
    local target = args.player
    STATS.message(player, "[스탯] " .. STATS.player_name(target) .. " " .. STATS.summary(target))
end)

aris.game.hook.register_endpoint("stats_point_add", function(player, args)
    if not STATS.require_admin(player) then return end
    STATS.add_points(args.player, args.amount, false)
    STATS.message(player, "[스탯] " .. STATS.player_name(args.player) .. " 포인트 추가: " .. tostring(args.amount))
end)

aris.game.hook.register_endpoint("stats_point_set", function(player, args)
    if not STATS.require_admin(player) then return end
    STATS.set_points(args.player, args.amount, false)
    STATS.message(player, "[스탯] " .. STATS.player_name(args.player) .. " 포인트 설정: " .. tostring(args.amount))
end)

aris.game.hook.register_endpoint("stats_point_take", function(player, args)
    if not STATS.require_admin(player) then return end
    STATS.add_points(args.player, -(tonumber(args.amount) or 0), false)
    STATS.message(player, "[스탯] " .. STATS.player_name(args.player) .. " 포인트 차감: " .. tostring(args.amount))
end)

for _, stat_key in ipairs(STATS.order) do
    aris.game.hook.register_endpoint("stats_stat_add_" .. stat_key, function(player, args)
        if not STATS.require_admin(player) then return end
        local ok, text = STATS.add_stat(args.player, stat_key, args.amount, false)
        STATS.message(player, "[스탯] " .. STATS.player_name(args.player) .. " " .. text)
    end)

    aris.game.hook.register_endpoint("stats_stat_set_" .. stat_key, function(player, args)
        if not STATS.require_admin(player) then return end
        local ok, text = STATS.set_stat(args.player, stat_key, args.amount, false)
        STATS.message(player, "[스탯] " .. STATS.player_name(args.player) .. " " .. text)
    end)
end

aris.game.hook.register_endpoint("stats_reset", function(player, args)
    if not STATS.require_admin(player) then return end
    STATS.reset(args.player, false)
    STATS.message(player, "[스탯] " .. STATS.player_name(args.player) .. " 스탯 초기화")
end)

while true do
    task_sleep(STATS.storage.flush_interval_ms)
    STATS.flush_dirty()
end
