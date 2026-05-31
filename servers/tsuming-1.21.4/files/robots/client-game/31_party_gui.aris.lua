-- 파티 GUI — GTCanvas(gtc) (길드 30_guild_gui 미러)
--  * 트리/on_click 생성은 S2C 핸들러(task 컨텍스트)에서. on_click 안에서는 visible 토글/패킷전송/get_text/close만.
--  * 초대는 같은 화면 안에서 visible 토글로 전환(파티장 전용).

local C_TEXT = 0xFFEAEAEA
local C_SUB  = 0xFFA0A0A0
local C_GOLD = 0xFFFACC15

local COL_CREATE  = { 34, 197, 94 }
local COL_ACCEPT  = { 59, 130, 246 }
local COL_DENY    = { 239, 68, 68 }
local COL_LEAVE   = { 234, 140, 40 }
local COL_DISBAND = { 239, 68, 68 }

local cur = {
    in_party = 0, members = 0, leader = "", member_names = "", leader_name = "", has_invite = 0,
}
local invite_input = nil

local function send_action(action, value)
    local p = aris.game.client.networking.create_c2s_packet_builder("party_gui_action")
    p:append_string("action", action)
    p:append_string("value", value or "")
    aris.game.client.networking.send_c2s_packet(p)
end

local function do_invite()
    local nm = ""
    if invite_input ~= nil then nm = invite_input:get_text() or "" end
    if nm == "" then
        aris.game.client.send_system_message("§e[파티] 초대할 플레이어 이름을 입력하세요")
        return
    end
    send_action("invite", nm)
end

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

local function member_row(member_name, is_leader_view, leader_name)
    local is_the_leader = (member_name == leader_name)
    local row = gtc.row():justify("space_between"):align("center"):padding4(6, 12, 6, 12)
        :background(gtc.rgba(26, 26, 26, 255))
        :border(1, gtc.rgba(38, 38, 38, 255))
        :border_radius(6)
        :add(gtc.label(member_name .. (is_the_leader and "  ★" or ""))
            :font_size(13):color(is_the_leader and C_GOLD or C_SUB))
    if is_leader_view and not is_the_leader then
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
    invite_input = nil

    if cur.in_party == 0 then
        -- 미가입
        local header = gtc.row():align("center"):justify("space_between")
            :add(gtc.label("파티"):font_size(22):font_weight(700):color(C_TEXT))
            :add(pill("미가입", { 120, 120, 120 }, C_SUB))

        local body = gtc.column():gap(10):align("stretch")
            :add(gtc.label("파티에 가입되어 있지 않습니다"):font_size(15):color(C_TEXT))
            :add(gtc.label("파티를 만들거나 초대를 받으세요"):font_size(13):color(C_SUB))
        if cur.has_invite == 1 then
            body:add(pill("받은 초대가 있습니다 — 수락 / 거절", { 250, 204, 21 }, C_GOLD))
        end

        local left = gtc.row():align("center"):gap(8)
            :add(accent_btn("생성", COL_CREATE, function() send_action("create") end))
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

    -- 가입 상태 (파티원이 메인) ────────────────────────────────
    local is_leader = (cur.leader == "파티장")
    local party_view, invite_view

    local pills = gtc.row():align("center"):gap(6)
        :add(pill(tostring(cur.members) .. "명", { 250, 204, 21 }, C_GOLD))
    local header = gtc.row():align("center"):justify("space_between")
        :add(gtc.label("파티"):font_size(22):font_weight(700):color(C_TEXT))
        :add(pills)

    local list_col = gtc.column():gap(6):align("stretch")
    local members = split_members(cur.member_names)
    if #members == 0 then
        list_col:add(gtc.label("-"):font_size(13):color(C_SUB))
    else
        for _, mn in ipairs(members) do
            list_col:add(member_row(mn, is_leader, cur.leader_name))
        end
    end
    local body = gtc.column():gap(6):align("stretch")
        :add(gtc.label("파티원 (" .. tostring(cur.members) .. ")"):font_size(11):color(0xFF606060))
        :add(gtc.scroll_view():min_height(270):max_height(270):align("stretch"):add(list_col))

    local left = gtc.row():align("center"):gap(8)
        :add(neutral_btn("새로고침", function() send_action("refresh") end))
    if is_leader then
        left:add(accent_btn("초대", COL_ACCEPT, function()
            party_view:visible(false)
            invite_view:visible(true)
        end))
        left:add(accent_btn("해산", COL_DISBAND, function() send_action("disband") end))
    else
        left:add(accent_btn("탈퇴", COL_LEAVE, function() send_action("leave") end))
    end
    local footer = gtc.row():justify("space_between"):align("center")
        :add(left)
        :add(neutral_btn("닫기", function() gtc.close_screen() end))

    party_view = gtc.column():align("stretch"):gap(14)
        :add(header)
        :add(gtc.panel():height(1):background(gtc.rgba(42, 42, 42, 255)))
        :add(body)
        :add(footer)

    if is_leader then
        invite_input = gtc.input()
            :placeholder("초대할 플레이어 이름")
            :height(38)
            :background(gtc.rgba(14, 14, 14, 255))
            :border(1, gtc.rgba(42, 42, 42, 255))
            :border_radius(6)
            :color(C_TEXT)

        local iheader = gtc.row():align("center"):justify("space_between")
            :add(gtc.label("파티원 초대"):font_size(22):font_weight(700):color(C_TEXT))
            :add(pill(tostring(cur.members) .. "명", { 250, 204, 21 }, C_GOLD))

        local ifooter = gtc.row():justify("space_between"):align("center")
            :add(accent_btn("초대", COL_ACCEPT, do_invite))
            :add(neutral_btn("뒤로", function()
                invite_view:visible(false)
                party_view:visible(true)
            end))

        invite_view = gtc.column():align("stretch"):gap(14)
            :add(iheader)
            :add(gtc.label("초대할 플레이어가 온라인이어야 합니다"):font_size(13):color(C_SUB))
            :add(invite_input)
            :add(ifooter)
        invite_view:visible(false)
    end

    local panel = panel_column():add(party_view)
    if invite_view ~= nil then panel:add(invite_view) end
    return panel
end

local function open_party()
    if gtc == nil then
        aris.game.client.send_system_message("§c[파티] gtc 라이브러리 없음 — GTCanvasAris 모드 확인")
        return
    end
    local tree = build_tree()
    local centered = gtc.column():flex(1):align("center"):justify("center"):add(tree)
    gtc.open_screen(true, function(root) root:add(centered) end)
end

aris.game.client.hook.add_s2c_packet_handler("party_sync", function(packet)
    cur.in_party = tonumber(packet.in_party) or 0
    cur.members = tonumber(packet.members) or 0
    cur.leader = packet.leader or ""
    cur.member_names = packet.member_names or ""
    cur.leader_name = packet.leader_name or ""
    cur.has_invite = tonumber(packet.has_invite) or 0
    open_party()
end)

-- (유지용 무한 루프 제거: 패킷 핸들러는 등록 후 task 가 끝나도 유지됨)
