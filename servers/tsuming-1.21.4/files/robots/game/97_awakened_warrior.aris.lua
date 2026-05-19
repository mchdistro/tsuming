depends_on("10_awakened_hud_shared.aris")

local DEG_TO_RAD = math.pi / 180

local state = {
    tick = 0,
    timers = {},
    auras = {},
    cooldowns = {},
    players = {},
    projectiles = {},
    next_vfx_id = 0,
    motion_tokens = {},
}

local SKILL = {
    item_name = "Brutesword",
    material = "STONE_SWORD",
    custom_model_data = 2086,
    brutal_damage = 4,
    leap_damage = 4,
    whirlwind_damage = 4,
    barrier_damage = 4,
    vicious_damage = 6,
    fury_damage = 8,
    brutal_cooldown = 6,
    leap_cooldown = 40,
    whirlwind_cooldown = 60,
    barrier_cooldown = 180,
    vicious_cooldown = 60,
    fury_cooldown = 140,
    brutal_combo_stack_duration = 300,
    brutal_combo_max_stack = 4,
    brutal_hit_limit = 6,
    brutal_hit_radius = 3,
    brutal_final_radius = 3,
    brutal_final_delay = 8,
    leap_casting_duration = 15,
    leap_hit_radius = 2.5,
    leap_hit_limit = 6,
    leap_landing_delay = 24,
    whirlwind_casting_duration = 40,
    whirlwind_tick_count = 25,
    whirlwind_hit_radius = 5.5,
    whirlwind_hit_limit = 8,
    barrier_duration = 160,
    vicious_casting_duration = 25,
    vicious_charge_duration = 25,
    vicious_projectile_radius = 2.5,
    vicious_projectile_pierce = 9,
    vicious_projectile_ticks = 9,
    vicious_projectile_speed = 1.6,
    vicious_projectile_life = 20,
    fury_casting_duration = 110,
    fury_slash_start_delay = 40,
    fury_slash_count = 4,
    fury_slash_interval = 5,
    fury_hit_radius = 4,
    fury_hit_limit = 10,
    fury_stomp_delay = 85,
    fury_stomp_radius = 5,
    fury_final_radius = 7,
    fury_final_multiplier = 2,
    bulwark_duration = 100,
    bulwark_particle_count = 50,
}

local HUD_SKILLS = {
    { id = "brutal_combo", key = "cooldown_Brutal_Combo", cooldown = SKILL.brutal_cooldown },
    { id = "berserkers_leap", key = "cooldown_Berserkers_Leap", cooldown = SKILL.leap_cooldown },
    { id = "strike_of_fury", key = "cooldown_Strike_Of_Fury", cooldown = SKILL.fury_cooldown },
    { id = "vicious_strike", key = "cooldown_Vicious_Strike", cooldown = SKILL.vicious_cooldown },
    { id = "relentless_whirlwind", key = "cooldown_Relentless_Whirlwind", cooldown = SKILL.whirlwind_cooldown },
    { id = "bloodbound_barrier", key = "cooldown_Bloodbound_Barrier", cooldown = SKILL.barrier_cooldown },
}

local VFX_NBT = "Invulnerable:1b,NoAI:1b,Silent:1b,NoGravity:1b,PersistenceRequired:0b,DeathLootTable:\"minecraft:empty\",CanPickUpLoot:0b,Health:1000000f,attributes:[{id:\"minecraft:max_health\",base:1000000d},{id:\"minecraft:armor\",base:1000000d}],Attributes:[{Name:\"minecraft:generic.max_health\",Base:1000000d},{Name:\"minecraft:generic.armor\",Base:1000000d}]"
local VFX_SELECTOR_EXCLUDE = ",tag=!aw_warrior_caster,tag=!aa_vfx,type=!aris:bloodbound_barrier,type=!aris:vicious_strike_charge,type=!aris:vfx_earthquake_rupture_1,type=!aris:vfx_earthquake_rupture_2,type=!aris:vfx_earthquake_rupture_3,type=!aris:vfx_earthquake_rupture_4,type=!aris:vfx_earthquake_rupture_5,type=!aris:vfx_rubbles"

