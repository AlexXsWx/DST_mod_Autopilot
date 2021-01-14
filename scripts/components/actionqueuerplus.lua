local constants        = require "actionQueuerPlus/constants"
local utils            = require "actionQueuerPlus/utils/utils"
local asyncUtils       = require "actionQueuerPlus/utils/asyncUtils"
local logger           = require "actionQueuerPlus/utils/logger"
local geoUtils         = require "actionQueuerPlus/utils/geoUtils"
local allowedActions   = require "actionQueuerPlus/allowedActions"
local mouseAPI         = require "actionQueuerPlus/input/mouseAPI"
local MouseManager     = require "actionQueuerPlus/MouseManager"
local SelectionManager = require "actionQueuerPlus/SelectionManager"

-- forward declaration --
local ActionQueuer_initializeMouseManagers
local ActionQueuer_reconfigureMouseManager
local ActionQueuer_waitAction
local ActionQueuer_autoCollect
local ActionQueuer_applyToDeploy
local ActionQueuer_tryToMakeDeployPossible
local ActionQueuer_applyToSelection
local getAction
local canAutoCollectEntity
-------------------------

local ActionQueuer = Class(function(self, playerInst)

    self._playerInst = playerInst

    self._config = {
        autoCollect = false,
        isSelectKeyDown   = nil,
        isDeselectKeyDown = nil,
        settingsForFilters = {},
        tryMakeDeployPossible = true,
    }

    --

    self._selectionManager = SelectionManager()

    self._mouseManager = nil

    -- TODO: change to ever increasing number?
    self._interrupted = true

    self._activeThread = nil

    self._startThread = asyncUtils.getStartThread(playerInst)

    --

    asyncUtils.setImmediate(playerInst, function(playerInst)
        if not (playerInst:IsValid() and playerInst.components.actionqueuerplus) then
            logger.logError("Unable to enable action queuer component")
            return
        end

        if playerInst.HUD and playerInst.HUD.controls then
            ActionQueuer_initializeMouseManagers(self)
        else
            logger.logError("Unable to initialize mouse managers")
        end

        self:Enable()
    end)
end)

function ActionQueuer:Configure(config)
    self._config = config
    if self._mouseManager then
        ActionQueuer_reconfigureMouseManager(self)
    end
end

--

function ActionQueuer:shouldKeepHighlight(entity)
    return self._selectionManager:shouldKeepHighlight(entity)
end

--

function ActionQueuer:CanInterrupt()
    return utils.toboolean(self._activeThread)
end


function ActionQueuer:Interrupt()

    -- FIXME: cancel current action (e.g. running to chop a tree)

    self._interrupted = true

    if self._mouseManager then
        self._mouseManager:Clear()
    end
    self._selectionManager:DeselectAllEntities()

    if self._activeThread then
        asyncUtils.cancelThread(self._activeThread)
        self._activeThread = nil
    end
end

--

function ActionQueuer:Enable()
    self._mouseManager:Attach(self._playerInst.HUD.controls)
end

function ActionQueuer:Disable()
    self:Interrupt()
    self._mouseManager:Detach()
end

--

function ActionQueuer:OnRemoveFromEntity()
    self:Disable()
end

function ActionQueuer:OnRemoveEntity()
    self:Disable()
end

-- Mouse managers

ActionQueuer_initializeMouseManagers = function(self)

    mouseAPI.initializeHandlerAddrs()

    local isPlayerValid = function()
        return self._playerInst:IsValid()
    end

    local canActUponEntity = function(entity, right, cherrypicking, deselecting)
        return utils.toboolean(
            getAction(
                {
                    playerInst = self._playerInst,
                    target = entity,
                    right = right,
                    cherrypicking = cherrypicking,
                    deselecting = deselecting,
                },
                self._config.settingsForFilters
            )
        )
    end

    local apply = function(optSelectionBox, right, cherrypicking)
        if (
            -- TODO: check why originally it was checking for not cherry picking
            optSelectionBox and
            right and
            allowedActions.canDeployItem(self._playerInst.replica.inventory:GetActiveItem())
        ) then
            ActionQueuer_applyToDeploy(self, optSelectionBox)
        else
            ActionQueuer_applyToSelection(self, cherrypicking)
        end
    end

    self._mouseManager = MouseManager(
        self._selectionManager,
        canActUponEntity,
        isPlayerValid,
        self._startThread,
        apply
    )
    ActionQueuer_reconfigureMouseManager(self)
end

ActionQueuer_reconfigureMouseManager = function(self)
    self._mouseManager:setKeyDownGetters(
        self._config.isSelectKeyDown,
        self._config.isDeselectKeyDown
    )
end

--

