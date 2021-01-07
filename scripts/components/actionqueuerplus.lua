local constants         = require "actionQueuerPlus/constants"
local utils             = require "actionQueuerPlus/utils"
local asyncUtils        = require "actionQueuerPlus/asyncUtils"
local logger            = require "actionQueuerPlus/logger"
local GeoUtil           = require "actionQueuerPlus/GeoUtil"
local prepareGetActions = require "actionQueuerPlus/prepareGetActions"
local mouseAPI          = require "actionQueuerPlus/mouseAPI"
local MouseManager      = require "actionQueuerPlus/MouseManager"
local SelectionManager  = require "actionQueuerPlus/SelectionManager"
local SelectionWidget   = require "actionQueuerPlus/SelectionWidget"

-- forward declaration
local ActionQueuer_initializeMouseManagers
local ActionQueuer_hookMouseManagerEvents
local ActionQueuer_reconfigureManagers
local ActionQueuer_waitAction
local ActionQueuer_autoCollect
local ActionQueuer_applyToDeploy
local ActionQueuer_applyToSelection

local ActionQueuer = Class(function(self, playerInst)

    -- TODO: figure out what's this for
    self.event_listeners = nil

    --

    self._playerInst = playerInst

    --

    self._config = {
        autoCollect = false,
        keyToQueueActions = nil,
    }


    self._selectionWidget = SelectionWidget()
    self._selectionManager = SelectionManager()

    -- former "enabled"
    self._mouseManagersAttached = false
    self._mouseManagers = {}

    -- TODO: change to ever increasing number?
    self._interrupted = true

    self._activeThread = nil

    -- cache

    self._getActions = prepareGetActions(playerInst)
    self._startThread = asyncUtils.getStartThread(self._playerInst)

    --

    asyncUtils.setImmediate(playerInst, function(playerInst)
        if not (playerInst:IsValid() and playerInst.components.actionqueuerplus) then
            return
        end

        if playerInst.HUD and playerInst.HUD.controls then
            self._selectionWidget:Create(playerInst.HUD.controls)
            ActionQueuer_initializeMouseManagers(self)
        end

        self:Enable()
    end)
end)

function ActionQueuer:Configure(config)
    self._config = config
    ActionQueuer_reconfigureManagers(self)
end

--

function ActionQueuer:IsEntitySelected(entity)
    return self._selectionManager:IsEntitySelected(entity)
end

--

function ActionQueuer:CanInterrupt()
    return utils.toboolean(self._activeThread)
end


function ActionQueuer:Interrupt()

    -- FIXME: cancel current action (e.g. running to chop a tree)

    self._interrupted = true

    self._selectionManager:DeselectAllEntities()

    for _, mouseManager in pairs(self._mouseManagers) do
        mouseManager:Clear()
    end

    self._selectionWidget:Hide()

    if self._activeThread then
        asyncUtils.cancelThread(self._activeThread)
        self._activeThread = nil
    end
end

--

function ActionQueuer:Enable()
    if self._mouseManagersAttached then return end

    for mouseButton, mouseManager in pairs(self._mouseManagers) do
        mouseManager:Attach(mouseButton)
    end

    self._mouseManagersAttached = true
end

function ActionQueuer:Disable()
    self:Interrupt()

    if not self._mouseManagersAttached then return end

    for _, mouseManager in pairs(self._mouseManagers) do
        mouseManager:Detach()
    end

    self._mouseManagersAttached = false
end

--

function ActionQueuer:OnRemoveFromEntity()
    self:Disable()
    self._selectionWidget:Kill()
end

function ActionQueuer:OnRemoveEntity()
    self:Disable()
    self._selectionWidget:Kill()
end

-- Mouse managers

ActionQueuer_initializeMouseManagers = function(self)

    mouseAPI.initializeHandlerAdders()

    local isAnyMouseManagerSelecting = function()
        for _, mouseManager in pairs(self._mouseManagers) do
            if mouseManager:IsSelecting() then
                return true
            end
        end
        return false
    end

    local isPlayerValid = function()
        return self._playerInst:IsValid()
    end

    -- TODO: 1 manager is enough
    local mouseButtons = { MOUSEBUTTON_LEFT, MOUSEBUTTON_RIGHT }

    for _, mouseButton in pairs(mouseButtons) do

        local right = (mouseButton == MOUSEBUTTON_RIGHT)

        local canActUponEntity = function(entity)
            local actions = self._getActions(entity, right)
            return utils.toboolean(actions[1])
        end

        local mouseManager = MouseManager(
            isAnyMouseManagerSelecting,
            canActUponEntity,
            isPlayerValid,
            self._startThread
        )
        self._mouseManagers[mouseButton] = mouseManager

        ActionQueuer_hookMouseManagerEvents(self, mouseManager.actionQueuerEvents, right)
    end

    ActionQueuer_reconfigureManagers(self)
end

