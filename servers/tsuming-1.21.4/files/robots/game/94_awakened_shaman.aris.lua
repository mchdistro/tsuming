local DEG_TO_RAD = math.pi / 180

local state = {
    tick = 0,
    timers = {},
    cooldowns = {},
    players = {},
    projectiles = {},
    next_vfx_id = 0,
}

local SKILL = {
    item_name = "Lifescepter",
    custom_model_data = 2090,
    soul_link_heal = 2,
    soul_link_interval = 20,
    soul_link_timer = 40,
    primal_damage = 3,
    primal_heal = 3,
    primal_cooldown = 6,
    echo_step_cooldown = 40,
    ritual_damage = 3,
    ritual_heal = 3,
    ritual_cooldown = 60,
    stance_timer = 200,
    stance_cooldown = 40,
    earthen_embrace_cooldown = 60,
    ancestral_damage = 7,
    ancestral_heal = 2,
    ancestral_cooldown = 140,
}

local VFX_NBT = "Invulnerable:1b,NoAI:1b,Silent:1b,NoGravity:1b,PersistenceRequired:0b,DeathLootTable:\"minecraft:empty\",CanPickUpLoot:0b,Health:1000000f,attributes:[{id:\"minecraft:max_health\",base:1000000d},{id:\"minecraft:armor\",base:1000000d}],Attributes:[{Name:\"minecraft:generic.max_health\",Base:1000000d},{Name:\"minecraft:generic.armor\",Base:1000000d}]"
local VFX_SELECTOR_EXCLUDE = ",tag=!ash_shaman_caster,tag=!aa_vfx"

local function uuid(entity)
    return entity:get_uuid()
end

local function key_for(entity, name)
    return uuid(entity) .. ":" .. name
end

local function can_cast(entity, name, cooldown_ticks)
    local key = key_for(entity, name)
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

local function yaw_vector(yaw, offset)
    local angle = (yaw + (offset or 0)) * DEG_TO_RAD
    return -math.sin(angle), math.cos(angle)
end

local function offset_position(entity, forward, y_offset, side, yaw_offset)
    local yaw = entity:get_yaw() + (yaw_offset or 0)
    local dx, dz = yaw_vector(yaw, 0)
    local sx, sz = math.cos(yaw * DEG_TO_RAD), math.sin(yaw * DEG_TO_RAD)
    local x = entity:get_x() + dx * (forward or 0) + sx * (side or 0)
    local y = entity:get_y() + (y_offset or 0)
    local z = entity:get_z() + dz * (forward or 0) + sz * (side or 0)
    return x, y, z, yaw
end

local function offset_from_point(base_x, base_y, base_z, yaw, forward, y_offset, side)
    local dx, dz = yaw_vector(yaw, 0)
    local sx, sz = math.cos(yaw * DEG_TO_RAD), math.sin(yaw * DEG_TO_RAD)
    return base_x + dx * (forward or 0) + sx * (side or 0), base_y + (y_offset or 0), base_z + dz * (forward or 0) + sz * (side or 0)
end

local function run_command_at(entity, command)
    aris.game.dispatch_command("execute positioned " .. tostring(entity:get_x()) .. " " .. tostring(entity:get_y()) .. " " .. tostring(entity:get_z()) .. " run " .. command)
end

local function command_as_player(player, command)
    aris.game.dispatch_command("execute positioned " .. tostring(player:get_x()) .. " " .. tostring(player:get_y()) .. " " .. tostring(player:get_z()) .. " as @p[distance=..1,limit=1,sort=nearest] at @s run " .. command)
end

local function sound(entity, id, volume, pitch)
    run_command_at(entity, "playsound " .. id .. " master @a[distance=..32] ~ ~ ~ " .. tostring(volume or 0.7) .. " " .. tostring(pitch or 1))
end

local function particle_at(x, y, z, id, amount, dx, dy, dz, speed)
    aris.game.dispatch_command("particle " .. id .. " " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " " .. tostring(dx or 0.3) .. " " .. tostring(dy or 0.3) .. " " .. tostring(dz or 0.3) .. " " .. tostring(speed or 0) .. " " .. tostring(amount or 10))
end

