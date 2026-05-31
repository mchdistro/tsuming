local attr = aris.init.geckolib.entity_attr()
attr:max_health(1856794)
attr:armor(1000000)
attr:movement_speed(0)
attr:follow_range(2048)

local function register(key, width, height)
    aris.init.geckolib.create_entity(key, width or 0.1, height or 0.1, attr)
end

for i = 1, 8 do
    register("brutal_combo_" .. tostring(i))
    register("relentless_whirlwind_" .. tostring(i))
end

for i = 1, 13 do
    register("berserker_leap_" .. tostring(i))
    register("strike_of_fury_" .. tostring(i))
    register("vicious_strike_" .. tostring(i))
end

register("bloodbound_barrier")
register("vicious_strike_charge")
