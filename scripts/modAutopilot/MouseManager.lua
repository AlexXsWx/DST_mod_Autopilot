local constants       = require "modAutopilot/constants"
local logger          = require "modAutopilot/utils/logger"
local utils           = require "modAutopilot/utils/utils"
local asyncUtils      = require "modAutopilot/utils/asyncUtils"
local geoUtils        = require "modAutopilot/utils/geoUtils"
local mouseAPI        = require "modAutopilot/input/mouseAPI"
local SelectionWidget = require "modAutopilot/ui/SelectionWidget"

-- forward declaration --
local MouseManager_CreateNewSession
local MouseManager_UpdateSession
local MouseManager_ClearSession
local MouseManager_OnDown
local MouseManager_OnUp
local MouseManager_GetTarget
local MouseManager_DoubleClick
local MouseManager_DirectClick
local MouseManager_StartSelectionBox
local MouseManager_UpdateSelectionBox
-------------------------

local MouseManager = Class(
    function(
        self,
        selectionManager,
        canActUponEntity,
        isPlayerValid,
        startThread,
        applyFn
    )
        -- save dependencies
        self._selectionManager = selectionManager
        self._canActUponEntity = canActUponEntity
        self._isPlayerValid    = isPlayerValid
        self._startThread      = startThread
        self._applyFn          = applyFn
        --

        self._config = {
            isSelectKeyDown   = function() return false end,
            isDeselectKeyDown = function() return false end,
            doubleClickMaxTimeSeconds = 0,
            doubleClickSearchRadiusTiles = 0,
            doubleClickKeepSearching = false,
        }

        self._selectionWidget = nil
        self._mouseButtonHandler = nil

        self._session = nil
        self._lastButton = nil
        self._lastButtonTime = 0
    end
)

function MouseManager:configure(config)
    self._config = config
end

--

local function MouseManager_isAttached(self)
    return utils.toboolean(self._selectionWidget)
end

function MouseManager:Attach(widgetParent)

    if MouseManager_isAttached(self) then
        self:Detach()
    end

    self._selectionWidget = SelectionWidget(widgetParent)

    self._mouseButtonHandler = mouseAPI.addButtonStateChangeHandler(
        function(mouseButton, down)
            if (
                mouseButton == MOUSEBUTTON_LEFT or
                mouseButton == MOUSEBUTTON_RIGHT
            ) then
                if down then
                    MouseManager_OnDown(self, mouseButton)
                else
                    MouseManager_OnUp(self, mouseButton)
                end
            end
        end
    )
end

function MouseManager:Detach()

    if not MouseManager_isAttached(self) then
        return
    end

    self:Clear()

    if self._mouseButtonHandler then
        self._mouseButtonHandler:Remove()
        self._mouseButtonHandler = nil
    end

    if self._selectionWidget then
        self._selectionWidget:Kill()
        self._selectionWidget = nil
    end
end

--

function MouseManager:Clear()
    if self._selectionWidget then
        self._selectionWidget:Hide()
    end
    MouseManager_ClearSession(self)
end

--

MouseManager_CreateNewSession = function(self, mouseButton, mousePosition, selecting)
    local session = {
        mouseButton = mouseButton,
        mousePositionStart = mousePosition,
        mousePositionCurrent = mousePosition,
        selectionBoxActive = false,
        updateSelectionBoxThread = nil,
        selecting = selecting,
    }
    return session
end

MouseManager_UpdateSession = function(self)
    local selecting   = self._config.isSelectKeyDown()
    local deselecting = self._config.isDeselectKeyDown()
    if (selecting or deselecting) and not (selecting and deselecting) then
        self._session.selecting = selecting or false
    end

    -- TODO: consider using arguments instead of separate API call
    self._session.mousePositionCurrent = mouseAPI.getMousePosition()
end

MouseManager_ClearSession = function(self)
    if not self._session then return end

    self._selectionManager:PreviewEntitiesSelection()

    if self._session.updateSelectionBoxThread then
        asyncUtils.cancelThread(self._session.updateSelectionBoxThread)
        self._session.updateSelectionBoxThread = nil
    end

    self._session = nil
end

--

MouseManager_OnDown = function(self, mouseButton)

    local selecting   = self._config.isSelectKeyDown()
    local deselecting = self._config.isDeselectKeyDown()

    if not self._session then
        if (selecting or deselecting) and not (selecting and deselecting) then
            if self._isPlayerValid() then
                -- TODO: consider using arguments instead of separate API call
                local mousePosition = mouseAPI.getMousePosition()
                self._session = MouseManager_CreateNewSession(
                    self,
                    mouseButton,
                    mousePosition,
                    selecting or false
                )
                local right = (mouseButton == MOUSEBUTTON_RIGHT)
                MouseManager_StartSelectionBox(self, right)
            else
                logger.logError("Mouse manager is unable to handle mouse down, player is not valid")
            end
        end
    else
        if mouseButton == self._session.mouseButton then
            logger.logWarning("Invalid state, attempting to handle same mouse button down twice")
        end
    end
end