function ActionQueuer:RepeatRecipe(recipe, skin)

    if self._activeThread then
        logger.logError("Unable to repeat recipe: something is already in process")
        return
    end

    if not self._playerInst.replica.builder then
        logger.logError("Unable to repeat recipe: missing builder")
        return
    end

    self._activeThread = self._startThread(function()

        local playerInst = self._playerInst
        local playerController = playerInst.components.playercontroller

        playerInst:ClearBufferedAction()

        self._interrupted = false

        while not self._interrupted and playerInst.replica.builder:CanBuild(recipe.name) do
            playerController:RemoteMakeRecipeFromMenu(recipe, skin)
            ActionQueuer_waitAction(self)
        end
        self:Interrupt()
    end)
end

--------------------------------------------------------------------

local function isItemValid(item)
    return utils.toboolean(item and item.replica and item.replica.inventoryitem)
end

ActionQueuer_applyToDeploy = function(self, selectionBox)

    if self._activeThread then return end

    local getNextDeployPosition = geoUtils.createPositionIterator(selectionBox)

    if (
        getNextDeployPosition == nil or
        not self._playerInst:IsValid() or
        not self._playerInst.components.playercontroller or
        not self._playerInst.replica.inventory
    ) then
        return
    end

    local initiallyActiveItem = self._playerInst.replica.inventory:GetActiveItem()
    local activeItemName = initiallyActiveItem.prefab

    if not allowedActions.canDeployItem(initiallyActiveItem) then return end

    self._activeThread = self._startThread(function()

        local playerInst = self._playerInst

        playerInst:ClearBufferedAction()

        local deployMode = allowedActions.getItemDeployMode(initiallyActiveItem)
        local function canDeployItemAtPosition(item, position)
            return item.replica.inventoryitem:CanDeploy(position, nil, playerInst) and (
                deployMode ~= DEPLOYMODE.WALL or
                utils.canPlayerDeployAWallAt(playerInst, position)
            )
        end

        self._interrupted = false

        while true do
            local inventory = playerInst.replica.inventory
            local itemToDeploy = (
                inventory:GetActiveItem() or
                utils.getItemFromInventory(inventory, activeItemName)
            )

            if self._interrupted or not isItemValid(itemToDeploy) then
                self:Interrupt()
                return
            end

            local deployPosition

            while true do
                local position, acceptPosition = getNextDeployPosition()
                if position == nil then
                    self:Interrupt()
                    return
                end
                if self._config.tryMakeDeployPossible then
                    while not canDeployItemAtPosition(itemToDeploy, position) do
                        local tried = ActionQueuer_tryToMakeDeployPossible(self, position)
                        if self._interrupted then
                            self:Interrupt()
                            return
                        end
                        if not tried then
                            break
                        end
                    end
                end
                if canDeployItemAtPosition(itemToDeploy, position) then
                    deployPosition = position
                    acceptPosition()
                    break
                end
            end

            -- TODO: is there any actual need to check for _interrupted / isItemValid 2nd time?
            if self._interrupted or not isItemValid(itemToDeploy) then
                self:Interrupt()
                return
            end

            utils.doDeployAction(playerInst, deployPosition, itemToDeploy)

            ActionQueuer_waitAction(self)
        end
    end)
end

ActionQueuer_tryToMakeDeployPossible = function(self, position)
    local playerInst = self._playerInst
    local playerController = playerInst.components.playercontroller
    -- try to make deploy possible
    local radius = 4
    local entitiesAround = TheSim:FindEntities(
        position.x, 0, position.z,
        radius,
        nil,
        constants.UNSELECTABLE_TAGS
    )
    local tried = false
    local seedEntity = nil
    for _, entity in pairs(entitiesAround) do
        if entity.prefab == "seeds" then
            tried = true
            utils.doAction(
                playerController,
                BufferedAction(playerInst, entity, ACTIONS.PICKUP),
                RPC.ActionButton,
                nil,
                entity,
                true
            )
            ActionQueuer_waitAction(self)
            break
        elseif (
            entity.prefab == "crow" or
            entity.prefab == "robin" or
            entity.prefab == "robin_winter" or
            entity.prefab == "canary"
        ) then
            tried = true
            utils.doAction(
                playerController,
                BufferedAction(playerInst, entity, ACTIONS.WALKTO),
                RPC.ActionButton,
                nil,
                entity,
                true
            )
            ActionQueuer_waitAction(self)
            break
        end
    end
    return tried
end