local function is_lifescepter(player)
    local item = player:get_main_hand_item()
    if item == nil then
        return false
    end
    local name = item:get_display_name() or item:get_name() or ""
    return string.find(name, SKILL.item_name, 1, true) ~= nil
end

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

local function remove_later(entity, tag, delay)
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
    local tag = "ash_vfx_" .. tostring(state.next_vfx_id)
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
        remove_later(entity, tag, life)
    end
    return entity, tag
end

local function mark_caster(player)
    command_as_player(player, "tag @s add ash_shaman_caster")
end

local function unmark_caster(player)
    command_as_player(player, "tag @s remove ash_shaman_caster")
end

local function damage_near(caster, x, y, z, radius, limit, damage)
    local entity_selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local player_selector = "@a[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    mark_caster(caster)
    aris.game.dispatch_command(base .. entity_selector .. " at @s run damage @s " .. tostring(damage))
    aris.game.dispatch_command(base .. player_selector .. " at @s run damage @s " .. tostring(damage))
    unmark_caster(caster)
    particle_at(x, y + 0.9, z, "minecraft:crit", 7, 0.25, 0.25, 0.25, 0.05)
end

local function heal_players_near(caster, x, y, z, radius, limit, level)
    local selector = "@a[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    aris.game.dispatch_command(base .. selector .. " at @s run effect give @s minecraft:instant_health 1 " .. tostring(level or 0) .. " true")
    aris.game.dispatch_command(base .. selector .. " at @s run particle minecraft:happy_villager ~ ~1 ~ 0.35 0.55 0.35 0.03 12")
end

local function effect_near(caster, x, y, z, radius, limit, effect, seconds, level)
    local entity_selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local player_selector = "@a[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    mark_caster(caster)
    aris.game.dispatch_command(base .. entity_selector .. " at @s run effect give @s minecraft:" .. effect .. " " .. tostring(seconds) .. " " .. tostring(level or 0) .. " true")
    aris.game.dispatch_command(base .. player_selector .. " at @s run effect give @s minecraft:" .. effect .. " " .. tostring(seconds) .. " " .. tostring(level or 0) .. " true")
    unmark_caster(caster)
end

local function push_entities_near(caster, x, y, z, radius, limit, y_motion)
    local selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    mark_caster(caster)
    aris.game.dispatch_command(base .. selector .. " at @s run data merge entity @s {Motion:[0.0d," .. tostring(y_motion) .. "d,0.0d]}")
    unmark_caster(caster)
end

local function damage_forward_line(player, y_offset, damage, radius)
    local points = { 2.2, 4.6, 7.0, 8.5 }
    for _, forward in ipairs(points) do
        local x, y, z = offset_position(player, forward, y_offset or 0.9, 0, 0)
        damage_near(player, x, y, z, radius or 2.4, 4, damage)
    end
end

local function heal_forward_line(player, y_offset, level, radius)
    local points = { 2.2, 4.6, 7.0, 8.5 }
    for _, forward in ipairs(points) do
        local x, y, z = offset_position(player, forward, y_offset or 0.8, 0, 0)
        heal_players_near(player, x, y, z, radius or 2.4, 4, level or 0)
    end
end

local function remove_active_totem(ps)
    if ps.active_totem == nil then
        return
    end
    if is_entity_object(ps.active_totem.entity) then
        ps.active_totem.entity:remove()
    end
    if ps.active_totem.tag ~= nil then
        remove_tagged_vfx(ps.active_totem.tag)
    end
    ps.active_totem = nil
end

local function is_looking_at_active_totem(player, ps)
    local totem = ps.active_totem
    if totem == nil or totem.until_tick <= state.tick then
        ps.active_totem = nil
        return false
    end
    local dx = totem.x - player:get_x()
    local dz = totem.z - player:get_z()
    local dist_sq = dx * dx + dz * dz
    if dist_sq < 1 or dist_sq > 256 then
        return false
    end
    local dist = math.sqrt(dist_sq)
    local fx, fz = yaw_vector(player:get_yaw(), 0)
    local dot = (fx * (dx / dist)) + (fz * (dz / dist))
    return dot >= 0.72
end

local function is_current_totem(ps, tag)
    return ps.active_totem ~= nil and ps.active_totem.tag == tag
