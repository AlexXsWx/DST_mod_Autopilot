local inputHelpers = {}

function inputHelpers.parseShortcutStr(shortcutStr)
    local keysInShortcut = {}
    for token in string.gmatch(shortcutStr, "KEY_[A-Z]+") do
        local keyCode = assert(_G[token])
        table.insert(keysInShortcut, keyCode)
    end
    return keysInShortcut
end

function inputHelpers.createShortcutsTester(...)
    local fns = {}
    for i = 1, arg.n do
        local shortcutStr = arg[i]
        if shortcutStr then
            local keysInShortcut = inputHelpers.parseShortcutStr(shortcutStr)
            local function isShortcutDown()
                for _, key in pairs(keysInShortcut) do
                    if not TheInput:IsKeyDown(key) then
                        return false
                    end
                end
                return true
            end
            table.insert(fns, isShortcutDown)
        end
    end
    local function isAnyShortcutDown()
        for _, isShortcutDown in pairs(fns) do
            if isShortcutDown() then
                return true
            end
        end
        return false
    end
    return isAnyShortcutDown
end

return inputHelpers
