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
    item_name = "Soultome",
    material = "STONE_SWORD",
    custom_model_data = 2091,
    spirit_wolf_damage = 4,
    spirit_wolf_timer = 60,
    soul_combo_damage = 3,
    soul_combo_cooldown = 4,
    blade_wheel_damage = 4,
    blade_wheel_cooldown = 40,
    minion_axe_damage = 3,
    minion_spin_damage = 2,
    minion_crossbow_damage = 4,
    summon_minion_cooldown = 20,
    command_timer = 200,
    command_cooldown = 20,
    soul_spear_damage = 3,
    soul_spear_stun_seconds = 3,
    soul_spear_cooldown = 60,
    summon_dragon_damage = 7,
    summon_dragon_cooldown = 200,
}

local VFX_NBT = "Invulnerable:1b,NoAI:1b,Silent:1b,NoGravity:1b,PersistenceRequired:0b,DeathLootTable:\"minecraft:empty\",CanPickUpLoot:0b,Health:1000000f,attributes:[{id:\"minecraft:max_health\",base:1000000d},{id:\"minecraft:armor\",base:1000000d}],Attributes:[{Name:\"minecraft:generic.max_health\",Base:1000000d},{Name:\"minecraft:generic.armor\",Base:1000000d}]"
local VFX_SELECTOR_EXCLUDE = ",tag=!as_summoner_caster,tag=!aa_vfx"

local function uuid(entity)
    return entity:get_uuid()
end

local function cooldown_key(entity, name)
    return uuid(entity) .. ":" .. name
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
    local x = base_x + dx * (forward or 0) + sx * (side or 0)
    local y = base_y + (y_offset or 0)
    local z = base_z + dz * (forward or 0) + sz * (side or 0)
    return x, y, z
end

local function run_command_at(entity, command)
    aris.game.dispatch_command("execute positioned " .. tostring(entity:get_x()) .. " " .. tostring(entity:get_y()) .. " " .. tostring(entity:get_z()) .. " run " .. command)
end

local function command_as_player(player, command)
    aris.game.dispatch_command("execute positioned " .. tostring(player:get_x()) .. " " .. tostring(player:get_y()) .. " " .. tostring(player:get_z()) .. " as @p[distance=..1,limit=1,sort=nearest] run " .. command)
end

local function sound(entity, id, volume, pitch)
    run_command_at(entity, "playsound " .. id .. " master @a[distance=..32] ~ ~ ~ " .. tostring(volume or 0.7) .. " " .. tostring(pitch or 1))
end

local function particle_at(x, y, z, id, amount, dx, dy, dz, speed)
    aris.game.dispatch_command("particle " .. id .. " " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " " .. tostring(dx or 0.3) .. " " .. tostring(dy or 0.3) .. " " .. tostring(dz or 0.3) .. " " .. tostring(speed or 0) .. " " .. tostring(amount or 10))
end

local function is_soultome(player)
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

local function clear_dragon_vfx()
    aris.game.dispatch_command("tp @e[type=aris:spirit_dragon,tag=aa_vfx] 0 -10000 0")
    aris.game.dispatch_command("tp @e[type=aris:soul_fireball,tag=aa_vfx] 0 -10000 0")
    aris.game.dispatch_command("tp @e[type=aris:soul_fire_breath,tag=aa_vfx] 0 -10000 0")
end

local function clear_soul_blade_slash()
    aris.game.dispatch_command("tp @e[type=aris:soul_blades_1,tag=aa_vfx] 0 -10000 0")
end

local function clear_summon_minion_vfx()
    aris.game.dispatch_command("tp @e[type=aris:axe_minion_1,tag=aa_vfx] 0 -10000 0")
    aris.game.dispatch_command("tp @e[type=aris:crossbow_minion,tag=aa_vfx] 0 -10000 0")
    aris.game.dispatch_command("tp @e[type=aris:vfx_arrow,tag=aa_vfx] 0 -10000 0")
end

local function clear_spirit_wolf_vfx()
    aris.game.dispatch_command("tp @e[type=aris:spirit_wolf,tag=aa_vfx] 0 -10000 0")
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
    local tag = "as_vfx_" .. tostring(state.next_vfx_id)
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

