depends_on("10_awakened_hud_shared.aris")

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
    motion_tokens = {},
}

local SKILL = {
    item_name = "Galebow",
    blasting_damage = 5,
    evasive_damage = 5,
    volley_damage = 5,
    piercing_damage = 6,
    rapid_damage = 5,
    destruction_damage = 40,
    blasting_cooldown = 6,
    evasive_cooldown = 40,
    volley_cooldown = 60,
    piercing_cooldown = 60,
    rapid_cooldown = 60,
    destruction_cooldown = 140,
    ambush_duration = 20,
    blasting_stack_duration = 300,
    blasting_max_stack = 3,
    arrow_speed = 2.05,
    arrow_radius = 0.7,
    arrow_pierce = 1,
    arrow_ticks = 35,
    blasting_charge_casting = 18,
    blasting_charge_delay = 12,
    blasting_charge_multiplier = 1,
    blasting_charge_radius = 0.8,
    evasive_casting = 15,
    evasive_shot_count = 3,
    evasive_shot_interval = 4,
    evasive_arrow_radius = 0.4,
    volley_casting = 25,
    volley_first_delay = 7,
    volley_first_count = 10,
    volley_second_delay = 25,
    volley_second_multiplier = 1.5,
    piercing_casting = 15,
    piercing_delay = 20,
    piercing_count = 8,
    piercing_radius = 1,
    piercing_pierce = 2,
    piercing_ticks = 16,
    rapid_casting = 25,
    rapid_first_count = 5,
    rapid_first_interval = 3,
    rapid_second_delay = 19,
    rapid_second_count = 3,
    rapid_second_interval = 5,
    rapid_second_multiplier = 1.5,
    rapid_second_pierce = 10,
    destruction_cooldown_damage_multiplier = 1.5,
    destruction_casting = 40,
    destruction_shoot_delay = 30,
    destruction_radius = 1.0,
    destruction_pierce = 5,
}

local HUD_SKILLS = {
    { id = "blasting_combo", key = "Blasting_Combo", cooldown = SKILL.blasting_cooldown },
    { id = "evasive_shot", key = "Evasive_Shot", cooldown = SKILL.evasive_cooldown },
    { id = "shot_of_destruction", key = "Shot_Of_Destruction", cooldown = SKILL.destruction_cooldown },
    { id = "rapid_arrows", key = "Rapid_Arrows", cooldown = SKILL.rapid_cooldown },
    { id = "volley_of_arrows", key = "Volley_Of_Arrows", cooldown = SKILL.volley_cooldown },
    { id = "piercing_skyfall", key = "Piercing_Skyfall", cooldown = SKILL.piercing_cooldown },
}

local VFX_SELECTOR_EXCLUDE = ",tag=!aa_vfx,type=!minecraft:armor_stand,type=!minecraft:item_display,type=!minecraft:block_display,type=!minecraft:text_display,type=!aris:vfx_awakened_arrow,type=!aris:vfx_awakened_arrow_impact,type=!aris:vfx_first_hit_impact,type=!aris:vfx_shot_charging,type=!aris:vfx_shot_of_destruction,type=!aris:vfx_sod_rubble,type=!aris:vfx_volley_of_arrow,type=!aris:piercing_skyfall,type=!aris:vfx_earthquake_rupture_1,type=!aris:vfx_earthquake_rupture_2,type=!aris:vfx_earthquake_rupture_3,type=!aris:vfx_earthquake_rupture_4,type=!aris:vfx_earthquake_rupture_5,type=!aris:vfx_rubbles"

local MOTION_TICKS = {
    ambush = 40,
    c1 = 20,
    c2 = 20,
    c3 = 20,
    c4 = 20,
    evasive_shot = 36,
    volley_of_arrow1 = 35,
    piercing_skyfall = 35,
    rapid_arrows1 = 33,
    shot_of_destruction = 90,
}

local function play_player_motion(player, motion)
    aris.game.geckolib.emote.set_emote_file(player, "boss_archer")
    aris.game.geckolib.emote.trigger_emote(player, motion)
    local id = player:get_uuid()
    local token = (state.motion_tokens[id] or 0) + 1
    state.motion_tokens[id] = token
    state.timers[#state.timers + 1] = { at = state.tick + (MOTION_TICKS[motion] or 20), fn = function()
        if state.motion_tokens[id] == token then
            aris.game.geckolib.emote.trigger_emote(player, "")
        end
    end }
