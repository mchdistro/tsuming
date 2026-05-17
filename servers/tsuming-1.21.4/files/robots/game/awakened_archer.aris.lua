local TICKS_PER_SECOND = 20
local DEG_TO_RAD = math.pi / 180

local state = {
    tick = 0,
    timers = {},
    projectiles = {},
    auras = {},
    cooldowns = {},
    players = {},
    next_vfx_id = 0,
}

local SKILL = {
    item_name = "Galebow",
    blasting_damage = 5,
    evasive_damage = 5,
    volley_damage = 5,
    piercing_damage = 6,
    rapid_damage = 5,
    destruction_damage = 40,
}

local function register_anim(entity_key, trigger_name, animation_name)
    local anim = aris.game.geckolib.create_animation(entity_key, trigger_name)
    anim:then_play(animation_name or trigger_name)
end

local function register_used_animations()
    for i = 1, 8 do
        register_anim("evasive_shot_" .. i, "back_roll", "back_roll")
        register_anim("quick_dash_vfx_" .. i, "back_roll", "back_roll")
        register_anim("quick_dash_vfx_" .. i, "jump", "jump")
    end

    register_anim("evasive_shot_arrows", "evasive_shot", "evasive_shot")
    register_anim("vfx_first_hit_impact", "animation", "animation")
    register_anim("vfx_awakened_arrow_impact", "impact", "impact")
    register_anim("vfx_awakened_arrow", "shoot", "shoot")
    register_anim("vfx_awakened_arrow", "shoot2", "shoot2")
    register_anim("vfx_awakened_arrow", "shoot_shaking", "shoot_shaking")
    register_anim("vfx_shot_charging", "charging_and_shoot", "charging_and_shoot")
    register_anim("vfx_shot_charging", "shoot_impact", "shoot_impact")
    register_anim("vfx_earthquake_rupture_1", "skill2", "skill2")
    register_anim("vfx_rubbles", "skill", "skill")
    register_anim("vfx_volley_of_arrow", "animation3", "animation3")
    register_anim("vfx_volley_of_arrow", "animation2", "animation2")
    register_anim("piercing_skyfall", "firing_multiple_arrows", "firing_multiple_arrows")
    for i = 1, 10 do
        register_anim("piercing_skyfall", "arrow_rain_" .. i, "arrow_rain_" .. i)
    end
    register_anim("vfx_shot_of_destruction", "chrage", "chrage")
    register_anim("vfx_shot_of_destruction", "arrow_destruction", "arrow_destruction")
    register_anim("vfx_sod_rubble", "rub1", "rub1")
end

register_used_animations()

local function uuid(entity)
    return entity:get_uuid()
end

local function is_galebow(player)
    local item = player:get_main_hand_item()
    if item == nil then
        return false
    end

    local name = item:get_display_name() or item:get_name() or ""
    return string.find(name, SKILL.item_name, 1, true) ~= nil
end

local function aura_key(entity, name)
    return uuid(entity) .. ":" .. name
end

local function add_aura(entity, name, duration, stacks, max_stacks)
    local key = aura_key(entity, name)
    local current = state.auras[key]
    local next_stacks = stacks or 1
    if current ~= nil then
        next_stacks = current.stacks + (stacks or 1)
    end
    if max_stacks ~= nil and next_stacks > max_stacks then
        next_stacks = max_stacks
    end
    state.auras[key] = { until_tick = state.tick + duration, stacks = next_stacks }
end

local function remove_aura(entity, name)
    state.auras[aura_key(entity, name)] = nil
end

local function has_aura(entity, name)
    local aura = state.auras[aura_key(entity, name)]
    return aura ~= nil and aura.until_tick > state.tick
end

local function aura_stacks(entity, name)
    local aura = state.auras[aura_key(entity, name)]
    if aura == nil or aura.until_tick <= state.tick then
        return 0
    end
    return aura.stacks or 0
end

local function cooldown_key(entity, name)
    return uuid(entity) .. ":" .. name
end

local function player_state(player)
    local id = player:get_uuid()
    local current = state.players[id]
    if current == nil then
        current = {
            player = player,
            sneak_down = false,
            sneak_click_until = 0,
            next_ambush = 0,
            next_piercing_timer = 0,
        }
        state.players[id] = current
    else
        current.player = player
    end
    return current
end

