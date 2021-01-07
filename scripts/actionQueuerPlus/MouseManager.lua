require "events"

local constants         = require "actionQueuerPlus/constants"
local utils             = require "actionQueuerPlus/utils"
local asyncUtils        = require "actionQueuerPlus/asyncUtils"
local GeoUtil           = require "actionQueuerPlus/GeoUtil"
local mouseAPI          = require "actionQueuerPlus/mouseAPI"

-- forward declaration
local MouseManager_OnDown
local MouseManager_OnUp

local MouseManager = Class(
    function(
        self,
        isAnyMouseManagerSelecting,
        canActUponEntity,
        isPlayerValid,
        startThread
    )
        -- save dependencies

        self._isAnyMouseManagerSelecting = isAnyMouseManagerSelecting
        self._canActUponEntity           = canActUponEntity
        self._isPlayerValid              = isPlayerValid
        self._startThread                = startThread

        -- private

        self._keyToUse = nil

        self._mouseHandlers = nil

        self._handleMouseMoveThread = nil
        self._handleMouseMove = nil

        self._posQuad = nil
        self._selectionBoxActive = false
        self._previousEntities = {}
        self._mousePositionStart = nil
        self._mousePositionCurrent = nil

        -- public

        self.actionQueuerEvents = EventProcessor()
    end
)

function MouseManager:SetKeyToUse(keyToUse)
    self._keyToUse = keyToUse
end

function MouseManager:IsSelecting()
    return self._handleMouseMoveThread ~= nil
end

function MouseManager:Clear()

    self._posQuad = nil
    self._selectionBoxActive = false

    self._previousEntities = {}

    if self._handleMouseMoveThread then
        asyncUtils.cancelThread(self._handleMouseMoveThread)
        self._handleMouseMoveThread = nil
        self.actionQueuerEvents:HandleEvent("ClearSelectionRectangle")
    end
    if self._mouseHandlers and self._mouseHandlers.move then
        self._mouseHandlers.move:Remove()
        self._mouseHandlers.move = nil
    end
    self._handleMouseMove = nil
end

function MouseManager:Attach(mouseButton)

    if self._mouseHandlers then
        return
    end

    self._mouseHandlers = {
        down = mouseAPI.addMouseButtonHandler(
            mouseButton,
            true,
            function() return MouseManager_OnDown(self) end
        ),
        up = mouseAPI.addMouseButtonHandler(
            mouseButton,
            false,
            function() return MouseManager_OnUp(self) end
        ),
        move = nil
    }
end

function MouseManager:Detach()
    self:Clear()

    if self._mouseHandlers then
        for _, handler in pairs(self._mouseHandlers) do
            handler:Remove()
        end
        self._mouseHandlers = nil
    end
end

--

local function MouseManager_OnDown_CherryPick(self)
    local entities = TheInput:GetAllEntitiesUnderMouse()

    for _, entity in ipairs(entities) do
        if utils.testEntity(entity) and self._canActUponEntity(entity) then
            self.actionQueuerEvents:HandleEvent("ToggleEntitySelection", entity)
            return
        end
    end
end

--

local function MouseManager_DispachSelectedEntitiesChanges(self, selectedActableEntities)

    for entity in pairs(self._previousEntities) do
        if not selectedActableEntities[entity] then
            self.actionQueuerEvents:HandleEvent("DeselectEntity", entity)
        end
    end

    for entity in pairs(selectedActableEntities) do
        if not self._previousEntities[entity] then
            self.actionQueuerEvents:HandleEvent("SelectEntity", entity)
        end
    end

    self._previousEntities = selectedActableEntities
end

local function MouseManager_HandleNewSelectionBox(self)

    local xMin = math.min(self._mousePositionStart.x, self._mousePositionCurrent.x)
    local xMax = math.max(self._mousePositionStart.x, self._mousePositionCurrent.x)
    local yMin = math.min(self._mousePositionStart.y, self._mousePositionCurrent.y)
    local yMax = math.max(self._mousePositionStart.y, self._mousePositionCurrent.y)
    
    self.actionQueuerEvents:HandleEvent("SetSelectionRectangle", xMin, yMin, xMax, yMax)

    -- TODO: consider keeping 90deg angles
    self._posQuad = {
        minXminYProjected = GeoUtil.MapScreenPt(xMin, yMin),
        maxXminYProjected = GeoUtil.MapScreenPt(xMax, yMin),
        minXmaxYProjected = GeoUtil.MapScreenPt(xMin, yMax), 
        maxXmaxYProjected = GeoUtil.MapScreenPt(xMax, yMax)
    }

    local isBounded = GeoUtil.CreateQuadrilateralTester(
        self._posQuad.minXminYProjected,
        self._posQuad.maxXminYProjected,
        self._posQuad.minXmaxYProjected,
        self._posQuad.maxXmaxYProjected
    )

    local selectionBoxCenter = GeoUtil.MapScreenPt((xMin + xMax) / 2, (yMin + yMax) / 2)

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
            self._canActUponEntity(entity) 
        ) then
            actableEntitiesWithinBox[entity] = true
        end
    end

    MouseManager_DispachSelectedEntitiesChanges(self, actableEntitiesWithinBox)
end

--

local function MouseManager_OnDown_SelectionBox(self)

    self._selectionBoxActive = false

    self._mousePositionStart = TheInput:GetScreenPosition()
    
    self._handleMouseMove = function()
        if not self._selectionBoxActive then
            self._selectionBoxActive = (
                GeoUtil.ManhattanDistance(self._mousePositionStart, self._mousePositionCurrent) >
                constants.MANHATTAN_DISTANCE_TO_START_BOX_SELECTION
            )
        end
        if self._selectionBoxActive then
            MouseManager_HandleNewSelectionBox(self)
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
                self._mousePositionCurrent = TheInput:GetScreenPosition()
                self._handleMouseMove()
            end
            Sleep(constants.GET_MOUSE_POS_PERIOD)
        end
        self:Clear()
    end)
end

--

MouseManager_OnDown = function(self)
    self:Clear()

    if not self._isPlayerValid() or self._isAnyMouseManagerSelecting() then return end

    if (
        not self._keyToUse or
        TheInput:IsKeyDown(self._keyToUse)
    ) then
        MouseManager_OnDown_CherryPick(self)
        MouseManager_OnDown_SelectionBox(self)
    end
end

MouseManager_OnUp = function(self)
    if self._selectionBoxActive then
        self._mousePositionCurrent = TheInput:GetScreenPosition()
        MouseManager_HandleNewSelectionBox(self)
    end
    self.actionQueuerEvents:HandleEvent(
        "Apply",
        -- can be nil, that's fine
        self._posQuad
    )
    self:Clear()
end

--

return MouseManager
