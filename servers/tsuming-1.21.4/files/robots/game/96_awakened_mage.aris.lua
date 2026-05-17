local DEG_TO_RAD = math.pi / 180

local state = {
    tick = 0,
    timers = {},
    auras = {},
    cooldowns = {},
    players = {},
    projectiles = {},
    next_vfx_id = 0,
}

local SKILL = {
    item_name = "Runestaff",
    material = "STONE_SWORD",
    custom_model_data = 2089,
    combo_damage = 5,
    burn_damage = 1,
    burn_duration = 3,
    slow_duration = 3,
    teleport_damage = 5,
    stun_duration = 2,
    barrage_damage = 5,
    cryo_damage = 6,
    freeze_damage = 5,
    freeze_duration = 3,
    hail_damage = 5,
    hail_slow_duration = 4,
    meteor_damage = 20,
    meteor_burn_damage = 2,
    meteor_burn_duration = 7,
}

local VFX_NBT = "Invulnerable:1b,NoAI:1b,Silent:1b,NoGravity:1b,PersistenceRequired:0b,DeathLootTable:\"minecraft:empty\",CanPickUpLoot:0b,Health:1000000f,attributes:[{id:\"minecraft:max_health\",base:1000000d},{id:\"minecraft:armor\",base:1000000d}],Attributes:[{Name:\"minecraft:generic.max_health\",Base:1000000d},{Name:\"minecraft:generic.armor\",Base:1000000d}]"
local VFX_SELECTOR_EXCLUDE = ",tag=!am_mage_caster,tag=!aa_vfx"

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
    if current ~= nil and current.until_tick > state.tick then
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

local function can_cast(entity, name, cooldown_ticks)
    local key = aura_key(entity, "cooldown_" .. name)
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

local function yaw_vector(yaw, horizontal_offset_degrees)
    local angle = (yaw + (horizontal_offset_degrees or 0)) * DEG_TO_RAD
    return -math.sin(angle), math.cos(angle)
end

local function offset_position(entity, forward_offset, y_offset, side_offset, yaw_offset)
    local yaw = entity:get_yaw() + (yaw_offset or 0)
    local dx, dz = yaw_vector(yaw, 0)
    local sx, sz = math.cos(yaw * DEG_TO_RAD), math.sin(yaw * DEG_TO_RAD)
    local x = entity:get_x() + dx * (forward_offset or 0) + sx * (side_offset or 0)
    local y = entity:get_y() + (y_offset or 0)
    local z = entity:get_z() + dz * (forward_offset or 0) + sz * (side_offset or 0)
    return x, y, z, yaw
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

local function particle_at(x, y, z, id, amount, dx, dy, dz, speed)
    aris.game.dispatch_command("particle " .. id .. " " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " " .. tostring(dx or 0.3) .. " " .. tostring(dy or 0.3) .. " " .. tostring(dz or 0.3) .. " " .. tostring(speed or 0) .. " " .. tostring(amount or 10))
end

local function is_runestaff(player)
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

local function kill_later(entity, tag, delay)
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
    local tag = "am_vfx_" .. tostring(state.next_vfx_id)
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

local function spawn_vfx_at_player(player, key, y_offset, forward_offset, side_offset, anim, life, yaw_offset)
    local x, y, z, yaw = offset_position(player, forward_offset or 0, y_offset or 0, side_offset or 0, yaw_offset or 0)
    return spawn_vfx(player:get_server_world(), key, x, y, z, anim, life, yaw, 0)
end

local function mark_caster(player)
    command_as_player(player, "tag @s add am_mage_caster")
end

local function unmark_caster(player)
    command_as_player(player, "tag @s remove am_mage_caster")
end

local function damage_near(caster, x, y, z, radius, limit, damage)
    local entity_selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local player_selector = "@a[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. VFX_SELECTOR_EXCLUDE .. "]"
    local base = "execute positioned " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z) .. " as "
    mark_caster(caster)
    aris.game.dispatch_command(base .. entity_selector .. " at @s run damage @s " .. tostring(damage))
    aris.game.dispatch_command(base .. player_selector .. " at @s run damage @s " .. tostring(damage))
    unmark_caster(caster)
    particle_at(x, y, z, "minecraft:crit", 8, 0.25, 0.25, 0.25, 0.05)
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

