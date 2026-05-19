package.path = package.path
    .. ";./lua_libs/?.lua"
    .. ";./lua_libs/?/init.lua"
    .. ";./lua_libs/?/?.lua"

local ok, lunajson_or_error = pcall(require, "lunajson")

if not ok then
    aris.log_error("[lunajson_loader] require('lunajson') FAILED: " .. tostring(lunajson_or_error))
    return
end

JSON = lunajson_or_error

aris.log_info("[lunajson_loader] lunajson loaded")
