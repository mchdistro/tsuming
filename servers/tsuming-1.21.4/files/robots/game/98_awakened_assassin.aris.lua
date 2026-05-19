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
    item_name = "Duskblade",
    lethal_damage = 3,
    ravaging_damage = 4,
    death_bloom_damage = 4,
    shadowquake_damage = 5,
    crimson_damage = 4,
    last_dance_damage = 2,
    lethal_cooldown = 4,
    ravaging_cooldown = 40,
    death_bloom_cooldown = 100,
    shadowquake_cooldown = 220,
    crimson_cooldown = 60,
    last_dance_cooldown = 240,
    deadly_calm_duration = 999999,
    lethal_stack_duration = 300,
    lethal_max_stack = 3,
    lethal_hit_radius = 3.5,
    lethal_hit_limit = 4,
    lethal_finisher_multiplier = 1.25,
    shadowquake_window = 20,
    ravaging_hit_radius = 3.5,
    ravaging_hit_limit = 4,
    ravaging_attack_count = 6,
    ravaging_attack_interval = 2,
    death_bloom_casting_duration = 40,
    death_bloom_start_delay = 20,
    death_bloom_hit_radius = 6,
    death_bloom_hit_limit = 6,
    death_bloom_cut_count = 8,
    death_bloom_cut_interval = 3,
    shadowquake_duration = 180,
    shadowquake_radius = 6,
    shadowquake_limit = 7,
    shadowquake_wave_radius = 1.2,
    shadowquake_wave_pierce = 4,
    shadowquake_wave_ticks = 18,
    shadowquake_wave_speed = 2.1,
    crimson_start_delay = 10,
    crimson_radius = 0.75,
    crimson_pierce = 4,
    crimson_ticks = 20,
    crimson_return_ticks = 12,
    crimson_speed = 2.0,
    crimson_life = 50,
    crimson_return_life = 30,
    last_dance_duration = 140,
    last_dance_blade_delay = 20,
    last_dance_dagger_count = 20,
    last_dance_dagger_interval = 3,
    last_dance_spin_delay = 80,
    last_dance_spin_radius = 5,
    last_dance_spin_limit = 7,
    last_dance_slash_delay = 95,
    last_dance_slash_count = 8,
    last_dance_slash_interval = 5,
    last_dance_final_delay = 135,
    last_dance_final_radius = 5,
    last_dance_final_limit = 10,
    last_dance_final_multiplier = 5,
}

local HUD_SKILLS = {
    { id = "lethal_combo", key = "cooldown_Lethal_Combo", cooldown = SKILL.lethal_cooldown },
    { id = "ravaging_dash", key = "cooldown_Ravaging_Dash", cooldown = SKILL.ravaging_cooldown },
    { id = "last_dance", key = "cooldown_Last_Dance", cooldown = SKILL.last_dance_cooldown },
    { id = "crimson_arc", key = "cooldown_Crimson_Arc", cooldown = SKILL.crimson_cooldown },
    { id = "death_bloom", key = "cooldown_Death_Bloom", cooldown = SKILL.death_bloom_cooldown },
    { id = "shadowquake", key = "cooldown_Shadowquake", cooldown = SKILL.shadowquake_cooldown },
}