local function burn_near(caster, x, y, z, radius, limit, damage, duration)
    for i = 1, (duration or 3) - 1 do
        after(i * 20, function()
            damage_near(caster, x, y, z, radius, limit, damage)
            particle_at(x, y + 1, z, "minecraft:small_flame", 10, 0.3, 0.7, 0.3, 0.03)
        end)
    end
end

local function freeze_near(caster, x, y, z, radius, limit, damage, duration)
    damage_near(caster, x, y, z, radius, limit, damage)
    effect_near(caster, x, y, z, radius, limit, "slowness", duration, 255)
    effect_near(caster, x, y, z, radius, limit, "mining_fatigue", duration, 4)
    particle_at(x, y + 1, z, "minecraft:snowflake", 30, 1.2, 1.2, 1.2, 0.03)
end

local function explosion_vfx(player, x, y, z, radius)
    spawn_vfx(player:get_server_world(), "fireball_explosion_1", x, y, z, "animation", 10, player:get_yaw(), 0)
    spawn_vfx(player:get_server_world(), "fireball_explosion_1", x, y, z, "animation2", 10, player:get_yaw() + 90, 0)
    particle_at(x, y, z, "minecraft:campfire_cosy_smoke", 6, radius or 0.4, 0.4, radius or 0.4, 0.05)
end

local function spawn_projectile(caster, model, anim, opts)
    opts = opts or {}
    local x, y, z, yaw = offset_position(caster, opts.start_forward or 0.5, 1.2 + (opts.start_y or 0), opts.side_offset or 0, opts.yaw_offset or 0)
    local dx, dz = yaw_vector(yaw, 0)
    local vfx = spawn_vfx(caster:get_server_world(), model, x, y, z, anim, opts.life or opts.max_ticks or 30, yaw, opts.pitch or 0)
    state.projectiles[#state.projectiles + 1] = {
        caster = caster,
        entity = vfx,
        x = x,
        y = y,
        z = z,
        dx = dx,
        dz = dz,
        yaw = yaw,
        speed = opts.speed or 1,
        dy = opts.dy or 0,
        impact_y = opts.impact_y,
        tick_damage = opts.tick_damage,
        tick_radius = opts.tick_radius or 3,
        tick_limit = opts.tick_limit or 10,
        tick_interval = opts.tick_interval or 1,
        tick_hit_once = opts.tick_hit_once,
        hit_done = false,
        tick_effect = opts.tick_effect,
        max_ticks = opts.max_ticks or 12,
        age = 0,
        on_end = opts.on_end,
    }
end

local function update_projectiles()
    local remaining = {}
    for _, p in ipairs(state.projectiles) do
        p.age = p.age + 1
        p.x = p.x + p.dx * p.speed
        p.y = p.y + p.dy
        p.z = p.z + p.dz * p.speed
        if is_entity_object(p.entity) then
            p.entity:move_to(p.x, p.y, p.z)
        end
        if p.tick_damage ~= nil and p.tick_damage > 0 and p.age % p.tick_interval == 0 and not p.hit_done then
            damage_near(p.caster, p.x, p.y, p.z, p.tick_radius, p.tick_limit, p.tick_damage)
            if p.tick_effect ~= nil then
                p.tick_effect(p)
            end
            if p.tick_hit_once then
                p.hit_done = true
            end
        end
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
            next_timer = 0,
            next_mana_barrier = 0,
            cryo_stack = 0,
        }
        state.players[id] = current
    else
        current.player = player
    end
    return current
end

