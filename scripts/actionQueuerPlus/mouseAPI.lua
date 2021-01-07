require "events"

local mouseAPI = {}

--

local mousedown = EventProcessor()
local mouseup   = EventProcessor()
local mousemove = EventProcessor()

--

local initialized_handlers = false

function mouseAPI.InitializeHandlerAdders()

    if initialized_handlers then return end

    local TheFrontEnd = rawget(GLOBAL, "TheFrontEnd")
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

function mouseAPI.AddMouseButtonHandler(button, down, fn)
    local eventProcessor = down and mousedown or mouseup
    eventProcessor:AddEventHandler(button, fn)
end

function mouseAPI.AddMouseMoveHandler(fn)
    mousemove:AddEventHandler("move", fn)
end

return mouseAPI