local VFX_NBT = "Invulnerable:1b,NoAI:1b,Silent:1b,NoGravity:1b,PersistenceRequired:0b,DeathLootTable:\"minecraft:empty\",CanPickUpLoot:0b,Health:1000000f,attributes:[{id:\"minecraft:max_health\",base:1000000d},{id:\"minecraft:armor\",base:1000000d}],Attributes:[{Name:\"minecraft:generic.max_health\",Base:1000000d},{Name:\"minecraft:generic.armor\",Base:1000000d}]"
local VFX_SELECTOR_EXCLUDE = ",tag=!aa_vfx,type=!aris:vfx_dusk_cut,type=!aris:vfx_dusk_dagger,type=!aris:vfx_dusk_dagger_circle,type=!aris:vfx_dusk_dash,type=!aris:vfx_dusk_downslash,type=!aris:vfx_dusk_shockwave_slash,type=!aris:vfx_dusk_shuriken,type=!aris:vfx_dusk_spinning_blades,type=!aris:vfx_pulse,type=!aris:vfx_dusk_dash_impact_1,type=!aris:vfx_dusk_dash_impact_2,type=!aris:vfx_dusk_dash_impact_3,type=!aris:vfx_dusk_dash_impact_4,type=!aris:vfx_dusk_dash_impact_5,type=!aris:vfx_dusk_dash_impact_6,type=!aris:vfx_dusk_dash_impact_7,type=!aris:vfx_dusk_dash_impact_8,type=!aris:vfx_dusk_dash_impact_9,type=!aris:vfx_dusk_pierce_1,type=!aris:vfx_dusk_pierce_2,type=!aris:vfx_dusk_pierce_3,type=!aris:vfx_dusk_pierce_4,type=!aris:vfx_dusk_pierce_5,type=!aris:vfx_dusk_pierce_6,type=!aris:vfx_dusk_pierce_7,type=!aris:vfx_dusk_pierce_8,type=!aris:vfx_dusk_pierce_9,type=!aris:vfx_dusk_slash_1,type=!aris:vfx_dusk_slash_2,type=!aris:vfx_dusk_slash_3,type=!aris:vfx_dusk_slash_4,type=!aris:vfx_dusk_slash_5,type=!aris:vfx_dusk_slash_6,type=!aris:vfx_dusk_slash_7,type=!aris:vfx_dusk_spin_1,type=!aris:vfx_dusk_spin_2,type=!aris:vfx_dusk_spin_3,type=!aris:vfx_dusk_spin_4,type=!aris:vfx_dusk_spin_5,type=!aris:vfx_dusk_spin_6,type=!aris:vfx_dusk_spin_7,type=!aris:vfx_shadow_figure_1,type=!aris:vfx_shadow_figure_2,type=!aris:vfx_shadow_figure_3,type=!aris:vfx_shadow_figure_4,type=!aris:vfx_shadow_figure_5"

local MOTION_TICKS = {
    deadly_calm = 63,
    lc1 = 10,
    lc2 = 20,
    lc3 = 29,
    lc4 = 16,
    ravaging_dash = 22,
    death_bloom = 70,
    shadowquake = 12,
    shadowquake_appear = 13,
    crimson_arc = 51,
    last_dance = 55,
}

local function play_player_motion(player, motion)
    aris.game.geckolib.emote.set_emote_file(player, "boss_assassin")
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
    AWAKENED_HUD.sync_skill(entity, "assassin")
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

local function sound(entity, id, volume, pitch)
    run_command_at(entity, "playsound " .. id .. " master @a[distance=..32] ~ ~ ~ " .. tostring(volume or 0.7) .. " " .. tostring(pitch or 1))
end

local function particle(entity, id, amount, dx, dy, dz, speed)
    run_command_at(entity, "particle " .. id .. " ~ ~1 ~ " .. tostring(dx or 0.3) .. " " .. tostring(dy or 0.3) .. " " .. tostring(dz or 0.3) .. " " .. tostring(speed or 0) .. " " .. tostring(amount or 10))
end

local function is_duskblade(player)
    local item = player:get_main_hand_item()
    if item == nil then
        return false
    end
    local name = item:get_display_name() or item:get_name() or ""
    return string.find(name, SKILL.item_name, 1, true) ~= nil
end

AWAKENED_HUD.register_class("assassin", is_duskblade, state.cooldowns, HUD_SKILLS, function()
    return state.tick
end)

local function trigger_entity_anim(entity, anim)
    if entity == nil or anim == nil then
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

local function kill_later(entity, delay)
    if entity == nil then
        return
    end
    after(delay, function()
        entity:remove()
    end)
end

