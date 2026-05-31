-- /bind 명령어 : 손에 든 아이템을 귀속
local bind_cmd = aris.init.command.create_command("bind")
bind_cmd:set_endpoint("bind_item")