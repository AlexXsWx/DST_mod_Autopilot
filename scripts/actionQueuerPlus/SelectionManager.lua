local highlight = require "actionQueuerPlus/highlight"

local SelectionManager = Class(function(self)
    -- Maps entities to "right button?" (true or false); nil if entity is not selected
    self._rightPerSelectedEntity = {}
end)

function SelectionManager:IsSelectionEmpty()
    return next(self._rightPerSelectedEntity) == nil
end

function SelectionManager:IsSelectedWithRight(entity)
    return self._rightPerSelectedEntity[entity] == true
end

function SelectionManager:IsEntitySelected(entity)
    return self._rightPerSelectedEntity[entity] ~= nil
end

function SelectionManager:GetSelectedEntitiesIterator()
    return pairs(self._rightPerSelectedEntity)
end

function SelectionManager:SelectEntity(entity, right)

    if not entity:IsValid() or entity:IsInLimbo() then
        self:DeselectEntity(entity)
        return
    end

    if self._rightPerSelectedEntity[entity] == nil then
        self._rightPerSelectedEntity[entity] = right or false
        highlight.highlightEntity(entity)
    end
end

function SelectionManager:DeselectEntity(entity)
    if self._rightPerSelectedEntity[entity] ~= nil then
        self._rightPerSelectedEntity[entity] = nil
        highlight.unhighlightEntity(entity)
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
