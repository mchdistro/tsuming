depends_on("20_stats_core.aris")

local STORAGE_CONFIG = {
    mongo = {
        enabled = true,
        players_collection = "players",
    },
    redis = {
        enabled = true,
    },
    stats = {
        redis_key_prefix = "rpg:player:",
        flush_interval_ms = 5000,
    },
}

STATS.storage = STATS.storage or {}
STATS.storage.ready = false
STATS.storage.mongo_enabled = true
STATS.storage.redis_enabled = true
STATS.storage.players_collection = "players"
STATS.storage.redis_key_prefix = "rpg:player:"
STATS.storage.flush_interval_ms = 5000

local function now_ms()
    return math.floor(os.time() * 1000)
end

local function safe_decode(value)
    if value == nil or value == "" then return nil end
    local ok, decoded = pcall(JSON.decode, value)
    if ok and type(decoded) == "table" then
        return decoded
    end
    aris.log_warn("[stats-storage] JSON decode failed: " .. tostring(decoded))
    return nil
end

local function load_config()
    local mongo = STORAGE_CONFIG.mongo or {}
    local redis = STORAGE_CONFIG.redis or {}
    local stats = STORAGE_CONFIG.stats or {}

    STATS.storage.mongo_enabled = mongo.enabled ~= false
    STATS.storage.redis_enabled = redis.enabled ~= false
    STATS.storage.players_collection = tostring(mongo.players_collection or "players")
    STATS.storage.redis_key_prefix = tostring(stats.redis_key_prefix or "rpg:player:")
    STATS.storage.flush_interval_ms = tonumber(stats.flush_interval_ms) or 5000
    STATS.storage.ready = true
end

local function collection()
    if not STATS.storage.mongo_enabled then return nil end
    return aris.game.mongo.collection(STATS.storage.players_collection)
end

function STATS.redis_key(uuid)
    return STATS.storage.redis_key_prefix .. tostring(uuid) .. ":stats"
end

function STATS.serialize_stats(uuid, name)
    local stats = STATS.get_by_uuid(uuid)
    return {
        points = stats.points or 0,
        str = stats.str or 0,
        agi = stats.agi or 0,
        int = stats.int or 0,
        vit = stats.vit or 0,
        luk = stats.luk or 0,
        name = name or stats.name or "",
        updated_at = now_ms(),
    }
end

function STATS.apply_loaded(uuid, data)
    local next_stats = STATS.clone_defaults()
    if type(data) == "table" then
        local source = data.stats or data
        for key, _ in pairs(STATS.defaults) do
            next_stats[key] = tonumber(source[key]) or next_stats[key]
        end
    end
    STATS.cache[uuid] = STATS.normalize(next_stats)
    STATS.dirty[uuid] = nil
end

function STATS.save_redis(uuid, name)
    if not STATS.storage.redis_enabled then return false end
    local ok, err = pcall(function()
        aris.game.redis.set(STATS.redis_key(uuid), JSON.encode(STATS.serialize_stats(uuid, name)))
    end)
    if not ok then
        aris.log_warn("[stats-storage] Redis save failed for " .. tostring(uuid) .. ": " .. tostring(err))
        return false
    end
    return true
end

function STATS.load_redis(uuid)
    if not STATS.storage.redis_enabled then return nil end
    local ok, value = pcall(aris.game.redis.get, STATS.redis_key(uuid))
    if not ok then
        aris.log_warn("[stats-storage] Redis load failed for " .. tostring(uuid) .. ": " .. tostring(value))
        return nil
    end
    return safe_decode(value)
end

function STATS.load_mongo(uuid)
    local coll = collection()
    if coll == nil then return nil end
    local query = JSON.encode({ uuid = uuid })
    local ok, value = pcall(function()
        return coll:find_one(query)
    end)
    if not ok then
        aris.log_warn("[stats-storage] Mongo load failed for " .. tostring(uuid) .. ": " .. tostring(value))
        return nil
    end
    return safe_decode(value)
end

function STATS.flush_mongo(uuid, name)
    local coll = collection()
    if coll == nil then return false end

    local stats_doc = STATS.serialize_stats(uuid, name)
    local query = JSON.encode({ uuid = uuid })
    local ok, err = pcall(function()
        if coll:count(query) <= 0 then
            coll:insert(JSON.encode({
                uuid = uuid,
                name = stats_doc.name,
                stats = stats_doc,
            }))
        else
            coll:update(query, JSON.encode({
                ["$set"] = {
                    name = stats_doc.name,
                    stats = stats_doc,
                }
            }))
        end
    end)

    if not ok then
        aris.log_warn("[stats-storage] Mongo flush failed for " .. tostring(uuid) .. ": " .. tostring(err))
        return false
    end

    STATS.dirty[uuid] = nil
    return true
end

function STATS.flush_dirty()
    for uuid, dirty in pairs(STATS.dirty) do
        if dirty and STATS.cache[uuid] ~= nil then
            STATS.flush_mongo(uuid, STATS.cache[uuid].name or "")
        end
    end
end

function STATS.load_player(player)
    local uuid = STATS.player_uuid(player)
    if uuid == "" then return end
    if STATS.cache[uuid] ~= nil then return end
    local name = STATS.player_name(player)

    local loaded = STATS.load_redis(uuid)
    if loaded == nil then
        loaded = STATS.load_mongo(uuid)
        if loaded == nil then
            loaded = STATS.clone_defaults()
        end
    end

    STATS.apply_loaded(uuid, loaded)
    STATS.cache[uuid].name = name
    STATS.save_redis(uuid, name)
    aris.log_info("[stats-storage] Loaded stats for " .. name)
end

function STATS.flush_player(player)
    local uuid = STATS.player_uuid(player)
    if uuid == "" then return end
    local name = STATS.player_name(player)
    STATS.save_redis(uuid, name)
    STATS.flush_mongo(uuid, name)
end

function STATS.unload_player(player)
    local uuid = STATS.player_uuid(player)
    if uuid == "" then return end
    STATS.cache[uuid] = nil
    STATS.dirty[uuid] = nil
end

local previous_mark_dirty = STATS.mark_dirty
function STATS.mark_dirty(uuid)
    previous_mark_dirty(uuid)
    local cached = STATS.cache[uuid]
    STATS.save_redis(uuid, cached ~= nil and cached.name or "")
end

load_config()
