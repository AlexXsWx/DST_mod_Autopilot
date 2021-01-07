local asyncUtils = {}

function asyncUtils.getWaitUntil(playerInst)
    local function waitUntil(checkCondition, callback)
        local function loop()
            if checkCondition() then
                callback()
                return
            end
            playerInst:DoTaskInTime(1, loop)
        end
        playerInst:DoTaskInTime(1, loop)
    end
    return waitUntil
end

return asyncUtils
