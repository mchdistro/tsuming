-- robots/init/awakened_shaman.init.aris.lua
-- Awakened Shaman command endpoints.
-- Based on Aris docs: define commands in init, handle endpoints in game.

local root = aris.init.command.create_command("awakened_shaman")

local function endpoint(name)
    local sub = aris.init.command.sub_command(name)
    sub:set_endpoint("awakened_shaman_" .. name)
    root:append(sub)
end

endpoint("soul_link")
endpoint("primal_combo")
endpoint("echo_step")
endpoint("ritual_totem")
endpoint("stance_switch")
endpoint("earthen_embrace")
endpoint("ancestral_hands")
