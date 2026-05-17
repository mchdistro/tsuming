local animations = {
    vfx_dusk_cut = { "lrd", "rld", "lr", "v", "v2" },
    vfx_dusk_dagger = { "spawn", "shoot_end", "shoot_down" },
    vfx_dusk_dagger_circle = { "skill" },
    vfx_dusk_dash = { "skill" },
    vfx_dusk_downslash = { "skill" },
    vfx_dusk_shockwave_slash = { "skill", "skill2" },
    vfx_dusk_shuriken = { "loop" },
    vfx_dusk_spinning_blades = { "spin" },
    vfx_pulse = { "skill3" },
}

for i = 1, 9 do
    animations["vfx_dusk_dash_impact_" .. i] = { "skill" }
    animations["vfx_dusk_pierce_" .. i] = i == 9 and { "skill" } or { "skill", "skill2", "skill3" }
end

for i = 1, 7 do
    animations["vfx_dusk_slash_" .. i] = { "lr_cut", "rl_cut", "lr", "rl", "lrd", "rld", "lrd2", "rld2" }
    animations["vfx_dusk_spin_" .. i] = i == 1 and { "skill", "skill2" } or { "skill" }
end

for i = 1, 5 do
    animations["vfx_shadow_figure_" .. i] = { "skill1", "skill2", "skill3", "skill4", "skill5", "skill6" }
end

local function register_animation(entity_key, name)
    local ok, err = xpcall(function()
        local raw = aris.game.geckolib.create_animation(entity_key, name)
        raw:then_play(name)
    end, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[03_awakened_assassin_animations] " .. tostring(entity_key) .. ":" .. tostring(name) .. " " .. tostring(err))
    end
end

for entity_key, names in pairs(animations) do
    for _, name in ipairs(names) do
        register_animation(entity_key, name)
    end
    local ok, err = xpcall(function()
        aris.game.geckolib.enable_idle(entity_key)
    end, debug ~= nil and debug.traceback or tostring)
    if not ok then
        aris.log_error("[03_awakened_assassin_animations:enable_idle] " .. tostring(entity_key) .. " " .. tostring(err))
    end
end
