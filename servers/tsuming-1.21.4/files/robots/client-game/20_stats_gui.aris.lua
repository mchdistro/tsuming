depends_on("00_lunajson_loader.aris")

local WIDTH = 520
local HEIGHT = 360
local START_X = 700
local START_Y = 300
local ROW_X = 48
local ROW_Y = 96
local ROW_H = 44
local VALUE_X = 260
local BUTTON_X = 410
local BUTTON_W = 64
local BUTTON_H = 32

local STAT_ORDER = { "str", "agi", "int", "vit", "luk" }
local STAT_LABELS = {
    str = "힘",
    agi = "민첩",
    int = "지능",
    vit = "체력",
    luk = "운",
}

local screen = nil
local root = nil
local points_text = nil
local rows = {}
local screen_opened = false
local current = {
    points = 0,
    str = 0,
    agi = 0,
    int = 0,
    vit = 0,
    luk = 0,
}

local function send_add(stat)
    local packet = aris.game.client.networking.create_c2s_packet_builder("stats_add_point")
    packet:append_string("stat", stat)
    aris.game.client.networking.send_c2s_packet(packet)
end

local function close_screen()
    if screen == nil then return end
    screen_opened = false
    screen:close()
end

local function add_text(parent, text, x, y, color, scale)
    local renderer = aris.client.create_default_text_renderer(text, color or 0xFFFFFFFF)
    renderer:set_x(x)
    renderer:set_y(y)
    renderer:set_scale(scale or 1.0)
    parent:add_child(renderer)
    return renderer
end

local function add_rect(parent, x, y, w, h, r, g, b, a)
    local renderer = aris.client.create_color_renderer(r, g, b, a)
    renderer:set_x(x)
    renderer:set_y(y)
    renderer:set_width(w)
    renderer:set_height(h)
    parent:add_child(renderer)
    return renderer
end

local function create_once()
    if screen ~= nil then return end

    screen = aris.client.create_window()
    screen:set_can_exit_with_esc(false)

    root = aris.client.create_component()
    root:set_x(START_X)
    root:set_y(START_Y)
    screen:add_child(root)

    add_rect(root, 0, 0, WIDTH, HEIGHT, 10, 10, 18, 240)
    add_rect(root, 6, 6, WIDTH - 12, HEIGHT - 12, 34, 34, 50, 225)
    add_rect(root, 18, 68, WIDTH - 36, 2, 95, 95, 130, 210)
    add_text(root, "스탯", 28, 24, 0xFFFFFFFF, 3.0)
    points_text = add_text(root, "보유 포인트: 0", 270, 32, 0xFFFFE082, 1.7)

    for i, stat in ipairs(STAT_ORDER) do
        local y = ROW_Y + ((i - 1) * ROW_H)
        add_rect(root, 28, y - 8, WIDTH - 56, ROW_H - 6, 22, 22, 34, 205)
        add_text(root, STAT_LABELS[stat], ROW_X, y, 0xFFFFFFFF, 2.0)
        local value = add_text(root, "0", VALUE_X, y, 0xFFB3E5FC, 2.0)

        add_rect(root, BUTTON_X, y - 7, BUTTON_W, BUTTON_H, 50, 120, 58, 235)
        add_text(root, "+", BUTTON_X + 23, y - 3, 0xFFFFFFFF, 2.0)
        local clickable = aris.client.create_clickable(function()
            send_add(stat)
        end, BUTTON_X, y - 7, BUTTON_W, BUTTON_H)
        root:add_child(clickable)

        rows[stat] = { value = value }
    end

    add_rect(root, 208, HEIGHT - 52, 104, 34, 70, 70, 88, 230)
    add_text(root, "닫기", 236, HEIGHT - 45, 0xFFFFFFFF, 1.5)
    root:add_child(aris.client.create_clickable(function()
        close_screen()
    end, 208, HEIGHT - 52, 104, 34))
end

local function refresh()
    create_once()
    points_text:set_text("보유 포인트: " .. tostring(current.points or 0))
    for _, stat in ipairs(STAT_ORDER) do
        if rows[stat] ~= nil then
            rows[stat].value:set_text(tostring(current[stat] or 0))
        end
    end
end

local function open_screen()
    create_once()
    refresh()
    if screen_opened then
        return
    end
    screen_opened = true
    screen:open()
end

aris.game.client.hook.add_s2c_packet_handler("stats_sync", function(packet)
    aris.game.client.send_system_message("[stats] stats_sync received")
    if JSON == nil then
        aris.game.client.send_system_message("[stats] JSON is nil; check lua_libs in client profile")
        return
    end
    local ok, decoded = pcall(JSON.decode, packet.payload or "{}")
    if not ok then
        aris.game.client.send_system_message("스탯 데이터를 읽지 못했습니다.")
        return
    end

    current.points = tonumber(decoded.points) or 0
    current.str = tonumber(decoded.str) or 0
    current.agi = tonumber(decoded.agi) or 0
    current.int = tonumber(decoded.int) or 0
    current.vit = tonumber(decoded.vit) or 0
    current.luk = tonumber(decoded.luk) or 0
    open_screen()
end)

while true do
    task_sleep(1000)
end