local function cast_sorcery_combo(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Sorcery_Combo", 6) then
        return
    end
    local stacks = aura_stacks(player, "Sorcery_Combo_Stack")
    if stacks == 0 then
        add_aura(player, "Sorcery_Combo_Stack", 300, 1, 3)
        sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_ball", 0.7, 1)
        spawn_projectile(player, "fireball", "animation", {
            speed = 1.7,
            tick_damage = SKILL.combo_damage,
            tick_radius = 3.2,
            tick_limit = 10,
            tick_interval = 1,
            max_ticks = 8,
            on_end = function(p)
                explosion_vfx(player, p.x, p.y, p.z, 0.4)
                damage_near(player, p.x, p.y, p.z, 3, 5, SKILL.combo_damage)
                burn_near(player, p.x, p.y, p.z, 3, 5, SKILL.burn_damage, SKILL.burn_duration)
                sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_explode", 0.7, 1)
            end,
        })
    elseif stacks == 1 then
        add_aura(player, "Sorcery_Combo_Stack", 300, 1, 3)
        sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_ball", 0.7, 1)
        spawn_projectile(player, "fireball", "animation", {
            speed = 1.7,
            tick_damage = SKILL.combo_damage,
            tick_radius = 3.2,
            tick_limit = 10,
            tick_interval = 1,
            max_ticks = 8,
            on_end = function(p)
                explosion_vfx(player, p.x, p.y, p.z, 0.4)
                damage_near(player, p.x, p.y, p.z, 3, 5, SKILL.combo_damage)
                burn_near(player, p.x, p.y, p.z, 3, 5, SKILL.burn_damage, SKILL.burn_duration)
                sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_explode", 0.7, 1)
            end,
        })
    elseif stacks == 2 then
        add_aura(player, "Sorcery_Combo_Stack", 300, 1, 3)
        spawn_vfx_at_player(player, "glacial_spike", 1.3, 0.5, 0, "animation", 20)
        sound(player, "awakened_mage_sounds:samus.awakened_mage.glacial_spikes_shoot", 0.7, 1)
        for i, yaw_offset in ipairs({ -45, -22.5, 0, 22.5, 45 }) do
            after((i - 1) * 3, function()
                spawn_projectile(player, "glacial_spike", "animation", {
                    yaw_offset = yaw_offset,
                    speed = 1.2,
                    tick_damage = SKILL.combo_damage,
                    tick_radius = 2.6,
                    tick_limit = 8,
                    tick_interval = 1,
                    tick_effect = function(p)
                        effect_near(player, p.x, p.y, p.z, 2, 3, "slowness", SKILL.slow_duration, 1)
                    end,
                    max_ticks = 7,
                    on_end = function(p)
                        damage_near(player, p.x, p.y, p.z, 3, 3, SKILL.combo_damage)
                        effect_near(player, p.x, p.y, p.z, 3, 3, "slowness", SKILL.slow_duration, 1)
                    end,
                })
            end)
        end
    else
        remove_aura(player, "Sorcery_Combo_Stack")
        add_aura(player, "CASTING", 18, 1, 1)
        local x, y, z, yaw = offset_position(player, 8, 0.1, 0, 0)
        after(1, function()
            spawn_vfx(player:get_server_world(), "thunder_strike_1", x, y, z, "animation2", 10, yaw, 0)
            spawn_vfx(player:get_server_world(), "thunder_strike_1", x, y, z, "animation3", 10, yaw + 25, 0)
            spawn_vfx(player:get_server_world(), "thunder_strike_1", x, y, z, "animation4", 10, yaw - 25, 0)
            spawn_vfx(player:get_server_world(), "vfx_earthquake_rupture_1", x, y, z, "skill2", 52, yaw, 0)
            spawn_vfx(player:get_server_world(), "vfx_rubbles", x, y, z, "skill", 45, yaw, 0)
            particle_at(x, y, z, "minecraft:campfire_cosy_smoke", 7, 1, 0.1, 1, 0.07)
            sound(player, "awakened_mage_sounds:samus.awakened_mage.thunder_strike", 0.7, 1)
        end)
        after(2, function()
            damage_near(player, x, y + 1, z, 5, 7, SKILL.combo_damage)
        end)
    end
end

local function cast_teleport_strike(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Teleport_Strike", 40) then
        return
    end
    add_aura(player, "CASTING", 5, 1, 1)
    prevent_fall_damage(player, 2)
    spawn_vfx_at_player(player, "thunder_teleport_1", 0, 0, 0, "animation", 10)
    after(1, function()
        player:add_velocity_relative(4, 0, 0)
        sound(player, "awakened_mage_sounds:samus.awakened_mage.thunder_teleport", 1, 1)
    end)
    after(5, function()
        spawn_vfx_at_player(player, "thunder_teleport_1", 0, 0, 0, "animation", 10)
        spawn_vfx_at_player(player, "thunder_explosion_1", 0, 0, 0, "animation", 14)
        sound(player, "awakened_mage_sounds:samus.awakened_mage.thunder_strike", 0.7, 0.7)
        damage_near(player, player:get_x(), player:get_y() + 1, player:get_z(), 5, 7, SKILL.teleport_damage)
        effect_near(player, player:get_x(), player:get_y() + 1, player:get_z(), 5, 7, "slowness", SKILL.stun_duration, 255)
        particle_at(player:get_x(), player:get_y() + 2.3, player:get_z(), "minecraft:crit", 22, 0.5, 0.1, 0.5, 0)
    end)
end

local function cast_blazing_barrage(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Blazing_Barrage", 60) then
        return
    end
    add_aura(player, "CASTING", 55, 1, 1)
    sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_circle", 0.7, 1)
    local circles = {
        { "animation6", -1.05, -2 },
        { "animation7", 1.05, 2 },
        { "animation4", -3.15, -2 },
        { "animation5", 3.15, 2 },
        { "animation2", -1.55, -2 },
        { "animation3", 1.55, 2 },
    }
    for i, data in ipairs(circles) do
        local delay = (i - 1) * 3
        after(delay, function()
            local height = 2.4
            if i >= 5 then
                height = 3.5
            end
            spawn_vfx_at_player(player, "magic_fire_circle", height, 0, 0, data[1], 28)
            sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_ball", 0.7, 1)
        end)
        after(delay + 4, function()
            spawn_projectile(player, "fireball", i % 2 == 0 and "animation4" or "animation3", {
                side_offset = data[2],
                yaw_offset = data[3],
                start_forward = -0.4,
                start_y = i >= 5 and 0.55 or -0.65,
                speed = 0.5 + (i * 0.12),
                tick_damage = SKILL.barrage_damage,
                tick_radius = 3,
                tick_limit = 8,
                tick_interval = 1,
                max_ticks = 14,
                on_end = function(p)
                    explosion_vfx(player, p.x, p.y, p.z, 0.4)
                    damage_near(player, p.x, p.y, p.z, 3, 3, SKILL.barrage_damage)
                    burn_near(player, p.x, p.y, p.z, 3, 3, SKILL.burn_damage, SKILL.burn_duration)
                    sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_explode", 0.7, 1)
                end,
            })
        end)
    end
    after(28, function()
        spawn_vfx_at_player(player, "big_fireball_charge", 0, 0, 0, "animation", 57)
        sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_circle", 0.7, 0.55)
    end)
    after(58, function()
        sound(player, "awakened_mage_sounds:samus.awakened_mage.fire_blast", 0.7, 1)
        spawn_projectile(player, "fireball", "animation", {
            speed = 1.5,
            tick_damage = SKILL.barrage_damage,
            tick_radius = 4,
            tick_limit = 10,
            tick_interval = 1,
            max_ticks = 8,
            on_end = function(p)
                explosion_vfx(player, p.x, p.y, p.z, 1)
                damage_near(player, p.x, p.y, p.z, 4, 7, SKILL.barrage_damage)
                burn_near(player, p.x, p.y, p.z, 4, 7, SKILL.burn_damage, SKILL.burn_duration)
            end,
        })
    end)
end

local function cast_cryo_prison(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Cryo_Prison", 60) then
        return
    end
    add_aura(player, "CASTING", 10, 1, 1)
    local x, y, z, yaw = offset_position(player, 8, 0.1, 0, 0)
    spawn_vfx(player:get_server_world(), "cryo_prison", x, y, z, "animation", 111, yaw, 0)
    sound(player, "awakened_mage_sounds:samus.awakened_mage.ice_charge", 1, 0.75)
    after(24, function()
        particle_at(x, y + 1.5, z, "minecraft:snowflake", 40, 3.5, 2, 3.5, 0.07)
        sound(player, "awakened_mage_sounds:samus.awakened_mage.ice_spike_creation", 0.7, 0.75)
        freeze_near(player, x, y + 1, z, 7, 15, SKILL.cryo_damage, SKILL.freeze_duration)
        after(1, function()
            freeze_near(player, x, y + 1, z, 7, 15, SKILL.freeze_damage, SKILL.freeze_duration)
        end)
    end)
end

local function cast_hailpiercer(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Hailpiercer", 60) then
        return
    end
    add_aura(player, "CASTING", 35, 1, 1)
    spawn_vfx_at_player(player, "hailpiercer_inhale_breath", 0, 1.5, 0, "animation", 28)
    sound(player, "awakened_mage_sounds:samus.awakened_mage.ice_charge", 1, 1)
    every(0, 6, 5, function()
        particle_at(player:get_x(), player:get_y() + 1, player:get_z(), "minecraft:snowflake", 8, 0.45, 0.9, 0.45, 0.03)
    end)
    local function hail_hit(forward_offset, side_offset)
        local x, y, z = offset_position(player, forward_offset, 1, side_offset or 0, 0)
        damage_near(player, x, y, z, 6.5, 8, SKILL.hail_damage)
        effect_near(player, x, y, z, 6.5, 8, "slowness", SKILL.hail_slow_duration, 1)
        particle_at(x, y, z, "minecraft:snowflake", 24, 1.2, 0.5, 1.2, 0.03)
        particle_at(x, y + 0.4, z, "minecraft:snowflake", 18, 1.2, 0.9, 1.2, 0.03)
    end
    local function hail_burst(forward_offset, side_offset)
        hail_hit(forward_offset, side_offset or 0)
    end
    local function delayed_hail_burst(delay, forward_offset, side_offset)
        after(delay, function()
            hail_burst(forward_offset, side_offset)
        end)
    end
    after(30, function()
        sound(player, "awakened_mage_sounds:samus.awakened_mage.ice_spike_creation", 0.7, 1)
        spawn_vfx_at_player(player, "hailpiercer", 0, 2, 0, "ice_spike_o", 42)
        delayed_hail_burst(2, 3, 0)
    end)
    after(35, function()
        sound(player, "awakened_mage_sounds:samus.awakened_mage.ice_spike_creation", 0.7, 1)
        spawn_vfx_at_player(player, "hailpiercer", 0, 6, -1, "ice_spike", 42)
        delayed_hail_burst(8, 7, -0.5)
    end)
    after(40, function()
        sound(player, "awakened_mage_sounds:samus.awakened_mage.ice_spike_creation", 0.7, 1)
        spawn_vfx_at_player(player, "hailpiercer", 0, 10, 0, "ice_spike2", 42)
        delayed_hail_burst(12, 11, 0)
    end)
end

local function cast_meteor_of_doom(player)
    if has_aura(player, "CASTING") or not can_cast(player, "Meteor_Of_Doom", 140) then
        return
    end
    add_aura(player, "CASTING", 45, 1, 1)
    prevent_fall_damage(player, 5)
    local ground_y = player:get_y()
    player:add_velocity_relative(0, 0.65, 0)
    spawn_vfx_at_player(player, "magic_fire_circle", 3.0, 1.8, 0, "animation", 28)
    spawn_vfx_at_player(player, "big_fireball_charge", 2.6, 2.2, 0, "animation", 36)
    sound(player, "awakened_mage_sounds:samus.awakened_mage.meteor_creation", 1, 1)
    after(25, function()
        player:add_velocity_relative(0, -0.55, 0)
    end)
    after(40, function()
        sound(player, "awakened_mage_sounds:samus.awakened_mage.meteor_shoot", 0.7, 1)
        spawn_projectile(player, "meteor_of_doom", "meteor_impact", {
            start_forward = 8,
            start_y = 8,
            speed = 0,
            dy = -0.7,
            tick_damage = 0,
            max_ticks = 12,
            pitch = 90,
            impact_y = ground_y + 0.2,
            on_end = function(p)
                local iy = p.impact_y or p.y
                damage_near(player, p.x, iy + 1, p.z, 10, 10, SKILL.meteor_damage)
                burn_near(player, p.x, iy + 1, p.z, 10, 10, SKILL.meteor_burn_damage, SKILL.meteor_burn_duration)
                spawn_vfx(player:get_server_world(), "meteor_of_doom_cross", p.x, iy, p.z, "meteor_impact", 97, player:get_yaw(), 0)
                explosion_vfx(player, p.x, iy + 1, p.z, 3)
                after(3, function() explosion_vfx(player, p.x + 3, iy + 0.6, p.z, 3) end)
                after(6, function() explosion_vfx(player, p.x - 3, iy + 0.6, p.z, 3) end)
                particle_at(p.x, iy + 0.6, p.z, "minecraft:small_flame", 40, 2.3, 1.2, 2.3, 0.1)
                particle_at(p.x, iy + 0.6, p.z, "minecraft:campfire_cosy_smoke", 25, 2.3, 1.2, 2.3, 0.1)
                sound(player, "awakened_mage_sounds:samus.awakened_mage.meteor_explosion", 1, 1)
                sound(player, "universal_sounds:samus.universal.rupture_quick", 0.8, 1)
            end,
        })
    end)
end

local function cast_mana_barrier(player)
    local ps = player_state(player)
    if state.tick < ps.next_mana_barrier then
        return
    end
    ps.next_mana_barrier = state.tick + 140
    for i = 0, 29 do
        after(i, function()
            local angle = (i * 12) * DEG_TO_RAD
            local r = 0.8
            local x = player:get_x() + math.cos(angle) * r
            local z = player:get_z() + math.sin(angle) * r
            particle_at(x, player:get_y() + 1, z, "minecraft:dust_color_transition 0.52 0.85 1 1 0.47 0.07 1", 2, 0.02, 0.02, 0.02, 0)
            particle_at(x, player:get_y() + 1.3, z, "minecraft:dust_color_transition 0.52 0.85 1 1 0.47 0.07 1", 2, 0.02, 0.02, 0.02, 0)
            particle_at(x, player:get_y() + 0.7, z, "minecraft:dust_color_transition 0.52 0.85 1 1 0.47 0.07 1", 2, 0.02, 0.02, 0.02, 0)
        end)
    end
end

local function cast_sneak_only_skill(player)
    local ps = player_state(player)
    if ps.blazing_until ~= nil and ps.blazing_until > state.tick then
        ps.blazing_until = nil
        cast_blazing_barrage(player)
    else
        ps.blazing_until = state.tick + 5
    end
end

aris.game.hook.add_on_left_click(function(event)
    local player = event:get_player()
    if player == nil or not is_runestaff(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_meteor_of_doom(player)
    else
        cast_sorcery_combo(player)
    end
end)

aris.game.hook.add_on_right_click(function(event)
    local player = event:get_player()
    if player == nil or not is_runestaff(player) then
        return
    end
    local ps = player_state(player)
    if player:get_is_sneaking() then
        ps.sneak_click_until = state.tick + 3
        cast_hailpiercer(player)
    else
        cast_teleport_strike(player)
    end
end)

while true do
    state.tick = state.tick + 1

    local timers = {}
    for _, timer in ipairs(state.timers) do
        if timer.at <= state.tick then
            timer.fn()
        else
            timers[#timers + 1] = timer
        end
    end
    state.timers = timers

    update_projectiles()

    for id, ps in pairs(state.players) do
        local player = ps.player
        if player == nil or not is_runestaff(player) then
            state.players[id] = nil
        else
            local sneaking = player:get_is_sneaking()
            if sneaking and not ps.sneak_down and state.tick > ps.sneak_click_until then
                cast_sneak_only_skill(player)
            end
            ps.sneak_down = sneaking

            if state.tick >= (ps.next_timer or 0) then
                ps.next_timer = state.tick + 200
                cast_mana_barrier(player)
                if sneaking then
                    ps.cryo_stack = (ps.cryo_stack or 0) + 1
                    if ps.cryo_stack >= 2 then
                        ps.cryo_stack = 0
                        cast_cryo_prison(player)
                    end
                else
                    ps.cryo_stack = 0
                end
            end
        end
    end

    task_sleep(50)
end
