require "events"

local mouseAPI = {}

--

local mousedown = EventProcessor()
local mouseup   = EventProcessor()
local mousemove = EventProcessor()

--

local initialized_handlers = false

function mouseAPI.initializeHandlerAdders()

    if initialized_handlers then return end

    local TheFrontEnd = rawget(_G, "TheFrontEnd")
    if not TheFrontEnd then return end

    -- Override TheFrontEnd.OnMouseButton

    local originalOnMouseButton = TheFrontEnd.OnMouseButton

    local function newOnMouseButton(self, button, down, x, y)
        if not originalOnMouseButton(self, button, down, x, y) then
            local eventProcessor = down and mousedown or mouseup
            eventProcessor:HandleEvent(button, x, y)
        else
            return true
        end
    end

    TheFrontEnd.OnMouseButton = newOnMouseButton

    -- Override TheFrontEnd.OnMouseMove

    local originalOnMouseMove = TheFrontEnd.OnMouseMove

    local function newOnMouseMove(self, x, y)
        mousemove:HandleEvent("move", x, y)
        return originalOnMouseMove(self, x, y)
    end

    TheFrontEnd.OnMouseMove = newOnMouseMove

    --

    initialized_handlers = true
end

function mouseAPI.addMouseButtonHandler(button, down, fn)
    local eventProcessor = down and mousedown or mouseup
    eventProcessor:AddEventHandler(button, fn)
end

function mouseAPI.addMouseMoveHandler(fn)
    mousemove:AddEventHandler("move", fn)
end

-- In pixels, 0:0 = bottom left corner
function mouseAPI.getMousePosition()
    return TheInput:GetScreenPosition()
end

return mouseAPI