local MOTION_TICKS = {
    bulwark_instinct = 30,
    c1 = 13,
    c2 = 13,
    c3 = 13,
    c4 = 19,
    c5 = 20,
    berserker_leap = 40,
    relentless_whirlwind_spin = 5,
    bloodbound_barrier = 16,
    vicious_strike = 95,
    strike_of_fury_1 = 58,
}

local function play_player_motion(player, motion)
    aris.game.geckolib.emote.set_emote_file(player, "boss_warrior")
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

for i = 1, 13 do
    VFX_SELECTOR_EXCLUDE = VFX_SELECTOR_EXCLUDE .. ",type=!aris:berserker_leap_" .. tostring(i)
    VFX_SELECTOR_EXCLUDE = VFX_SELECTOR_EXCLUDE .. ",type=!aris:strike_of_fury_" .. tostring(i)
    VFX_SELECTOR_EXCLUDE = VFX_SELECTOR_EXCLUDE .. ",type=!aris:vicious_strike_" .. tostring(i)
end

for i = 1, 8 do
    VFX_SELECTOR_EXCLUDE = VFX_SELECTOR_EXCLUDE .. ",type=!aris:brutal_combo_" .. tostring(i)
    VFX_SELECTOR_EXCLUDE = VFX_SELECTOR_EXCLUDE .. ",type=!aris:relentless_whirlwind_" .. tostring(i)
end

local function uuid(entity)
    return entity:get_uuid()
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

local function send_cooldown_message(entity, name, remaining_ticks)
    entity:send_message_text("§6[스킬] §c" .. name .. " 쿨타임: " .. string.format("%.1f", remaining_ticks / 20) .. "초 남음")
end

local function can_cast(entity, name, cooldown_ticks)
    local key = aura_key(entity, "cooldown_" .. name)
    local until_tick = state.cooldowns[key] or 0
    if until_tick > state.tick then
        send_cooldown_message(entity, name, until_tick - state.tick)
        return false
    end
    state.cooldowns[key] = state.tick + cooldown_ticks
    AWAKENED_HUD.sync_skill(entity, "warrior")
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

local function yaw_vector(yaw, horizontal_offset_degrees)
    local angle = (yaw + (horizontal_offset_degrees or 0)) * DEG_TO_RAD
    return -math.sin(angle), math.cos(angle)
end

local function forward_position(entity, forward_offset, y_offset, horizontal_offset_degrees)
    local yaw = entity:get_yaw() + (horizontal_offset_degrees or 0)
    local dx, dz = yaw_vector(yaw, 0)
    return entity:get_x() + dx * (forward_offset or 0), entity:get_y() + (y_offset or 0), entity:get_z() + dz * (forward_offset or 0), yaw
end

local function run_command_at(entity, command)
    aris.game.dispatch_command("execute positioned " .. tostring(entity:get_x()) .. " " .. tostring(entity:get_y()) .. " " .. tostring(entity:get_z()) .. " run " .. command)
end

local function command_as_player(player, command)
    aris.game.dispatch_command("execute positioned " .. tostring(player:get_x()) .. " " .. tostring(player:get_y()) .. " " .. tostring(player:get_z()) .. " as @p[distance=..1,limit=1,sort=nearest] run " .. command)
end

local function prevent_fall_damage(player, seconds)
    command_as_player(player, "effect give @s minecraft:resistance " .. tostring(seconds or 4) .. " 255 true")
    every(0, (seconds or 4) * 20, 1, function()
        command_as_player(player, "data merge entity @s {FallDistance:0f}")
    end)
end

local function sound(entity, id, volume, pitch)
    run_command_at(entity, "playsound " .. id .. " master @a[distance=..32] ~ ~ ~ " .. tostring(volume or 0.7) .. " " .. tostring(pitch or 1))
end

local function particle(entity, id, amount, dx, dy, dz, speed)
    run_command_at(entity, "particle " .. id .. " ~ ~1 ~ " .. tostring(dx or 0.3) .. " " .. tostring(dy or 0.3) .. " " .. tostring(dz or 0.3) .. " " .. tostring(speed or 0) .. " " .. tostring(amount or 10))
end

local function is_brutesword(player)
    local item = player:get_main_hand_item()
    if item == nil then
        return false
    end
    local name = item:get_display_name() or item:get_name() or ""
    return string.find(name, SKILL.item_name, 1, true) ~= nil