MouseManager_OnUp = function(self, mouseButton)

    if not self._session or self._session.mouseButton ~= mouseButton then
        return
    end

    MouseManager_UpdateSession(self)

    local nowSeconds = GetTime()

    local right = (mouseButton == MOUSEBUTTON_RIGHT)

    if self._session.selectionBoxActive then
        MouseManager_UpdateSelectionBox(self, right)
        self._selectionManager:SubmitPreview(right)
    else
        local entity = MouseManager_GetTarget(self, right)
        if entity then
            if (
                -- FIXME: test distance
                self._lastButton == mouseButton and
                nowSeconds - self._lastButtonTime <= self._config.doubleClickMaxTimeSeconds
            ) then
                MouseManager_DoubleClick(self, entity, right)
            else
                MouseManager_DirectClick(self, entity, right)
            end
        end
    end

    self._lastButton = mouseButton
    self._lastButtonTime = nowSeconds

    local cherrypicking = not self._session.selectionBoxActive
    self._applyFn(
        self._session.selectionBoxActive and {
            startPos = self._session.mousePositionStart,
            endPos   = self._session.mousePositionCurrent,
        } or nil,
        right,
        cherrypicking
    )

    self:Clear()
end

--

MouseManager_GetTarget = function(self, right)
    local entities = TheInput:GetAllEntitiesUnderMouse()

    for _, entity in ipairs(entities) do
        if (
            utils.testEntity(entity) and
            self._canActUponEntity(entity, right, true, not self._session.selecting)
        ) then
            return entity
        end
    end

    return nil
end

MouseManager_DoubleClick = function(self, entity, right)

    if self._config.doubleClickSearchRadiusTiles <= 0 then
        return
    end

    local pos = entity:GetPosition()
    local tileSideSize = 4
    local entitiesAround = TheSim:FindEntities(
        pos.x,
        pos.y,
        pos.z,
        self._config.doubleClickSearchRadiusTiles * tileSideSize,
        nil,
        constants.UNSELECTABLE_TAGS
    )
    if self._session.selecting then
        for k, v in ipairs(entitiesAround) do
            if (
                utils.arePrefabsEqual(v.prefab, entity.prefab) and
                utils.testEntity(v) and
                self._canActUponEntity(v, right, true, false)
            ) then
                self._selectionManager:SelectEntity(v, right)
            end
        end
    else
        for k, v in ipairs(entitiesAround) do
            if utils.arePrefabsEqual(v.prefab, entity.prefab) then
                self._selectionManager:DeselectEntity(v)
            end
        end
    end

    if self._config.doubleClickKeepSearching then
        if self._session.selecting then
            self._selectionManager:SelectPrefabName(entity.prefab, right)
        else
            self._selectionManager:DeselectPrefabName(entity.prefab, right)
        end
    end
end

MouseManager_DirectClick = function(self, entity, right)
    if self._session.selecting then
        self._selectionManager:ToggleEntitySelection(entity, right)
    else
        self._selectionManager:DeselectEntity(entity)
    end
end

--

MouseManager_StartSelectionBox = function(self, right)
    self._session.updateSelectionBoxThread = self._startThread(function()
        while self._isPlayerValid() do
            MouseManager_UpdateSession(self)
            if (
                self._session.selectionBoxActive or
                constants.MANHATTAN_DISTANCE_TO_START_BOX_SELECTION < geoUtils.ManhattanDistance(
                    self._session.mousePositionStart,
                    self._session.mousePositionCurrent
                )
            ) then
                self._session.selectionBoxActive = true
                MouseManager_UpdateSelectionBox(self, right)
            end
            -- TODO: separate UI feedback and entities finding logic for more fluid user feedback
            Sleep(constants.GET_MOUSE_POS_PERIOD)
        end
        self:Clear()
    end)
end

--

MouseManager_UpdateSelectionBox = function(self, right)

    local session = self._session

    local minX = math.min(session.mousePositionStart.x, session.mousePositionCurrent.x)
    local maxX = math.max(session.mousePositionStart.x, session.mousePositionCurrent.x)
    local minY = math.min(session.mousePositionStart.y, session.mousePositionCurrent.y)
    local maxY = math.max(session.mousePositionStart.y, session.mousePositionCurrent.y)
    
    if self._selectionWidget then
        self._selectionWidget:Show(minX, minY, maxX, maxY)
    end

    -- TODO: consider keeping 90deg angles
    local A = geoUtils.MapScreenPt(
        session.mousePositionStart.x,
        session.mousePositionStart.y
    )
    local B = geoUtils.MapScreenPt(
        session.mousePositionCurrent.x,
        session.mousePositionStart.y
    )
    local C = geoUtils.MapScreenPt(
        session.mousePositionCurrent.x,
        session.mousePositionCurrent.y
    )
    local D = geoUtils.MapScreenPt(
        session.mousePositionStart.x,
        session.mousePositionCurrent.y
    )

    local isBounded = geoUtils.CreateQuadrilateralTester(A, B, C, D)

    local selectionBoxCenter = geoUtils.MapScreenPt((minX + maxX) / 2, (minY + maxY) / 2)

    local selectionBoxOuterRadius = math.sqrt(
        math.max(
            selectionBoxCenter:DistSq(A),
            selectionBoxCenter:DistSq(B),
            selectionBoxCenter:DistSq(C),
            selectionBoxCenter:DistSq(D)
        )
    )

    local entitiesAround = TheSim:FindEntities(
        selectionBoxCenter.x,
        selectionBoxCenter.y,
        selectionBoxCenter.z,
        selectionBoxOuterRadius,
        nil,
        constants.UNSELECTABLE_TAGS
    )

    local actableEntitiesWithinSelectionBox = {}

    for _, entity in ipairs(entitiesAround) do
        if (
            utils.testEntity(entity) and
            isBounded(entity:GetPosition()) and
            self._canActUponEntity(entity, right, false, not session.selecting)
        ) then
            actableEntitiesWithinSelectionBox[entity] = true
        end
    end

    self._selectionManager:PreviewEntitiesSelection(
        actableEntitiesWithinSelectionBox,
        session.selecting
    )
end

--

return MouseManager