ActionQueuer_applyToSelection = function(self, cherrypicking)
    if (
        self._selectionManager:IsSelectionEmpty() or
        self._activeThread or
        not self._playerInst:IsValid() or
        not self._playerInst.components.playercontroller
    ) then
        return
    end

    self._activeThread = self._startThread(function()

        local playerInst = self._playerInst

        playerInst:ClearBufferedAction()

        self._interrupted = false

        local smartDoNextAction = utils.createSmartDoNextAction(
            playerInst.components.playercontroller
        )

        while (
            not self._interrupted and
            playerInst:IsValid() and
            not self._selectionManager:IsSelectionEmpty()
        ) do

            local target
            local minDistSq = nil

            for entity in self._selectionManager:GetSelectedEntitiesIterator() do
                if entity:IsValid() and not entity:IsInLimbo() then
                    local distSq = playerInst:GetDistanceSqToInst(entity)
                    if minDistSq == nil or distSq < minDistSq then
                        minDistSq = distSq
                        target = entity
                    end
                else
                    -- TODO: don't modify array while iterating over it
                    self._selectionManager:DeselectEntity(entity)
                end
            end

            if not target then break end

            local action = getAction(
                {
                    playerInst = playerInst,
                    target = target,
                    right = self._selectionManager:IsSelectedWithRight(target),
                    cherrypicking = cherrypicking,
                    deselecting = false,
                },
                self._config.settingsForFilters
            )
            local targetPosition = target:GetPosition()

            if action and smartDoNextAction(target, action) then

                if action.action == ACTIONS.WALKTO then
                    Sleep(0.2)
                    playerInst.components.locomotor:Stop()
                end

                if self._interrupted then break end

                ActionQueuer_waitAction(self, true, function()
                    -- Don't wait for animation end when chopping and digging finished
                    return (
                        action.action == ACTIONS.CHOP or
                        action.action == ACTIONS.DIG
                    ) and (
                        not utils.testEntity(target) or
                        not target:HasTag(action.action.id.."_workable")
                    )
                end)

                -- TODO: only apply to newly appeared entities
                if (
                    self._config.autoCollect and
                    targetPosition and
                    allowedActions.canAutoCollectAfter(action.action)
                ) then
                    ActionQueuer_autoCollect(self, targetPosition)
                end

            else
                self._selectionManager:DeselectEntity(target)
            end
        end

        self._activeThread = nil
    end)
end

ActionQueuer_autoCollect = function(self, position)
    local entitiesAround = TheSim:FindEntities(
        position.x,
        position.y,
        position.z,
        constants.AUTO_COLLECT_RADIUS,
        nil,
        constants.UNSELECTABLE_TAGS
    )
    local right = false
    for _, entity in ipairs(entitiesAround) do
        if canAutoCollectEntity(self._playerInst, entity, right) then
            self._selectionManager:SelectEntity(entity, right)
        end
    end
end

--------------------------------------------------------------------

ActionQueuer_waitAction = function(self, optWaitWork, optCancelEarly)
    local playerInst = self._playerInst
    local playerController = playerInst.components.playercontroller
    if playerController.locomotor ~= nil then
        repeat Sleep(0.06) until (
            self._interrupted or
            optCancelEarly and optCancelEarly() or 
            (
                playerInst:HasTag("idle") and
                playerInst.sg and
                playerInst.sg:HasStateTag("idle") and
                not playerInst:HasTag("moving") and
                not playerInst.sg:HasStateTag("moving") and
                not playerController:IsDoingOrWorking()
            )
        )
    else
        if optWaitWork then
            repeat Sleep(FRAMES) until (
                not playerInst:HasTag("idle") or
                playerInst:HasTag("moving") or
                playerController:IsDoingOrWorking()
            )
        end
        repeat Sleep(0.06) until (
            self._interrupted or 
            not playerInst:HasTag("moving") and not playerController:IsDoingOrWorking()
        )
    end
end

--

getAction = function(context, config)
    local pos = context.target:GetPosition()
    local actionPicker = context.playerInst.components.playeractionpicker

    -- Fix for alt+tab leaving alt pressed for the game which messes up GetLeftClickActions
    local removeControlCheckOverride = utils.override(
        context.playerInst.components.playercontroller,
        "IsControlPressed",
        function() return false end
    )

    local potentialActions
    if context.right then
        potentialActions = actionPicker:GetRightClickActions(pos, context.target)
    else
        potentialActions = actionPicker:GetLeftClickActions(pos, context.target)
    end

    removeControlCheckOverride()

    for _, act in ipairs(potentialActions) do
        if allowedActions.isActionAllowed(act, context, config) then
            -- FIXME: Mutation
            act.isRight = context.right
            return act
        end
    end

    return nil
end

canAutoCollectEntity = function(playerInst, entity, right)
    if utils.testEntity(entity) then
        local actionPicker = playerInst.components.playeractionpicker
        local actions = actionPicker:GetSceneActions(entity, right)
        if (
            actions[1] and (
                actions[1].action == ACTIONS.PICK or
                actions[1].action == ACTIONS.PICKUP
            ) and
            not allowedActions.shouldIgnorePickupTarget(entity)
        ) then
            return true
        end
    end
    return false
end

--

return ActionQueuer
