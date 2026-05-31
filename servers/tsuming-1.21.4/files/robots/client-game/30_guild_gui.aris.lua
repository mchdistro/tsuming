-- 길드 GUI — GTCanvas(gtc) 포팅판
--
-- 엔진 제약 메모:
--  * 트리/on_click 생성은 S2C 핸들러(task 컨텍스트)에서 한다 → currentTask 있음, 안전.
--  * 버튼 on_click 안에서는 새 LuaFunc 금지. 패킷 전송 / get_text / close / visible 토글만.
--  * 초대는 새 화면을 여는 게 아니라, 같은 화면 안에서 뷰를 visible 토글로 전환한다.
--    (길드 뷰 / 초대 뷰를 둘 다 미리 만들어 두고 visible 로 바꿈 — GTShop 방식)

local C_TEXT = 0xFFEAEAEA
local C_SUB  = 0xFFA0A0A0
local C_GOLD = 0xFFFACC15

local COL_CREATE  = { 34, 197, 94 }
local COL_ACCEPT  = { 59, 130, 246 }
local COL_DENY    = { 239, 68, 68 }
local COL_LEAVE   = { 234, 140, 40 }
local COL_DISBAND = { 239, 68, 68 }

local cur = {
    in_guild = 0, name = "", level = 0, exp = 0,
    members = 0, owner = "", member_names = "", owner_name = "", has_invite = 0,
}
local name_input = nil    -- 길드 생성 이름 입력
local invite_input = nil  -- 초대 대상 이름 입력

local function send_action(action, value)
    local p = aris.game.client.networking.create_c2s_packet_builder("guild_gui_action")
    p:append_string("action", action)
    p:append_string("value", value or "")
    aris.game.client.networking.send_c2s_packet(p)
end

local function do_create()
    local nm = ""
    if name_input ~= nil then nm = name_input:get_text() or "" end
    send_action("create", nm)
end

local function do_invite()
    local nm = ""
    if invite_input ~= nil then nm = invite_input:get_text() or "" end
    if nm == "" then
        aris.game.client.send_system_message("§e[길드] 초대할 플레이어 이름을 입력하세요")
        return
    end
    send_action("invite", nm)
end

