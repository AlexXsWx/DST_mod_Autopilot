local constants       = require "actionQueuerPlus/constants"
local utils           = require "actionQueuerPlus/utils"
local asyncUtils      = require "actionQueuerPlus/asyncUtils"
local GeoUtil         = require "actionQueuerPlus/GeoUtil"
local mouseAPI        = require "actionQueuerPlus/mouseAPI"
local SelectionWidget = require "actionQueuerPlus/SelectionWidget"

-- forward declaration
local MouseManager_OnDown
local MouseManager_OnUp

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

        self._attached = false

        self._currentButton = nil

        self._isQueiengActive = nil

        self._mouseHandlers = nil

        self._handleMouseMoveThread = nil

        self._posQuad = nil
        self._selectionBoxActive = false
        self._previousEntities = {}
        self._mousePositionStart = nil
        self._mousePositionCurrent = nil

        self._selectionWidget = nil
    end
)

function MouseManager:setIsQueiengActive(isQueiengActive)
    self._isQueiengActive = isQueiengActive
end

function MouseManager:Clear(optSoft)

    if not optSoft then
        self._currentButton = nil
    end

    self._posQuad = nil
    self._selectionBoxActive = false

    self._previousEntities = {}

    if self._handleMouseMoveThread then
        asyncUtils.cancelThread(self._handleMouseMoveThread)
        self._handleMouseMoveThread = nil
    end
    if self._mouseHandlers and self._mouseHandlers.move then
        self._mouseHandlers.move:Remove()
        self._mouseHandlers.move = nil
    end

    if self._selectionWidget then
        self._selectionWidget:Hide()
    end
end

function MouseManager:Attach(widgetParent)

    if self._attached then
        return
    end
    self._attached = true

    self._selectionWidget = SelectionWidget(widgetParent)

    self._mouseHandlers = {
        buttonStateChange = mouseAPI.addButtonStateChangeHandler(
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
        ),
        move = nil
    }
end

function MouseManager:Detach()

    if not self._attached then
        return
    end
    self._attached = false

    self:Clear()

    for _, handler in pairs(self._mouseHandlers) do
        handler:Remove()
    end
    self._mouseHandlers = nil

    if self._selectionWidget then
        self._selectionWidget:Kill()
        self._selectionWidget = nil
    end
end

--

local function MouseManager_OnDown_CherryPick(self, right)
    local entities = TheInput:GetAllEntitiesUnderMouse()

    for _, entity in ipairs(entities) do
        if utils.testEntity(entity) and self._canActUponEntity(entity, right) then
            self._selectionManager:ToggleEntitySelection(entity, right)
            return
        end
    end
end

--

local function MouseManager_DispachSelectedEntitiesChanges(self, selectedActableEntities, right)
    for entity in pairs(self._previousEntities) do
        if not selectedActableEntities[entity] then
            self._selectionManager:DeselectEntity(entity)
        end
    end

    for entity in pairs(selectedActableEntities) do
        if not self._previousEntities[entity] then
            self._selectionManager:SelectEntity(entity, right)
        end
    end

    self._previousEntities = selectedActableEntities
end

local function MouseManager_HandleNewSelectionBox(self, right)

    local minX = math.min(self._mousePositionStart.x, self._mousePositionCurrent.x)
    local maxX = math.max(self._mousePositionStart.x, self._mousePositionCurrent.x)
    local minY = math.min(self._mousePositionStart.y, self._mousePositionCurrent.y)
    local maxY = math.max(self._mousePositionStart.y, self._mousePositionCurrent.y)
    
    if self._selectionWidget then
        self._selectionWidget:Show(minX, minY, maxX, maxY)
    end

    -- TODO: consider keeping 90deg angles
    self._posQuad = {
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
        self._posQuad.minXminYProjected,
        self._posQuad.maxXminYProjected,
        self._posQuad.maxXmaxYProjected, -- warning: order is different here
        self._posQuad.minXmaxYProjected
    )

    local selectionBoxCenter = GeoUtil.MapScreenPt((minX + maxX) / 2, (minY + maxY) / 2)

    local selectionBoxOuterRadius = math.sqrt(
        math.max(
            selectionBoxCenter:DistSq(self._posQuad.minXminYProjected),
            selectionBoxCenter:DistSq(self._posQuad.maxXminYProjected),
            selectionBoxCenter:DistSq(self._posQuad.minXmaxYProjected),
            selectionBoxCenter:DistSq(self._posQuad.maxXmaxYProjected)
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

    MouseManager_DispachSelectedEntitiesChanges(self, actableEntitiesWithinBox, right)
end

--

local function MouseManager_OnDown_SelectionBox(self, right)

    self._selectionBoxActive = false

    self._mousePositionStart = mouseAPI.getMousePosition()

    local handleMouseMove = function()
        if not self._selectionBoxActive then
            self._selectionBoxActive = (
                GeoUtil.ManhattanDistance(self._mousePositionStart, self._mousePositionCurrent) >
                constants.MANHATTAN_DISTANCE_TO_START_BOX_SELECTION
            )
        end
        if self._selectionBoxActive then
            MouseManager_HandleNewSelectionBox(self, right)
        end
    end

    local mouseMoved = false
    assert(self._mouseHandlers).move = mouseAPI.addMouseMoveHandler(function()
        mouseMoved = true
    end)

    self._handleMouseMoveThread = self._startThread(function()
        while self._isPlayerValid() do
            if mouseMoved then
                mouseMoved = false
                self._mousePositionCurrent = mouseAPI.getMousePosition()
                handleMouseMove()
            end
            Sleep(constants.GET_MOUSE_POS_PERIOD)
        end
        self:Clear()
    end)
end

--

MouseManager_OnDown = function(self, mouseButton)

    if self._currentButton ~= nil then
        return
    end
    self._currentButton = mouseButton

    self:Clear(true)

    if (
        self._isPlayerValid() and
        self._handleMouseMoveThread == nil and
        self._isQueiengActive and
        self._isQueiengActive()
    ) then
        local right = (mouseButton == MOUSEBUTTON_RIGHT)
        MouseManager_OnDown_CherryPick(self, right)
        MouseManager_OnDown_SelectionBox(self, right)
    end
end

MouseManager_OnUp = function(self, mouseButton)

    if self.self._currentButton ~= nil and self._currentButton ~= mouseButton then
        return
    end

    local right = (mouseButton == MOUSEBUTTON_RIGHT)

    if self._selectionBoxActive then
        self._mousePositionCurrent = mouseAPI.getMousePosition()
        MouseManager_HandleNewSelectionBox(self, right)
    end
    -- _posQuad can be nil, that's fine
    self._applyFn(self._posQuad, right)
    self:Clear()
end

--

return MouseManager