end

for i = 1, 8 do
    VFX_SELECTOR_EXCLUDE = VFX_SELECTOR_EXCLUDE .. ",type=!aris:evasive_shot_" .. tostring(i)
    VFX_SELECTOR_EXCLUDE = VFX_SELECTOR_EXCLUDE .. ",type=!aris:quick_dash_vfx_" .. tostring(i)
end

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

AWAKENED_HUD.register_class("archer", is_galebow, state.cooldowns, HUD_SKILLS, function()
    return state.tick
end)

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

local function send_cooldown_message(entity, name, remaining_ticks)
    entity:send_message_text("§6[스킬] §c" .. name .. " 쿨타임: " .. string.format("%.1f", remaining_ticks / TICKS_PER_SECOND) .. "초 남음")
end

local function can_cast(entity, name, cooldown_ticks)
    local key = cooldown_key(entity, name)
    local until_tick = state.cooldowns[key] or 0
    if until_tick > state.tick then
        send_cooldown_message(entity, name, until_tick - state.tick)
        return false
    end
    state.cooldowns[key] = state.tick + cooldown_ticks
    AWAKENED_HUD.sync_skill(entity, "archer")
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
    aris.game.dispatch_command("summon aris:" .. key .. " " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " {Tags:[\"aa_vfx\",\"" .. tag .. "\"],Rotation:[" .. tostring(ry) .. "f," .. tostring(rp) .. "f]}")
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

local function is_vfx_entity(entity)
    local entity_type = entity:get_type() or ""
    if entity_type == "minecraft:armor_stand" or entity_type == "minecraft:item_display" or entity_type == "minecraft:block_display" or entity_type == "minecraft:text_display" then
        return true
    end
    return string.find(entity_type, "aris:vfx_", 1, true) ~= nil
        or string.find(entity_type, "aris:evasive_shot_", 1, true) ~= nil
        or string.find(entity_type, "aris:quick_dash_vfx_", 1, true) ~= nil
        or entity_type == "aris:piercing_skyfall"
end

local function hit_projectile_targets(projectile)
    local radius = tonumber(projectile.radius) or 0.7
    local radius_sq = radius * radius
    local limit = tonumber(projectile.pierce) or 1
    local hit_count = 0
    local search_radius = projectile.speed * projectile.age + radius + 2

    projectile.hit_uuids = projectile.hit_uuids or {}
    projectile.caster:iter_entities_nearby(function(target)
        if hit_count >= limit or target == nil or is_vfx_entity(target) then
            return
        end

        local target_id = target:get_uuid()
        if projectile.hit_uuids[target_id] then
            return
        end

        local sx = projectile.prev_x or projectile.x
        local sy = projectile.prev_y or projectile.y
        local sz = projectile.prev_z or projectile.z
        local vx = projectile.x - sx
        local vy = projectile.y - sy
        local vz = projectile.z - sz
        local wx = target:get_x() - sx
        local wy = (target:get_y() + 1.0) - sy
        local wz = target:get_z() - sz
        local vv = (vx * vx) + (vy * vy) + (vz * vz)
        local t = 0
        if vv > 0 then
            t = ((wx * vx) + (wy * vy) + (wz * vz)) / vv
            if t < 0 then
                t = 0
            elseif t > 1 then
                t = 1
            end
        end

        local cx = sx + (vx * t)
        local cy = sy + (vy * t)
        local cz = sz + (vz * t)
        local dx = target:get_x() - cx
        local dy = (target:get_y() + 1.0) - cy
        local dz = target:get_z() - cz
        if (dx * dx + dy * dy + dz * dz) > radius_sq then
            return
        end

        if apply_hit(projectile.caster, target, projectile.damage, projectile.first_hit_multiplier, projectile.knock_y) then
            projectile.hit_uuids[target_id] = true
            hit_count = hit_count + 1
        end
    end, search_radius, false)

    return hit_count
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
    local vfx = spawn_vfx(caster:get_server_world(), model, x, y, z, anim, opts.life or 40, yaw, pitch)
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
        hit_uuids = {},
    }
end

local function update_projectiles()
    local remaining = {}
    for _, p in ipairs(state.projectiles) do
        p.age = p.age + 1
        p.prev_x = p.x
        p.prev_y = p.y
        p.prev_z = p.z
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

        local hit_count = hit_projectile_targets(p)

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
    play_player_motion(player, "ambush")
    add_aura(player, "Ambush", SKILL.ambush_duration, 1, 1)
    particle(player, "dust_color_transition 0.89 1.0 0.52 0.7 0.29 0.72 0.0 1", 20, 0.4, 0.2, 0.4, 0)