end

local function player_state(player)
    local id = uuid(player)
    local ps = state.players[id]
    if ps == nil then
        ps = {
            player = player,
            stance = "thunder",
            combo = 0,
            combo_until = 0,
            sneak_click_until = 0,
            sneak_down = false,
            sneak_tap_until = 0,
            stance_stack = 0,
            active_totem = nil,
        }
        state.players[id] = ps
    end
    ps.player = player
    return ps
end

local function spawn_projectile(caster, key, anim, x, y, z, yaw, speed, life, radius, damage, on_end)
    local entity, tag = spawn_vfx(caster:get_server_world(), key, x, y, z, anim, life + 4, yaw, 0)
    local dx, dz = yaw_vector(yaw, 0)
    state.projectiles[#state.projectiles + 1] = {
        caster = caster,
        entity = entity,
        tag = tag,
        x = x,
        y = y,
        z = z,
        yaw = yaw,
        dx = dx,
        dz = dz,
        speed = speed,
        life = life,
        radius = radius,
        damage = damage,
        age = 0,
        on_end = on_end,
    }
end

local function stance_particles(player, ps)
    if ps.stance == "thunder" then
        particle_at(player:get_x(), player:get_y() + 0.2, player:get_z(), "minecraft:electric_spark", 18, 0.7, 0.08, 0.7, 0.02)
    else
        particle_at(player:get_x(), player:get_y() + 0.2, player:get_z(), "minecraft:happy_villager", 12, 0.7, 0.08, 0.7, 0.02)
    end
end

local function cast_stance_switch(player)
    local ps = player_state(player)
    if not can_cast(player, "stance_switch", SKILL.stance_cooldown) then
        return
    end
    if ps.stance == "thunder" then
        ps.stance = "earth"
        particle_at(player:get_x(), player:get_y() + 0.7, player:get_z(), "minecraft:happy_villager", 45, 0.45, 0.7, 0.45, 0.03)
        sound(player, "minecraft:block.amethyst_block.chime", 0.7, 1.25)
    else
        ps.stance = "thunder"
        particle_at(player:get_x(), player:get_y() + 0.7, player:get_z(), "minecraft:electric_spark", 45, 0.45, 0.7, 0.45, 0.03)
        sound(player, "minecraft:item.trident.thunder", 0.7, 1.15)
    end
end

local function soul_link_tick(player)
    local ps = player_state(player)
    stance_particles(player, ps)
    if ps.stance == "thunder" then
        command_as_player(player, "effect give @s minecraft:strength 1 0 true")
        aris.game.dispatch_command("execute positioned " .. tostring(player:get_x()) .. " " .. tostring(player:get_y()) .. " " .. tostring(player:get_z()) .. " as @a[distance=..10,limit=1,sort=nearest] run effect give @s minecraft:strength 1 0 true")
    else
        heal_players_near(player, player:get_x(), player:get_y(), player:get_z(), 10, 1, 0)
    end
end