local function spawn_vfx(world, key, x, y, z, anim, life, yaw, pitch)
    state.next_vfx_id = state.next_vfx_id + 1
    local tag = "as_vfx_" .. tostring(state.next_vfx_id)
    local ry = yaw or 0
    local rp = pitch or 0
    local nbt = aris.game.nbt.from_string("{id:\"aris:" .. key .. "\",Pos:[" .. tostring(x) .. "d," .. tostring(y) .. "d," .. tostring(z) .. "d],Rotation:[" .. tostring(ry) .. "f," .. tostring(rp) .. "f],Tags:[\"as_vfx\",\"aa_vfx\",\"" .. tag .. "\"]," .. VFX_NBT .. "}")
    local entity = nbt:spawn_entity(world)
    if entity == nil then
        return nil
    end
    trigger_entity_anim(entity, anim)
    if life ~= nil then
        kill_later(entity, life)
    end
    return entity
end

local function spawn_vfx_at_player(player, key, y_offset, forward_offset, anim, life, yaw_offset)
    local yaw = player:get_yaw() + (yaw_offset or 0)
    local dx, dz = yaw_vector(yaw, 0)
    return spawn_vfx(player:get_server_world(), key, player:get_x() + dx * (forward_offset or 0), player:get_y() + (y_offset or 0), player:get_z() + dz * (forward_offset or 0), anim, life, yaw, 0)
end

local function spawn_frame_models_at_player(player, prefix, first_frame, last_frame, anim, y_offset, forward_offset, yaw_offset, first_life, frame_life, frame_start_delay, frame_interval)
    spawn_vfx_at_player(player, prefix .. tostring(first_frame), y_offset, forward_offset, anim, first_life or 12, yaw_offset)
    local delay = frame_start_delay or 5
    local interval = frame_interval or 1
    for frame = first_frame + 1, last_frame do
        after(delay + ((frame - first_frame - 1) * interval), function()
            spawn_vfx_at_player(player, prefix .. tostring(frame), y_offset, forward_offset, anim, frame_life or 2, yaw_offset)
        end)
    end
end

local function damage_near(caster, world, x, y, z, radius, limit, damage)
    local r = tonumber(radius) or 3
    local l = tonumber(limit) or 4
    local d = tonumber(damage) or 0
    state.next_vfx_id = state.next_vfx_id + 1
    local hit_tag = "as_vfx_hit_cmd_" .. tostring(state.next_vfx_id)
    local caster_tag = "as_vfx_caster_immune_" .. tostring(state.next_vfx_id)
    aris.game.dispatch_command("execute positioned " .. tostring(caster:get_x()) .. " " .. tostring(caster:get_y()) .. " " .. tostring(caster:get_z()) .. " run tag @p[distance=..0.2,limit=1] add " .. caster_tag)
    local selector = "@e[distance=.." .. tostring(r) .. ",limit=" .. tostring(l) .. ",sort=nearest,tag=!" .. caster_tag .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as " .. selector .. " at @s run "
    spawn_vfx(world, "vfx_dusk_cut", x, y + 1.2, z, "lrd", 8, 0, 0)
    aris.game.dispatch_command(base .. "summon aris:vfx_dusk_cut ~ ~1.2 ~ {Tags:[\"as_vfx\",\"aa_vfx\",\"" .. hit_tag .. "\"],Invulnerable:1b,NoAI:1b,Silent:1b,NoGravity:1b,PersistenceRequired:0b,DeathLootTable:\"minecraft:empty\",CanPickUpLoot:0b,Health:1000000f}")
    after(8, function()
        remove_tagged_vfx(hit_tag)
    end)
    aris.game.dispatch_command(base .. "damage @s " .. tostring(d))
    aris.game.dispatch_command("tag @a[tag=" .. caster_tag .. "] remove " .. caster_tag)
end

local function skill_damage(player, x, y, z, radius, limit, damage)
    local final_damage = damage
    if has_aura(player, "Deadly_Calm") then
        final_damage = damage * 2
        remove_aura(player, "Deadly_Calm")
    end
    damage_near(player, player:get_server_world(), x, y, z, radius, limit, final_damage)
    sound(player, "item.mace.smash_air", 0.8, 1.3)
