require "events"

local logger = require "modAutopilot/utils/logger"
local utils  = require "modAutopilot/utils/utils"

local mouseAPI = {}

--

local EVENT_BUTTON_STATE_CHANGE = "buttonStateChange"
local EVENT_MOUSE_MOVE          = "move"

local mouseEvents = EventProcessor()

--

local handlerAddrsInitialized = false

function mouseAPI.initializeHandlerAddrs()

    if handlerAddrsInitialized then return end
    handlerAddrsInitialized = true

    utils.override(
        TheFrontEnd,
        "OnMouseButton",
        function(self, originalFn, button, down, x, y)
            if not originalFn(self, button, down, x, y) then
                mouseEvents:HandleEvent(
                    EVENT_BUTTON_STATE_CHANGE,
                    button, down, x, y
                )
            else
                return true
            end
        end
    )

    utils.override(
        TheFrontEnd,
        "OnMouseMove",
        function(self, originalFn, x, y)
            mouseEvents:HandleEvent(EVENT_MOUSE_MOVE, x, y)
            return originalFn(self, x, y)
        end
    )
end

--

function mouseAPI.addButtonStateChangeHandler(handlerFn)
    return mouseEvents:AddEventHandler(EVENT_BUTTON_STATE_CHANGE, handlerFn)
end

function mouseAPI.addMouseMoveHandler(handlerFn)
    mouseEvents:AddEventHandler(EVENT_MOUSE_MOVE, handlerFn)
end

-- In pixels, 0:0 = bottom left corner
function mouseAPI.getMousePosition()
    return TheInput:GetScreenPosition()
end

--

return mouseAPI
