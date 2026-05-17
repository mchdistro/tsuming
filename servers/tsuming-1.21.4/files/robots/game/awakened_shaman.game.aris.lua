-- robots/game/awakened_shaman.game.aris.lua
-- MythicMobs Awakened Shaman -> Aris Lua conversion.
-- VFX: item_display only. Summon/modify/remove via commands.
-- NOTE: exact model ids/item_model namespace must match your resource pack.

local TICK_MS = 50
local clock_ms = 0
local states = {}
local delayed = {}
local rng_counter = 0

local CONFIG = {
    weapon_ids = { ["minecraft:stick"] = true, ["minecraft:blaze_rod"] = true }, -- 바꿔주세요
    model_namespace = "awakened_shaman",
    base_item = "minecraft:paper",
    damage = 7,
    heal = 5,
    soul_heal_interval_ms = 1000,
    combo_reset_ms = 15000,
    stance_double_sneak_ms = 6000,
}

local MODELS = {
    impact = {"impact_1","impact_2","impact_3","impact_4","impact_5","impact_6","impact_7"},
    thunder_horiz = {"horizontal_thunder_strike_vfx_1","horizontal_thunder_strike_vfx_2","horizontal_thunder_strike_vfx_3","horizontal_thunder_strike_vfx_4","horizontal_thunder_strike_vfx_5","horizontal_thunder_strike_vfx_6","horizontal_thunder_strike_vfx_7","horizontal_thunder_strike_vfx_8"},
    thunder_constant = "constant_thunder_strike_vfx",
    thunder_vert = {"vertical_thunder_strike_vfx_1","vertical_thunder_strike_vfx_2","vertical_thunder_strike_vfx_3","vertical_thunder_strike_vfx_4","vertical_thunder_strike_vfx_5","vertical_thunder_strike_vfx_6","vertical_thunder_strike_vfx_7","vertical_thunder_strike_vfx_8"},
    heal_horiz = "healing_beam_vfx",
    heal_constant = "constant_healing_beam_vfx",
    heal_vert = "vertical_healing_beam_vfx",
    echo_step = "echo_step",
    hunter_totem = "hunter_totem",
    guardian_totem = "guardian_totem",
    earthen_embrace = "earthen_embrace",
    ancestor_hands = "ancestor_hands",
    nature_hands = "nature_hands",
    rupture = {"vfx_earthquake_rupture_1","vfx_earthquake_rupture_2","vfx_earthquake_rupture_3","vfx_earthquake_rupture_4"},
    rubbles = "vfx_rubbles",
}

local function now_ms()
    return clock_ms
end

local function schedule(delay_ms, fn)
    table.insert(delayed, { at = now_ms() + delay_ms, fn = fn })
end

local function each_tick()
    local t = now_ms()
    local i = 1
    while i <= #delayed do
        if delayed[i].at <= t then
            local fn = delayed[i].fn
            table.remove(delayed, i)
            if type(fn) == "function" then
                fn()
            else
                aris.log_error("[awakened_shaman] bad delayed fn: " .. tostring(fn))
            end
        else
            i = i + 1
        end
    end
end

local function uuid_of(player)
    return player:get_name()
end

local function state_of(player)
    local id = uuid_of(player)
    if states[id] == nil then
        states[id] = { player = player, stance = "thunder", combo = 0, combo_until = 0, sneak_triggered = false, stance_stack = 0, stance_until = 0, ritual_armed_until = 0 }
    end
    states[id].player = player
    return states[id]
end

local function is_holding_shaman_weapon(player)
    local item = player:get_main_hand_item()
    if item == nil then return false end
    local name = item:get_name()
    return CONFIG.weapon_ids[name] == true
end

local function q(s)
    return '"' .. tostring(s):gsub('"', '\\"') .. '"'
end

local function model_id(model)
    if string.find(model, ":") then return model end
    return CONFIG.model_namespace .. ":" .. model
end

local function cmd(c)
    aris.game.dispatch_command(c)
end