end

AWAKENED_HUD.register_class("warrior", is_brutesword, state.cooldowns, HUD_SKILLS, function()
    return state.tick
end)

local function is_entity_object(entity)
    local kind = type(entity)
    return entity ~= nil and kind ~= "number" and kind ~= "boolean" and kind ~= "string"
end

local function trigger_entity_anim(entity, anim)
    if not is_entity_object(entity) or anim == nil then
        return
    end
    local anim_entity = aris.game.geckolib.into_anim_entity(entity)
    if anim_entity ~= nil then
        anim_entity:trigger_anim(anim)
    end
end

local function remove_tagged_vfx(tag)
    aris.game.dispatch_command("tp @e[tag=" .. tag .. "] 0 -10000 0")
end

local function move_tagged_vfx(tag, x, y, z, yaw, pitch)
    aris.game.dispatch_command("tp @e[tag=" .. tag .. ",limit=1] " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " " .. tostring(yaw or 0) .. " " .. tostring(pitch or 0))
end

local function kill_later(entity, tag, delay)
    if entity == nil and tag == nil then
        return
    end
    after(delay, function()
        if is_entity_object(entity) then
            entity:remove()
        end
        if tag ~= nil then
            remove_tagged_vfx(tag)
        end
    end)
end

local function spawn_vfx(world, key, x, y, z, anim, life, yaw, pitch)
    state.next_vfx_id = state.next_vfx_id + 1
    local tag = "aw_vfx_" .. tostring(state.next_vfx_id)
    local ry = yaw or 0
    local rp = pitch or 0
    local nbt = aris.game.nbt.from_string("{id:\"aris:" .. key .. "\",Pos:[" .. tostring(x) .. "d," .. tostring(y) .. "d," .. tostring(z) .. "d],Rotation:[" .. tostring(ry) .. "f," .. tostring(rp) .. "f],Tags:[\"aa_vfx\",\"" .. tag .. "\"]," .. VFX_NBT .. "}")
    local entity = nbt:spawn_entity(world)
    if not is_entity_object(entity) then
        return nil
    end
    move_tagged_vfx(tag, x, y, z, ry, rp)
    trigger_entity_anim(entity, anim)
    if life ~= nil then
        kill_later(entity, tag, life)
    end
    return entity
end

local function spawn_vfx_at_player(player, key, y_offset, forward_offset, anim, life, yaw_offset)
    local yaw = player:get_yaw() + (yaw_offset or 0)
    local dx, dz = yaw_vector(yaw, 0)
    return spawn_vfx(player:get_server_world(), key, player:get_x() + dx * (forward_offset or 0), player:get_y() + (y_offset or 0), player:get_z() + dz * (forward_offset or 0), anim, life, yaw, 0)
end

local function spawn_frame_sequence(player, prefix, first_frame, last_frame, anim, y_offset, forward_offset, first_life, frame_life, frame_start_delay, frame_interval)
    spawn_vfx_at_player(player, prefix .. tostring(first_frame), y_offset, forward_offset, anim, first_life or 12)
    local delay = frame_start_delay or 1
    local interval = frame_interval or 1
    for frame = first_frame + 1, last_frame do
        after(delay + ((frame - first_frame - 1) * interval), function()
            spawn_vfx_at_player(player, prefix .. tostring(frame), y_offset, forward_offset, anim, frame_life or 2)
        end)
    end
end

local function mark_caster(player)
    command_as_player(player, "tag @s add aw_warrior_caster")
end

local function unmark_caster(player)
    command_as_player(player, "tag @s remove aw_warrior_caster")
end

local function damage_near(caster, x, y, z, radius, limit, damage)
    local selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as " .. selector .. " at @s run "
    mark_caster(caster)
    aris.game.dispatch_command(base .. "damage @s " .. tostring(damage))
    unmark_caster(caster)
    aris.game.dispatch_command("particle minecraft:sweep_attack " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " 0.1 0.1 0.1 0 1")
    aris.game.dispatch_command("particle minecraft:crit " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " 0.25 0.25 0.25 0.05 8")
end

local function lift_near(caster, x, y, z, radius, limit)
    local selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as " .. selector .. " at @s run "
    mark_caster(caster)
    aris.game.dispatch_command(base .. "effect give @s minecraft:levitation 1 3 true")
    unmark_caster(caster)
