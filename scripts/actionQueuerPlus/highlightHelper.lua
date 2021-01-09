local Highlight = require "components/highlight"

local utils = require "actionQueuerPlus/utils"

local highlightHelper = {}

function highlightHelper.applyUnhighlightOverride(playerInst)
    utils.overrideToCancelIf(
        Highlight,
        "UnHighlight",
        function(self, ...)
            return (
                playerInst and
                playerInst.components.actionqueuerplus and
                playerInst.components.actionqueuerplus:shouldKeepHighlight(self.inst)
            )
        end
    )
end

--

function highlightHelper.highlightEntity(entity)
    if not entity.components.highlight then
        entity:AddComponent("highlight")
    end
    local component = entity.components.highlight
    if not component.highlit then
        local override = entity.highlight_override
        if override then
            component:Highlight(override[1], override[2], override[3])
        else
            component:Highlight()
        end
    end
end

function highlightHelper.unhighlightEntity(entity)
    if entity:IsValid() and entity.components.highlight then
        entity.components.highlight:UnHighlight()
    end
end

--

return highlightHelper
