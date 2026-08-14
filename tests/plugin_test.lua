package.preload["talkcan.runtime"] = function()
    return {
        spawn = function(worker)
            assert(type(worker) == "function")
            return true
        end,
    }
end
package.preload["talkcan.log"] = function()
    return {
        info = function() end,
    }
end
package.preload["talkcan.channel"] = function()
    return {}
end

local plugin = assert(loadfile("lua/plugin.lua"))()
local result = plugin.startup({
    schema_version = 1,
    values = {},
})

assert(type(result) == "table")
assert(type(result.input) == "table")
assert(result.input.max_duration_ms == 60000)
assert(next(result) == "input")
assert(next(result, "input") == nil)
assert(next(result.input) == "max_duration_ms")
assert(next(result.input, "max_duration_ms") == nil)

print("diagnostics plugin tests passed")