end

local function spawn_projectile(caster, model, anim, damage, opts)
    opts = opts or {}
    local yaw = caster:get_yaw() + (opts.h_offset or 0)
    local dx, dz = yaw_vector(yaw, 0)
    local x = caster:get_x() + dx * (opts.start_forward or 1)
    local y = caster:get_y() + 1.2 + (opts.start_y or 0)
    local z = caster:get_z() + dz * (opts.start_forward or 1)
    local vfx = spawn_vfx(caster:get_server_world(), model, x, y, z, anim, opts.life or 40, yaw, 0)
    state.projectiles[#state.projectiles + 1] = {
        caster = caster,
        entity = vfx,
        x = x,
        y = y,
        z = z,
        dx = dx,
        dz = dz,
        yaw = yaw,
        speed = opts.speed or 1.8,
        radius = opts.radius or 1,
        damage = damage,
        pierce = opts.pierce or 4,
        max_ticks = opts.max_ticks or 25,
        age = 0,
        on_end = opts.on_end,
        trail_model = opts.trail_model,
        trail_anim = opts.trail_anim,
        trail_interval = opts.trail_interval,
    }
end

local function update_projectiles()
    local remaining = {}
    for _, p in ipairs(state.projectiles) do
        p.age = p.age + 1
        p.x = p.x + p.dx * p.speed
        p.z = p.z + p.dz * p.speed
        if p.entity ~= nil then
            p.entity:move_to(p.x, p.y, p.z)
        end
        if p.trail_model ~= nil and p.trail_interval ~= nil and p.age % p.trail_interval == 0 then
            spawn_vfx(p.caster:get_server_world(), p.trail_model, p.x, p.y, p.z, p.trail_anim or "skill", 12, p.yaw, 0)
        end
        damage_near(p.caster, p.caster:get_server_world(), p.x, p.y, p.z, p.radius, p.pierce, p.damage)
        if p.age >= p.max_ticks then
            if p.on_end ~= nil then
                p.on_end(p)
            end
            if p.entity ~= nil then
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
            next_deadly = 0,
            next_shadow = 0,
            last_x = player:get_x(),
            last_y = player:get_y(),
            last_z = player:get_z(),
            still_ticks = 0,
        }
        state.players[id] = current
    else
        current.player = player
    end
    return current
end

local function cast_deadly_calm(player)
    play_player_motion(player, "deadly_calm")
    add_aura(player, "Deadly_Calm", SKILL.deadly_calm_duration, 1, 1)
    sound(player, "entity.phantom.death", 0.9, 1.2)
    for i = 0, 8 do
        after(i, function()
            particle(player, "dust_color_transition 0.87 0.59 0.59 0.13 0.01 0.01 0.4", 80, 5 - (i * 0.5), 0, 5 - (i * 0.5), 0)
        end)
    end
end

