-- /skill 명령어 트리 (스킬 밸런스 튜닝). 엔드포인트 핸들러는 game/09_skill_tuning 에서 등록.
local root = aris.init.command.create_command("skill")

-- /skill list <class>
local list = aris.init.command.sub_command("list")
local list_class = aris.init.command.word_arg("class")
list_class:set_endpoint("skill_list")
list:append(list_class)
root:append(list)

-- /skill get <class> <key>
local get = aris.init.command.sub_command("get")
local get_class = aris.init.command.word_arg("class")
local get_key = aris.init.command.word_arg("key")
get_key:set_endpoint("skill_get")
get_class:append(get_key)
get:append(get_class)
root:append(get)

-- /skill set <class> <key> <value>
local set = aris.init.command.sub_command("set")
local set_class = aris.init.command.word_arg("class")
local set_key = aris.init.command.word_arg("key")
local set_value = aris.init.command.float_arg("value")
set_value:set_endpoint("skill_set")
set_key:append(set_value)
set_class:append(set_key)
set:append(set_class)
root:append(set)

-- /skill reset <class> [<key>]
local reset = aris.init.command.sub_command("reset")
local reset_class = aris.init.command.word_arg("class")
reset_class:set_endpoint("skill_reset_class")
local reset_key = aris.init.command.word_arg("key")
reset_key:set_endpoint("skill_reset_key")
reset_class:append(reset_key)
reset:append(reset_class)
root:append(reset)
