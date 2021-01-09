local constants       = require "actionQueuerPlus/constants"
local utils           = require "actionQueuerPlus/utils"
local asyncUtils      = require "actionQueuerPlus/asyncUtils"
local GeoUtil         = require "actionQueuerPlus/GeoUtil"
local mouseAPI        = require "actionQueuerPlus/mouseAPI"
local SelectionWidget = require "actionQueuerPlus/SelectionWidget"

-- forward declaration --
local MouseManager_CreateNewSession
local MouseManager_ClearSession
local MouseManager_OnDown
local MouseManager_OnUp
local MouseManager_CherryPick
local MouseManager_StartSelectionBox
local MouseManager_OnSelectionBoxUpdate
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
        -- this one is set later
        self._isQueuingKeyDown = nil
        --

        self._selectionWidget = nil
        self._mouseButtonHandler = nil

        self._session = nil
    end
)

function MouseManager:setQueuingKeyDownGetter(isQueuingKeyDown)
    self._isQueuingKeyDown = isQueuingKeyDown
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

MouseManager_CreateNewSession = function(self, mouseButton, mousePosition)
    local session = {
        mouseButton = mouseButton,
        mousePositionStart = mousePosition,
        mousePositionCurrent = mousePosition,
        posQuad = nil,
        selectionBoxActive = false,
        handleMouseMoveThread = nil,
        mouseMoveHandler = nil,
        entities = {},
    }
    return session
end

MouseManager_ClearSession = function(self)
    if not self._session then return end

    self._selectionManager:PreviewEntitiesSelection({})

    if self._session.handleMouseMoveThread then
        asyncUtils.cancelThread(self._session.handleMouseMoveThread)
        self._session.handleMouseMoveThread = nil
    end

    if self._session.mouseMoveHandler then
        self._session.mouseMoveHandler:Remove()
        self._session.mouseMoveHandler = nil
    end

    self._session = nil
end

--

MouseManager_OnDown = function(self, mouseButton)

    local queuingKeyDown = self._isQueuingKeyDown and self._isQueuingKeyDown()

    if not self._session then
        if queuingKeyDown then
            if self._isPlayerValid() then
                -- TODO: consider using arguments instead of separate API call
                local mousePosition = mouseAPI.getMousePosition()
                self._session = MouseManager_CreateNewSession(self, mouseButton, mousePosition)
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

    -- TODO: consider using arguments instead of separate API call
    self._session.mousePositionCurrent = mouseAPI.getMousePosition()

    local right = (mouseButton == MOUSEBUTTON_RIGHT)

    if self._session.selectionBoxActive then
        MouseManager_OnSelectionBoxUpdate(self, right)
        self._selectionManager:SelectEntities(self._session.entities, right)
    else
        MouseManager_CherryPick(self, right)
    end

    -- posQuad can be nil, that's fine
    self._applyFn(self._session.posQuad, right)

    self:Clear()
end

--

MouseManager_CherryPick = function(self, right)
    local entities = TheInput:GetAllEntitiesUnderMouse()

    for _, entity in ipairs(entities) do
        if utils.testEntity(entity) and self._canActUponEntity(entity, right) then
            self._selectionManager:ToggleEntitySelection(entity, right)
            return
        end
    end
end

--

MouseManager_StartSelectionBox = function(self, right)
    local handleMouseMove = function()
        if not self._session.selectionBoxActive then
            self._session.selectionBoxActive = (
                constants.MANHATTAN_DISTANCE_TO_START_BOX_SELECTION < GeoUtil.ManhattanDistance(
                    self._session.mousePositionStart,
                    self._session.mousePositionCurrent
                )
            )
        end
        if self._session.selectionBoxActive then
            MouseManager_OnSelectionBoxUpdate(self, right)
        end
    end

    local mouseMoved = false
    self._session.mouseMoveHandler = mouseAPI.addMouseMoveHandler(function()
        mouseMoved = true
    end)

    self._session.handleMouseMoveThread = self._startThread(function()
        while self._isPlayerValid() do
            if mouseMoved then
                mouseMoved = false
                self._session.mousePositionCurrent = mouseAPI.getMousePosition()
                handleMouseMove()
            end
            Sleep(constants.GET_MOUSE_POS_PERIOD)
        end
        self:Clear()
    end)
end

--

MouseManager_OnSelectionBoxUpdate = function(self, right)

    local session = self._session
    local minX = math.min(session.mousePositionStart.x, session.mousePositionCurrent.x)
    local maxX = math.max(session.mousePositionStart.x, session.mousePositionCurrent.x)
    local minY = math.min(session.mousePositionStart.y, session.mousePositionCurrent.y)
    local maxY = math.max(session.mousePositionStart.y, session.mousePositionCurrent.y)
    
    if self._selectionWidget then
        self._selectionWidget:Show(minX, minY, maxX, maxY)
    end

    -- TODO: consider keeping 90deg angles
    session.posQuad = {
        --     North
        -- -Z  _   _ -X
        --    |\   /|
        --      \ /
        --       X     East
        --      / \
        --    |/   \|
        -- +X        +Z
        -- each tile has a side of 4 units
        -- geometric placement makes 8x8 points per tile
        minXminYProjected = GeoUtil.MapScreenPt(minX, minY),
        maxXminYProjected = GeoUtil.MapScreenPt(maxX, minY),
        minXmaxYProjected = GeoUtil.MapScreenPt(minX, maxY), 
        maxXmaxYProjected = GeoUtil.MapScreenPt(maxX, maxY)
    }

    local isBounded = GeoUtil.CreateQuadrilateralTester(
        session.posQuad.minXminYProjected,
        session.posQuad.maxXminYProjected,
        session.posQuad.maxXmaxYProjected, -- warning: order is different here
        session.posQuad.minXmaxYProjected
    )

    local selectionBoxCenter = GeoUtil.MapScreenPt((minX + maxX) / 2, (minY + maxY) / 2)

    local selectionBoxOuterRadius = math.sqrt(
        math.max(
            selectionBoxCenter:DistSq(session.posQuad.minXminYProjected),
            selectionBoxCenter:DistSq(session.posQuad.maxXminYProjected),
            selectionBoxCenter:DistSq(session.posQuad.minXmaxYProjected),
            selectionBoxCenter:DistSq(session.posQuad.maxXmaxYProjected)
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

    local actableEntitiesWithinBox = {}

    for _, entity in ipairs(entitiesAround) do
        if (
            utils.testEntity(entity) and
            isBounded(entity:GetPosition()) and
            self._canActUponEntity(entity, right) 
        ) then
            actableEntitiesWithinBox[entity] = true
        end
    end

    self._session.entities = actableEntitiesWithinBox
    self._selectionManager:PreviewEntitiesSelection(self._session.entities)
end

--

return MouseManager
