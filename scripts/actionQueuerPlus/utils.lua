local constants = require "actionQueuerPlus/constants"
local logger    = require "actionQueuerPlus/logger"

local utils = {}

--

function utils.toboolean(arg)
    return arg and true or false
end

--

function utils.overrideToCancelIf(obj, property, shouldCancel)
    local originalFn = obj[property]
    obj[property] = function(self, ...)
        if not shouldCancel(self, ...) then
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

-- TODO: move to some more appropriate place, maybe prepareGetActions / actionsHelper?

function utils.shouldIgnorePickupTarget(entity)
    -- logger.logDebug(
    --     "shouldIgnorePickupTarget: ismastersim = " ..
    --     (ThePlayer and ThePlayer.components.playercontroller.ismastersim and "true" or "false")
    -- ) -- always false
    return utils.toboolean(
        entity.components.mine and not entity.components.mine.inactive or
        entity.components.trap and not entity.components.trap.isset or
        (
            -- ThePlayer and
            -- not ThePlayer.components.playercontroller.ismastersim and
            entity:HasTag("trap")
        )
    )
end

function utils.getItemDeployMode(item)
    if not item or not item.replica then return nil end
    local inventoryItem = item.replica.inventoryitem
    if inventoryItem then
        if inventoryItem.inst.components.deployable then
            return inventoryItem.inst.components.deployable.mode
        end
        if inventoryItem.classified and inventoryItem.classified.deploymode then
            return inventoryItem.classified.deploymode:value()
        end
    end
    return nil
end

function utils.canDeployItem(item)
    if not item then return false end
    return utils.toboolean(
        constants.ALLOWED_DEPLOY_PREFABS[item.prefab] or
        constants.ALLOWED_DEPLOY_MODES[utils.getItemDeployMode(item)]
    )
end

--

function utils.getItemFromInventory(masterSim, inventory, prefabName)

    local itemContainer = nil

    if (
        inventory:GetOverflowContainer() and
        inventory:GetOverflowContainer():Has(prefabName, 1)
    ) then
        itemContainer = inventory:GetOverflowContainer()
    elseif inventory:Has(prefabName, 1) then
        itemContainer = inventory
    end

    if not itemContainer then return nil end

    local itemslots = nil

    if itemContainer.GetItems then 
        logger.logDebug("getItemFromInventory: GetItems")
        itemslots = itemContainer:GetItems() 
    elseif masterSim then
        logger.logDebug("getItemFromInventory: ismastersim")
        itemslots = itemContainer.itemslots or itemContainer.slots
    else
        logger.logWarning("getItemFromInventory failed to retrieve itemslots")
    end

    for slot, v in pairs(itemslots or {}) do
        if slot and v.prefab == prefabName then
            itemContainer:TakeActiveItemFromAllOfSlot(slot)
            return inventory:GetActiveItem()
        end
    end
end

--

-- TODO: double check if refactoring broke anything
local function doAction(
    playerController,
    bufferedAction,
    right,
    position,
    target,
    released
)
    -- if playerController.ismastersim then
    --     logger.logDebug("doAction: ismastersim")
    --     playerInst.components.combat:SetTarget(nil)
    --     playerController:DoAction(bufferedAction)
    --     return
    -- end

    -- logger.logDebug("doAction: not master sim") -- always false

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
                rotation, -- only for right click?
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

local function createPreventRepeatAction(masterSim)

    logger.logDebug(
        "createPreventRepeatAction: ismastersim = " .. (masterSim and "true" or "false")
    ) -- always false

    local lastEntity, lastAction --, lastPickEntity

    local function preventRepeatAction(targetEntity, action)
        if lastEntity ~= nil and lastEntity == targetEntity then

            -- Don't get stuck turning things on and off repeatedly
            -- TODO: gate open/close; also move to constants
            if (
                lastAction == ACTIONS.TURNOFF and action == ACTIONS.TURNON or
                lastAction == ACTIONS.TURNON  and action == ACTIONS.TURNOFF
            ) then
                return true
            end

            -- Don't shave same entity twice            
            if action == ACTIONS.SHAVE then
                return true
            end

            if (
                lastAction == action and (
                    action == ACTIONS.PICKUP or
                    action == ACTIONS.PICK
                )
            ) then
                -- TODO: figure out what's this for
                -- if not masterSim then 
                    return true
                -- end

                -- if lastPickEntity ~= nil and lastPickEntity == targetEntity then
                --     return true
                -- else
                --     -- TODO: shouldn't this be set regardless if action/target is repeated or not?
                --     lastPickEntity = targetEntity
                -- end
            end
        end

        lastEntity = targetEntity
        lastAction = action

        return false
    end

    return preventRepeatAction
end

function utils.createSmartDoNextAction(playerInst)

    local playerController = playerInst.components.playercontroller

    local preventRepeatAction = createPreventRepeatAction(playerController.ismastersim)

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
