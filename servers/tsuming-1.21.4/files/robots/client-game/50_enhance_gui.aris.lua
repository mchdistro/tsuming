-- 무기 강화 — gtc 강화창. 레퍼런스 디자인(ui-test/design/enhance) 레이아웃 + 현재 색상.
--   가운데 = 강화 메인 패널(슬롯/info/버튼) / 오른쪽 = 장비·재료 리스트
-- 선택/파괴방지권은 클라 즉시 처리(visible 토글, 서버 왕복 없음). 강화 실행만 서버.
-- 아이템 아이콘: gtc.item_icon():width():height():item() — gtcanvas 0.5.12+.

-- 색상 (현재 팔레트 유지)
-- 길드/파티 GUI 팔레트
local C_TEXT  = 0xFFEAEAEA
local C_SUB   = 0xFFA0A0A0
local C_KEY   = 0xFF606060
local C_GREEN = 0xFF22C55E   -- {34,197,94} 성공/게이지/강화버튼
local C_BLUE  = 0xFF3B82F6   -- {59,130,246} 다음 단계/방지권
local C_GOLD  = 0xFFFACC15
local C_RED   = 0xFFEF4444   -- {239,68,68}
local C_ORANGE= 0xFFEA8C28   -- {234,140,40}
local BG_PANEL = function() return gtc.rgba(20, 20, 20, 245) end
local BG_SLOT  = function() return gtc.rgba(14, 14, 14, 255) end
local BORDER   = function() return gtc.rgba(42, 42, 42, 255) end
local BORDER2  = function() return gtc.rgba(38, 38, 38, 255) end

--==========================================================
-- CONFIG (서버 50_enhance.aris.lua 와 동일 유지)
--==========================================================
local MAX_LEVEL = 15
-- 공격력 수치는 서버(50_enhance.aris.lua 의 WEAPON_ATK)가 weapon_atks 패킷 필드로 내려줌 — 클라 복제 없음
local SUCCESS = {
    [0] = 1.00, [1] = 1.00, [2] = 0.95, [3] = 0.90, [4] = 0.85,
    [5] = 0.80, [6] = 0.70, [7] = 0.60, [8] = 0.50, [9] = 0.40,
    [10] = 0.35, [11] = 0.30, [12] = 0.25, [13] = 0.20, [14] = 0.15,
}
local STONE_COST = {
    [0] = 1, [1] = 1, [2] = 2, [3] = 2, [4] = 3,
    [5] = 3, [6] = 4, [7] = 5, [8] = 6, [9] = 8,
    [10] = 10, [11] = 12, [12] = 15, [13] = 18, [14] = 22,
}
local function penalty_of(level)
    if level < 5 then return "keep"
    elseif level < 10 then return "down"
    else return "destroy" end
end

--==========================================================
-- 상태
--==========================================================
local cur = { weapon_slots = {}, weapon_atks = {}, stone_slot = -1, stone_count = 0, ticket_slot = -1, ticket_count = 0,
              result = "", from_level = 0, to_level = 0 }
local sel = -1
local ticket_on = false
-- 토스트(자동 사라짐) 상태
local toast_el = nil
local toast_timer = 0
-- 땅땅땅 연출 상태 (결과 공개 전 긴장 연출 — 현재 화면의 오버레이 레이어)
local suspense = nil
local fx_running = false      -- 연출 중 강화 재클릭 방지
local fx_weapon_name = ""     -- 클릭 시점 무기 이름 (파괴되면 이후엔 못 읽으므로 미리 캡처)

--==========================================================
-- 헬퍼
--==========================================================
local function item_at(slot)
    if slot == nil or slot < 0 then return nil end
    -- 서버 get_slot 규약 99 = 오프핸드 → 클라 Inventory.getItem 인덱스는 40
    if slot == 99 then slot = 40 end
    local item = nil
    local ok = pcall(function() item = aris.game.client.get_inventory_item(slot) end)
    if ok and item ~= nil and item:get_name() ~= "minecraft:air" then return item end
    return nil
end

local function get_level(item)
    if item == nil then return 0 end
    local ok, t = pcall(function() return item:get_data():into_table() end)
    if ok and type(t) == "table" then return tonumber(t.enhance_level) or 0 end
    return 0
end

