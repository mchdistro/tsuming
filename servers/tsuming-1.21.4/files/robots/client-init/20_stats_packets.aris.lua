local sync_packet = aris.init.networking.create_s2c_packet("stats_sync")
sync_packet:append(aris.init.networking.string_arg("payload"))

local add_packet = aris.init.networking.create_c2s_packet("stats_add_point")
add_packet:append(aris.init.networking.string_arg("stat"))

local apply_packet = aris.init.networking.create_c2s_packet("stats_apply_points")
apply_packet:append(aris.init.networking.string_arg("payload"))

local open_packet = aris.init.networking.create_c2s_packet("stats_open_request")
open_packet:append(aris.init.networking.string_arg("reason"))
