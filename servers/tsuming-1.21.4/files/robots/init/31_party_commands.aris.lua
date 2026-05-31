-- 파티 패킷 선언 + 명령어 트리 (길드 30_guild_commands 미러)
local sync_packet = aris.init.networking.create_s2c_packet("party_sync")
sync_packet:append(aris.init.networking.integer_arg("in_party"))
sync_packet:append(aris.init.networking.integer_arg("members"))
sync_packet:append(aris.init.networking.string_arg("leader"))
sync_packet:append(aris.init.networking.string_arg("member_names"))
sync_packet:append(aris.init.networking.string_arg("leader_name"))
sync_packet:append(aris.init.networking.integer_arg("has_invite"))

-- 파티원 체력 HUD용 (같은 서버 멤버 "name:hp:max,..." CSV)
local health_packet = aris.init.networking.create_s2c_packet("party_health")
health_packet:append(aris.init.networking.string_arg("data"))

local action_packet = aris.init.networking.create_c2s_packet("party_gui_action")
action_packet:append(aris.init.networking.string_arg("action"))
action_packet:append(aris.init.networking.string_arg("value"))

local root = aris.init.command.create_command("party")
root:set_endpoint("party_open")

local create = aris.init.command.sub_command("create")
create:set_endpoint("party_create")
root:append(create)

local info = aris.init.command.sub_command("info")
info:set_endpoint("party_info")
root:append(info)

local leave = aris.init.command.sub_command("leave")
leave:set_endpoint("party_leave")
root:append(leave)

local disband = aris.init.command.sub_command("disband")
disband:set_endpoint("party_disband")
root:append(disband)

local accept = aris.init.command.sub_command("accept")
accept:set_endpoint("party_accept")
root:append(accept)

local deny = aris.init.command.sub_command("deny")
deny:set_endpoint("party_deny")
root:append(deny)

local invite = aris.init.command.sub_command("invite")
local invite_player = aris.init.command.player_arg("player")
invite_player:set_endpoint("party_invite")
invite:append(invite_player)
root:append(invite)

local pc = aris.init.command.create_command("pc")
local pc_message = aris.init.command.string_arg("message")
pc_message:set_endpoint("party_chat")
pc:append(pc_message)