local function spawn_vfx_at_player(player, key, y_offset, forward, side, anim, life, yaw_offset)
    local x, y, z, yaw = offset_position(player, forward or 0, y_offset or 0, side or 0, yaw_offset or 0)
    return spawn_vfx(player:get_server_world(), key, x, y, z, anim, life, yaw, 0)
end

local function mark_caster(player)
    command_as_player(player, "tag @s add as_summoner_caster")
end

local function unmark_caster(player)
    command_as_player(player, "tag @s remove as_summoner_caster")
end

local function damage_near(caster, x, y, z, radius, limit, damage)
    local entity_selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local player_selector = "@a[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    mark_caster(caster)
    aris.game.dispatch_command(base .. entity_selector .. " at @s run damage @s " .. tostring(damage))
    aris.game.dispatch_command(base .. player_selector .. " at @s run damage @s " .. tostring(damage))
    unmark_caster(caster)
    particle_at(x, y + 0.9, z, "minecraft:crit", 6, 0.25, 0.25, 0.25, 0.05)
end

local function damage_near_non_players(caster, x, y, z, radius, limit, damage)
    local entity_selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest,type=!minecraft:player,type=!aris:spirit_wolf,type=!aris:axe_minion_1,type=!aris:crossbow_minion,type=!aris:vfx_arrow,type=!aris:vfx_summon" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    mark_caster(caster)
    aris.game.dispatch_command(base .. entity_selector .. " at @s run damage @s " .. tostring(damage))
    unmark_caster(caster)
    particle_at(x, y + 0.9, z, "minecraft:crit", 6, 0.25, 0.25, 0.25, 0.05)
end

local function stun_vfx_near(caster, x, y, z, radius, limit, duration_ticks)
    local entity_selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local player_selector = "@a[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    mark_caster(caster)
    every(0, duration_ticks, 4, function()
        aris.game.dispatch_command(base .. entity_selector .. " at @s run particle minecraft:crit ~ ~2.3 ~ 0.35 0.08 0.35 0.02 6")
        aris.game.dispatch_command(base .. player_selector .. " at @s run particle minecraft:crit ~ ~2.3 ~ 0.35 0.08 0.35 0.02 6")
    end)
    unmark_caster(caster)
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

local function push_near(caster, x, y, z, radius, limit, y_motion)
    local entity_selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    mark_caster(caster)
    aris.game.dispatch_command(base .. entity_selector .. " at @s run data merge entity @s {Motion:[0.0d," .. tostring(y_motion) .. "d,0.0d]}")
    unmark_caster(caster)
end