local function new_tag(prefix)
    rng_counter = rng_counter + 1
    return "aris_as_" .. prefix .. "_" .. tostring(math.floor(now_ms())) .. "_" .. tostring(rng_counter)
end

local function summon_display_at(worldless, x, y, z, model, life_ms, yaw, pitch, sx, sy, sz)
    local tag = new_tag("vfx")
    sx = sx or 1; sy = sy or sx; sz = sz or sx
    yaw = yaw or 0; pitch = pitch or 0
    local nbt = "{Tags:[" .. q(tag) .. ",\"aris_awakened_shaman_vfx\"],billboard:\"fixed\",brightness:{block:15,sky:15}," ..
        "item_display:\"head\",item:{id:" .. q(CONFIG.base_item) .. ",count:1,components:{\"minecraft:item_model\":" .. q(model_id(model)) .. "}}," ..
        "transformation:{translation:[0f,0f,0f],scale:[" .. sx .. "f," .. sy .. "f," .. sz .. "f],left_rotation:[0f,0f,0f,1f],right_rotation:[0f,0f,0f,1f]}," ..
        "Rotation:[" .. yaw .. "f," .. pitch .. "f]}"
    cmd("summon minecraft:item_display " .. x .. " " .. y .. " " .. z .. " " .. nbt)
    if life_ms ~= nil and life_ms > 0 then
        schedule(life_ms, function() cmd("tp @e[tag=" .. tag .. "] 0 -10000 0") end)
    end
    return tag
end

local function change_display_model(tag, model)
    local nbt = "{item:{id:" .. q(CONFIG.base_item) .. ",count:1,components:{\"minecraft:item_model\":" .. q(model_id(model)) .. "}},item_display:\"head\"}"
    cmd("data merge entity @e[tag=" .. tag .. ",limit=1] " .. nbt)
end

local function pos(player, yoff)
    return player:get_x(), player:get_y() + (yoff or 0), player:get_z()
end

local function forward(player, dist, yoff, side)
    local yaw = math.rad(player:get_yaw())
    local x = player:get_x() + (-math.sin(yaw) * dist) + (math.cos(yaw) * (side or 0))
    local z = player:get_z() + ( math.cos(yaw) * dist) + (math.sin(yaw) * (side or 0))
    return x, player:get_y() + (yoff or 0), z
end

