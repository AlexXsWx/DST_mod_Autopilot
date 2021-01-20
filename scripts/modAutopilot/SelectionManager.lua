local utils           = require "modAutopilot/utils/utils"
local highlightHelper = require "modAutopilot/highlightHelper"
local constants       = require "modAutopilot/constants"

local PREFAB_GROUPS = {
    {
        ["stalker_minion"]  = true,
        ["stalker_minion1"] = true,
        ["stalker_minion2"] = true,
    },
    {
        ["deer_antler"]  = true,
        ["deer_antler1"] = true,
        ["deer_antler2"] = true,
        ["deer_antler3"] = true,
    },
}

local SelectionManager = Class(function(self)
    -- keys = selected entities, value = "right button?" (true or false)
    -- Also tells if entity is selected or not (has entry or not)
    self._rightPerSelectedEntity = {}
    -- key = prefab name, value = "right button?""
    self._rightPerPrefabName = {}

    -- Are preview entities for selecting or deselecting?
    self._previewSelecting = true
    self._previewEntities = {}

    self._highlitEntities = {}
end)

function SelectionManager:IsSelectionEmpty()
    return next(self._rightPerSelectedEntity) == nil
end

function SelectionManager:IsSelectedWithRight(entity)
    return self._rightPerSelectedEntity[entity] == true
end

function SelectionManager:shouldKeepHighlight(entity)
    if not self._previewSelecting and self._previewEntities[entity] ~= nil then
        return false
    end
    return (
        self:IsEntitySelected(entity) or
        self._previewSelecting and self._previewEntities[entity] ~= nil
    )
end

function SelectionManager:IsEntitySelected(entity)
    return self._rightPerSelectedEntity[entity] ~= nil
end

function SelectionManager:GetSelectedEntitiesIterator()
    return pairs(self._rightPerSelectedEntity)
end

function SelectionManager:MakeBackup()
    local rightPerEntity = {}
    for entity, right in pairs(self._rightPerSelectedEntity) do
        rightPerEntity[entity] = right
    end
    local rightPerPrefabName = {}
    for prefabName, right in pairs(self._rightPerPrefabName) do
        rightPerPrefabName[prefabName] = right
    end
    return {
        rightPerEntity     = rightPerEntity,
        rightPerPrefabName = rightPerPrefabName,
    }
end

function SelectionManager:RestoreFromBackup(backup)
    self:DeselectAllEntities()
    for entity, right in pairs(backup.rightPerEntity) do
        self:SelectEntity(entity, right)
    end
    for prefabName, right in pairs(backup.rightPerPrefabName) do
        self._rightPerPrefabName[prefabName] = right
    end
end

local function SelectionManager_updateHighlight(self, entity)
    local highlight = self:shouldKeepHighlight(entity)
    if highlight ~= utils.toboolean(self._highlitEntities[entity]) then
        if highlight then
            highlightHelper.highlightEntity(entity)
            self._highlitEntities[entity] = true
        else
            highlightHelper.unhighlightEntity(entity)
            self._highlitEntities[entity] = nil
        end
    end
end

function SelectionManager:PreviewEntitiesSelection(optEntities, optForSelection)
    if optForSelection ~= nil then
        self._previewSelecting = optForSelection    
    else
        self._previewSelecting = true
    end
    local oldPreview = self._previewEntities
    self._previewEntities = optEntities or {}
    for entity in pairs(oldPreview) do
        SelectionManager_updateHighlight(self, entity)
    end
    for entity in pairs(self._previewEntities) do
        SelectionManager_updateHighlight(self, entity)
    end
end

function SelectionManager:SubmitPreview(right)
    if self._previewSelecting then
        for entity in pairs(self._previewEntities) do
            self:SelectEntity(entity, right)
        end
    else
        for entity in pairs(self._previewEntities) do
            self:DeselectEntity(entity)
        end
    end
end

function SelectionManager:SelectPrefabName(prefabName, right)
    self._rightPerPrefabName[prefabName] = right
    for _, group in pairs(PREFAB_GROUPS) do
        if group[prefabName] then
            for key in pairs(group) do
                self._rightPerPrefabName[key] = right
            end
        end
    end
end

function SelectionManager:DeselectPrefabName(prefabName, right)
    self._rightPerPrefabName[prefabName] = nil
    for _, group in pairs(PREFAB_GROUPS) do
        if group[prefabName] then
            for key in pairs(group) do
                self._rightPerPrefabName[key] = nil
            end
        end
    end
end

function SelectionManager:ExpandSelection(pos, radiusTiles, filter)
    local tileSideSize = 4
    local entitiesAround = TheSim:FindEntities(
        pos.x,
        pos.y,
        pos.z,
        radiusTiles * tileSideSize,
        nil,
        constants.UNSELECTABLE_TAGS
    )
    for k, v in ipairs(entitiesAround) do
        local right = self._rightPerPrefabName[v.prefab]
        if (
            right ~= nil and
            utils.testEntity(v) and
            filter(v, right, true, false)
        ) then
            self:SelectEntity(v, right)
        end
    end
end

function SelectionManager:SelectEntity(entity, right)
    if not entity:IsValid() or entity:IsInLimbo() then
        self:DeselectEntity(entity)
        return
    end

    if self._rightPerSelectedEntity[entity] == nil then
        self._rightPerSelectedEntity[entity] = right or false
        SelectionManager_updateHighlight(self, entity)
    end
end

function SelectionManager:DeselectEntity(entity)
    if self._rightPerSelectedEntity[entity] ~= nil then
        self._rightPerSelectedEntity[entity] = nil
        SelectionManager_updateHighlight(self, entity)
    end
end

function SelectionManager:ToggleEntitySelection(entity, right)
    if self:IsEntitySelected(entity) then
        self:DeselectEntity(entity)
    else
        self:SelectEntity(entity, right)
    end
end

function SelectionManager:DeselectAllEntities()
    for entity in pairs(self._rightPerSelectedEntity) do
        self:DeselectEntity(entity)
    end
    self._rightPerPrefabName = {}
end

return SelectionManager
