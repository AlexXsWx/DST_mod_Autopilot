local Highlight = require "components/highlight"

local highlight = {}

function highlight.applyUnhighlightOverride(playerInst)
    Highlight.UnHighlight = (function()
        local originalUnHighlight = assert(Highlight.UnHighlight)
        return function(self, ...)
            -- local playerInst = ThePlayer
            if (
                playerInst and
                playerInst.components.actionqueuerplus and
                playerInst.components.actionqueuerplus:IsEntitySelected(self.inst)
            ) then
                return
            end
            return originalUnHighlight(self, ...)
        end
    end)()
end

--

function highlight.highlightEntity(entity)
    local highlight = entity.components.highlight
    if not highlight then
        entity:AddComponent("highlight")
        highlight = entity.components.highlight
    end
    if not highlight.highlit then
        local override = entity.highlight_override
        if override then
            highlight:Highlight(override[1], override[2], override[3])
        else
            highlight:Highlight()
        end
    end
end

function highlight.unhighlightEntity(entity)
    if entity:IsValid() and entity.components.highlight then
        entity.components.highlight:UnHighlight()
    end
end

--

return highlight
