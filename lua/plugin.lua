local runtime = require("talkcan.runtime")
local log = require("talkcan.log")
local channel = require("talkcan.channel")

local release_marker = "1.3.2"

local function typed_runtime_code(failure, fallback)
    if type(failure) == "table" and type(failure.error) == "string" and failure.error ~= "" then
        return failure.error
    end
    return fallback
end

local function empty_table(value)
    if type(value) ~= "table" then
        return false
    end
    return next(value) == nil
end

local function valid_configuration(configuration)
    if type(configuration) ~= "table" then
        return false
    end

    local keys = 0
    for key in pairs(configuration) do
        if key ~= "schema_version" and key ~= "values" then
            return false
        end
        keys = keys + 1
    end

    return keys == 2 and configuration.schema_version == 1 and empty_table(configuration.values)
end

local function heartbeat_loop()
    local sequence = 0
    while true do
        sequence = sequence + 1
        log.info({
            event = "heartbeat",
            sequence = sequence,
            release_marker = release_marker
        })
        local ok, failure = runtime.sleep(30.0)
        if not ok then
            return {
                error = {
                    code = "E_HEARTBEAT_LIVENESS",
                    detail = typed_runtime_code(failure, "heartbeat timer unavailable")
                }
            }
        end
    end
end

local function startup(configuration)
    if not valid_configuration(configuration) then
        return {
            error = {
                code = "E_CONFIGURATION",
                detail = "expected schema_version 1 with empty values"
            }
        }
    end

    log.info({
        event = "startup",
        schema_version = 1,
        release_marker = release_marker
    })

    local ok, failure = runtime.spawn(heartbeat_loop)
    if not ok then
        return {
            error = {
                code = "E_SPAWN_FAILED",
                detail = typed_runtime_code(failure, "heartbeat admission failed")
            }
        }
    end
    return { input = { max_duration_ms = 60000 } }
end

local function handle_lifecycle(event)
    local ready_event = channel.LIFECYCLE_READY or "ready"
    if type(event) ~= "table" or event.event ~= ready_event then
        return {
            error = {
                code = "E_LIFECYCLE",
                detail = "unexpected lifecycle event"
            }
        }
    end
    log.info({
        event = "ready",
        release_marker = release_marker
    })
end

local function handle_readiness()
    return { ready = true }
end

local function bounded_number(value, maximum)
    return type(value) == "number" and value == value and value >= 0 and value <= maximum
end

local function bounded_positive_integer(value, maximum)
    return type(value) == "number" and value == value and value > 0 and value <= maximum and value % 1 == 0
end

local function handle_input(event)
    local capture_event = channel.CAPTURE_COMPLETE or "capture"
    if type(event) ~= "table" or event.event ~= capture_event or type(event.session) ~= "string" then
        return {
            error = {
                code = "E_INPUT",
                detail = "unexpected capture event"
            }
        }
    end

    local metadata = event.metadata
    if type(metadata) ~= "table" or
        not bounded_number(metadata.duration_ms, 86400000) or
        not bounded_positive_integer(metadata.sample_rate, 384000) or
        not bounded_number(metadata.channels, 32) then
        return {
            error = {
                code = "E_INPUT_MALFORMED",
                detail = "malformed capture metadata"
            }
        }
    end

    log.info({
        event = "input",
        duration_ms = metadata.duration_ms,
        sample_rate_hz = metadata.sample_rate,
        channel_count = metadata.channels,
        release_marker = release_marker
    })
    return { ok = true }
end

local function handle_sos(event)
    local sos_event = channel.SOS_TRIGGERED or "sos"
    if type(event) ~= "table" or event.event ~= sos_event then
        return {
            error = {
                code = "E_SOS",
                detail = "unexpected SOS event"
            }
        }
    end
    log.info({
        event = "sos",
        release_marker = release_marker
    })
end

return {
    startup = startup,
    handle_lifecycle = handle_lifecycle,
    handle_readiness = handle_readiness,
    handle_input = handle_input,
    handle_sos = handle_sos,
}