local function send_do()
    if sel < 0 then return end
    if fx_running then return end   -- 땅땅땅 연출 중 재클릭 방지
    fx_weapon_name = ""
    pcall(function()
        local it = item_at(sel)
        if it ~= nil then fx_weapon_name = it:get_display_name() or "" end
    end)
    local p = aris.game.client.networking.create_c2s_packet_builder("enhance_do")
    p:append_int("slot", sel)
    p:append_int("use_ticket", ticket_on and 1 or 0)
    aris.game.client.networking.send_c2s_packet(p)
end

local function icon(it, size)
    local ic = gtc.item_icon():width(size):height(size):show_tooltip(true)
    if it ~= nil then ic:item(it) end
    return ic
end

-- 슬롯 박스 (item_icon 을 가운데 담음)
local function slot_box(size, inner)
    local b = gtc.column():width(size):height(size):align("center"):justify("center")
        :background(BG_SLOT()):border(2, BORDER()):border_radius(4)
    if inner ~= nil then b:add(inner) end
    return b
end

local function info_row(key, value_label)
    return gtc.row():justify("space_between"):align("center")
        :add(gtc.label(key):font_size(13):color(C_KEY))
        :add(value_label)
end

--==========================================================
-- 빌드
--==========================================================
local function build_tree()
    local apply_sel, apply_ticket

    --------------------------------------------------------
    -- 가운데: 강화 메인 패널
    --------------------------------------------------------
    -- 헤더
    local close_btn = gtc.button("닫기"):height(28):border_radius(6)
        :background(gtc.rgba(30, 30, 30, 255)):border(1, BORDER()):color(C_SUB)
        :on_click(function() gtc.close_screen() end)
    local header = gtc.column():gap(6):align("stretch")
        :add(gtc.row():align("center"):justify("space_between")
            :add(gtc.label("무기 강화"):font_size(22):font_weight(900):color(0xFFFFFFFF))
            :add(close_btn))
        :add(gtc.label("장비에 재료를 사용하여 강화합니다"):font_size(12):color(C_KEY))

    -- 장비 슬롯 (선택 무기 — 무기별 아이콘 stack, visible 토글)
    local equip_stack = gtc.stack():width(72):height(72)
    local equip_slot = gtc.column():align("center"):gap(8)
        :add(slot_box(72, equip_stack))
        :add(gtc.label("장비"):font_size(11):color(C_KEY))

    -- 재료 슬롯 (강화석)
    local stone_it = item_at(cur.stone_slot)
    local mat_slot = gtc.column():align("center"):gap(8)
        :add(slot_box(72, stone_it and icon(stone_it, 68) or nil))
        :add(gtc.label("재료"):font_size(11):color(C_KEY))

    local enhance_area = gtc.row():align("center"):justify("center"):gap(16)
        :add(equip_slot)
        :add(gtc.label("+"):font_size(20):font_weight(700):color(0xFF444444))
        :add(mat_slot)

    -- 파괴방지권 영역 (점선)
    local tk = item_at(cur.ticket_slot)
    local prot_inner = icon(tk, 28)
    prot_inner:visible(false)
    local prot_slot = gtc.column():width(40):height(40):align("center"):justify("center")
        :background(BG_SLOT()):border(2, BORDER()):border_radius(4):border_style("dashed")
        :add(prot_inner)
    local prot_off = gtc.label("미장착"):font_size(11):color(C_KEY)
    local prot_on  = gtc.label("장착됨"):font_size(11):color(C_BLUE):visible(false)
    local prot_status = gtc.stack():add(prot_off):add(prot_on)
    local protect_area = gtc.row():align("center"):gap(12):padding4(10, 16, 10, 16)
        :background(BG_SLOT()):border(1, BORDER2()):border_radius(4):border_style("dashed")
        :add(prot_slot)
        :add(gtc.column():gap(2)
            :add(gtc.label("파괴 방지권"):font_size(12):font_weight(600):color(C_SUB))
            :add(prot_status))
    protect_area:on_click(function() apply_ticket(not ticket_on) end)
    prot_slot:on_click(function() apply_ticket(not ticket_on) end)

    -- 강화 정보 섹션 (무기별로 미리 만들고 visible 토글)
    local info_stack = gtc.stack():align("stretch")
    local prompt_info = gtc.column():padding4(14, 18, 14, 18):align("center"):justify("center")
        :background(BG_SLOT()):border(1, BORDER2()):border_radius(4)
        :add(gtc.label("오른쪽에서 강화할 장비를 선택하세요"):font_size(13):color(C_KEY))
    info_stack:add(prompt_info)

    -- 강화 버튼
    local enhance_btn = gtc.button("강 화"):height(46):border_radius(8)
        :background(gtc.rgba(34, 197, 94, 46)):border(1, gtc.rgba(34, 197, 94, 150)):color(C_GREEN)
        :font_size(15):font_weight(700)
        :on_click(function() send_do() end)

    local main_panel = gtc.column():width(380):padding4(28, 28, 24, 28):gap(18):align("stretch")
        :background(BG_PANEL()):border(1, BORDER()):border_radius(12)
        :add(header)
        :add(enhance_area)
        :add(protect_area)
        :add(info_stack)
        :add(enhance_btn)

    --------------------------------------------------------
    -- 오른쪽: 장비 + 재료 리스트
    --------------------------------------------------------
    local toggles = {}

    local equip_list = gtc.column():gap(2):align("stretch")
    for idx, slot in ipairs(cur.weapon_slots) do
        local s = slot
        local it = item_at(s)
        local lv = get_level(it)
        local nm = (it ~= nil) and it:get_display_name() or "?"
        -- 서버가 내려준 "현재atk:다음atk" (weapon_slots 와 같은 순서)
        local atk_cur, atk_next = string.match((cur.weapon_atks or {})[idx] or "", "([^:]+):([^:]+)")
        atk_cur = atk_cur or "0"
        atk_next = atk_next or "0"

        -- 장비 슬롯에 들어갈 큰 아이콘
        local bigicon = icon(it, 68)
        bigicon:visible(false)
        equip_stack:add(bigicon)

        -- info 패널
        local info = gtc.column():padding4(14, 18, 14, 18):gap(8):align("stretch")
            :background(BG_SLOT()):border(1, BORDER2()):border_radius(4)
        info:visible(false)
        if lv >= MAX_LEVEL then
            info:add(info_row("현재 단계", gtc.label("+" .. lv):font_size(13):font_weight(700):color(C_GOLD)))
            info:add(info_row("공격력", gtc.label("+" .. atk_cur):font_size(13):font_weight(700):color(C_GOLD)))
            info:add(gtc.label("최대 강화 단계 도달"):font_size(12):color(C_SUB))
        else
            local rate = SUCCESS[lv] or 0
            local cost = STONE_COST[lv] or 1
            local pen = penalty_of(lv)
            local pen_txt, pen_col = "단계 유지", C_SUB
            if pen == "down" then pen_txt, pen_col = "단계 하락", C_ORANGE
            elseif pen == "destroy" then pen_txt, pen_col = "장비 파괴", C_RED end
            info:add(info_row("현재 단계", gtc.label("+" .. lv):font_size(13):font_weight(700):color(C_TEXT)))
            info:add(info_row("다음 단계", gtc.label("+" .. (lv + 1)):font_size(13):font_weight(700):color(C_BLUE)))
            info:add(info_row("공격력", gtc.label("+" .. atk_cur .. " → +" .. atk_next):font_size(13):font_weight(700):color(C_GREEN)))
            info:add(info_row("성공 확률", gtc.label(math.floor(rate * 100 + 0.5) .. "%"):font_size(13):font_weight(700):color(C_GREEN)))
            info:add(info_row("실패 시", gtc.label(pen_txt):font_size(12):font_weight(500):color(pen_col)))
            info:add(gtc.row():align("center"):add(gtc.progress_bar():flex(1):height(6):border_radius(3)
                :progress(rate):fill_color(gtc.rgba(34, 197, 94, 255)):track_color(gtc.rgba(255, 255, 255, 16))))
            info:add(info_row("필요 강화석", gtc.label("강화석 x" .. cost):font_size(13):font_weight(700):color(C_BLUE)))
        end
        info_stack:add(info)

        -- 리스트 행 (아이콘 + 이름/공격력 + 선택 오버레이)
        local base = gtc.row():align("center"):gap(10):padding4(8, 10, 8, 10):border_radius(4)
            :add(icon(it, 40))
            :add(gtc.column():gap(1):flex(1)
                :add(gtc.label(nm):font_size(12):font_weight(600):color(0xFFCCCCCC))
                :add(gtc.label("강화 +" .. lv .. "  ·  공격력 +" .. atk_cur):font_size(10):color(C_KEY)))
        local ov = gtc.panel():border_radius(4):background(gtc.rgba(34, 197, 94, 20))
            :border(1, gtc.rgba(34, 197, 94, 90)):visible(false)
        local row = gtc.stack():align("stretch"):add(base):add(ov)
        row:on_click(function() apply_sel(s) end)
        equip_list:add(row)
        toggles[#toggles + 1] = { slot = s, bigicon = bigicon, info = info, overlay = ov }
    end
    if #toggles == 0 then
        equip_list:add(gtc.label("강화 가능한 장비가 없습니다"):font_size(12):color(C_KEY))
    end

    -- 보유 재료
    local mat_list = gtc.column():gap(2):align("stretch")
    local function mat_row(it, name, count, count_col, on_click)
        local base = gtc.row():align("center"):gap(10):padding4(8, 10, 8, 10):border_radius(4)
            :add(icon(it, 40))
            :add(gtc.column():flex(1):add(gtc.label(name):font_size(12):font_weight(600):color(0xFFCCCCCC)))
            :add(gtc.label("x" .. count):font_size(12):font_weight(700):color(count_col))
        if on_click ~= nil then base:on_click(on_click) end
        return base
    end
    local any_mat = false
    if cur.stone_count > 0 then
        mat_list:add(mat_row(stone_it, "강화석", cur.stone_count, C_SUB))
        any_mat = true
    end
    if cur.ticket_count > 0 then
        mat_list:add(mat_row(tk, "파괴 방지권", cur.ticket_count, C_BLUE,
            function() apply_ticket(not ticket_on) end))
        any_mat = true
    end
    if not any_mat then
        mat_list:add(gtc.label("보유한 재료가 없습니다"):font_size(12):color(C_KEY))
    end

    local function list_label(t)
        return gtc.label(t):font_size(11):font_weight(700):color(0xFF555555)
    end
    local list_panel = gtc.column():width(240):padding4(20, 14, 14, 14):gap(10):align("stretch")
        :background(BG_PANEL()):border(1, BORDER()):border_radius(12)
        :add(list_label("강화 가능 장비"))
        :add(gtc.scroll_view():min_height(180):max_height(180):align("stretch"):add(equip_list))
        :add(gtc.panel():height(1):background(gtc.rgba(58, 58, 80, 120)))
        :add(list_label("보유 재료"))
        :add(mat_list)

    --------------------------------------------------------
    -- 토글 함수
    --------------------------------------------------------
    apply_sel = function(slot)
        if sel == slot then slot = -1 end   -- 같은 장비 다시 클릭 → 선택 해제
        sel = slot
        prompt_info:visible(slot < 0)
        for _, t in ipairs(toggles) do
            local on = (t.slot == slot)
            t.bigicon:visible(on)
            t.info:visible(on)
            t.overlay:visible(on)
        end
    end

    apply_ticket = function(on)
        if on and cur.ticket_count <= 0 then on = false end
        ticket_on = on
        prot_inner:visible(on and tk ~= nil)
        prot_on:visible(on)
        prot_off:visible(not on)
    end

    local found = false
    for _, t in ipairs(toggles) do if t.slot == sel then found = true end end
    if found then
        -- 재빌드 후 선택 복원. apply_sel 은 같은 슬롯 재클릭=해제 토글이라
        -- sel 을 먼저 비워서 토글에 안 걸리게 한다 (강화 직후 무기 선택 유지)
        local keep = sel
        sel = -1
        apply_sel(keep)
    else
        sel = -1; prompt_info:visible(true)
    end
    apply_ticket(ticket_on)

    -- 왼쪽에 리스트 패널 폭(240)만큼 투명 스페이서 → 메인 패널이 화면 정중앙
    local spacer = gtc.panel():width(240):height(1)
    return gtc.row():gap(12):align("center"):add(spacer):add(main_panel):add(list_panel)
end

-- ShopToast 스타일: 좌우 페이드 그라디언트 + 가운데 제목/설명. (gtc.background_linear_gradient 사용)
local function build_toast()
    local r = cur.result
    if r == "" then return nil end
    local title, desc, tcol, center
    if r == "success" then
        title = "강화 성공!"; desc = "+" .. cur.from_level .. " → +" .. cur.to_level
        tcol = 0xFF6FCF7C; center = 0x595AB464
    elseif r == "keep" then
        title = "강화 실패"; desc = "단계가 유지됩니다"
        tcol = 0xFFBBBBBB; center = 0x59808080
    elseif r == "down" then
        title = "단계 하락"; desc = "+" .. cur.from_level .. " → +" .. cur.to_level
        tcol = 0xFFE8A832; center = 0x59E8A832
    elseif r == "destroy" then
        title = "장비 파괴!"; desc = "강화에 실패하여 파괴되었습니다"
        tcol = 0xFFEF5050; center = 0x59B45A5A
    elseif r == "protected" then
        title = "파괴 방지!"; desc = "파괴방지권으로 보호되었습니다"
        tcol = 0xFF64B4FF; center = 0x595A78B4
    elseif r == "no_stone" then
        -- 서버가 from/to 필드에 필요/보유 개수를 실어 보냄
        title = "강화석 부족"; desc = "필요 " .. cur.from_level .. "개 / 보유 " .. cur.to_level .. "개"
        tcol = 0xFFE8A832; center = 0x59E8A832
    else
        return nil
    end
    local H = 72
    local grad = gtc.row():width(500):height(H)
        :add(gtc.panel():width(250):height(H):background_linear_gradient(0x00000000, center, false))
        :add(gtc.panel():width(250):height(H):background_linear_gradient(center, 0x00000000, false))
    -- text_align("center") 필수: 라벨 폭은 근사치(한글 과대 추정)라 기본 START 정렬이면
    -- 박스는 중앙이어도 글자가 왼쪽으로 치우침. center 는 박스 정중앙에 그려서 오차 무관.
    local txt = gtc.column():width(500):height(H):align("stretch"):justify("center"):gap(6)
        :add(gtc.label(title):font_size(18):font_weight(900):color(tcol):text_align("center"))
        :add(gtc.label(desc):font_size(12):color(0x99FFFFFF):text_align("center"))
    return gtc.stack():width(500):height(H):add(grad):add(txt)
end

-- 땅땅땅 연출 레이어 (결과 토스트와 같은 밴드 스타일, 숨김 상태로 미리 만들어 둠)
--   title "강화 중" + 아래에 "땅!" 3개가 하나씩 나타남. 핸들러가 visible 토글 + task_sleep 으로 진행.
local function build_suspense()
    local H = 72
    local hits = {}
    local hit_row = gtc.row():align("center"):justify("center"):gap(18)
    for i = 1, 3 do
        local l = gtc.label("땅!"):font_size(17):font_weight(900):color(0xFFFFD24A)
            :text_align("center"):visible(false)
        hits[i] = l
        hit_row:add(l)
    end
    local center = 0x59E8A832
    local grad = gtc.row():width(500):height(H)
        :add(gtc.panel():width(250):height(H):background_linear_gradient(0x00000000, center, false))
        :add(gtc.panel():width(250):height(H):background_linear_gradient(center, 0x00000000, false))
    local title = gtc.label("강화 중"):font_size(18):font_weight(900):color(0xFFE8A832):text_align("center")
    -- 고정 높이 박스로 감싸서 점멸(visible 토글) 시 아래 땅! 행이 출렁이지 않게 함
    local title_box = gtc.stack():height(22):align("stretch"):add(title)
    local txt = gtc.column():width(500):height(H):align("stretch"):justify("center"):gap(6)
        :add(title_box)
        :add(hit_row)
    local band = gtc.stack():width(500):height(H):add(grad):add(txt)
    local layer = gtc.column():flex(1):align("center"):justify("center")
        :enabled(false):visible(false):add(band)
    return { layer = layer, hits = hits, band = band }
end

local function open_enhance()
    if gtc == nil then
        aris.game.client.send_system_message("§c[강화] gtc 라이브러리 없음 — GTCanvasAris 모드 확인")
        return
    end
    local tree = build_tree()
    local main = gtc.column():flex(1):align("center"):justify("center"):add(tree)
    suspense = build_suspense()
    local toast = build_toast()
    if toast ~= nil then
        toast_timer = 35   -- ≈1.7초 (20tps)
        -- stack 금지: Stack은 자식 flex/stretch가 기본 적용 안 돼 좌상단으로 뭉개짐.
        -- root는 자식마다 풀스크린 배치라 레이어를 각각 add. enabled(false) = 클릭 통과.
        local toast_layer = gtc.column():flex(1):align("center"):justify("center")
            :enabled(false):add(toast)
        toast_el = toast_layer
        gtc.open_screen(true, function(root)
            root:add(main)
            root:add(toast_layer)
            root:add(suspense.layer)
        end)
    else
        toast_el = nil
        gtc.open_screen(true, function(root)
            root:add(main)
            root:add(suspense.layer)
        end)
    end
end

--==========================================================
-- S2C 수신
--==========================================================
aris.game.client.hook.add_s2c_packet_handler("enhance_open", function(packet)
    cur.weapon_slots = {}
    for s in string.gmatch(packet.weapon_slots or "", "([^,]+)") do
        local n = tonumber(s)
        if n ~= nil then cur.weapon_slots[#cur.weapon_slots + 1] = n end
    end
    cur.weapon_atks = {}
    for s in string.gmatch(packet.weapon_atks or "", "([^,]+)") do
        cur.weapon_atks[#cur.weapon_atks + 1] = s
    end
    cur.stone_slot = tonumber(packet.stone_slot) or -1
    cur.stone_count = tonumber(packet.stone_count) or 0
    cur.ticket_slot = tonumber(packet.ticket_slot) or -1
    cur.ticket_count = tonumber(packet.ticket_count) or 0
    if cur.ticket_count <= 0 then ticket_on = false end
    cur.result = packet.result or ""
    cur.from_level = tonumber(packet.from_level) or 0
    cur.to_level = tonumber(packet.to_level) or 0
    -- 판정 결과면 공개 전에 "강화 중 — 땅! 땅! 땅!" 연출 (기존 화면 위 오버레이).
    -- S2C 핸들러는 task 로 실행되므로(callAsTaskRawArg) task_sleep 안전.
    local r = cur.result
    if (r == "success" or r == "keep" or r == "down" or r == "destroy" or r == "protected")
        and suspense ~= nil and not fx_running then
        fx_running = true
        pcall(function()
            suspense.layer:visible(true)
            -- 1초 사이클 x 3 = 약 3초. 토스트 전체가 코사인 곡선으로
            -- 서서히 어두워졌다 밝아짐 (1.0 → 0.1 → 1.0). 사이클 시작마다 땅! 추가.
            for cycle = 1, 3 do
                suspense.hits[cycle]:visible(true)
                for t = 1, 20 do   -- 50ms x 20 = 1초
                    local a = 0.55 + 0.45 * math.cos(t / 20 * 2 * math.pi)
                    suspense.band:opacity(a)
                    task_sleep(50)
                end
            end
            suspense.band:opacity(1)
        end)
        fx_running = false
    end
    open_enhance()
    -- 결과 채팅 (연출이 끝난 뒤 출력 — 서버가 보내면 연출 전에 스포일러라 클라가 담당)
    if r == "success" or r == "keep" or r == "down" or r == "destroy" or r == "protected" then
        local wn = (fx_weapon_name ~= "") and ("§f" .. fx_weapon_name .. " ") or ""
        local m
        if r == "success" then
            m = "§6[강화] " .. wn .. "§a강화 성공! §7+" .. cur.from_level .. " §8→ §a+" .. cur.to_level
        elseif r == "protected" then
            m = "§6[강화] " .. wn .. "§b파괴 방지! §7파괴방지권으로 보호됨 (+" .. cur.to_level .. ")"
        elseif r == "keep" then
            m = "§6[강화] " .. wn .. "§e강화 실패 §7— 단계 유지 (+" .. cur.to_level .. ")"
        elseif r == "down" then
            m = "§6[강화] " .. wn .. "§c강화 실패 §7— 단계 하락 +" .. cur.from_level .. " §8→ §c+" .. cur.to_level
        else
            m = "§6[강화] " .. wn .. "§4강화 실패 — 장비가 파괴되었습니다!"
        end
        pcall(function() aris.game.client.send_system_message(m) end)
    end
end)

-- 토스트 자동 사라짐 타이머 (클라 틱 훅 1개. 새 jar LuaFunc 수정으로 안전)
pcall(function()
    aris.game.client.hook.add_tick_hook(function()
        if toast_timer > 0 then
            toast_timer = toast_timer - 1
            if toast_timer <= 0 and toast_el ~= nil then
                pcall(function() toast_el:visible(false) end)
                toast_el = nil
            end
        end
    end)
end)
