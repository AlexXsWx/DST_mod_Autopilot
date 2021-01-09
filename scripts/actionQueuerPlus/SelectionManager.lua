local utils           = require "actionQueuerPlus/utils"
local highlightHelper = require "actionQueuerPlus/highlightHelper"

local SelectionManager = Class(function(self)
    -- Maps entities to "right button?" (true or false); nil if entity is not selected
    self._rightPerSelectedEntity = {}
    self._previewEntities = {}
    self._highlitEntities = {}
end)

function SelectionManager:IsSelectionEmpty()
    return next(self._rightPerSelectedEntity) == nil
end

function SelectionManager:IsSelectedWithRight(entity)
    return self._rightPerSelectedEntity[entity] == true
end

function SelectionManager:shouldKeepHighlight(entity, optPreviewMap)
    local previewMap = optPreviewMap or self._previewEntities
    return self:IsEntitySelected(entity) or previewMap[entity] ~= nil
end

function SelectionManager:IsEntitySelected(entity)
    return self._rightPerSelectedEntity[entity] ~= nil
end

function SelectionManager:GetSelectedEntitiesIterator()
    return pairs(self._rightPerSelectedEntity)
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

function SelectionManager:PreviewEntitiesSelection(entities)
    local oldPreview = self._previewEntities
    self._previewEntities = entities
    for entity in pairs(oldPreview) do
        SelectionManager_updateHighlight(self, entity)
    end
    for entity in pairs(entities) do
        SelectionManager_updateHighlight(self, entity)
    end
end

function SelectionManager:SelectEntities(entities, right)
    for entity in pairs(entities) do
        self:SelectEntity(entity, right)
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
end

return SelectionManager