local function cast_primal_combo(player)
    if not can_cast(player, "primal_combo", SKILL.primal_cooldown) then
        return
    end
    local ps = player_state(player)
    if state.tick > ps.combo_until then
        ps.combo = 0
    end
    ps.combo = ps.combo + 1
    if ps.combo > 4 then
        ps.combo = 1
    end
    ps.combo_until = state.tick + 300

    local x, y, z, yaw = offset_position(player, 1.0, 1.1, 0, 0)
    if ps.stance == "thunder" then
        if ps.combo <= 2 then
            spawn_vfx(player:get_server_world(), "horizontal_thunder_strike_vfx_1", x, y, z, "animation", 9, yaw, 0)
            after(1, function()
                damage_forward_line(player, 0.9, SKILL.primal_damage, 2.4)
            end)
            sound(player, "minecraft:entity.lightning_bolt.impact", 0.45, 1.8)
        elseif ps.combo == 3 then
            spawn_vfx(player:get_server_world(), "constant_thunder_strike_vfx", x, y, z, "on", 45, yaw, 0)
            every(0, 6, 5, function()
                damage_forward_line(player, 0.9, SKILL.primal_damage, 2.2)
            end)
            sound(player, "minecraft:entity.lightning_bolt.thunder", 0.45, 1.5)
        else
            local sx, sy, sz = offset_position(player, 5.5, 0.2, 0, 0)
            spawn_vfx(player:get_server_world(), "vertical_thunder_strike_vfx_1", sx, sy, sz, "animation", 24, yaw, 0)
            spawn_vfx(player:get_server_world(), "vfx_earthquake_rupture_1", sx, sy - 0.1, sz, "skill2", 24, yaw, 0)
            after(2, function()
                damage_near(player, sx, sy + 0.5, sz, 4.5, 7, SKILL.primal_damage)
            end)
            sound(player, "minecraft:item.trident.thunder", 0.7, 1.0)
        end
    else
        if ps.combo <= 2 then
            spawn_vfx(player:get_server_world(), "constant_healing_beam_vfx", x, y, z, "on", 13, yaw, 0)
            heal_forward_line(player, 0.8, 0, 2.4)
            sound(player, "minecraft:block.trial_spawner.spawn_item_begin", 0.7, 1.3)
        elseif ps.combo == 3 then
            spawn_vfx(player:get_server_world(), "constant_healing_beam_vfx", x, y, z, "on", 49, yaw, 0)
            every(0, 6, 5, function()
                heal_forward_line(player, 0.8, 0, 2.2)
            end)
            sound(player, "minecraft:block.beacon.ambient", 0.6, 1.3)
        else
            local sx, sy, sz = offset_position(player, 5.5, 0.2, 0, 0)
            spawn_vfx(player:get_server_world(), "vertical_healing_beam_vfx", sx, sy, sz, "animation", 24, yaw, 0)
            after(2, function()
                heal_players_near(player, sx, sy, sz, 4.5, 7, 0)
            end)
            sound(player, "minecraft:block.trial_spawner.spawn_item_begin", 0.9, 1.15)
        end
    end
end

local function cast_echo_step(player)
    if not can_cast(player, "echo_step", SKILL.echo_step_cooldown) then
        return
    end
    local x, y, z, yaw = offset_position(player, 0, 1.3, 0, 0)
    spawn_vfx(player:get_server_world(), "echo_step", x, y, z, "dash_front", 40, yaw, 0)
    command_as_player(player, "effect give @s minecraft:invisibility 2 0 true")
    command_as_player(player, "effect give @s minecraft:speed 2 5 true")
    command_as_player(player, "effect give @s minecraft:resistance 2 4 true")
    every(0, 8, 1, function()
        local px, py, pz = offset_position(player, 0, 1.2, 0, 0)
        particle_at(px, py, pz, "minecraft:soul_fire_flame", 4, 0.25, 0.45, 0.25, 0.02)
    end)
    sound(player, "minecraft:entity.wither.ambient", 0.35, 0.45)
end

local function spawn_ritual_totem(player, ps, x, y, z, yaw)
    remove_active_totem(ps)
    if ps.stance == "thunder" then
        local totem, tag = spawn_vfx(player:get_server_world(), "hunter_totem", x, y, z, "spawn", 220, yaw, 0)
        ps.active_totem = { entity = totem, tag = tag, x = x, y = y, z = z, yaw = yaw, until_tick = state.tick + 220, stance = ps.stance }
        sound(player, "minecraft:block.trial_spawner.spawn_item", 0.7, 1.0)
        after(30, function()
            if is_current_totem(ps, tag) then
                trigger_entity_anim(totem, "idle")
            end
        end)
        every(40, 8, 20, function()
            if not is_current_totem(ps, tag) then
                return
            end
            trigger_entity_anim(totem, "hit")
            for side = -1, 1 do
                local sx, sy, sz = offset_from_point(x, y, z, yaw, 0.5, 1.1, side * 0.5)
                spawn_projectile(player, "horizontal_thunder_strike_vfx_1", "animation", sx, sy, sz, yaw, 1.1, 22, 3, SKILL.ritual_damage, nil)
            end
            sound(player, "minecraft:entity.blaze.shoot", 0.45, 1.0)
        end)
        after(200, function()
            if is_current_totem(ps, tag) then
                trigger_entity_anim(totem, "despawn")
            end
        end)
    else
        local totem, tag = spawn_vfx(player:get_server_world(), "guardian_totem", x, y, z, "spawn", 220, yaw, 0)
        ps.active_totem = { entity = totem, tag = tag, x = x, y = y, z = z, yaw = yaw, until_tick = state.tick + 220, stance = ps.stance }
        sound(player, "minecraft:block.trial_spawner.spawn_item", 0.7, 1.4)
        after(30, function()
            if is_current_totem(ps, tag) then
                trigger_entity_anim(totem, "idle")
            end
        end)
        every(20, 9, 20, function()
            if not is_current_totem(ps, tag) then
                return
            end
            trigger_entity_anim(totem, "hit")
            heal_players_near(player, x, y, z, 12, 8, 0)
            particle_at(x, y + 0.2, z, "minecraft:happy_villager", 35, 3, 0.35, 3, 0.03)
        end)
        every(25, 8, 20, function()
            if not is_current_totem(ps, tag) then
                return
            end
            effect_near(player, x, y, z, 12, 10, "slowness", 1, 1)
        end)
        after(200, function()
            if is_current_totem(ps, tag) then
                trigger_entity_anim(totem, "despawn")
            end
        end)
    end
