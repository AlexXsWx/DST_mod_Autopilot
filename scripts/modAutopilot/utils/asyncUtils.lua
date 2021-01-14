local asyncUtils = {}

--

function asyncUtils.setImmediate(playerInst, fn)
    playerInst:DoTaskInTime(0, fn)
end

--

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

--

function asyncUtils.getStartThread(playerInst)
    return function(threadFn)
        local thread = playerInst:StartThread(threadFn)
        return thread
    end
end

function asyncUtils.cancelThread(thread)
    if thread then thread:SetList(nil) end
end

--

return asyncUtils
