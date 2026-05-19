local packet = aris.init.networking.create_s2c_packet("skill_cooldown_hud")
packet:append(aris.init.networking.string_arg("weapon"))
packet:append(aris.init.networking.string_arg("payload"))