end

local function skill_damage(player, x, y, z, radius, limit, damage)
    damage_near(player, x, y, z, radius, limit, damage)
    sound(player, "item.mace.smash_air", 1, 1.3)
end

local function skill_damage_forward(player, forward_offset, y_offset, radius, limit, damage)
    local x, y, z = forward_position(player, forward_offset or 1.6, y_offset or 1, 0)
    skill_damage(player, x, y, z, radius, limit, damage)
end

local function lift_forward(player, forward_offset, y_offset, radius, limit)
    local x, y, z = forward_position(player, forward_offset or 1.3, y_offset or 1, 0)
    lift_near(player, x, y, z, radius, limit)
end

local function spawn_projectile(caster, model, anim, damage, opts)
    opts = opts or {}
    local yaw = caster:get_yaw() + (opts.h_offset or 0)
    local dx, dz = yaw_vector(yaw, 0)
    local x = caster:get_x() + dx * (opts.start_forward or 1)
    local y = caster:get_y() + 1.2 + (opts.start_y or 0)
    local z = caster:get_z() + dz * (opts.start_forward or 1)
    local vfx = spawn_vfx(caster:get_server_world(), model, x, y, z, anim, opts.life or 30, yaw, 0)
    state.projectiles[#state.projectiles + 1] = {
        caster = caster,
        entity = vfx,
        x = x,
        y = y,
        z = z,
        dx = dx,
        dz = dz,
        yaw = yaw,
        speed = opts.speed or 1.6,
        radius = opts.radius or 2,
        damage = damage,
        pierce = opts.pierce or 6,
        max_ticks = opts.max_ticks or 10,
        age = 0,
        on_end = opts.on_end,
    }
end

