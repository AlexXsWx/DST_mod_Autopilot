local function log(msg)
    print("[Mod_AQP] " .. msg)
end

local logger = {}

function logger.logError(msg)
    log("Error: " .. msg)
end

function logger.logWarning(msg)
    log("Warning: " .. msg)
end

function logger.logDebug(msg)
    log(msg)
end

return logger
