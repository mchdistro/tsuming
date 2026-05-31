-- GTCanvasAris 테스트: G 키를 누르면 GTCanvas(gtc) 화면을 연다.
--
-- 중요(엔진 제약): on_key_pressed 콜백은 engine.loop() 밖에서 실행되어
-- currentTask 가 nil 이다. 그 안에서 gtc 콜백(LuaFunc)을 만들면 NPE 로 죽는다
-- (LuaFunc.kt: `engine.currentTask!!`). 그래서:
--   1) 키 콜백은 플래그만 세운다 (LuaFunc 생성 없음).
--   2) 실제 화면 생성은 메인 루프(task 컨텍스트, currentTask 있음)에서 한다.
--   3) 버튼 트리도 메인 루프에서 미리 만들고, open_screen 빌더는 붙이기만 한다
--      → 화면 buildUI 시점(렌더스레드)에 LuaFunc 를 만들지 않으므로 안전.

local want_open = false

aris.game.client.hook.on_key_pressed("gtc_test", function()
    want_open = true
end)

local function build_tree()
    -- 인풋 참조를 잡아둔다 → 버튼 클릭 시 get_text()로 현재 값 읽기
    local input = gtc.input()
        :placeholder("길드 이름을 입력해보세요")
        :width(372):height(34)
        :background(gtc.rgba(14, 14, 14, 255))
        :border(1, gtc.rgba(42, 42, 42, 255))
        :border_radius(6)
        :color(0xFFEAEAEA)
        :on_change(function(v)
            aris.log_info("[gtctest] 입력 변경: " .. tostring(v))
        end)

    local ok_btn = gtc.button("확인")
        :width(120):height(38):border_radius(8)
        :background(gtc.rgba(34, 197, 94, 46))
        :border(1, gtc.rgba(34, 197, 94, 150))
        :color(0xFF22C55E)
        :on_click(function()
            local text = input:get_text()
            if text == nil or text == "" then
                aris.game.client.send_system_message("§e[gtctest] 입력값이 비어있음")
            else
                aris.game.client.send_system_message("§a[gtctest] 입력값: §f" .. tostring(text))
            end
            gtc.close_screen()
        end)

    return gtc.column()
        :width(420):padding(24):gap(14)
        :background(gtc.rgba(20, 20, 20, 245))
        :border(1, gtc.rgba(42, 42, 42, 255))
        :border_radius(12)
        :add(gtc.label("GTCanvas 테스트")
            :font_size(22):font_weight(700):color(0xFFEAEAEA))
        :add(gtc.label("입력값 가져오기 테스트 — 입력 후 확인")
            :font_size(13):color(0xFFA0A0A0))
        :add(input)
        :add(gtc.row()
            :gap(10)
            :add(ok_btn)
            :add(gtc.button("닫기")
                :width(120):height(38):border_radius(8)
                :background(gtc.rgba(30, 30, 30, 255))
                :border(1, gtc.rgba(42, 42, 42, 255))
                :color(0xFFA0A0A0)
                :on_click(function()
                    gtc.close_screen()
                end)))
end

local function open_test()
    if gtc == nil then
        aris.game.client.send_system_message("§c[gtctest] gtc 라이브러리 없음 — 모드 미로드")
        return
    end
    local tree = build_tree()
    -- 화면 전체를 채우는 래퍼로 감싸 중앙 정렬 (GTShop 방식)
    local centered = gtc.column()
        :flex(1)
        :align("center")
        :justify("center")
        :add(tree)
    gtc.open_screen(true, function(root)
        root:add(centered)
    end)
end

while true do
    if want_open then
        want_open = false
        open_test()
    end
    task_sleep(50)
end