end

local function cast_ritual_totem(player)
    if not can_cast(player, "ritual_totem", SKILL.ritual_cooldown) then
        return
    end
    local ps = player_state(player)
    local x, y, z, yaw = offset_position(player, 7, 0, 0, 0)
    spawn_ritual_totem(player, ps, x, y, z, yaw)
end

local function switch_active_totem(player)
    local ps = player_state(player)
    if not is_looking_at_active_totem(player, ps) then
        return false
    end
    local totem = ps.active_totem
    if ps.stance == "thunder" then
        ps.stance = "earth"
        particle_at(totem.x, totem.y + 0.7, totem.z, "minecraft:happy_villager", 45, 0.8, 0.8, 0.8, 0.03)
        sound(player, "minecraft:block.amethyst_block.chime", 0.7, 1.25)
    else
        ps.stance = "thunder"
        particle_at(totem.x, totem.y + 0.7, totem.z, "minecraft:electric_spark", 45, 0.8, 0.8, 0.8, 0.03)
        sound(player, "minecraft:item.trident.thunder", 0.7, 1.15)
    end
    spawn_ritual_totem(player, ps, totem.x, totem.y, totem.z, player:get_yaw())
    return true
end

local function cast_earthen_embrace(player)
    if not can_cast(player, "earthen_embrace", SKILL.earthen_embrace_cooldown) then
        return
    end
    sound(player, "minecraft:block.rooted_dirt.break", 0.9, 0.6)
    local forward_points = { 3.5, 5.5, 7.5 }
    for index, forward in ipairs(forward_points) do
        after((index - 1) * 2, function()
            local cx, cy, cz, yaw = offset_position(player, forward, 0, 0, 0)
            spawn_vfx(player:get_server_world(), "earthen_embrace", cx, cy, cz, "animation", 52, yaw, 0)
            effect_near(player, cx, cy, cz, 2.3, 3, "slowness", 3, 255)
            effect_near(player, cx, cy, cz, 2.3, 3, "mining_fatigue", 3, 2)
            particle_at(cx, cy + 0.1, cz, "minecraft:campfire_cosy_smoke", 9, 0.35, 0.1, 0.35, 0.05)
            particle_at(cx, cy + 0.9, cz, "minecraft:block minecraft:rooted_dirt", 18, 0.45, 0.7, 0.45, 0.02)
        end)
    end
end