local function cast_lethal_combo(player)
    if has_aura(player, "CASTING") or has_aura(player, "Last_Dance") or not can_cast(player, "Lethal_Combo", SKILL.lethal_cooldown) then
        return
    end
    if has_aura(player, "Shadowquake") then
        add_aura(player, "Shadowquake_ON", SKILL.shadowquake_window, 1, 1)
        return
    end

    local stacks = aura_stacks(player, "Lethal_Combo_Stack")
    if stacks == 0 then
        play_player_motion(player, "lc1")
        add_aura(player, "Lethal_Combo_Stack", SKILL.lethal_stack_duration, 1, SKILL.lethal_max_stack)
        spawn_frame_models_at_player(player, "vfx_dusk_slash_", 1, 7, "lr_cut", 1.4, 0.2, 0, 11, 2, 5, 1)
        skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.lethal_hit_radius, SKILL.lethal_hit_limit, SKILL.lethal_damage)
        sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_slash", 0.7, 1.1)
    elseif stacks == 1 then
        play_player_motion(player, "lc2")
        add_aura(player, "Lethal_Combo_Stack", SKILL.lethal_stack_duration, 1, SKILL.lethal_max_stack)
        spawn_frame_models_at_player(player, "vfx_dusk_slash_", 1, 7, "rl_cut", 1.4, 0.2, 0, 11, 2, 5, 1)
        after(4, function()
            spawn_frame_models_at_player(player, "vfx_dusk_spin_", 1, 7, "skill", 1.4, 0.2, 0, 12, 2, 6, 1)
            after(2, function()
                spawn_frame_models_at_player(player, "vfx_dusk_spin_", 1, 7, "skill", 0.8, 0.2, 0, 12, 2, 6, 1)
            end)
            skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.lethal_hit_radius, SKILL.lethal_hit_limit, SKILL.lethal_damage)
            sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_blades_spin", 0.7, 1.1)
        end)
        skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.lethal_hit_radius, SKILL.lethal_hit_limit, SKILL.lethal_damage)
    elseif stacks == 2 then
        play_player_motion(player, "lc3")
        add_aura(player, "Lethal_Combo_Stack", SKILL.lethal_stack_duration, 1, SKILL.lethal_max_stack)
        player:add_velocity_relative(-0.6, -0.05, 0)
        sound(player, "entity.ender_dragon.flap", 0.6, 1.4)
        after(4, function()
            player:add_velocity_relative(1, -0.05, 0)
            sound(player, "entity.ender_dragon.flap", 0.6, 1.4)
        end)
        after(6, function()
            spawn_frame_models_at_player(player, "vfx_dusk_pierce_", 1, 9, "skill2", 1.4, 0.8, 0, 18, 2, 2, 2)
            skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.lethal_hit_radius, SKILL.lethal_hit_limit, SKILL.lethal_damage)
            sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_pierce", 0.7, 1.1)
        end)
        after(9, function()
            player:add_velocity_relative(-0.7, 0.3, 0)
            after(2, function()
                player:add_velocity_relative(0, 0.04, 0)
            end)
            sound(player, "entity.ender_dragon.flap", 0.6, 1.4)
        end)
    else
        play_player_motion(player, "lc4")
        remove_aura(player, "Lethal_Combo_Stack")
        spawn_projectile(player, "vfx_dusk_dagger", "shoot_down", SKILL.lethal_damage * SKILL.lethal_finisher_multiplier, { radius = 1, pierce = 1, max_ticks = 12, speed = 1.6, start_forward = 1.5 })
        sound(player, "item.trident.throw", 0.8, 1.6)
        after(7, function()
            player:add_velocity_relative(1.3, -1, 0)
            spawn_vfx_at_player(player, "vfx_dusk_downslash", 2.4, 1.0, "skill", 15)
            sound(player, "entity.ender_dragon.flap", 0.6, 1.4)
            sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_spin", 0.7, 1.1)
        end)
        after(12, function()
            sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_slash", 0.7, 1.1)
        end)
        after(14, function()
            local x, y, z, yaw = forward_position(player, 3.0, 0.1, 0)
            spawn_vfx(player:get_server_world(), "vfx_earthquake_rupture_1", x, y, z, "skill3", 52, yaw, 0)
            spawn_vfx(player:get_server_world(), "vfx_rubbles", x, y, z, "skill2", 45, yaw, 0)
            aris.game.dispatch_command("execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " run particle campfire_cosy_smoke ~ ~ ~ 0.8 0.1 0.8 0 7")
            aris.game.dispatch_command("execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " run particle block minecraft:dirt ~ ~ ~ 0.9 0.2 0.9 0 25")
            skill_damage(player, x, y, z, 4, SKILL.lethal_hit_limit, SKILL.lethal_damage * SKILL.lethal_finisher_multiplier)
            sound(player, "item.mace.smash_ground_heavy", 0.8, 1.2)
        end)
    end
end

local function cast_ravaging_dash(player)
    if has_aura(player, "Last_Dance") then
        player:add_velocity_relative(2.5, 0, 0)
        particle(player, "smoke", 20, 0.5, 0.8, 0.5, 0.1)
        sound(player, "entity.enderman.teleport", 1, 0.5)
        return
    end
    if has_aura(player, "CASTING") or not can_cast(player, "Ravaging_Dash", SKILL.ravaging_cooldown) then
        return
    end
    play_player_motion(player, "ravaging_dash")
    sound(player, "entity.phantom.ambient", 0.8, 0.8)
    particle(player, "dust_color_transition 1 0 0 0.07 0.01 0.01 0.55", 80, 4, 0.1, 4, 0)
    after(10, function()
        spawn_frame_models_at_player(player, "vfx_dusk_dash_impact_", 1, 9, "skill", 1.4, -0.7, 0, 12, 2, 1, 1)
        spawn_vfx_at_player(player, "vfx_dusk_dash", 1.4, 0, "skill", 15)
        player:add_velocity_relative(1.8, -0.05, 0)
        sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_dash", 0.7, 1.1)
        every(0, SKILL.ravaging_attack_count, SKILL.ravaging_attack_interval, function()
            spawn_frame_models_at_player(player, "vfx_dusk_slash_", 1, 7, math.random(1, 2) == 1 and "lr" or "rl", 1.0, 0.5, math.random(-30, 30), 8, 2, 5, 1)
            skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.ravaging_hit_radius, SKILL.ravaging_hit_limit, SKILL.ravaging_damage)
        end)
    end)
end

local function cast_death_bloom(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Death_Bloom", SKILL.death_bloom_cooldown) then
        return
    end
    play_player_motion(player, "death_bloom")
    add_aura(player, "CASTING", SKILL.death_bloom_casting_duration, 1, 1)
    particle(player, "smoke", 50, 4, 0.15, 4, 0.05)
    sound(player, "entity.phantom.ambient", 0.7, 0.6)
    after(SKILL.death_bloom_start_delay, function()
        spawn_vfx_at_player(player, "vfx_shadow_figure_" .. tostring(math.random(1, 5)), 0.5, 0, "skill" .. tostring(math.random(1, 6)), 24)
        every(0, SKILL.death_bloom_cut_count, SKILL.death_bloom_cut_interval, function()
            spawn_vfx_at_player(player, "vfx_dusk_cut", 1.2, math.random(-3, 3), math.random(1, 2) == 1 and "lrd" or "rld", 8, math.random(0, 360))
            skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.death_bloom_hit_radius, SKILL.death_bloom_hit_limit, SKILL.death_bloom_damage)
            sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_cut", 0.6, 1.1)
        end)
    end)
end

local function request_death_bloom(player)
    if has_aura(player, "Death_Bloom_aura") then
        remove_aura(player, "Death_Bloom_aura")
        cast_death_bloom(player)
    else
        add_aura(player, "Death_Bloom_aura", 5, 1, 1)
    end
end

local function cast_shadowquake(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Shadowquake", SKILL.shadowquake_cooldown) then
        return
    end
    play_player_motion(player, "shadowquake")
    add_aura(player, "Shadowquake", SKILL.shadowquake_duration, 1, 1)
    particle(player, "smoke", 15, 0.35, 0.6, 0.35, 0.1)
    sound(player, "entity.phantom.ambient", 0.7, 0.6)
end

local function trigger_shadowquake_appear(player)
    if not has_aura(player, "Shadowquake") or not has_aura(player, "Shadowquake_ON") then
        return
    end
    remove_aura(player, "Shadowquake")
    remove_aura(player, "Shadowquake_ON")
    play_player_motion(player, "shadowquake_appear")
    spawn_vfx_at_player(player, "vfx_pulse", 0.1, 0, "skill3", 28)
    spawn_vfx_at_player(player, "vfx_earthquake_rupture_1", 0.1, 0, "skill", 52)
    spawn_vfx_at_player(player, "vfx_rubbles", 0.1, 0, "skill", 45)
    skill_damage(player, player:get_x(), player:get_y(), player:get_z(), SKILL.shadowquake_radius, SKILL.shadowquake_limit, SKILL.shadowquake_damage)
    sound(player, "item.mace.smash_ground_heavy", 1.1, 0.6)
    spawn_projectile(player, "vfx_dusk_shockwave_slash", "skill", SKILL.shadowquake_damage, { radius = SKILL.shadowquake_wave_radius, pierce = SKILL.shadowquake_wave_pierce, max_ticks = SKILL.shadowquake_wave_ticks, speed = SKILL.shadowquake_wave_speed })
end

local function cast_crimson_arc(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Crimson_Arc", SKILL.crimson_cooldown) then
        return
    end
    play_player_motion(player, "crimson_arc")
    player:add_velocity_relative(-0.8, 0, 0)
    particle(player, "smoke", 15, 0.35, 0.6, 0.35, 0.01)
    sound(player, "block.trial_spawner.ambient_ominous", 0.8, 1.3)
    after(SKILL.crimson_start_delay, function()
        for _, h in ipairs({ 0, 10, -10 }) do
            spawn_projectile(player, "vfx_dusk_shuriken", "loop", SKILL.crimson_damage, {
                h_offset = h,
                radius = SKILL.crimson_radius,
                pierce = SKILL.crimson_pierce,
                max_ticks = SKILL.crimson_ticks,
                speed = SKILL.crimson_speed,
                life = SKILL.crimson_life,
                on_end = function(p)
                    spawn_projectile(player, "vfx_dusk_shuriken", "loop", SKILL.crimson_damage, {
                        h_offset = h + 180,
                        radius = SKILL.crimson_radius,
                        pierce = SKILL.crimson_pierce,
                        max_ticks = SKILL.crimson_return_ticks,
                        speed = SKILL.crimson_speed,
                        start_forward = 8,
                        life = SKILL.crimson_return_life,
                    })
                end,
            })
        end
        sound(player, "block.trial_spawner.spawn_item", 0.7, 0.65)
    end)
end

local function cast_last_dance(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Last_Dance", SKILL.last_dance_cooldown) then
        return
    end
    play_player_motion(player, "last_dance")
    add_aura(player, "CASTING", SKILL.last_dance_duration, 1, 1)
    add_aura(player, "Last_Dance", SKILL.last_dance_duration, 1, 1)
    spawn_vfx_at_player(player, "vfx_dusk_dagger_circle", 2.4, 0, "skill", 20)
    sound(player, "block.trial_spawner.spawn_item", 0.7, 1.35)
    after(SKILL.last_dance_blade_delay, function()
        spawn_vfx_at_player(player, "vfx_dusk_spinning_blades", 2.4, 0, "spin", 60)
        every(0, SKILL.last_dance_dagger_count, SKILL.last_dance_dagger_interval, function()
            spawn_projectile(player, "vfx_dusk_dagger", "shoot_down", SKILL.last_dance_damage, { h_offset = math.random(-55, 55), radius = SKILL.crimson_radius, pierce = 1, max_ticks = 16, speed = SKILL.crimson_speed })
        end)
        sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_blades_spin", 0.7, 1.2)
    end)
    after(SKILL.last_dance_spin_delay, function()
        spawn_frame_models_at_player(player, "vfx_dusk_spin_", 1, 7, "skill2", 1.4, 0.2, 0, 12, 2, 6, 1)
        spawn_frame_models_at_player(player, "vfx_dusk_spin_", 1, 7, "skill2", 0.7, 0.2, 0, 12, 2, 6, 1)
        skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.last_dance_spin_radius, SKILL.last_dance_spin_limit, SKILL.last_dance_damage)
        sound(player, "awakened_assassin_sounds:samus.awakened_assassin.aa_spin", 0.7, 1.1)
    end)
    after(SKILL.last_dance_slash_delay, function()
        player:add_velocity_relative(0.01, 0.7, 0)
        every(5, SKILL.last_dance_slash_count, SKILL.last_dance_slash_interval, function()
            spawn_frame_models_at_player(player, "vfx_dusk_slash_", 1, 7, math.random(1, 2) == 1 and "lrd" or "rld", 1.2, 0.2, math.random(0, 360), 10, 2, 5, 1)
            skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.last_dance_spin_radius, SKILL.last_dance_final_limit, SKILL.last_dance_damage)
        end)
    end)
    after(SKILL.last_dance_final_delay, function()
        player:add_velocity_relative(2.5, -1.2, 0)
        spawn_frame_models_at_player(player, "vfx_dusk_pierce_", 1, 9, "skill3", 1.2, 0.8, 0, 18, 2, 2, 2)
        skill_damage(player, player:get_x(), player:get_y() + 1, player:get_z(), SKILL.last_dance_final_radius, SKILL.last_dance_final_limit, SKILL.last_dance_damage * SKILL.last_dance_final_multiplier)
    end)
end

local function diagnostic_loop(label, fn)
    local handler = debug ~= nil and debug.traceback or tostring
    local ok, err = xpcall(fn, handler)
    if not ok then
        aris.log_error("[" .. label .. "] " .. tostring(err))
    end
end

local logged_first_yield = false
local function safe_yield(label)
    if not logged_first_yield then
        logged_first_yield = true
        aris.log_error("[" .. label .. ":first_yield] type_task_yield=" .. tostring(type(task_yield)))
    end
    task_yield()
end

aris.game.hook.add_on_left_click(function(event)
    diagnostic_loop("awakened_assassin:left_click", function()
    local player = event:get_player()
    if player == nil or not is_duskblade(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_last_dance(player)
    else
        cast_lethal_combo(player)
        trigger_shadowquake_appear(player)
    end
    end)
end)

aris.game.hook.add_on_right_click(function(event)
    diagnostic_loop("awakened_assassin:right_click", function()
    local player = event:get_player()
    if player == nil or not is_duskblade(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_crimson_arc(player)
    else
        cast_ravaging_dash(player)
    end
    end)
end)

while true do
    diagnostic_loop("awakened_assassin", function()
    state.tick = state.tick + 1

    local pending = {}
    for _, timer in ipairs(state.timers) do
        if timer.at <= state.tick then
            if type(timer.fn) == "function" then
                timer.fn()
            else
                aris.log_error("[awakened_assassin] bad timer fn: " .. tostring(timer.fn))
            end
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
        if player == nil or not is_duskblade(player) then
            state.players[id] = nil
        else
            local dx = math.abs(player:get_x() - ps.last_x)
            local dy = math.abs(player:get_y() - ps.last_y)
            local dz = math.abs(player:get_z() - ps.last_z)
            if dx + dy + dz < 0.02 then
                ps.still_ticks = ps.still_ticks + 1
            else
                ps.still_ticks = 0
                remove_aura(player, "Deadly_Calm_ACTIVATOR")
            end
            ps.last_x = player:get_x()
            ps.last_y = player:get_y()
            ps.last_z = player:get_z()

            if state.tick >= ps.next_deadly then
                ps.next_deadly = state.tick + 10
                if not has_aura(player, "Deadly_Calm") and ps.still_ticks >= 60 then
                    cast_deadly_calm(player)
                end
            end

            if state.tick >= ps.next_shadow then
                ps.next_shadow = state.tick + 10
                if player:get_is_sneaking() then
                    local stacks = aura_stacks(player, "Shadowquake_STACK")
                    if stacks >= 2 then
                        remove_aura(player, "Shadowquake_STACK")
                        cast_shadowquake(player)
                    else
                        add_aura(player, "Shadowquake_STACK", 120, 1, 2)
                    end
                else
                    remove_aura(player, "Shadowquake_STACK")
                end
            end

            local sneaking = player:get_is_sneaking()
            if sneaking and not ps.sneak_down and state.tick > ps.sneak_click_until then
                request_death_bloom(player)
            end
            ps.sneak_down = sneaking
        end
    end

    end)
    safe_yield("awakened_assassin")
end