ActionQueuer_hookMouseManagerEvents = function(self, events, right)

    -- Selection widget

    events:AddEventHandler(
        "SetSelectionRectangle",
        function(xMin, yMin, xMax, yMax) self._selectionWidget:Show(xMin, yMin, xMax, yMax) end
    )
    events:AddEventHandler(
        "ClearSelectionRectangle",
        function() self._selectionWidget:Hide() end
    )

    -- Selection manager

    events:AddEventHandler(
        "SelectEntity",
        function(entity) self._selectionManager:SelectEntity(entity, right) end
    )
    events:AddEventHandler(
        "DeselectEntity",
        function(entity) self._selectionManager:DeselectEntity(entity) end
    )

    events:AddEventHandler(
        "ToggleEntitySelection",
        function(entity) self._selectionManager:ToggleEntitySelection(entity, right) end
    )

    -- Action

    events:AddEventHandler(
        "Apply",
        function(optQuad)
            if (
                -- TODO: check why originally it was checking for not cherry picking
                optQuad and
                -- TODO: shouldn't this be `playerInst`?
                ThePlayer and right and
                utils.canDeployItem(ThePlayer.replica.inventory:GetActiveItem())
            ) then
                ActionQueuer_applyToDeploy(self, optQuad)
            else
                ActionQueuer_applyToSelection(self)
            end
        end
    )
end

ActionQueuer_reconfigureManagers = function(self)
    for _, mouseManager in pairs(self._mouseManagers) do
        mouseManager:SetKeyToQueueActions(self._config.keyToQueueActions)
    end
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

        while true do

            if (
                self._interrupted or
                not playerInst.replica.builder:CanBuild(recipe.name)
            ) then
                self:Interrupt()
                return
            end

            -- if playerController.ismastersim and playerInst.components.builder then
            --     logger.logDebug("RepeatRecipe: is master sim and builder")
            --     playerInst.components.combat:SetTarget(nil)
            --     playerInst.components.builder:MakeRecipeFromMenu(recipe, skin)
            -- else
                -- logger.logDebug("RepeatRecipe: is not master sim or no builder")
                playerController:RemoteMakeRecipeFromMenu(recipe, skin)
            -- end
            ActionQueuer_waitAction(self)
        end

    end)
end

--------------------------------------------------------------------

local function isItemValid(item)
    return utils.toboolean(item and item.replica and item.replica.inventoryitem)
end

ActionQueuer_applyToDeploy = function(self, quad)

    if self._activeThread then return end

    local getNextDeployPosition = GeoUtil.createPositionIterator(quad)

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

    if not utils.canDeployItem(initiallyActiveItem) then return end

    self._activeThread = self._startThread(function()

        local playerInst = self._playerInst
        local playerController = playerInst.components.playercontroller

        playerInst:ClearBufferedAction()

        local deployMode = utils.getItemDeployMode(initiallyActiveItem)
        local function canDeployItemAtPosition(item, position)
            return (
                item.replica.inventoryitem:CanDeploy(position) and (
                    deployMode ~= DEPLOYMODE.WALL or
                    utils.canPlayerDeployAWallAt(playerInst, position)
                )
            )
        end

        self._interrupted = false

        while true do
            local inventory = playerInst.replica.inventory
            local itemToDeploy = (
                inventory:GetActiveItem() or
                utils.getItemFromInventory(playerController.ismastersim, inventory, activeItemName)
            )

            if self._interrupted or not isItemValid(itemToDeploy) then
                self:Interrupt()
                return
            end

            local deployPosition = getNextDeployPosition(
                function(position) return canDeployItemAtPosition(itemToDeploy, position) end
            )

            -- TODO: is there any actual need to check for _interrupted / isItemValid 2nd time?
            if deployPosition == nil or self._interrupted or not isItemValid(itemToDeploy) then
                self:Interrupt()
                return
            end

            utils.doDeployAction(playerInst, playerController, deployPosition, itemToDeploy)

            ActionQueuer_waitAction(self)
        end
    end)
end

ActionQueuer_applyToSelection = function(self)
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

            local actions = self._getActions(
                target,
                self._selectionManager:IsSelectedWithRight(target)
            )
            local targetPosition = target:GetPosition()

            if #actions >= 1 and smartDoNextAction(target, actions[1]) then

                local action = actions[1].action

                if action == ACTIONS.WALKTO then
                    Sleep(0.2)
                    playerInst.components.locomotor:Stop()
                end

                if self._interrupted then break end

                ActionQueuer_waitAction(self, true)

                -- TODO: only apply to newly appeared entities
                if (
                    self._config.autoCollect and
                    targetPosition and
                    constants.AUTO_COLLECT_ACTIONS[action]
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
        if utils.testEntity(entity) then
            local actionPicker = self._playerInst.components.playeractionpicker
            local actions = actionPicker:GetSceneActions(entity, right)
            if (
                actions[1] and (
                    actions[1].action == ACTIONS.PICK or
                    actions[1].action == ACTIONS.PICKUP
                ) and
                not utils.shouldIgnorePickupTarget(entity)
            ) then
                self._selectionManager:SelectEntity(entity, right)
            end
        end
    end
end

--------------------------------------------------------------------

ActionQueuer_waitAction = function(self, optWaitWork)
    local playerInst = self._playerInst
    local playerController = playerInst.components.playercontroller
    if playerController.locomotor ~= nil then
        repeat Sleep(0.06) until (
            self._interrupted or
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

return ActionQueuer
