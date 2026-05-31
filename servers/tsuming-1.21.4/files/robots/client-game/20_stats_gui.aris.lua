-- 스탯 GUI — GTCanvas(gtc) 포팅판
--
-- 엔진 제약 메모:
--  * LuaFunc(콜백)는 "생성 시점"에만 currentTask 가 필요하다. S2C 패킷 핸들러는
--    task 로 실행되므로(핸들러 안 = currentTask 있음) 거기서 트리/on_click 을 만들면 안전.
--  * 반대로 버튼 on_click 콜백 안에서는 currentTask 가 없으므로 새 LuaFunc 를 만들면 안 된다.
--    → +/- 클릭에서는 라벨 텍스트만 바꾸고(:text), 패킷 전송/close 만 한다.

local STAT_ORDER = { "str", "agi", "int", "vit", "luk" }
local STAT_LABELS = {
    str = "힘", agi = "민첩", int = "지능", vit = "체력", luk = "운",
}

-- 팔레트
local C_TEXT  = 0xFFEAEAEA
local C_SUB   = 0xFFA0A0A0
local C_GOLD  = 0xFFFACC15
local C_VALUE = 0xFF93D6FF

local cur = { points = 0, str = 0, agi = 0, int = 0, vit = 0, luk = 0 }
local pending = { str = 0, agi = 0, int = 0, vit = 0, luk = 0 }
local refs = nil  -- { points_lbl, rows = { stat -> { val, pend } } }

local function pending_total()
    local t = 0
    for _, s in ipairs(STAT_ORDER) do t = t + (pending[s] or 0) end
    return t
end

local function reset_pending()
    for _, s in ipairs(STAT_ORDER) do pending[s] = 0 end
end

-- 라벨 텍스트만 갱신 (LuaFunc 생성 없음 → 클릭 콜백/핸들러 어디서든 안전)
local function update_labels()
    if refs == nil then return end
    refs.points_lbl:text("보유 포인트 " .. tostring((cur.points or 0) - pending_total()))
    for _, s in ipairs(STAT_ORDER) do
        local r = refs.rows[s]
        if r ~= nil then
            -- 미리보기 값 = 현재 + 가배정 (적용 시 확정)
            r.val:text(tostring((cur[s] or 0) + (pending[s] or 0)))
        end
    end
end

local function send_apply()
    if pending_total() <= 0 then
        aris.game.client.send_system_message("§e[스탯] 적용할 변경 사항이 없습니다.")
        return
    end
    local p = aris.game.client.networking.create_c2s_packet_builder("stats_apply_points")
    p:append_int("str", pending.str or 0)
    p:append_int("agi", pending.agi or 0)
    p:append_int("int", pending.int or 0)
    p:append_int("vit", pending.vit or 0)
    p:append_int("luk", pending.luk or 0)
    aris.game.client.networking.send_c2s_packet(p)
end

local function small_btn(label, r, g, b, on_click)
    return gtc.button(label)
        :width(38):height(30):border_radius(6)
        :background(gtc.rgba(r, g, b, 46))
        :border(1, gtc.rgba(r, g, b, 150))
        :color(0xFF000000 + r * 0x10000 + g * 0x100 + b)
        :on_click(on_click)
end

local function build_row(stat)
    local val = gtc.label("0"):font_size(15):color(C_VALUE):width(44):text_align("center")
    refs.rows[stat] = { val = val }

    local minus = small_btn("−", 239, 68, 68, function()
        if (pending[stat] or 0) > 0 then
            pending[stat] = pending[stat] - 1
            update_labels()
        end
    end)
    local plus = small_btn("+", 34, 197, 94, function()
        if pending_total() < (cur.points or 0) then
            pending[stat] = (pending[stat] or 0) + 1
            update_labels()
        else
            aris.game.client.send_system_message("§e[스탯] 사용 가능한 스탯 포인트가 없습니다.")
        end
    end)

    -- 좌: 라벨 / 우: [−] 값 [+] 스텝퍼  (justify space_between 으로 좌우 분배)
    return gtc.row()
        :justify("space_between"):align("center"):padding4(8, 14, 8, 14)
        :background(gtc.rgba(26, 26, 26, 255))
        :border(1, gtc.rgba(38, 38, 38, 255))
        :border_radius(8)
        :add(gtc.label(STAT_LABELS[stat]):font_size(15):color(C_TEXT))
        :add(gtc.row():align("center"):gap(8):add(minus):add(val):add(plus))
end

local function build_tree()
    refs = { rows = {} }
    refs.points_lbl = gtc.label("보유 포인트 0"):font_size(11):color(C_GOLD)

    local header = gtc.row():align("center"):justify("space_between")
        :add(gtc.label("스탯"):font_size(22):font_weight(700):color(C_TEXT))
        :add(gtc.row():padding4(3, 11, 3, 11):border_radius(8)
            :background(gtc.rgba(250, 204, 21, 20))
            :border(1, gtc.rgba(250, 204, 21, 90))
            :add(refs.points_lbl))

    local rows_col = gtc.column():gap(8):align("stretch")
    for _, s in ipairs(STAT_ORDER) do rows_col:add(build_row(s)) end

    local footer = gtc.row():justify("center"):align("center"):gap(12)
        :add(gtc.button("적용"):width(160):height(38):border_radius(8)
            :background(gtc.rgba(34, 197, 94, 46)):border(1, gtc.rgba(34, 197, 94, 150))
            :color(0xFF22C55E)
            :on_click(send_apply))
        :add(gtc.button("닫기"):width(120):height(38):border_radius(8)
            :background(gtc.rgba(30, 30, 30, 255)):border(1, gtc.rgba(42, 42, 42, 255))
            :color(C_SUB)
            :on_click(function() gtc.close_screen() end))

    local panel = gtc.column()
        :width(420):padding(24):gap(14):align("stretch")
        :background(gtc.rgba(20, 20, 20, 245))
        :border(1, gtc.rgba(42, 42, 42, 255))
        :border_radius(12)
        :add(header):add(rows_col):add(footer)

    update_labels()
    return panel
end

local function open_stats()
    if gtc == nil then
        aris.game.client.send_system_message("§c[스탯] gtc 라이브러리 없음 — GTCanvasAris 모드 확인")
        return
    end
    local tree = build_tree()
    local centered = gtc.column():flex(1):align("center"):justify("center"):add(tree)
    gtc.open_screen(true, function(root) root:add(centered) end)
end

aris.game.client.hook.add_s2c_packet_handler("stats_sync", function(packet)
    cur.points = tonumber(packet.points) or 0
    cur.str = tonumber(packet.str) or 0
    cur.agi = tonumber(packet.agi) or 0
    cur.int = tonumber(packet.int) or 0
    cur.vit = tonumber(packet.vit) or 0
    cur.luk = tonumber(packet.luk) or 0
    reset_pending()
    if (tonumber(packet.open) or 0) == 1 then
        open_stats()
    else
        update_labels()  -- 이미 열려있으면 값만 갱신 (닫혀있으면 무해)
    end
end)

-- (유지용 무한 루프 제거: 패킷 핸들러는 등록 후 task 가 끝나도 유지됨)