local function spawn_sequence(player, models, x, y, z, frame_ms, scale)
    local yaw = 0
    if player ~= nil then
        yaw = player:get_yaw()
    end
    local tag = summon_display_at(nil, x, y, z, models[1], frame_ms * #models + 100, yaw, 0, scale or 1)
    for i = 2, #models do
        local m = models[i]
        schedule((i - 1) * frame_ms, function() change_display_model(tag, m) end)
    end
    return tag
end

local function spawn_impact(x, y, z)
    spawn_sequence(nil, MODELS.impact, x, y, z, 50, 0.8)
end

local function affect_near(player, radius, damage, heal_players, max_count)
    local x, y, z = pos(player, 1)
    local limit = max_count or 5
    local exclude_vfx = ",type=!minecraft:item_display,type=!minecraft:text_display,type=!minecraft:block_display,type=!minecraft:armor_stand,tag=!aris_awakened_shaman_vfx"
    if damage ~= nil and damage > 0 then
        local selector = "@e[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest" .. exclude_vfx .. "]"
        cmd("execute positioned " .. x .. " " .. y .. " " .. z .. " as " .. selector .. " at @s run damage @s " .. tostring(damage))
    end
    if heal_players == true then
        local selector = "@a[distance=.." .. tostring(radius) .. ",limit=" .. tostring(limit) .. ",sort=nearest]"
        cmd("execute positioned " .. x .. " " .. y .. " " .. z .. " as " .. selector .. " at @s run effect give @s minecraft:regeneration 2 1 true")
    end
end

local function play_sound(player, sound, volume, pitch)
    local x,y,z = pos(player, 1)
    cmd("playsound " .. sound .. " master @a " .. x .. " " .. y .. " " .. z .. " " .. (volume or 0.7) .. " " .. (pitch or 1.0))
end

local function beam(player, thunder, constant, life_ms)
    local model = thunder and MODELS.thunder_constant or MODELS.heal_constant
    if not constant then model = thunder and MODELS.thunder_horiz[1] or MODELS.heal_horiz end
    local x,y,z = forward(player, 1, 1.1, 0)
    local tag = summon_display_at(nil, x, y, z, model, life_ms, player:get_yaw(), player:get_pitch(), 1)
    if type(thunder and MODELS.thunder_horiz or nil) == "table" and not constant then
        local arr = MODELS.thunder_horiz
        for i=2,#arr do local mm=arr[i]; schedule((i-1)*50, function() change_display_model(tag, mm) end) end
    end
end

local function soul_link(player)
    local st = state_of(player)
    if st.stance == "earth" then
        affect_near(player, 10, nil, true, 1)
        local x,y,z = pos(player, 0.05)
        summon_display_at(nil, x, y, z, MODELS.heal_horiz, 950, player:get_yaw(), 0, 0.9)
        play_sound(player, "minecraft:block.amethyst_block.chime", 0.45, 1.2)
    else
        local eff = aris.game.create_effect_builder("minecraft", "strength")
        eff:set_duration(20); eff:set_amplifier(0); eff:set_visible(false); eff:set_showIcon(false)
        player:add_effect(eff)
        local x,y,z = pos(player, 0.05)
        summon_display_at(nil, x, y, z, MODELS.thunder_horiz[1], 350, player:get_yaw(), 0, 0.9)
        play_sound(player, "awakened_shaman_sounds:samus.awakened_shaman.thunder_zap", 0.7, 1.0)
    end
end

local function primal_projectile(player, thunder, strong)
    local steps = strong and 18 or 9
    local dmg = strong and CONFIG.damage * 1.7 or CONFIG.damage
    for i=1,steps do
        schedule(i * 35, function()
            local x,y,z = forward(player, i * 0.75, 1.1, 0)
            if thunder then
                summon_display_at(nil, x, y, z, strong and MODELS.thunder_vert[1] or MODELS.thunder_horiz[1], 250, player:get_yaw(), player:get_pitch(), strong and 1.2 or 0.8)
            else
                summon_display_at(nil, x, y, z, MODELS.heal_horiz, 250, player:get_yaw(), player:get_pitch(), strong and 1.2 or 0.8)
            end
            affect_near(player, 2.2, thunder and dmg or nil, not thunder, strong and 5 or 2)
        end)
    end
    play_sound(player, thunder and "awakened_shaman_sounds:samus.awakened_shaman.thunder_zap" or "minecraft:block.grass.break", 0.7, 1.0)
end

local function primal_combo(player)
    local st = state_of(player)
    local t = now_ms()
    if t > st.combo_until then st.combo = 0 end
    st.combo = (st.combo % 4) + 1
    st.combo_until = t + CONFIG.combo_reset_ms
    local thunder = st.stance ~= "earth"

    if st.combo == 1 then
        beam(player, thunder, false, thunder and 450 or 950)
        primal_projectile(player, thunder, false)
    elseif st.combo == 2 then
        local x,y,z = pos(player, 1.0)
        summon_display_at(nil, x, y, z, thunder and MODELS.thunder_constant or MODELS.heal_constant, 900, player:get_yaw(), 0, 1)
        affect_near(player, 3.0, thunder and CONFIG.damage or nil, not thunder, 5)
    elseif st.combo == 3 then
        beam(player, thunder, false, thunder and 450 or 950)
        primal_projectile(player, thunder, false)
    else
        primal_projectile(player, thunder, true)
        st.combo = 0
    end
end

local function echo_step(player)
    local x,y,z = pos(player, 0.1)
    summon_display_at(nil, x, y, z, MODELS.echo_step, 2000, player:get_yaw(), 0, 1)
    player:add_velocity_relative(1.9, 0.15, 0)
    play_sound(player, "minecraft:entity.enderman.teleport", 0.6, 1.25)
end

local function stance_switch(player)
    local st = state_of(player)
    if st.stance == "thunder" then
        st.stance = "earth"
        local x,y,z = pos(player, 0.7)
        summon_display_at(nil, x, y, z, MODELS.heal_vert, 1200, player:get_yaw(), 0, 1)
        play_sound(player, "awakened_shaman_sounds:samus.awakened_shaman.earth_stance", 0.7, 1)
        player:send_message_text("§aShaman Stance: EARTH")
    else
        st.stance = "thunder"
        local x,y,z = pos(player, 0.7)
        summon_display_at(nil, x, y, z, MODELS.thunder_vert[1], 500, player:get_yaw(), 0, 1)
        play_sound(player, "awakened_shaman_sounds:samus.awakened_shaman.thunder_stance", 0.7, 1)
        player:send_message_text("§bShaman Stance: THUNDER")
    end
end

local function ritual_totem_cast(player)
    local st = state_of(player)
    local thunder = st.stance ~= "earth"
    local x,y,z = forward(player, 6, 0, 0)
    local model = thunder and MODELS.hunter_totem or MODELS.guardian_totem
    summon_display_at(nil, x, y, z, model, 11000, player:get_yaw(), 0, 1)
    play_sound(player, "awakened_shaman_sounds:samus.awakened_shaman.totem_summon", 0.7, 1)
    for wave=1,8 do
        schedule(2000 + wave * 1000, function()
            if thunder then
                for s=-1,1 do
                    summon_display_at(nil, x + s*0.5, y + 1.0, z, MODELS.impact[1], 600, player:get_yaw(), 0, 0.7)
                    affect_near(player, 25, CONFIG.damage * 0.7, false, 1)
                end
                play_sound(player, "minecraft:entity.blaze.shoot", 0.45, 1)
            else
                summon_display_at(nil, x, y + 1.0, z, MODELS.nature_hands, 1200, player:get_yaw(), 0, 0.9)
                affect_near(player, 8, nil, true, 5)
                play_sound(player, "minecraft:block.amethyst_block.chime", 0.5, 1)
            end
        end)
    end
end

local function ritual_totem(player)
    local st = state_of(player)
    local t = now_ms()
    if st.ritual_armed_until > t then
        st.ritual_armed_until = 0
        ritual_totem_cast(player)
    else
        st.ritual_armed_until = t + 2500
        player:send_message_text("§eRitual Totem armed: 우클릭을 한 번 더 하면 토템을 소환합니다.")
    end
end

local function earthen_embrace(player)
    affect_near(player, 10, CONFIG.damage * 0.3, false, 5)
    local x, y, z = pos(player, 1)
    local tag = new_tag("root")
    local selector = "@e[distance=..10,limit=5,sort=nearest,type=!minecraft:item_display,type=!minecraft:text_display,type=!minecraft:block_display,type=!minecraft:armor_stand,tag=!aris_awakened_shaman_vfx]"
    cmd("execute positioned " .. x .. " " .. y .. " " .. z .. " as " .. selector .. " at @s run summon minecraft:item_display ~ ~ ~ {Tags:[\"aris_awakened_shaman_vfx\",\"" .. tag .. "\"],billboard:\"fixed\",brightness:{block:15,sky:15},item_display:\"head\",item:{id:\"" .. CONFIG.base_item .. "\",count:1,components:{\"minecraft:item_model\":\"" .. model_id(MODELS.earthen_embrace) .. "\"}},transformation:{translation:[0f,0f,0f],scale:[1f,1f,1f],left_rotation:[0f,0f,0f,1f],right_rotation:[0f,0f,0f,1f]}}")
    cmd("execute positioned " .. x .. " " .. y .. " " .. z .. " as " .. selector .. " at @s run effect give @s minecraft:slowness 3 6 true")
    schedule(4500, function() cmd("tp @e[tag=" .. tag .. "] 0 -10000 0") end)
    play_sound(player, "awakened_shaman_sounds:samus.awakened_shaman.earth_roots_entangle", 0.7, 1)
end

local function ancestral_hands(player)
    local st = state_of(player)
    if st.stance ~= "earth" then
        for i,delay in ipairs({0,1100,1950}) do
            schedule(delay, function()
                local x,y,z = forward(player, 4 + i * 1.6, 0, 0)
                summon_display_at(nil, x, y, z, MODELS.ancestor_hands, 1100, player:get_yaw(), 0, 1.1)
                schedule(550, function() affect_near(player, 5, CONFIG.damage * 1.25, false, 5) end)
                play_sound(player, "awakened_shaman_sounds:samus.awakened_shaman.thunder_fist", 0.7, 1)
            end)
        end
    else
        local x,y,z = forward(player, 4, 0, 0)
        summon_display_at(nil, x, y, z, MODELS.nature_hands, 6200, player:get_yaw(), 0, 1.15)
        for i=1,5 do
            schedule(i * 650, function() affect_near(player, 7, nil, true, 5) end)
        end
        player:add_velocity(0, 0.7, 0)
        play_sound(player, "minecraft:block.amethyst_block.chime", 0.7, 0.9)
    end
end

local function handle_skill(player, name)
    if name == "soul_link" then soul_link(player)
    elseif name == "primal_combo" then primal_combo(player)
    elseif name == "echo_step" then echo_step(player)
    elseif name == "ritual_totem" then ritual_totem(player)
    elseif name == "stance_switch" then stance_switch(player)
    elseif name == "earthen_embrace" then earthen_embrace(player)
    elseif name == "ancestral_hands" then ancestral_hands(player)
    end
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

-- Commands: /awakened_shaman <skill>
for _, name in ipairs({"soul_link","primal_combo","echo_step","ritual_totem","stance_switch","earthen_embrace","ancestral_hands"}) do
    aris.game.hook.register_endpoint("awakened_shaman_" .. name, function(ctx)
        diagnostic_loop("awakened_shaman:endpoint:" .. name, function()
        -- 추정: endpoint callback에서 player를 직접 받을 수 있는 환경이면 ctx가 플레이어입니다.
        -- 서버 버전에 따라 ctx:get_player() 형태라면 아래 3줄 중 맞는 형태만 남기세요.
        local player = ctx
        if ctx ~= nil and type(ctx.get_player) == "function" then player = ctx:get_player() end
        if player ~= nil then handle_skill(player, name) end
        end)
    end)
end

-- 기본 입력 매핑: 우클릭 = Primal Combo, 웅크린 우클릭 = Stance Switch 2스택 처리.
aris.game.hook.add_on_right_click(function(event)
    diagnostic_loop("awakened_shaman:right_click", function()
    local player = event:get_player()
    if player == nil or not is_holding_shaman_weapon(player) then return end
    local st = state_of(player)
    if player:get_is_sneaking() then
        st.sneak_triggered = true
        return
    end
    primal_combo(player)
    end)
end)

-- 웅크리기 플래그 처리: add_tick은 LuaJIT native crash 이력이 있어 루프로 처리합니다.
while true do
    diagnostic_loop("awakened_shaman", function()
    clock_ms = clock_ms + TICK_MS
    each_tick()
    for uuid, st in pairs(states) do
        if st.sneak_triggered and st.player ~= nil then
            st.sneak_triggered = false
            if is_holding_shaman_weapon(st.player) then
                local t = now_ms()
                if t > st.stance_until then st.stance_stack = 0 end
                st.stance_stack = st.stance_stack + 1
                st.stance_until = t + CONFIG.stance_double_sneak_ms
                if st.stance_stack >= 2 then
                    st.stance_stack = 0
                    stance_switch(st.player)
                else
                    st.player:send_message_text("§7한 번 더 쉬프트+우클릭하면 자세가 전환됩니다.")
                end
            end
        end
    end
    end)
    safe_yield("awakened_shaman")
end
