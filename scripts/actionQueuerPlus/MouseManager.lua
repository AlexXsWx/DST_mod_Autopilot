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
        -- these two are set later
        self._isSelectKeyDown   = nil
        self._isDeselectKeyDown = nil
        --

        self._selectionWidget = nil
        self._mouseButtonHandler = nil

        self._session = nil
    end
)

function MouseManager:setKeyDownGetters(isSelectKeyDown, isDeselectKeyDown)
    self._isSelectKeyDown   = isSelectKeyDown
    self._isDeselectKeyDown = isDeselectKeyDown
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
        selectionBoxProjected = nil,
        updateSelectionBoxThread = nil,
        selecting = selecting,
    }
    return session
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

    local selecting   = self._isSelectKeyDown   and self._isSelectKeyDown()
    local deselecting = self._isDeselectKeyDown and self._isDeselectKeyDown()

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

    -- TODO: consider using arguments instead of separate API call
    self._session.mousePositionCurrent = mouseAPI.getMousePosition()

    local right = (mouseButton == MOUSEBUTTON_RIGHT)

    if self._session.selectionBoxProjected then
        MouseManager_UpdateSelectionBox(self, right)
        self._selectionManager:SubmitPreview(right)
    else
        MouseManager_CherryPick(self, right)
    end

    local cherrypicking = not self._session.selectionBoxProjected
    self._applyFn(
        -- selectionBoxProjected can be nil, that's fine
        self._session.selectionBoxProjected,
        right,
        cherrypicking
    )

    self:Clear()
end

--

MouseManager_CherryPick = function(self, right)
    local entities = TheInput:GetAllEntitiesUnderMouse()

    for _, entity in ipairs(entities) do
        if utils.testEntity(entity) and self._canActUponEntity(entity, right, true) then
            self._selectionManager:ToggleEntitySelection(entity, right)
            return
        end
    end
end

--

MouseManager_StartSelectionBox = function(self, right)
    self._session.updateSelectionBoxThread = self._startThread(function()
        while self._isPlayerValid() do

            local selecting   = self._isSelectKeyDown   and self._isSelectKeyDown()
            local deselecting = self._isDeselectKeyDown and self._isDeselectKeyDown()
            if (selecting or deselecting) and not (selecting and deselecting) then
                self._session.selecting = selecting or false
            end

            self._session.mousePositionCurrent = mouseAPI.getMousePosition()
            if (
                self._session.selectionBoxProjected or
                constants.MANHATTAN_DISTANCE_TO_START_BOX_SELECTION < GeoUtil.ManhattanDistance(
                    self._session.mousePositionStart,
                    self._session.mousePositionCurrent
                )
            ) then
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

    -- 0:0 = bottom left corner
    local minX = math.min(session.mousePositionStart.x, session.mousePositionCurrent.x)
    local maxX = math.max(session.mousePositionStart.x, session.mousePositionCurrent.x)
    local minY = math.min(session.mousePositionStart.y, session.mousePositionCurrent.y)
    local maxY = math.max(session.mousePositionStart.y, session.mousePositionCurrent.y)
    
    if self._selectionWidget then
        self._selectionWidget:Show(minX, minY, maxX, maxY)
    end

    -- TODO: consider keeping 90deg angles
    session.selectionBoxProjected = {
        --     North
        -- -Z  _   _ -X
        --    |\   /|
        --      \ /
        --       X     East
        --      / \
        --    |/   \|
        -- +X        +Z
        --
        --    B-----C
        --    |     |
        --    |     |
        --    A-----D
        --
        -- each tile has a side of 4 units
        -- geometric placement makes 8x8 points per tile
        --
        A = GeoUtil.MapScreenPt(minX, minY),
        B = GeoUtil.MapScreenPt(minX, maxY), 
        C = GeoUtil.MapScreenPt(maxX, maxY),
        D = GeoUtil.MapScreenPt(maxX, minY)
    }

    local quad = session.selectionBoxProjected

    local isBounded = GeoUtil.CreateQuadrilateralTester(quad.A, quad.B, quad.C, quad.D)

    local selectionBoxCenter = GeoUtil.MapScreenPt((minX + maxX) / 2, (minY + maxY) / 2)

    local selectionBoxOuterRadius = math.sqrt(
        math.max(
            selectionBoxCenter:DistSq(quad.A),
            selectionBoxCenter:DistSq(quad.B),
            selectionBoxCenter:DistSq(quad.C),
            selectionBoxCenter:DistSq(quad.D)
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
            self._canActUponEntity(entity, right, not session.selecting)
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
