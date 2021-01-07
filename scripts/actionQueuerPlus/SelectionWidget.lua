local Image = require "widgets/image"

local constants = require "actionQueuerPlus/constants"

local SelectionWidget = Class(function(self)
    self._image = nil
end)

function SelectionWidget:Create(parent)
    self:Kill()
    self._image = Image("images/selection_square.xml", "selection_square.tex")
    self._image:SetTint(unpack(constants.SELECTION_BOX_TINT))
    parent:AddChild(self._image)
    self:Hide()
end

function SelectionWidget:Show(xMin, yMin, xMax, yMax)
    if self._image then
        self._image:SetPosition((xMin + xMax) / 2, (yMin + yMax) / 2)
        self._image:SetSize(xMax - xMin, yMax - yMin)
        self._image:Show()
    end
end

function SelectionWidget:Hide()
    if self._image then
        self._image:Hide()   
    end
end

function SelectionWidget:Kill()
    if self._image then
        self._image:Kill()
        self._image = nil
    end
end

return SelectionWidget
