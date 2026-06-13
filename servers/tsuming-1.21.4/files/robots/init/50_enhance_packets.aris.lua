-- 무기 강화 — 패킷 정의 + 명령어
-- (클라 파싱용 동일 정의는 client-init/50_enhance_packets.aris.lua 에도 있음)
-- 선택/파괴방지권 상태는 클라가 관리하므로 select/ticket 패킷은 없음.

-- S2C: 강화창 오픈/갱신 (서버가 인벤 현황만 내려줌)
local open = aris.init.networking.create_s2c_packet("enhance_open")
open:append(aris.init.networking.string_arg("weapon_slots"))  -- "0,3,7" 강화 가능 무기 슬롯들
open:append(aris.init.networking.integer_arg("stone_slot"))   -- 강화석 대표 슬롯(렌더용), 없으면 -1
open:append(aris.init.networking.integer_arg("stone_count"))  -- 강화석 보유 총합
open:append(aris.init.networking.integer_arg("ticket_slot"))  -- 파괴방지권 대표 슬롯, 없으면 -1
open:append(aris.init.networking.integer_arg("ticket_count")) -- 파괴방지권 보유 총합
open:append(aris.init.networking.string_arg("result"))        -- 결과 토스트 타입 ("" 없음)
open:append(aris.init.networking.integer_arg("from_level"))   -- 강화 전 단계
open:append(aris.init.networking.integer_arg("to_level"))     -- 강화 후 단계

-- C2S: 강화 실행 ([강화하기] 클릭). 클라가 선택 슬롯 + 파괴방지권 사용여부를 함께 전송
local do_pkt = aris.init.networking.create_c2s_packet("enhance_do")
do_pkt:append(aris.init.networking.integer_arg("slot"))
do_pkt:append(aris.init.networking.integer_arg("use_ticket")) -- 0/1

-- 명령어 (Aris 는 한글 명령어 리터럴 미지원 → 영문만)
local function register_command(name)
    local root = aris.init.command.create_command(name)
    root:set_endpoint("enhance_open")
end
register_command("enhance")
register_command("enh")
