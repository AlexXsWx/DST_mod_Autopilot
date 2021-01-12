local function log(msg)
    print("[Mod_AQP] " .. msg)
end

local logger = {}

local debugAllowed = false

function logger.logError(msg)
    log("Error: " .. msg)
end

function logger.logWarning(msg)
    log("Warning: " .. msg)
end

function logger.logDebug(msg)
    if debugAllowed then
        log(msg)
    end
end

function logger.setDebugEnabled(enabled)
    debugAllowed = enabled
end

return logger