-- "a, b, c" → { "a", "b", "c" }
local function split_members(s)
    local out = {}
    for part in string.gmatch(s or "", "([^,]+)") do
        local t = string.gsub(string.gsub(part, "^%s+", ""), "%s+$", "")
        if t ~= "" then out[#out + 1] = t end
    end
    return out
end

local function accent_btn(label, rgb, on_click)
    return gtc.button(label)
        :height(38):border_radius(8)
        :background(gtc.rgba(rgb[1], rgb[2], rgb[3], 46))
        :border(1, gtc.rgba(rgb[1], rgb[2], rgb[3], 150))
        :color(0xFF000000 + rgb[1] * 0x10000 + rgb[2] * 0x100 + rgb[3])
        :on_click(on_click)
end

local function neutral_btn(label, on_click)
    return gtc.button(label)
        :height(38):border_radius(8)
        :background(gtc.rgba(30, 30, 30, 255))
        :border(1, gtc.rgba(42, 42, 42, 255))
        :color(C_SUB)
        :on_click(on_click)
end

-- 작은 버튼 (길드원 추방용)
local function mini_btn(label, rgb, on_click)
    return gtc.button(label)
        :height(26):width(56):border_radius(6)
        :background(gtc.rgba(rgb[1], rgb[2], rgb[3], 46))
        :border(1, gtc.rgba(rgb[1], rgb[2], rgb[3], 150))
        :color(0xFF000000 + rgb[1] * 0x10000 + rgb[2] * 0x100 + rgb[3])
        :on_click(on_click)
end

local function pill(text, rgb, text_color)
    return gtc.row():padding4(3, 11, 3, 11):border_radius(8)
        :background(gtc.rgba(rgb[1], rgb[2], rgb[3], 20))
        :border(1, gtc.rgba(rgb[1], rgb[2], rgb[3], 90))
        :add(gtc.label(text):font_size(11):color(text_color))
end

local function info_row(label, value)
    return gtc.row():justify("space_between"):align("center"):padding4(10, 14, 10, 14)
        :background(gtc.rgba(26, 26, 26, 255))
        :border(1, gtc.rgba(38, 38, 38, 255))
        :border_radius(8)
        :add(gtc.label(label):font_size(13):color(C_SUB))
        :add(gtc.label(value):font_size(14):color(C_TEXT))
end

-- 길드원 한 명 행 (길드장이면 추방 버튼)
local function member_row(member_name, is_owner_view, owner_name)
    local is_the_owner = (member_name == owner_name)
    local row = gtc.row():justify("space_between"):align("center"):padding4(6, 12, 6, 12)
        :background(gtc.rgba(26, 26, 26, 255))
        :border(1, gtc.rgba(38, 38, 38, 255))
        :border_radius(6)
        :add(gtc.label(member_name .. (is_the_owner and "  ★" or ""))
            :font_size(13):color(is_the_owner and C_GOLD or C_SUB))
    if is_owner_view and not is_the_owner then
        row:add(mini_btn("추방", { 239, 68, 68 }, function()
            send_action("kick", member_name)
        end))
    end
    return row
end

local function panel_column()
    return gtc.column():width(480):padding(24):align("stretch")
        :background(gtc.rgba(20, 20, 20, 245))
        :border(1, gtc.rgba(42, 42, 42, 255))
        :border_radius(12)
end

local function build_tree()
    name_input = nil
    invite_input = nil

    if cur.in_guild == 0 then
        -- 미가입
        local header = gtc.row():align("center"):justify("space_between")
            :add(gtc.label("길드"):font_size(22):font_weight(700):color(C_TEXT))
            :add(pill("미가입", { 120, 120, 120 }, C_SUB))

        name_input = gtc.input()
            :placeholder("길드 이름 (비우면 기본 이름)")
            :height(36)
            :background(gtc.rgba(14, 14, 14, 255))
            :border(1, gtc.rgba(42, 42, 42, 255))
            :border_radius(6)
            :color(C_TEXT)

        local body = gtc.column():gap(10):align("stretch")
            :add(gtc.label("가입된 길드가 없습니다"):font_size(15):color(C_TEXT))
            :add(gtc.label("이름을 입력하고 생성을 누르세요"):font_size(13):color(C_SUB))
            :add(name_input)
        if cur.has_invite == 1 then
            body:add(pill("받은 초대가 있습니다 — 수락 / 거절", { 250, 204, 21 }, C_GOLD))
        end

        local left = gtc.row():align("center"):gap(8)
            :add(accent_btn("생성", COL_CREATE, do_create))
        if cur.has_invite == 1 then
            left:add(accent_btn("수락", COL_ACCEPT, function() send_action("accept") end))
            left:add(accent_btn("거절", COL_DENY, function() send_action("deny") end))
        end
        left:add(neutral_btn("새로고침", function() send_action("refresh") end))
        local footer = gtc.row():justify("space_between"):align("center")
            :add(left)
            :add(neutral_btn("닫기", function() gtc.close_screen() end))

        return panel_column():gap(16):add(header):add(body):add(footer)
    end

    -- 가입 상태 ───────────────────────────────────────────────
    local is_owner = (cur.owner == "길드장")
    local guild_view, invite_view  -- 토글용 (closure 가 캡처)

    -- 길드 뷰 ----------------------------------------------------
    -- 상단: 길드명 + 정보 pill (Lv / EXP / 인원)
    local pills = gtc.row():align("center"):gap(6)
        :add(pill("Lv. " .. tostring(cur.level), { 250, 204, 21 }, C_GOLD))
        :add(pill("EXP " .. tostring(cur.exp), { 120, 120, 120 }, C_SUB))
        :add(pill(tostring(cur.members) .. "명", { 120, 120, 120 }, C_SUB))
    local header = gtc.row():align("center"):justify("space_between")
        :add(gtc.label(cur.name):font_size(22):font_weight(700):color(C_TEXT))
        :add(pills)

    -- 메인: 길드원 목록 (고정 높이 스크롤 영역 — 인원 수와 무관하게 높이 일정)
    local list_col = gtc.column():gap(6):align("stretch")
    local members = split_members(cur.member_names)
    if #members == 0 then
        list_col:add(gtc.label("-"):font_size(13):color(C_SUB))
    else
        for _, mn in ipairs(members) do
            list_col:add(member_row(mn, is_owner, cur.owner_name))
        end
    end
    local body = gtc.column():gap(6):align("stretch")
        :add(gtc.label("길드원 (" .. tostring(cur.members) .. ")"):font_size(11):color(0xFF606060))
        :add(gtc.scroll_view():min_height(270):max_height(270):align("stretch"):add(list_col))

    local left = gtc.row():align("center"):gap(8)
        :add(neutral_btn("새로고침", function() send_action("refresh") end))
    if is_owner then
        -- 초대: 같은 화면 안에서 초대 뷰로 전환 (visible 토글, LuaFunc 생성 없음)
        left:add(accent_btn("초대", COL_ACCEPT, function()
            guild_view:visible(false)
            invite_view:visible(true)
        end))
        left:add(accent_btn("해산", COL_DISBAND, function() send_action("disband") end))
    else
        left:add(accent_btn("탈퇴", COL_LEAVE, function() send_action("leave") end))
    end
    local footer = gtc.row():justify("space_between"):align("center")
        :add(left)
        :add(neutral_btn("닫기", function() gtc.close_screen() end))

    guild_view = gtc.column():align("stretch"):gap(14)
        :add(header)
        :add(gtc.panel():height(1):background(gtc.rgba(42, 42, 42, 255)))
        :add(body)
        :add(footer)

    -- 초대 뷰 (길드장만, 처음엔 숨김) -----------------------------
    if is_owner then
        invite_input = gtc.input()
            :placeholder("초대할 플레이어 이름")
            :height(38)
            :background(gtc.rgba(14, 14, 14, 255))
            :border(1, gtc.rgba(42, 42, 42, 255))
            :border_radius(6)
            :color(C_TEXT)

        local iheader = gtc.row():align("center"):justify("space_between")
            :add(gtc.label("길드원 초대"):font_size(22):font_weight(700):color(C_TEXT))
            :add(pill("Lv. " .. tostring(cur.level), { 250, 204, 21 }, C_GOLD))

        local ifooter = gtc.row():justify("space_between"):align("center")
            :add(accent_btn("초대", COL_ACCEPT, do_invite))
            :add(neutral_btn("뒤로", function()
                invite_view:visible(false)
                guild_view:visible(true)
            end))

        invite_view = gtc.column():align("stretch"):gap(14)
            :add(iheader)
            :add(gtc.label("초대할 플레이어가 온라인이어야 합니다"):font_size(13):color(C_SUB))
            :add(invite_input)
            :add(ifooter)
        invite_view:visible(false)
    end

    -- 패널은 내용에 맞춤(고정 높이 X). 길드원 목록 스크롤(270px 고정)이
    -- 인원 수와 무관하게 높이를 일정하게 유지하므로 footer 아래 빈 슬랙이 없다.
    local panel = panel_column():add(guild_view)
    if invite_view ~= nil then panel:add(invite_view) end
    return panel
end

local function open_guild()
    if gtc == nil then
        aris.game.client.send_system_message("§c[길드] gtc 라이브러리 없음 — GTCanvasAris 모드 확인")
        return
    end
    local tree = build_tree()
    local centered = gtc.column():flex(1):align("center"):justify("center"):add(tree)
    gtc.open_screen(true, function(root) root:add(centered) end)
end

aris.game.client.hook.add_s2c_packet_handler("guild_sync", function(packet)
    cur.in_guild = tonumber(packet.in_guild) or 0
    cur.name = packet.name or ""
    cur.level = tonumber(packet.level) or 0
    cur.exp = tonumber(packet.exp) or 0
    cur.members = tonumber(packet.members) or 0
    cur.owner = packet.owner or ""
    cur.member_names = packet.member_names or ""
    cur.owner_name = packet.owner_name or ""
    cur.has_invite = tonumber(packet.has_invite) or 0
    open_guild()
end)

-- (유지용 무한 루프 제거: 패킷 핸들러는 등록 후 task 가 끝나도 유지됨)