local function cast_ancestral_hands(player)
    if not can_cast(player, "ancestral_hands", SKILL.ancestral_cooldown) then
        return
    end
    local ps = player_state(player)
    local yaw = player:get_yaw()
    if ps.stance == "thunder" then
        local attacks = {
            { delay = 0, anim = "attack1", forward = 6, y = 0, hit_delay = 11, lift = 0.7 },
            { delay = 22, anim = "attack2", forward = 6, y = 2.3, hit_delay = 9, lift = 1.2 },
            { delay = 39, anim = "attack3", forward = 6, y = 0, hit_delay = 10, lift = -1.2 },
        }
        for _, attack in ipairs(attacks) do
            after(attack.delay, function()
                local x, y, z = offset_position(player, attack.forward, attack.y, 0, 0)
                spawn_vfx(player:get_server_world(), "ancestor_hands", x, y, z, attack.anim, 22, yaw, 0)
                after(attack.hit_delay, function()
                    damage_near(player, x, y + 0.7, z, 5, 8, SKILL.ancestral_damage)
                    push_entities_near(player, x, y, z, 5, 8, attack.lift)
                end)
            end)
        end
        sound(player, "minecraft:item.trident.thunder", 0.9, 0.8)
    else
        local x, y, z, pyaw = offset_position(player, 5, 0, 0, 0)
        spawn_vfx(player:get_server_world(), "nature_hands", x, y, z, "animation", 124, pyaw, 0)
        every(20, 22, 5, function()
            heal_players_near(player, x, y + 2, z, 4, 8, 0)
            command_as_player(player, "effect give @s minecraft:resistance 1 1 true")
        end)
        sound(player, "minecraft:block.beacon.activate", 0.8, 1.25)
    end
end

local function handle_sneak_only(player)
    local ps = player_state(player)
    if state.tick <= ps.sneak_tap_until then
        ps.sneak_tap_until = 0
        if not switch_active_totem(player) then
            cast_ritual_totem(player)
        end
    else
        ps.sneak_tap_until = state.tick + 5
    end
end

aris.game.hook.add_on_left_click(function(event)
    local player = event:get_player()
    if player == nil or not is_lifescepter(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_ancestral_hands(player)
    else
        cast_primal_combo(player)
    end
end)

aris.game.hook.add_on_right_click(function(event)
    local player = event:get_player()
    if player == nil or not is_lifescepter(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_earthen_embrace(player)
    else
        cast_echo_step(player)
    end
end)

while true do
    state.tick = state.tick + 1

    local i = 1
    while i <= #state.timers do
        local timer = state.timers[i]
        if timer.at <= state.tick then
            table.remove(state.timers, i)
            timer.fn()
        else
            i = i + 1
        end
    end

    i = 1
    while i <= #state.projectiles do
        local projectile = state.projectiles[i]
        projectile.age = projectile.age + 1
        projectile.x = projectile.x + projectile.dx * projectile.speed
        projectile.z = projectile.z + projectile.dz * projectile.speed
        if projectile.tag ~= nil then
            move_tagged_vfx(projectile.tag, projectile.x, projectile.y, projectile.z, projectile.yaw, 0)
        elseif is_entity_object(projectile.entity) then
            projectile.entity:move_to(projectile.x, projectile.y, projectile.z)
        end
        if projectile.age % 5 == 0 and projectile.damage ~= nil then
            damage_near(projectile.caster, projectile.x, projectile.y, projectile.z, projectile.radius, 5, projectile.damage)
        end
        if projectile.age >= projectile.life then
            if projectile.on_end ~= nil then
                projectile.on_end(projectile)
            end
            if is_entity_object(projectile.entity) then
                projectile.entity:remove()
            end
            if projectile.tag ~= nil then
                remove_tagged_vfx(projectile.tag)
            end
            table.remove(state.projectiles, i)
        else
            i = i + 1
        end
    end

    for id, ps in pairs(state.players) do
        local player = ps.player
        if player == nil or not is_lifescepter(player) then
            remove_active_totem(ps)
            state.players[id] = nil
        else
            if ps.active_totem ~= nil and ps.active_totem.until_tick <= state.tick then
                ps.active_totem = nil
            end
            if state.tick % SKILL.soul_link_timer == 0 then
                soul_link_tick(player)
            end
            if state.tick % SKILL.stance_timer == 0 and player:get_is_sneaking() then
                ps.stance_stack = (ps.stance_stack or 0) + 1
                if ps.stance_stack >= 2 then
                    ps.stance_stack = 0
                    cast_stance_switch(player)
                end
            elseif state.tick % SKILL.stance_timer == 0 then
                ps.stance_stack = 0
            end

            local sneaking = player:get_is_sneaking()
            if sneaking and not ps.sneak_down and state.tick > ps.sneak_click_until then
                handle_sneak_only(player)
            end
            ps.sneak_down = sneaking
        end
    end

    task_sleep(50)
end