local function can_cast(entity, name, cooldown_ticks)
    local key = cooldown_key(entity, name)
    local until_tick = state.cooldowns[key] or 0
    if until_tick > state.tick then
        return false
    end
    state.cooldowns[key] = state.tick + cooldown_ticks
    return true
end

local function after(delay, fn)
    state.timers[#state.timers + 1] = { at = state.tick + delay, fn = fn }
end

local function every(start_delay, repeat_count, interval, fn)
    for i = 0, repeat_count - 1 do
        after(start_delay + (i * interval), function()
            fn(i + 1)
        end)
    end
end

local function run_command_at(entity, command)
    local x = tostring(entity:get_x())
    local y = tostring(entity:get_y())
    local z = tostring(entity:get_z())
    aris.game.dispatch_command("execute positioned " .. x .. " " .. y .. " " .. z .. " run " .. command)
end

local function sound(entity, id, volume, pitch)
    run_command_at(entity, "playsound " .. id .. " master @a[distance=..32] ~ ~ ~ " .. tostring(volume or 0.7) .. " " .. tostring(pitch or 1))
end

local function particle(entity, id, amount, dx, dy, dz, speed)
    run_command_at(entity, "particle " .. id .. " ~ ~1 ~ " .. tostring(dx or 0.2) .. " " .. tostring(dy or 0.2) .. " " .. tostring(dz or 0.2) .. " " .. tostring(speed or 0) .. " " .. tostring(amount or 10))
end

local function remove_tagged_vfx(tag)
    -- /kill makes GeckoLib mob VFX flash red. Move it out of view first, then clean it up off-screen.
    aris.game.dispatch_command("tp @e[tag=" .. tag .. "] 0 -10000 0")
    after(40, function()
        aris.game.dispatch_command("kill @e[tag=" .. tag .. "]")
    end)
end

local function kill_later(entity, delay)
    if entity == nil then
        return
    end
    after(delay, function()
        if entity.command_tag ~= nil then
            remove_tagged_vfx(entity.command_tag)
        else
            entity:add_damage(999999)
        end
    end)
end

local function point(x, y, z)
    return aris.math.create_point(x, y, z)
end

local function yaw_vector(yaw, horizontal_offset_degrees)
    local angle = (yaw + (horizontal_offset_degrees or 0)) * DEG_TO_RAD
    return -math.sin(angle), math.cos(angle)
end

local function spawn_vfx(world, key, x, y, z, anim, life, yaw, pitch)
    state.next_vfx_id = state.next_vfx_id + 1
    local tag = "aa_vfx_" .. tostring(state.next_vfx_id)
    local ry = yaw or 0
    local rp = pitch or 0
    aris.game.dispatch_command("summon aris:" .. key .. " " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " {Tags:[\"" .. tag .. "\"],Rotation:[" .. tostring(ry) .. "f," .. tostring(rp) .. "f]}")
    local entity = { command_tag = tag, x = x, y = y, z = z, yaw = ry, pitch = rp }
    if life ~= nil then
        kill_later(entity, life)
    end
    return entity
end

local function spawn_vfx_at_player(player, key, y_offset, forward_offset, anim, life)
    local dx, dz = yaw_vector(player:get_yaw(), 0)
    return spawn_vfx(
        player:get_server_world(),
        key,
        player:get_x() + dx * (forward_offset or 0),
        player:get_y() + (y_offset or 0),
        player:get_z() + dz * (forward_offset or 0),
        anim,
        life,
        player:get_yaw(),
        player:get_pitch()
    )
end

local function spawn_frame_sequence(player, prefix, anim, frames, life_per_frame, y_offset, forward_offset)
    every(0, frames, 1, function(frame)
        spawn_vfx_at_player(player, prefix .. frame, y_offset or 0.5, forward_offset or 0, anim, life_per_frame or 2)
    end)
end

local function apply_hit(caster, target, damage, first_hit_multiplier, knock_y)
    if target == nil or target:get_uuid() == caster:get_uuid() then
        return false
    end
    if target:get_type() == "minecraft:armor_stand" then
        return false
    end

    local final_damage = damage
    if has_aura(caster, "Ambush") and not has_aura(target, "FIRSTHIT") then
        final_damage = damage * (first_hit_multiplier or 1.5)
        add_aura(target, "FIRSTHIT", 600, 1, 1)
        spawn_vfx(caster:get_server_world(), "vfx_first_hit_impact", target:get_x(), target:get_y() + 1.0, target:get_z(), "animation", 12, caster:get_yaw(), caster:get_pitch())
        sound(caster, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_first_hit", 0.7, 1)
    end

    if has_aura(target, "immunedelay") then
        return false
    end
    add_aura(target, "immunedelay", 3, 1, 1)
    target:add_damage(final_damage)
    if knock_y ~= nil and knock_y ~= 0 then
        target:add_velocity(0, knock_y, 0)
    end
    spawn_vfx(caster:get_server_world(), "vfx_awakened_arrow_impact", target:get_x(), target:get_y() + 1.0, target:get_z(), "impact", 9, caster:get_yaw(), caster:get_pitch())
    sound(caster, "universal_sounds:samus.universal.hit_impact_thud", 0.7, 1.15)
    return true
end

local function spawn_projectile(caster, model, anim, damage, opts)
    opts = opts or {}
    local yaw = caster:get_yaw() + (opts.h_offset or 0)
    local pitch = caster:get_pitch()
    local dx, dz = yaw_vector(yaw, 0)
    local py = -math.sin(pitch * DEG_TO_RAD)
    local x = caster:get_x() + dx * (opts.start_forward or 1.0)
    local y = caster:get_y() + 1.45 + (opts.start_y or 0)
    local z = caster:get_z() + dz * (opts.start_forward or 1.0)
    local vfx = spawn_vfx(caster:get_server_world(), model, x, y, z, anim, opts.life or 40)
    state.projectiles[#state.projectiles + 1] = {
        caster = caster,
        entity = vfx,
        x = x,
        y = y,
        z = z,
        dx = dx,
        dy = py,
        dz = dz,
        yaw = yaw,
        pitch = pitch,
        speed = opts.speed or 2.05,
        radius = opts.radius or 0.7,
        damage = damage,
        max_ticks = opts.max_ticks or 35,
        age = 0,
        pierce = opts.pierce or 1,
        first_hit_multiplier = opts.first_hit_multiplier or 1.5,
        on_end = opts.on_end,
        knock_y = opts.knock_y,
    }
end

local function update_projectiles()
    local remaining = {}
    for _, p in ipairs(state.projectiles) do
        p.age = p.age + 1
        p.x = p.x + p.dx * p.speed
        p.y = p.y + p.dy * p.speed
        p.z = p.z + p.dz * p.speed
        if p.entity ~= nil then
            if p.entity.command_tag ~= nil then
                aris.game.dispatch_command("tp @e[tag=" .. p.entity.command_tag .. ",limit=1] " .. tostring(p.x) .. " " .. tostring(p.y) .. " " .. tostring(p.z) .. " " .. tostring(p.yaw or 0) .. " " .. tostring(p.pitch or 0))
            else
                p.entity:move_to(p.x, p.y, p.z)
            end
        end

        -- Avoid nested Lua callback APIs inside tick hooks; this Aris build can NPE while wrapping LuaFunc there.
        local hit_count = 0

        if p.age >= p.max_ticks or hit_count >= p.pierce then
            if p.on_end ~= nil then
                p.on_end(p)
            end
            if p.entity ~= nil then
                if p.entity.command_tag ~= nil then
                    remove_tagged_vfx(p.entity.command_tag)
                else
                    p.entity:add_damage(999999)
                end
            end
        else
            remaining[#remaining + 1] = p
        end
    end
    state.projectiles = remaining
end

local function cast_ambush(player)
    add_aura(player, "Ambush", 20, 1, 1)
    particle(player, "dust_color_transition 0.89 1.0 0.52 0.7 0.29 0.72 0.0 1", 20, 0.4, 0.2, 0.4, 0)
end

local function shoot_arrow(player, damage, model, anim, h_offset, radius, pierce, max_ticks)
    spawn_vfx_at_player(player, "vfx_awakened_arrow_impact", 1.3, 1.6, "impact", 9)
    spawn_projectile(player, model or "vfx_awakened_arrow", anim or "shoot", damage, {
        h_offset = h_offset or 0,
        radius = radius or 0.7,
        pierce = pierce or 1,
        max_ticks = max_ticks or 35,
        speed = 2.05,
    })
    sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_arrow_shoot", 0.7, 1)
end

local function cast_blasting_combo(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Blasting_Combo", 6) then
        return
    end

    local stacks = aura_stacks(player, "Blasting_Combo_Stack")
    if stacks < 3 then
        add_aura(player, "Blasting_Combo_Stack", 300, 1, 3)
        spawn_frame_sequence(player, "quick_dash_vfx_", "back_roll", 8, 2, 0.5, 0)
        player:add_velocity_relative(-0.8, -0.05, 0)
        sound(player, "universal_sounds:samus.universal.move", 0.7, 1)
        after(4, function()
            shoot_arrow(player, SKILL.blasting_damage, "vfx_awakened_arrow", "shoot", 0, 0.7, 1, 35)
        end)
        return
    end

    remove_aura(player, "Blasting_Combo_Stack")
    add_aura(player, "CASTING", 18, 1, 1)
    player:add_velocity_relative(-0.5, 0.4, 0)
    spawn_frame_sequence(player, "quick_dash_vfx_", "jump", 8, 2, 0.5, 0)
    sound(player, "awakened_archer_sounds:samus.awakened_archer.move", 0.7, 0.75)
    after(5, function()
        spawn_vfx_at_player(player, "vfx_shot_charging", 1.5, 0.8, "charging_and_shoot", 20)
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_charge", 0.7, 1)
    end)
    after(12, function()
        spawn_projectile(player, "vfx_awakened_arrow", "shoot_shaking", SKILL.blasting_damage, {
            radius = 0.8,
            pierce = 1,
            max_ticks = 35,
            knock_y = 4,
            on_end = function(p)
                spawn_vfx(player:get_server_world(), "vfx_earthquake_rupture_1", p.x, p.y - 1, p.z, "skill2", 52, player:get_yaw(), 0)
                spawn_vfx(player:get_server_world(), "vfx_rubbles", p.x, p.y - 1, p.z, "skill", 45, player:get_yaw(), 0)
                spawn_vfx(player:get_server_world(), "vfx_shot_charging", p.x, p.y, p.z, "shoot_impact", 18, player:get_yaw(), player:get_pitch())
                sound(player, "universal_sounds:samus.universal.rupture_quick", 0.7, 1)
            end,
        })
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_charge_shot", 0.7, 1)
    end)
end

local function cast_evasive_shot(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Evasive_Shot", 40) then
        return
    end
    add_aura(player, "CASTING", 15, 1, 1)
    spawn_frame_sequence(player, "evasive_shot_", "back_roll", 8, 2, 0.5, 0)
    player:add_velocity_relative(-1.4, 0.3, 0)
    sound(player, "universal_sounds:samus.universal.move", 0.7, 1)

    every(4, 3, 4, function()
        spawn_vfx_at_player(player, "evasive_shot_arrows", 1.3, 1.6, "evasive_shot", 35)
        shoot_arrow(player, SKILL.evasive_damage, "vfx_awakened_arrow", "shoot", math.random(1, 3), 0.4, 1, 35)
        shoot_arrow(player, SKILL.evasive_damage, "vfx_awakened_arrow", "shoot", -math.random(1, 3), 0.4, 1, 35)
    end)
    after(19, function()
        player:add_velocity_relative(-0.4, -1, 0)
    end)
end

local function cast_volley_of_arrows(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Volley_Of_Arrows", 60) then
        return
    end
    add_aura(player, "CASTING", 25, 1, 1)
    spawn_vfx_at_player(player, "vfx_volley_of_arrow", 1.0, 0, "animation3", 24)
    sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_rapid_fire", 0.7, 1)
    after(7, function()
        for i = 1, 10 do
            spawn_projectile(player, "vfx_awakened_arrow", "shoot", SKILL.volley_damage, {
                h_offset = -25 + (i * 5),
                radius = 1.0,
                max_ticks = 8,
                pierce = 1,
            })
        end
    end)
    after(25, function()
        spawn_vfx_at_player(player, "vfx_volley_of_arrow", 1.0, -1.5, "animation2", 11)
        for _, h in ipairs({ 0, 40, -40, 20, -20 }) do
            spawn_projectile(player, "vfx_awakened_arrow", "shoot", SKILL.volley_damage * 1.5, {
                h_offset = h,
                radius = 0.7,
                max_ticks = 12,
                pierce = 1,
                knock_y = 0,
            })
        end
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_arrow_fan", 0.7, 1)
    end)
end

local function cast_piercing_skyfall(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Piercing_Skyfall", 60) then
        return
    end
    add_aura(player, "CASTING", 15, 1, 1)
    spawn_vfx_at_player(player, "piercing_skyfall", 1.0, 0, "firing_multiple_arrows", 20)
    sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_arrow_shoot", 0.7, 1)
    after(20, function()
        for i = 1, 8 do
            local h = math.random(-35, 35)
            spawn_projectile(player, "piercing_skyfall", "arrow_rain_" .. tostring(math.random(1, 10)), SKILL.piercing_damage, {
                h_offset = h,
                radius = 1,
                max_ticks = 16,
                pierce = 2,
            })
        end
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_arrow_shoot_whoosh", 0.7, 1)
    end)
end

local function cast_rapid_arrows(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Rapid_Arrows", 60) then
        return
    end
    add_aura(player, "CASTING", 25, 1, 1)
    every(0, 5, 3, function()
        player:add_velocity_relative(-0.1, -0.01, 0)
        shoot_arrow(player, SKILL.rapid_damage, "vfx_awakened_arrow", "shoot", 0, 0.7, 1, 35)
    end)
    after(12, function()
        particle(player, "dust_color_transition 1.0 0.73 0.23 0.65 0.66 0.02 0.0 1", 120, 2, 2, 2, 0)
    end)
    every(19, 3, 5, function()
        player:add_velocity_relative(-0.65, -0.01, 0)
        spawn_projectile(player, "vfx_awakened_arrow", "shoot2", SKILL.rapid_damage * 1.5, {
            radius = 0.7,
            pierce = 10,
            max_ticks = 35,
        })
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_rapid_fire", 0.7, 1)
    end)
end

local function cast_shot_of_destruction(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Shot_Of_Destruction", 140) then
        return
    end
    add_aura(player, "CASTING", 40, 1, 1)
    spawn_vfx_at_player(player, "vfx_shot_of_destruction", 1.3, 0, "chrage", 41)
    sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_charge", 0.7, 0.7)
    after(30, function()
        player:add_velocity_relative(-1.5, -0.01, 0)
        spawn_projectile(player, "vfx_shot_of_destruction", "arrow_destruction", SKILL.destruction_damage * 1.5, {
            radius = 1.0,
            pierce = 5,
            max_ticks = 35,
            knock_y = 0,
            on_end = function(p)
                spawn_vfx(player:get_server_world(), "vfx_sod_rubble", p.x, p.y - 1, p.z, "rub1", 69, player:get_yaw(), 0)
                spawn_vfx(player:get_server_world(), "vfx_rubbles", p.x, p.y - 1, p.z, "skill", 45, player:get_yaw(), 0)
            end,
        })
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_strong_arrow", 0.7, 1)
    end)
end

aris.game.hook.add_on_left_click(function(event)
    local player = event:get_player()
    if player == nil or not is_galebow(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_shot_of_destruction(player)
    else
        cast_blasting_combo(player)
    end
end)

aris.game.hook.add_on_right_click(function(event)
    local player = event:get_player()
    if player == nil or not is_galebow(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_rapid_arrows(player)
    else
        cast_evasive_shot(player)
    end
end)

while true do
    state.tick = state.tick + 1

    local pending = {}
    for _, timer in ipairs(state.timers) do
        if timer.at <= state.tick then
            timer.fn()
        else
            pending[#pending + 1] = timer
        end
    end
    state.timers = pending

    for key, aura in pairs(state.auras) do
        if aura.until_tick <= state.tick then
            state.auras[key] = nil
        end
    end

    update_projectiles()

    for id, ps in pairs(state.players) do
        local player = ps.player
        if player == nil or not is_galebow(player) then
            state.players[id] = nil
        else
            if state.tick >= ps.next_ambush then
                ps.next_ambush = state.tick + 200
                cast_ambush(player)
            end

            if state.tick >= ps.next_piercing_timer then
                ps.next_piercing_timer = state.tick + 200
                if player:get_is_sneaking() then
                    local stacks = aura_stacks(player, "Piercing_Skyfall_STACK")
                    if stacks >= 2 then
                        remove_aura(player, "Piercing_Skyfall_STACK")
                        cast_piercing_skyfall(player)
                    else
                        add_aura(player, "Piercing_Skyfall_STACK", 120, 1, 2)
                    end
                else
                    remove_aura(player, "Piercing_Skyfall_STACK")
                end
            end

            local sneaking = player:get_is_sneaking()
            if sneaking and not ps.sneak_down and state.tick > ps.sneak_click_until then
                cast_volley_of_arrows(player)
            end
            ps.sneak_down = sneaking
        end
    end

    task_sleep(50)
end