end

local function shoot_arrow(player, damage, model, anim, h_offset, radius, pierce, max_ticks)
    spawn_vfx_at_player(player, "vfx_awakened_arrow_impact", 1.3, 1.6, "impact", 9)
    spawn_projectile(player, model or "vfx_awakened_arrow", anim or "shoot", damage, {
        h_offset = h_offset or 0,
        radius = radius or 0.7,
        pierce = pierce or 1,
        max_ticks = max_ticks or 35,
        speed = SKILL.arrow_speed,
    })
    sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_arrow_shoot", 0.7, 1)
end

local function cast_blasting_combo(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Blasting_Combo", SKILL.blasting_cooldown) then
        return
    end

    local stacks = aura_stacks(player, "Blasting_Combo_Stack")
    if stacks < SKILL.blasting_max_stack then
        play_player_motion(player, "c" .. tostring(stacks + 1))
        add_aura(player, "Blasting_Combo_Stack", SKILL.blasting_stack_duration, 1, SKILL.blasting_max_stack)
        spawn_frame_sequence(player, "quick_dash_vfx_", "back_roll", 8, 2, 0.5, 0)
        player:add_velocity_relative(-0.8, -0.05, 0)
        sound(player, "universal_sounds:samus.universal.move", 0.7, 1)
        after(4, function()
            shoot_arrow(player, SKILL.blasting_damage, "vfx_awakened_arrow", "shoot", 0, SKILL.arrow_radius, SKILL.arrow_pierce, SKILL.arrow_ticks)
        end)
        return
    end

    remove_aura(player, "Blasting_Combo_Stack")
    play_player_motion(player, "c4")
    add_aura(player, "CASTING", SKILL.blasting_charge_casting, 1, 1)
    player:add_velocity_relative(-0.5, 0.4, 0)
    spawn_frame_sequence(player, "quick_dash_vfx_", "jump", 8, 2, 0.5, 0)
    sound(player, "awakened_archer_sounds:samus.awakened_archer.move", 0.7, 0.75)
    after(5, function()
        spawn_vfx_at_player(player, "vfx_shot_charging", 1.5, 0.8, "charging_and_shoot", 20)
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_charge", 0.7, 1)
    end)
    after(SKILL.blasting_charge_delay, function()
        spawn_projectile(player, "vfx_awakened_arrow", "shoot_shaking", SKILL.blasting_damage * SKILL.blasting_charge_multiplier, {
            radius = SKILL.blasting_charge_radius,
            pierce = SKILL.arrow_pierce,
            max_ticks = SKILL.arrow_ticks,
            knock_y = 1.2,
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
    if has_aura(player, "CASTING") or not can_cast(player, "Evasive_Shot", SKILL.evasive_cooldown) then
        return
    end
    play_player_motion(player, "evasive_shot")
    add_aura(player, "CASTING", SKILL.evasive_casting, 1, 1)
    spawn_frame_sequence(player, "evasive_shot_", "back_roll", 8, 2, 0.5, 0)
    player:add_velocity_relative(-1.4, 0.3, 0)
    sound(player, "universal_sounds:samus.universal.move", 0.7, 1)

    every(4, SKILL.evasive_shot_count, SKILL.evasive_shot_interval, function()
        spawn_vfx_at_player(player, "evasive_shot_arrows", 1.3, 1.6, "evasive_shot", 35)
        shoot_arrow(player, SKILL.evasive_damage, "vfx_awakened_arrow", "shoot", math.random(1, 3), SKILL.evasive_arrow_radius, SKILL.arrow_pierce, SKILL.arrow_ticks)
        shoot_arrow(player, SKILL.evasive_damage, "vfx_awakened_arrow", "shoot", -math.random(1, 3), SKILL.evasive_arrow_radius, SKILL.arrow_pierce, SKILL.arrow_ticks)
    end)
    after(19, function()
        player:add_velocity_relative(-0.4, -1, 0)
    end)
end

local function cast_volley_of_arrows(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Volley_Of_Arrows", SKILL.volley_cooldown) then
        return
    end
    play_player_motion(player, "volley_of_arrow1")
    add_aura(player, "CASTING", SKILL.volley_casting, 1, 1)
    spawn_vfx_at_player(player, "vfx_volley_of_arrow", 1.0, 0, "animation3", 24)
    sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_rapid_fire", 0.7, 1)
    after(SKILL.volley_first_delay, function()
        for i = 1, SKILL.volley_first_count do
            spawn_projectile(player, "vfx_awakened_arrow", "shoot", SKILL.volley_damage, {
                h_offset = -25 + (i * 5),
                radius = SKILL.piercing_radius,
                max_ticks = 8,
                pierce = 1,
            })
        end
    end)
    after(SKILL.volley_second_delay, function()
        spawn_vfx_at_player(player, "vfx_volley_of_arrow", 1.0, -1.5, "animation2", 11)
        for _, h in ipairs({ 0, 40, -40, 20, -20 }) do
            spawn_projectile(player, "vfx_awakened_arrow", "shoot", SKILL.volley_damage * SKILL.volley_second_multiplier, {
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
    if has_aura(player, "CASTING") or not can_cast(player, "Piercing_Skyfall", SKILL.piercing_cooldown) then
        return
    end
    play_player_motion(player, "piercing_skyfall")
    add_aura(player, "CASTING", SKILL.piercing_casting, 1, 1)
    spawn_vfx_at_player(player, "piercing_skyfall", 1.0, 0, "firing_multiple_arrows", 20)
    sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_arrow_shoot", 0.7, 1)
    after(SKILL.piercing_delay, function()
        for i = 1, SKILL.piercing_count do
            local h = math.random(-35, 35)
            spawn_projectile(player, "piercing_skyfall", "arrow_rain_" .. tostring(math.random(1, 10)), SKILL.piercing_damage, {
                h_offset = h,
                radius = SKILL.piercing_radius,
                max_ticks = SKILL.piercing_ticks,
                pierce = SKILL.piercing_pierce,
            })
        end
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_arrow_shoot_whoosh", 0.7, 1)
    end)
end

local function cast_rapid_arrows(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Rapid_Arrows", SKILL.rapid_cooldown) then
        return
    end
    play_player_motion(player, "rapid_arrows1")
    add_aura(player, "CASTING", SKILL.rapid_casting, 1, 1)
    every(0, SKILL.rapid_first_count, SKILL.rapid_first_interval, function()
        player:add_velocity_relative(-0.1, -0.01, 0)
        shoot_arrow(player, SKILL.rapid_damage, "vfx_awakened_arrow", "shoot", 0, SKILL.arrow_radius, SKILL.arrow_pierce, SKILL.arrow_ticks)
    end)
    after(12, function()
        particle(player, "dust_color_transition 1.0 0.73 0.23 0.65 0.66 0.02 0.0 1", 120, 2, 2, 2, 0)
    end)
    every(SKILL.rapid_second_delay, SKILL.rapid_second_count, SKILL.rapid_second_interval, function()
        player:add_velocity_relative(-0.65, -0.01, 0)
        spawn_projectile(player, "vfx_awakened_arrow", "shoot2", SKILL.rapid_damage * SKILL.rapid_second_multiplier, {
            radius = SKILL.arrow_radius,
            pierce = SKILL.rapid_second_pierce,
            max_ticks = SKILL.arrow_ticks,
        })
        sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_rapid_fire", 0.7, 1)
    end)
end

local function cast_shot_of_destruction(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Shot_Of_Destruction", SKILL.destruction_cooldown) then
        return
    end
    play_player_motion(player, "shot_of_destruction")
    add_aura(player, "CASTING", SKILL.destruction_casting, 1, 1)
    spawn_vfx_at_player(player, "vfx_shot_of_destruction", 1.3, 0, "chrage", 41)
    sound(player, "awakened_archer_sounds:samus.awakened_archer.awakened_archer_charge", 0.7, 0.7)
    after(SKILL.destruction_shoot_delay, function()
        player:add_velocity_relative(-1.5, -0.01, 0)
        spawn_projectile(player, "vfx_shot_of_destruction", "arrow_destruction", SKILL.destruction_damage * SKILL.destruction_cooldown_damage_multiplier, {
            radius = SKILL.destruction_radius,
            pierce = SKILL.destruction_pierce,
            max_ticks = SKILL.arrow_ticks,
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

    if state.tick % 5 == 0 then
        AWAKENED_HUD.poll_weapons()
    end

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