local function update_projectiles()
    local remaining = {}
    for _, p in ipairs(state.projectiles) do
        p.age = p.age + 1
        p.x = p.x + p.dx * p.speed
        p.z = p.z + p.dz * p.speed
        if is_entity_object(p.entity) then
            p.entity:move_to(p.x, p.y, p.z)
        end
        damage_near(p.caster, p.x, p.y, p.z, p.radius, p.pierce, p.damage)
        if p.age >= p.max_ticks then
            if p.on_end ~= nil then
                p.on_end(p)
            end
            if is_entity_object(p.entity) then
                p.entity:remove()
            end
        else
            remaining[#remaining + 1] = p
        end
    end
    state.projectiles = remaining
end

local function player_state(player)
    local id = player:get_uuid()
    local current = state.players[id]
    if current == nil then
        current = {
            player = player,
            sneak_down = false,
            sneak_click_until = 0,
            next_barrier_timer = 0,
        }
        state.players[id] = current
    else
        current.player = player
    end
    return current
end

local function cast_brutal_combo(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Brutal_Combo", SKILL.brutal_cooldown) then
        return
    end

    local stacks = aura_stacks(player, "Brutal_Combo_Stack")
    if stacks == 0 then
        play_player_motion(player, "c1")
        add_aura(player, "Brutal_Combo_Stack", SKILL.brutal_combo_stack_duration, 1, SKILL.brutal_combo_max_stack)
        spawn_frame_sequence(player, "brutal_combo_", 1, 8, "slash_left_diag", 1.4, 1.3, 4, 1, 1, 1)
        skill_damage_forward(player, 1.6, 1, SKILL.brutal_hit_radius, SKILL.brutal_hit_limit, SKILL.brutal_damage)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_slash", 0.7, 1)
    elseif stacks == 1 then
        play_player_motion(player, "c2")
        add_aura(player, "Brutal_Combo_Stack", SKILL.brutal_combo_stack_duration, 1, SKILL.brutal_combo_max_stack)
        spawn_frame_sequence(player, "brutal_combo_", 1, 8, "slash_right_diag", 1.4, 1.3, 4, 1, 1, 1)
        skill_damage_forward(player, 1.6, 1, SKILL.brutal_hit_radius, SKILL.brutal_hit_limit, SKILL.brutal_damage)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_slash", 0.7, 1)
    elseif stacks == 2 then
        play_player_motion(player, "c3")
        add_aura(player, "Brutal_Combo_Stack", SKILL.brutal_combo_stack_duration, 1, SKILL.brutal_combo_max_stack)
        player:add_velocity_relative(0, -0.05, 0)
        spawn_frame_sequence(player, "brutal_combo_", 1, 8, "pierce", 1.4, 1.3, 4, 1, 1, 1)
        skill_damage_forward(player, 2.1, 1, 2.6, SKILL.brutal_hit_limit, SKILL.brutal_damage)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_pierce", 0.7, 1)
    elseif stacks == 3 then
        play_player_motion(player, "c4")
        add_aura(player, "Brutal_Combo_Stack", SKILL.brutal_combo_stack_duration, 1, SKILL.brutal_combo_max_stack)
        prevent_fall_damage(player, 3)
        player:add_velocity_relative(0, 0.7, 0)
        spawn_frame_sequence(player, "brutal_combo_", 1, 8, "spin", 2.4, 1.3, 5, 1, 1, 1)
        after(6, function()
            spawn_frame_sequence(player, "brutal_combo_", 1, 8, "spin", 2.4, 1.3, 5, 1, 1, 1)
            skill_damage_forward(player, 1.3, 1.2, 3.2, SKILL.brutal_hit_limit, SKILL.brutal_damage)
            lift_forward(player, 1.3, 1.2, 3.2, SKILL.brutal_hit_limit)
        end)
        after(12, function()
            player:add_velocity_relative(0, -1.1, 0)
        end)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_wheel_spin", 0.7, 1)
    else
        play_player_motion(player, "c5")
        remove_aura(player, "Brutal_Combo_Stack")
        prevent_fall_damage(player, 4)
        player:add_velocity_relative(0, -1.5, 0)
        after(3, function()
            spawn_frame_sequence(player, "brutal_combo_", 1, 8, "strike", 1.4, 1.3, 7, 1, 1, 1)
        end)
        after(6, function()
            sound(player, "awakened_warrior_sounds:samus.awakened_warrior.rupture_quick", 0.7, 0.85)
        end)
        after(SKILL.brutal_final_delay, function()
            local x, y, z, yaw = forward_position(player, 2, 0.05, 0)
            spawn_vfx(player:get_server_world(), "vfx_earthquake_rupture_1", x, y, z, "skill", 24, yaw, 0)
            spawn_vfx(player:get_server_world(), "vfx_rubbles", x, y, z, "skill", 30, yaw, 0)
            skill_damage(player, x, y, z, SKILL.brutal_final_radius, SKILL.brutal_hit_limit, SKILL.brutal_damage)
        end)
    end
end

local function cast_berserkers_leap(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Berserkers_Leap", SKILL.leap_cooldown) then
        return
    end
    play_player_motion(player, "berserker_leap")
    add_aura(player, "CASTING", SKILL.leap_casting_duration, 1, 1)
    prevent_fall_damage(player, 5)
    spawn_frame_sequence(player, "berserker_leap_", 1, 13, "animation", 0.1, 0.7, 14, 2, 1, 1)
    spawn_frame_sequence(player, "brutal_combo_", 1, 8, "slash_up", 1.4, 0, 10, 2, 1, 1)
    skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.leap_hit_radius, SKILL.leap_hit_limit, SKILL.leap_damage)
    sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_slash", 0.7, 1)
    after(10, function()
        player:add_velocity_relative(1.4, 1, 0)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.move", 0.7, 1)
    end)
    after(18, function()
        player:add_velocity_relative(0.4, -1.5, 0)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_airdash", 0.7, 1)
    end)
    after(SKILL.leap_landing_delay, function()
        local x, y, z, yaw = forward_position(player, 2, 0.05, 0)
        spawn_frame_sequence(player, "brutal_combo_", 1, 8, "strike", 1.4, 0.2, 10, 2, 1, 1)
        spawn_vfx(player:get_server_world(), "vfx_earthquake_rupture_1", x, y, z, "skill2", 52, yaw, 0)
        spawn_vfx(player:get_server_world(), "vfx_rubbles", x, y, z, "skill2", 45, yaw, 0)
        skill_damage(player, x, y + 1, z, SKILL.brutal_final_radius, SKILL.leap_hit_limit, SKILL.leap_damage)
    end)
end

local function cast_relentless_whirlwind(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Relentless_Whirlwind", SKILL.whirlwind_cooldown) then
        return
    end
    play_player_motion(player, "relentless_whirlwind_spin")
    add_aura(player, "CASTING", SKILL.whirlwind_casting_duration, 1, 1)
    prevent_fall_damage(player, 4)
    every(0, SKILL.whirlwind_tick_count, 1, function()
        player:add_velocity_relative(0.25, 0, 0)
    end)
    every(0, 5, 7, function()
        spawn_frame_sequence(player, "relentless_whirlwind_", 1, 8, "spin", 2.6, 0, 10, 2, 1, 1)
        skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.whirlwind_hit_radius, SKILL.whirlwind_hit_limit, SKILL.whirlwind_damage)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_wheel_spin", 0.7, 1)
    end)
    after(32, function()
        player:add_velocity_relative(-1.15, -0.05, 0)
        spawn_frame_sequence(player, "relentless_whirlwind_", 1, 8, "back_step", 1.2, 0, 10, 2, 1, 1)
    end)
    after(39, function()
        player:add_velocity_relative(0.7, -0.05, 0)
        spawn_frame_sequence(player, "relentless_whirlwind_", 1, 8, "dash_pierce", 2.4, 0.5, 10, 2, 1, 1)
        skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.brutal_final_radius, SKILL.whirlwind_hit_limit, SKILL.whirlwind_damage)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_pierce", 0.7, 0.8)
    end)
    after(44, function()
        player:add_velocity_relative(0.5, -0.05, 0)
        spawn_frame_sequence(player, "relentless_whirlwind_", 1, 8, "dash_pierce", 2.4, 0.5, 10, 2, 1, 1)
        skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.brutal_final_radius, SKILL.whirlwind_hit_limit, SKILL.whirlwind_damage)
    end)
