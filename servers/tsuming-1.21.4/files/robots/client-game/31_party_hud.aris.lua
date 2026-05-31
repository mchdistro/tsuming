-- 파티원 체력 HUD — 스킬 쿨다운 HUD(20_skill_cooldown_hud) 패턴 미러(네이티브 aris HUD).
-- 컴포넌트(색 사각형/텍스트)는 콜백이 없어 LuaFunc 제약과 무관. 슬롯을 미리 만들고
-- party_health 패킷 수신 시 텍스트/바 폭/표시여부만 갱신한다.

local MAX_ROWS = 10
local START_X = 16
local START_Y = 16
local ROW_H = 30
local BAR_W = 120
local BAR_H = 8
local NAME_SCALE = 1.5
local HP_SCALE = 1.1
local C_NAME = 0xFFFFFFFF
local C_HP = 0xFFDDDDDD

local hud = nil
local root = nil
local rows = {}
local visible = false

local function split(s, sep)
    local out = {}
    if s == nil or s == "" then return out end
    for part in string.gmatch(s, "([^" .. sep .. "]+)") do out[#out + 1] = part end
    return out
end

local function create_once()
    if hud ~= nil then return end
    hud = aris.game.client.create_hud()
    root = aris.client.create_component()
    root:set_x(START_X)
    root:set_y(START_Y)
    hud:add_child(root)

    for i = 1, MAX_ROWS do
        local c = aris.client.create_component()
        c:set_x(0)
        c:set_y((i - 1) * ROW_H)
        root:add_child(c)

        local nm = aris.client.create_default_text_renderer("", C_NAME)
        nm:set_x(0)
        nm:set_y(0)
        nm:set_scale(NAME_SCALE)
        c:add_child(nm)

        local bg = aris.client.create_color_renderer(60, 60, 60, 200)
        bg:set_x(0)
        bg:set_y(17)
        bg:set_width(BAR_W)
        bg:set_height(BAR_H)
        c:add_child(bg)

        local fg = aris.client.create_color_renderer(60, 200, 80, 255)
        fg:set_x(0)
        fg:set_y(17)
        fg:set_width(BAR_W)
        fg:set_height(BAR_H)
        c:add_child(fg)

        local hp = aris.client.create_default_text_renderer("", C_HP)
        hp:set_x(BAR_W + 6)
        hp:set_y(15)
        hp:set_scale(HP_SCALE)
        c:add_child(hp)

        c:set_is_visible(false)
        rows[i] = { container = c, name = nm, fg = fg, hp = hp }
    end
end

local function set_visible(v)
    if v == visible then return end
    visible = v
    if v then hud:open_hud() else hud:close_hud() end
end

local function apply(data)
    create_once()
    local entries = split(data, ",")
    local shown = 0
    for i = 1, MAX_ROWS do
        local row = rows[i]
        local e = entries[i]
        if e ~= nil then
            local f = split(e, ":")
            local nm = f[1] or "?"
            local hp = tonumber(f[2]) or 0
            local mx = tonumber(f[3]) or 0
            local ratio = 0
            if mx > 0 then ratio = hp / mx end
            if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
            row.name:set_text(nm)
            row.fg:set_width(math.floor(BAR_W * ratio + 0.5))
            row.hp:set_text(tostring(hp) .. " / " .. tostring(mx))
            row.container:set_is_visible(true)
            shown = shown + 1
        else
            row.container:set_is_visible(false)
        end
    end
    set_visible(shown > 0)
end

aris.game.client.hook.add_s2c_packet_handler("party_health", function(packet)
    apply(packet.data or "")
end)

-- (유지용 무한 루프 제거: 패킷 핸들러는 등록 후 task 가 끝나도 유지됨)

-- /aris reload 시 옛 엔진이 연 HUD 렌더러가 클라 HUD 엔진에 남아 중첩되는 것 방지
aris.hook.on_engine_dispose(function()
    if hud ~= nil then
        hud:close_hud()
        hud = nil
    end
end)