local function player_state(player)
    local id = uuid(player)
    local ps = state.players[id]
    if ps == nil then
        ps = {
            player = player,
            combo = 0,
            combo_until = 0,
            sneak_click_until = 0,
            sneak_down = false,
            sneak_tap_until = 0,
            minion_type = "axe",
            stance = "idle",
            last_wolf_tick = -999,
            last_command_tick = 0,
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

local function cast_soul_combo(player)
    if not can_cast(player, "soul_combo", SKILL.soul_combo_cooldown) then
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

    local anims = {
        "left_slash",
        "right_slash2_up_slash1",
        "right_slash2_slash1_slash2",
        "duo_slash",
    }
    local lives = { 7, 9, 11, 7 }
    clear_soul_blade_slash()
    spawn_vfx_at_player(player, "soul_blades_1", 1.2, 1.0, 0, anims[ps.combo], lives[ps.combo])
    sound(player, "minecraft:entity.player.attack.sweep", 0.7, 0.9 + ps.combo * 0.08)

    local delays = { { 1 }, { 1, 5 }, { 1, 4, 9 }, { 1 } }
    for _, delay in ipairs(delays[ps.combo]) do
        after(delay, function()
            local x, y, z = offset_position(player, 2.2, 0.8, 0, 0)
            damage_near(player, x, y, z, 3, 5, SKILL.soul_combo_damage)
        end)
    end
end

local function cast_blade_wheel(player)
    if not can_cast(player, "blade_wheel", SKILL.blade_wheel_cooldown) then
        return
    end
    local x, y, z, yaw = offset_position(player, -0.5, 1.0, 0, 0)
    sound(player, "minecraft:entity.breeze.wind_burst", 0.8, 1.1)
    spawn_projectile(player, "soul_blades_1", "spin_sword", x, y, z, yaw, 0.9, 40, 3, SKILL.blade_wheel_damage, nil)
end

local function cast_soul_spear(player)
    if not can_cast(player, "soul_spear", SKILL.soul_spear_cooldown) then
        return
    end
    local x, y, z, yaw = offset_position(player, -0.5, 1.0, 0, 0)
    sound(player, "minecraft:item.trident.throw", 0.8, 0.75)
    every(1, 10, 2, function(i)
        local tx, ty, tz = offset_from_point(x, y, z, yaw, i * 0.9, 0, 0)
        particle_at(tx, ty, tz, "minecraft:soul_fire_flame", 3, 0.05, 0.05, 0.05, 0.01)
    end)
    spawn_projectile(player, "soul_spear_vfx", "on", x, y, z, yaw, 1.0, 35, 5, SKILL.soul_spear_damage, function(projectile)
        spawn_vfx(player:get_server_world(), "soul_spear_vfx", projectile.x, projectile.y - 0.5, projectile.z, "on", 12, projectile.yaw, 90)
        damage_near(player, projectile.x, projectile.y, projectile.z, 5, 15, SKILL.soul_spear_damage)
        effect_near(player, projectile.x, projectile.y, projectile.z, 5, 15, "slowness", SKILL.soul_spear_stun_seconds, 255)
        stun_vfx_near(player, projectile.x, projectile.y, projectile.z, 5, 15, SKILL.soul_spear_stun_seconds * 20)
        spawn_vfx(player:get_server_world(), "vfx_earthquake_rupture_1", projectile.x, projectile.y - 0.9, projectile.z, "skill2", 24, projectile.yaw, 0)
        spawn_vfx(player:get_server_world(), "vfx_rubbles", projectile.x, projectile.y - 0.9, projectile.z, "skill", 22, projectile.yaw, 0)
        particle_at(projectile.x, projectile.y, projectile.z, "minecraft:campfire_cosy_smoke", 14, 1.1, 0.12, 1.1, 0.07)
        particle_at(projectile.x, projectile.y + 0.3, projectile.z, "minecraft:soul_fire_flame", 18, 0.7, 0.25, 0.7, 0.03)
        particle_at(projectile.x, projectile.y + 0.8, projectile.z, "minecraft:enchanted_hit", 22, 0.8, 0.35, 0.8, 0.05)
        sound(player, "minecraft:block.amethyst_block.chime", 0.7, 0.65)
        sound(player, "minecraft:entity.warden.sonic_boom", 0.55, 1.4)
    end)
end

local function command_stance(player)
    local ps = player_state(player)
    if not can_cast(player, "summoners_command", SKILL.command_cooldown) then
        return
    end
    if ps.stance == "idle" then
        ps.stance = "focus"
        particle_at(player:get_x(), player:get_y() + 0.7, player:get_z(), "minecraft:flame", 35, 0.35, 0.6, 0.35, 0.02)
        sound(player, "minecraft:block.trial_spawner.spawn_item", 0.7, 1)
    elseif ps.stance == "focus" then
        ps.stance = "free"
        particle_at(player:get_x(), player:get_y() + 0.7, player:get_z(), "minecraft:happy_villager", 35, 0.35, 0.6, 0.35, 0.02)
        sound(player, "minecraft:block.trial_spawner.spawn_item", 0.7, 1.25)
    else
        ps.stance = "idle"
        particle_at(player:get_x(), player:get_y() + 0.7, player:get_z(), "minecraft:end_rod", 35, 0.35, 0.6, 0.35, 0.02)
        sound(player, "minecraft:block.trial_spawner.spawn_item", 0.7, 1.5)
    end
end

local function spawn_spirit_wolf(player)
    local ps = player_state(player)
    if ps.wolf ~= nil and is_entity_object(ps.wolf) and (ps.wolf_until or 0) > state.tick then
        return
    end
    clear_spirit_wolf_vfx()
    local x, y, z, yaw = offset_position(player, 2, 0, 2, 0)
    spawn_vfx(player:get_server_world(), "vfx_summon", x, y + 0.1, z, "on", 28, yaw, 0)
    ps.wolf, ps.wolf_tag = spawn_vfx(player:get_server_world(), "spirit_wolf", x, y, z, "idle", 90, yaw, 0)
    ps.wolf_until = state.tick + 90
    sound(player, "minecraft:entity.wolf.ambient", 0.7, 1.1)
end

local function wolf_attack(player)
    local ps = player_state(player)
    if not is_entity_object(ps.wolf) or (ps.wolf_until or 0) <= state.tick then
        return
    end
    local anim = "scratch_left"
    if state.tick % 3 == 0 then
        anim = "bite"
    elseif state.tick % 2 == 0 then
        anim = "scratch_right"
    end
    local wx, wy, wz, yaw = offset_position(player, 2.8, 0, 1.0, 0)
    if ps.wolf_tag ~= nil then
        move_tagged_vfx(ps.wolf_tag, wx, wy, wz, yaw, 0)
    elseif is_entity_object(ps.wolf) then
        ps.wolf:move_to(wx, wy, wz)
    end
    trigger_entity_anim(ps.wolf, anim)
    sound(player, "minecraft:entity.wolf.growl", 0.35, 1.2)
    after(5, function()
        local x1, y1, z1 = offset_position(player, 2.6, 0.7, 0, 0)
        local x2, y2, z2 = offset_position(player, 4.6, 0.7, 0, 0)
        damage_near_non_players(player, wx, wy + 0.7, wz, 3.2, 5, SKILL.spirit_wolf_damage)
        damage_near_non_players(player, x1, y1, z1, 3.2, 5, SKILL.spirit_wolf_damage)
        damage_near_non_players(player, x2, y2, z2, 3.2, 5, SKILL.spirit_wolf_damage)
    end)
end

local function cast_summon_minion(player)
    if not can_cast(player, "summon_minion", SKILL.summon_minion_cooldown) then
        return
    end
    local ps = player_state(player)
    local minion_type = ps.minion_type
    ps.minion_type = minion_type == "axe" and "crossbow" or "axe"
    local summon_forward = minion_type == "axe" and 3.2 or 8
    local x, y, z, yaw = offset_position(player, summon_forward, 0, 0, 0)
    clear_summon_minion_vfx()
    spawn_vfx(player:get_server_world(), "vfx_summon", x, y + 0.1, z, "on", minion_type == "axe" and 14 or 24, yaw, 0)
    sound(player, "minecraft:block.trial_spawner.spawn_item", 0.8, 0.9)

    if minion_type == "axe" then
        after(10, function()
            local ax, ay, az, ayaw = offset_position(player, 3.2, 0, -0.9, 0)
            local axe, axe_tag = spawn_vfx(player:get_server_world(), "axe_minion_1", ax, ay, az, "spawn", 64, ayaw, 0)
            every(2, 16, 3, function()
                local mx, my, mz, myaw = offset_position(player, 3.2, 0, -0.9, 0)
                if axe_tag ~= nil then
                    move_tagged_vfx(axe_tag, mx, my, mz, myaw, 0)
                elseif is_entity_object(axe) then
                    axe:move_to(mx, my, mz)
                end
            end)
            every(10, 2, 20, function()
                trigger_entity_anim(axe, "slash")
                after(9, function()
                    local hx, hy, hz = offset_position(player, 3.6, 0.7, -0.6, 0)
                    damage_near(player, hx, hy, hz, 3, 5, SKILL.minion_axe_damage)
                end)
            end)
            after(48, function()
                trigger_entity_anim(axe, "despawn")
            end)
            after(62, function()
                if is_entity_object(axe) then
                    axe:remove()
                end
                if axe_tag ~= nil then
                    remove_tagged_vfx(axe_tag)
                end
            end)
        end)
    else
        after(24, function()
            local crossbow = spawn_vfx(player:get_server_world(), "crossbow_minion", x, y, z, "spawn", 78, yaw, 0)
            every(20, 2, 24, function()
                trigger_entity_anim(crossbow, "shoot")
                after(10, function()
                    local sx, sy, sz = x, y + 1.2, z
                    spawn_projectile(player, "vfx_arrow", "shoot2", sx, sy, sz, yaw, 1.6, 20, 2.5, SKILL.minion_crossbow_damage, nil)
                    sound(player, "minecraft:entity.arrow.shoot", 0.7, 1.1)
                end)
            end)
            after(68, function()
                trigger_entity_anim(crossbow, "despawn")
            end)
        end)
    end
end

local function cast_summon_dragon(player)
    if not can_cast(player, "summon_dragon", SKILL.summon_dragon_cooldown) then
        return
    end
    clear_dragon_vfx()
    local x, y, z, yaw = offset_position(player, 6, 0, 0, 0)
    spawn_vfx(player:get_server_world(), "vfx_summon", x, y + 0.1, z, "on2", 22, yaw, 0)
    sound(player, "minecraft:entity.ender_dragon.growl", 0.75, 1.15)
    after(14, function()
        local dragon, dragon_tag = spawn_vfx(player:get_server_world(), "spirit_dragon", x, y, z, "spawn", 150, yaw, 0)
        after(20, function()
            trigger_entity_anim(dragon, "idle")
        end)
        every(24, 2, 30, function()
            trigger_entity_anim(dragon, "shoot_fireball")
            after(10, function()
                local sx, sy, sz = offset_from_point(x, y, z, yaw, 1.2, 2.0, 0)
                spawn_projectile(player, "soul_fireball", "animation", sx, sy, sz, yaw, 1.6, 18, 5, SKILL.summon_dragon_damage, function(projectile)
                    spawn_vfx(player:get_server_world(), "fireball_explosion", projectile.x, projectile.y, projectile.z, "actived", 16, yaw, 0)
                    spawn_vfx(player:get_server_world(), "vfx_rubbles", projectile.x, projectile.y - 0.8, projectile.z, "skill", 14, yaw, 0)
                    damage_near(player, projectile.x, projectile.y, projectile.z, 5, 8, SKILL.summon_dragon_damage)
                    push_near(player, projectile.x, projectile.y, projectile.z, 5, 8, 0.8)
                    after(3, function()
                        push_near(player, projectile.x, projectile.y, projectile.z, 5, 8, -0.8)
                    end)
                    sound(player, "minecraft:entity.generic.explode", 0.8, 1)
                end)
                sound(player, "minecraft:entity.blaze.shoot", 0.6, 1.1)
            end)
        end)
        after(86, function()
            trigger_entity_anim(dragon, "fire_breath")
            local bx, by, bz = offset_from_point(x, y, z, yaw, 1.6, 1.8, 0)
            spawn_vfx(player:get_server_world(), "soul_fire_breath", bx, by, bz, "loop", 24, yaw, 0)
            sound(player, "minecraft:entity.blaze.shoot", 0.8, 0.7)
            every(10, 7, 2, function(i)
                local hx, hy, hz = offset_from_point(x, y, z, yaw, 2.2 + i * 0.65, 1.2, 0)
                damage_near(player, hx, hy, hz, 3.8, 6, SKILL.summon_dragon_damage)
            end)
        end)
        after(124, function()
            trigger_entity_anim(dragon, "despawn")
        end)
        after(142, function()
            if is_entity_object(dragon) then
                dragon:remove()
            end
            if dragon_tag ~= nil then
                remove_tagged_vfx(dragon_tag)
            end
            clear_dragon_vfx()
        end)
    end)
end

local function handle_sneak_only(player)
    local ps = player_state(player)
    if state.tick <= ps.sneak_tap_until then
        ps.sneak_tap_until = 0
        cast_summon_minion(player)
    else
        ps.sneak_tap_until = state.tick + 5
    end
end

aris.game.hook.add_on_left_click(function(event)
    local player = event:get_player()
    if player == nil or not is_soultome(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_summon_dragon(player)
    else
        cast_soul_combo(player)
    end
end)

aris.game.hook.add_on_right_click(function(event)
    local player = event:get_player()
    if player == nil or not is_soultome(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_soul_spear(player)
    else
        cast_blade_wheel(player)
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
        if player == nil or not is_soultome(player) then
            if ps.wolf_tag ~= nil then
                remove_tagged_vfx(ps.wolf_tag)
            end
            if is_entity_object(ps.wolf) then
                ps.wolf:remove()
            end
            state.players[id] = nil
        else
            if state.tick % SKILL.spirit_wolf_timer == 0 then
                spawn_spirit_wolf(player)
            end
            if state.tick % 20 == 0 then
                wolf_attack(player)
            end
            if state.tick % SKILL.command_timer == 0 and player:get_is_sneaking() then
                ps.command_stack = (ps.command_stack or 0) + 1
                if ps.command_stack >= 2 then
                    ps.command_stack = 0
                    command_stance(player)
                end
            elseif state.tick % SKILL.command_timer == 0 then
                ps.command_stack = 0
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