end

local function cast_bloodbound_barrier(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Bloodbound_Barrier", SKILL.barrier_cooldown) then
        return
    end
    play_player_motion(player, "bloodbound_barrier")
    add_aura(player, "Bloodbound_Barrier", SKILL.barrier_duration, 1, 1)
    add_aura(player, "Bloodbound_Barrier_Reset", SKILL.barrier_duration, 0, 5)
    spawn_vfx_at_player(player, "bloodbound_barrier", 1.3, 0, "idle_bloodbound_barrier", SKILL.barrier_duration)
    sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_airdash", 0.7, 0.5)
end

local function cast_vicious_strike(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Vicious_Strike", SKILL.vicious_cooldown) then
        return
    end
    play_player_motion(player, "vicious_strike")
    add_aura(player, "CASTING", SKILL.vicious_casting_duration, 1, 1)
    spawn_vfx_at_player(player, "vicious_strike_charge", 2.4, 0, "charge", SKILL.vicious_charge_duration)
    sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_stomp_charge", 0.7, 1)
    after(SKILL.vicious_charge_duration, function()
        spawn_frame_sequence(player, "vicious_strike_", 1, 13, "animation", 0.1, 0.7, 14, 2, 1, 1)
        spawn_frame_sequence(player, "brutal_combo_", 1, 8, "slash_up2", 1.4, 0, 10, 2, 1, 1)
        spawn_projectile(player, "vicious_strike_1", "animation", SKILL.vicious_damage, { radius = SKILL.vicious_projectile_radius, pierce = SKILL.vicious_projectile_pierce, max_ticks = SKILL.vicious_projectile_ticks, speed = SKILL.vicious_projectile_speed, life = SKILL.vicious_projectile_life })
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_stomp", 0.7, 1)
    end)
end

local function cast_strike_of_fury(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Strike_Of_Fury", SKILL.fury_cooldown) then
        return
    end
    play_player_motion(player, "strike_of_fury_1")
    add_aura(player, "CASTING", SKILL.fury_casting_duration, 1, 1)
    prevent_fall_damage(player, 7)
    spawn_frame_sequence(player, "strike_of_fury_", 1, 13, "charge_sword", 2.4, 0, 100, 2, 1, 1)
    sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_charge", 0.8, 1)
    for i = 0, 9 do
        after(i, function()
            local radius = 0.5 + ((9 - i) * 0.5)
            particle(player, "dust_color_transition 1.0 0.37 0.0 0.78 0.01 0.0 0.55", 40 + ((9 - i) * 30), radius, 0.6, radius, 0)
        end)
    end
    every(SKILL.fury_slash_start_delay, SKILL.fury_slash_count, SKILL.fury_slash_interval, function(step)
        local anim = step % 2 == 1 and "sword_slash1" or "sword_slash2"
        spawn_frame_sequence(player, "strike_of_fury_", 1, 13, anim, 2.4, 0, 9, 2, 1, 1)
        skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.fury_hit_radius, SKILL.fury_hit_limit, SKILL.fury_damage)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_slash_ult", 0.7, 0.8 + (step * 0.08))
    end)
    after(65, function()
        prevent_fall_damage(player, 5)
        player:add_velocity_relative(1.4, 1.4, 0)
        spawn_frame_sequence(player, "strike_of_fury_", 1, 13, "sword_jump", 2.4, 0, 12, 2, 1, 1)
    end)
    after(SKILL.fury_stomp_delay, function()
        prevent_fall_damage(player, 5)
        player:add_velocity_relative(0.4, -2, 0)
        local x, y, z, yaw = forward_position(player, 0, 0.1, 0)
        spawn_vfx(player:get_server_world(), "strike_of_fury_1", x, y, z, "floor_crack", 66, yaw, 0)
        skill_damage(player, x, y + 1, z, SKILL.fury_stomp_radius, SKILL.fury_hit_limit, SKILL.fury_damage)
        after(20, function()
            skill_damage(player, x, y + 1, z, SKILL.fury_final_radius, SKILL.fury_hit_limit, SKILL.fury_damage * SKILL.fury_final_multiplier)
        end)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.ult_stomp", 0.7, 1)
    end)
    after(95, function()
        prevent_fall_damage(player, 6)
        player:add_velocity_relative(-1.6, 1.4, 0)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.move", 0.7, 0.75)
    end)
    after(107, function()
        prevent_fall_damage(player, 4)
        player:add_velocity_relative(-0.4, -2, 0)
        sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_airdash", 0.7, 1)
    end)
end

local function cast_bulwark_instinct(player)
    play_player_motion(player, "bulwark_instinct")
    add_aura(player, "Bulwark_Instinct", SKILL.bulwark_duration, 1, 1)
    sound(player, "awakened_warrior_sounds:samus.awakened_warrior.warrior_airdash", 0.7, 0.75)
    every(0, SKILL.bulwark_particle_count, 2, function()
        particle(player, "dust_color_transition 1.0 0.5 0.09 1.0 0.16 0.01 0.6", 20, 1.5, 0.2, 1.5, 0)
    end)
end

aris.game.hook.add_on_left_click(function(event)
    local player = event:get_player()
    if player == nil or not is_brutesword(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_strike_of_fury(player)
    else
        cast_brutal_combo(player)
    end
end)

aris.game.hook.add_on_right_click(function(event)
    local player = event:get_player()
    if player == nil or not is_brutesword(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_vicious_strike(player)
    else
        cast_berserkers_leap(player)
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
        if player == nil or not is_brutesword(player) then
            state.players[id] = nil
        else
            if state.tick >= ps.next_barrier_timer then
                ps.next_barrier_timer = state.tick + 200
                if player:get_is_sneaking() then
                    local stacks = aura_stacks(player, "Bloodbound_Barrier_STACK")
                    if stacks >= 2 then
                        remove_aura(player, "Bloodbound_Barrier_STACK")
                        cast_bloodbound_barrier(player)
                    else
                        add_aura(player, "Bloodbound_Barrier_STACK", 120, 1, 2)
                    end
                else
                    remove_aura(player, "Bloodbound_Barrier_STACK")
                end
            end

            local sneaking = player:get_is_sneaking()
            if sneaking and not ps.sneak_down and state.tick > ps.sneak_click_until then
                if has_aura(player, "Relentless_Whirlwind_aura") then
                    remove_aura(player, "Relentless_Whirlwind_aura")
                    cast_relentless_whirlwind(player)
                else
                    add_aura(player, "Relentless_Whirlwind_aura", 5, 1, 1)
                end
            end
            ps.sneak_down = sneaking
        end
    end

    task_sleep(50)
end
