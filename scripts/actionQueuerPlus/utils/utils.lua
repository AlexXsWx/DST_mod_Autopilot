local constants = require "actionQueuerPlus/constants"
local logger    = require "actionQueuerPlus/utils/logger"

local utils = {}

--

function utils.toboolean(arg)
    return arg and true or false
end

--

function utils.override(obj, method, fn)
    local originalFn = obj[method]
    obj[method] = function(self, ...)
        return fn(self, originalFn, ...)
    end
end

function utils.overrideToCancelIf(obj, method, shouldCancelFn)
    local originalFn = obj[method]
    obj[method] = function(self, ...)
        if not shouldCancelFn(self, ...) then
            return originalFn(self, ...)
        end
    end
end

--

function utils.canPlayerDeployAWallAt(playerInst, position)
    local radius = 0.9
    local entitiesAround = TheSim:FindEntities(
        position.x, 0, position.z,
        radius,
        nil,
        constants.UNSELECTABLE_TAGS
    )
    local entitiesAroundCount = #entitiesAround
    if entitiesAroundCount > 0 then
        -- TODO: could it be that playerInst is not the first one?
        if entitiesAround[1] == playerInst then
            entitiesAroundCount = entitiesAroundCount - 1
        end
    end
    return entitiesAroundCount == 0
end

--

function utils.testEntity(entity)
    return utils.toboolean(
        entity.Transform and entity:IsValid() and not entity:IsInLimbo()
    )
end

--

function utils.getItemFromInventory(inventory, prefabName)

    local itemContainer = nil

    if (
        inventory:GetOverflowContainer() and
        inventory:GetOverflowContainer():Has(prefabName, 1)
    ) then
        itemContainer = inventory:GetOverflowContainer()
    elseif inventory:Has(prefabName, 1) then
        itemContainer = inventory
    end

    if not itemContainer then
        logger.logError("Unable to get item container")
        return nil
    end

    for slot, v in pairs(itemContainer:GetItems() or {}) do
        if slot and v.prefab == prefabName then
            itemContainer:TakeActiveItemFromAllOfSlot(slot)
            return inventory:GetActiveItem()
        end
    end
end

--

local function doAction(
    playerController,
    bufferedAction,
    right,
    position,
    target,
    released
)
    local controlmods = playerController:EncodeControlMods()

    local function rpcClick(preview)
        local canForceOrNil, releasedOrNil
        if preview then
            canForceOrNil = nil
            releasedOrNil = released
        else
            canForceOrNil = bufferedAction.action.canforce
            releasedOrNil = nil
        end

        -- FIXME: update
        local platform = nil
        local platform_relative = nil

        if right then
            playerController.remote_controls[CONTROL_SECONDARY] = 0
            local rotation = bufferedAction.rotation ~= 0 and bufferedAction.rotation or nil
            SendRPCToServer(
                RPC.RightClick,
                bufferedAction.action.code,
                position.x,
                position.z,
                target,
                rotation, -- only for right click
                releasedOrNil,
                controlmods,
                canForceOrNil,
                bufferedAction.action.mod_name,
                platform,
                platform_relative
            )
        else
            playerController.remote_controls[CONTROL_PRIMARY] = 0
            SendRPCToServer(
                RPC.LeftClick,
                bufferedAction.action.code,
                position.x,
                position.z,
                target,
                releasedOrNil,
                controlmods,
                canForceOrNil,
                bufferedAction.action.mod_name,
                platform,
                platform_relative
            )
        end
    end

    if playerController.locomotor == nil then
        rpcClick(false)
    elseif (
        bufferedAction.action ~= ACTIONS.WALKTO and
        playerController:CanLocomote()
    ) then
        bufferedAction.preview_cb = function()
            rpcClick(true)
        end
    end

    playerController:DoAction(bufferedAction)
end

function utils.doDeployAction(
    playerInst,
    playerController,
    actionPositionToCopy,
    activeItem
)
    local actionPosition = Vector3(actionPositionToCopy.x, 0, actionPositionToCopy.z)

    local bufferedAction = BufferedAction(
        playerInst, nil, ACTIONS.DEPLOY, activeItem, actionPosition
    )

    if (
        playerController.deployplacer ~= nil and
        bufferedAction.action == ACTIONS.DEPLOY
    ) then
        bufferedAction.rotation = playerController.deployplacer.Transform:GetRotation()
    end

    doAction(playerController, bufferedAction, true, actionPosition, nil, true)
end

-- TODO: move to a better place

local function createPreventRepeatAction()

    local lastEntity, lastAction

    local function preventRepeatAction(targetEntity, action)
        if (
            lastEntity ~= nil and lastEntity == targetEntity and (
                -- Don't get stuck turning things on and off repeatedly
                lastAction == ACTIONS.TURNOFF and action == ACTIONS.TURNON or
                lastAction == ACTIONS.TURNON  and action == ACTIONS.TURNOFF or
                -- Fix for mushroom farm
                lastAction == ACTIONS.GIVE and action == ACTIONS.HARVEST or
                -- Don't shave same entity twice
                action == ACTIONS.SHAVE or
                -- ???
                lastAction == action and (
                    action == ACTIONS.PICKUP or
                    action == ACTIONS.PICK or
                    -- Without this, character attempts to repair each leak twice
                    action == ACTIONS.REPAIR_LEAK or
                    -- Fix for gate door
                    action == ACTIONS.ACTIVATE or
                    action == ACTIONS.ASSESSPLANTHAPPINESS
                )
            )
        ) then
            return true
        end

        lastEntity = targetEntity
        lastAction = action

        return false
    end

    return preventRepeatAction
end

function utils.createSmartDoNextAction(playerController)

    local preventRepeatAction = createPreventRepeatAction()

    local function smartDoNextAction(target, bufferedAction)

        if bufferedAction == nil or not bufferedAction:TestForStart() then
            return false
        end

        local action = bufferedAction.action
        local right = utils.toboolean(bufferedAction.isRight)

        if preventRepeatAction(target, action) then
            return false
        end

        local position
        local targetEntity
        local released

        if right then
            position = target:GetPosition()
            targetEntity = target or nil
            released = (action ~= ACTIONS.HAMMER)
        else
            if action == ACTIONS.WALKTO then
                position = TheInput:GetWorldPosition()
            else
                position = target:GetPosition()
            end
            targetEntity = action ~= ACTIONS.DROP and target or nil
            released = (
                action ~= ACTIONS.CHOP and
                action ~= ACTIONS.MINE
            )
        end

        doAction(playerController, bufferedAction, right, position, targetEntity, released)

        return true
    end

    return smartDoNextAction
end

--

return utils
