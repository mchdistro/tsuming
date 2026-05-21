local sync_packet = aris.init.networking.create_s2c_packet("stats_sync")
sync_packet:append(aris.init.networking.string_arg("uuid"))
sync_packet:append(aris.init.networking.string_arg("name"))
sync_packet:append(aris.init.networking.integer_arg("points"))
sync_packet:append(aris.init.networking.integer_arg("str"))
sync_packet:append(aris.init.networking.integer_arg("agi"))
sync_packet:append(aris.init.networking.integer_arg("int"))
sync_packet:append(aris.init.networking.integer_arg("vit"))
sync_packet:append(aris.init.networking.integer_arg("luk"))

local add_packet = aris.init.networking.create_c2s_packet("stats_add_point")
add_packet:append(aris.init.networking.string_arg("stat"))

local apply_packet = aris.init.networking.create_c2s_packet("stats_apply_points")
apply_packet:append(aris.init.networking.integer_arg("str"))
apply_packet:append(aris.init.networking.integer_arg("agi"))
apply_packet:append(aris.init.networking.integer_arg("int"))
apply_packet:append(aris.init.networking.integer_arg("vit"))
apply_packet:append(aris.init.networking.integer_arg("luk"))

local open_packet = aris.init.networking.create_c2s_packet("stats_open_request")
open_packet:append(aris.init.networking.string_arg("reason"))

local root = aris.init.command.create_command("stat")
root:set_endpoint("stats_open")

local info = aris.init.command.sub_command("info")
info:set_endpoint("stats_info_self")
root:append(info)

local info_player = aris.init.command.player_arg("player")
info_player:set_endpoint("stats_info_player")
info:append(info_player)

local point = aris.init.command.sub_command("point")
root:append(point)

local function append_point_action(name, endpoint)
    local action = aris.init.command.sub_command(name)
    local player = aris.init.command.player_arg("player")
    local amount = aris.init.command.integer_arg("amount")
    amount:set_endpoint(endpoint)
    player:append(amount)
    action:append(player)
    point:append(action)
end

append_point_action("add", "stats_point_add")
append_point_action("set", "stats_point_set")
append_point_action("take", "stats_point_take")

local stat_keys = { "str", "agi", "int", "vit", "luk" }

local function append_stat_action(name)
    local action = aris.init.command.sub_command(name)
    local player = aris.init.command.player_arg("player")
    for _, stat_key in ipairs(stat_keys) do
        local stat = aris.init.command.sub_command(stat_key)
        local amount = aris.init.command.integer_arg("amount")
        amount:set_endpoint("stats_stat_" .. name .. "_" .. stat_key)
        stat:append(amount)
        player:append(stat)
    end
    action:append(player)
    root:append(action)
end

append_stat_action("add")
append_stat_action("set")

local reset = aris.init.command.sub_command("reset")
local reset_player = aris.init.command.player_arg("player")
reset_player:set_endpoint("stats_reset")
reset:append(reset_player)
root:append(reset)
