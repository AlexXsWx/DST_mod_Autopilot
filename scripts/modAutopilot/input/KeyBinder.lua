local inputHelpers = require "modAutopilot/input/inputHelpers"

-- forward declaration --
local KeyBinder_bindConfigurableShortcut
-------------------------

local KeyBinder = Class(function(self)
    self._keyHandlers = {}
    self._bindings = {}
end)

function KeyBinder:update()
    -- remove all previous handlers
    for _, keyHandler in pairs(self._keyHandlers) do
        TheInput.onkeydown:RemoveHandler(keyHandler)
    end
    self._keyHandlers = {}

    -- re-add everything that was added before using up to date configu
    for _, binding in pairs(self._bindings) do
        KeyBinder_bindConfigurableShortcut(self, binding)
    end
end

function KeyBinder:bindConfigurableShortcut(
    config,
    propertyNames,
    shortcutAction
)
    -- Ensure 2nd arg is a table
    local t = propertyNames
    if type(t) ~= "table" then
        t = { t }
    end
    --
    for _, propertyName in pairs(t) do
        local binding = {
            config         = config,
            propertyName   = propertyName,
            shortcutAction = shortcutAction,
        }
        table.insert(self._bindings, binding)
        KeyBinder_bindConfigurableShortcut(self, binding)
    end
end

KeyBinder_bindConfigurableShortcut = function(self, binding)

    local shortcutStr = binding.config[binding.propertyName]

    if not shortcutStr then
        -- Not all shortcuts are mandatory
        return
    end

    local keysInShortcut = inputHelpers.parseShortcutStr(shortcutStr)
    local isShortcutDown = inputHelpers.createShortcutsTester(shortcutStr)

    local function onKeyDown()
        if isShortcutDown() then
            binding.shortcutAction()
        end
    end

    for _, key in pairs(keysInShortcut) do
        local keyHandler = TheInput.onkeydown:AddEventHandler(key, onKeyDown)
        table.insert(self._keyHandlers, keyHandler)
    end
end

return KeyBinder
