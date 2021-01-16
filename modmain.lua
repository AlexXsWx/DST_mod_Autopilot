local ModConfigutationScreen = require("screens/redux/modconfigurationscreen")

local keyMap           = require "modAutopilot/input/keyMap"
local logger           = require "modAutopilot/utils/logger"
local utils            = require "modAutopilot/utils/utils"
local asyncUtils       = require "modAutopilot/utils/asyncUtils"
local highlightHelper  = require "modAutopilot/highlightHelper"

Assets = {
    Asset("ATLAS", "images/selection_square.xml"),
    Asset("IMAGE", "images/selection_square.tex"),
}

local TheInput = GLOBAL.TheInput
local assert = GLOBAL.assert

-- forward declaration --
local onPlayerPostInit
local initAutopilot
local updateInputHandler
local bindOpenMenuButton
local enableAutoRepeatCraft
-------------------------

local config = {}

local function main()
    logger.setDebugEnabled(
        GetModConfigData("logDebugEnabled") == "yes"
    )

    logger.logDebug("main")
    AddPlayerPostInit(onPlayerPostInit)
end

onPlayerPostInit = function(playerInst)
    logger.logDebug("onPlayerPostInit")
    local waitUntil = asyncUtils.getWaitUntil(playerInst)
    waitUntil(
        -- condition
        function() return utils.toboolean(playerInst.components.playercontroller) end,
        -- action once the condition is met
        function() initAutopilot(playerInst) end
    )
end

local function updateConfig()
    logger.setDebugEnabled(
        GetModConfigData("logDebugEnabled") == "yes"
    )

    config.keyToOpenOptions = keyMap[GetModConfigData("keyToOpenOptions")] or nil

    local keyToQueueActions    = assert(keyMap[GetModConfigData("keyToQueueActions")])
    local altKeyToQueueActions = keyMap[GetModConfigData("altKeyToQueueActions")] or nil
    local optKeyToDeselect     = keyMap[GetModConfigData("keyToDeselect")] or nil
    local optKeyToInterrupt    = keyMap[GetModConfigData("keyToInterrupt")] or nil
    local altKeyToInterrupt    = keyMap[GetModConfigData("altKeyToInterrupt")] or nil

    local function isSelectKeyDown()
        return (
            TheInput:IsKeyDown(keyToQueueActions) or
            altKeyToQueueActions and TheInput:IsKeyDown(altKeyToQueueActions)
        )
    end

    local function isDeselectKeyDown()
        return optKeyToDeselect and TheInput:IsKeyDown(optKeyToDeselect)
    end

    local function isInterruptKeyDown()
        return (
            optKeyToInterrupt and TheInput:IsKeyDown(optKeyToInterrupt) or
            altKeyToInterrupt and TheInput:IsKeyDown(altKeyToInterrupt)
        )
    end

    config.isSelectKeyDown     = isSelectKeyDown
    config.isDeselectKeyDown   = isDeselectKeyDown
    config.isInterruptKeyDown  = isInterruptKeyDown

    config.autoCollect     = GetModConfigData("autoCollect") == "yes"
    config.interruptOnMove = GetModConfigData("interruptOnMove") == "yes"

    config.tryMakeDeployPossible = GetModConfigData("tryMakeDeployPossible") == "yes"

    config.doubleClickMaxTimeSeconds    = GetModConfigData("doubleClickMaxTimeSeconds")
    config.doubleClickSearchRadiusTiles = GetModConfigData("doubleClickSearchRadiusTiles")

    --

    local settingsForFilters = {}

    settingsForFilters.digStumpsAsWerebeaver = GetModConfigData("digStumpsAsWerebeaver") == "yes"

    local pickModes = {
        "pickFlowersMode",
        "pickCarrotsMode",
        "pickMandrakesMode",
        "pickMushroomsMode",
        "pickTwigsMode",
        "pickRotMode",
        "pickSeedsMode",
        "pickRocksMode",
        "pickFlintMode",
        "pickTreeBlossomMode",
        "digUpSeeds",
    }
    for _, pickMode in pairs(pickModes) do
        settingsForFilters[pickMode] = GetModConfigData(pickMode)
    end

    config.settingsForFilters = settingsForFilters
end

local function reconfigureComponent(modautopilot)
    modautopilot:Configure({
        autoCollect                  = config.autoCollect,
        isSelectKeyDown              = config.isSelectKeyDown,
        isDeselectKeyDown            = config.isDeselectKeyDown,
        settingsForFilters           = config.settingsForFilters,
        tryMakeDeployPossible        = config.tryMakeDeployPossible,
        doubleClickMaxTimeSeconds    = config.doubleClickMaxTimeSeconds,
        doubleClickSearchRadiusTiles = config.doubleClickSearchRadiusTiles,
    })
end

initAutopilot = function(playerInst)
    logger.logDebug("initAutopilot")

    highlightHelper.applyUnhighlightOverride(playerInst)

    updateConfig()

    if playerInst.components.modautopilot then
        logger.logWarning("modautopilot component already exists")
        return
    end

    playerInst:AddComponent("modautopilot")
    reconfigureComponent(playerInst.components.modautopilot)

    updateInputHandler(playerInst)
    bindOpenMenuButton(function()
        updateConfig()
        reconfigureComponent(playerInst.components.modautopilot)
    end)
    enableAutoRepeatCraft(playerInst)
end

--

-- We want to make sure that chatting, or being in menus, etc, doesn't toggle
local function getActiveScreenName()
    local screen = TheFrontEnd:GetActiveScreen()
    return screen and screen.name or ""
end

local function isDefaultScreen()
    return getActiveScreenName():find("HUD") ~= nil
end

--

updateInputHandler = function(playerInst)
    utils.overrideToCancelIf(
        playerInst.components.playercontroller,
        "OnControl",
        function(self, ...)
            if not isDefaultScreen() then
                return false
            end

            if config.isSelectKeyDown() or config.isDeselectKeyDown() then
                return true
            end

            local modautopilot = playerInst.components.modautopilot

            if (
                config.isInterruptKeyDown() and
                modautopilot:CanInterrupt()
            ) then
                modautopilot:Interrupt()
                return true
            end

            if (
                config.interruptOnMove and (
                    TheInput:IsControlPressed(GLOBAL.CONTROL_MOVE_UP) or
                    TheInput:IsControlPressed(GLOBAL.CONTROL_MOVE_DOWN) or
                    TheInput:IsControlPressed(GLOBAL.CONTROL_MOVE_LEFT) or
                    TheInput:IsControlPressed(GLOBAL.CONTROL_MOVE_RIGHT)
                ) or
                not TheInput:GetHUDEntityUnderMouse() and (
                    TheInput:IsControlPressed(GLOBAL.CONTROL_PRIMARY) or
                    TheInput:IsControlPressed(GLOBAL.CONTROL_SECONDARY)
                ) or
                TheInput:IsControlPressed(GLOBAL.CONTROL_ATTACK)
            )
            then
                modautopilot:Interrupt()
                -- don't prevent action though
            end
        end
    )
end

bindOpenMenuButton = function(onConfigChanged)
    local keyHandler = nil

    -- forward declaration --
    local tryUnbindOpenMenuButton
    local tryBindOpenMenuButton
    local onOpenMenuButton
    local openModOptionsScreen
    local dismissModOptionsScreen
    -------------------------

    tryUnbindOpenMenuButton = function()
        if keyHandler then
            TheInput.onkeydown:RemoveHandler(keyHandler)
            keyHandler = nil
        end
    end

    tryBindOpenMenuButton = function()
        if config.keyToOpenOptions ~= nil then
            keyHandler = TheInput.onkeydown:AddEventHandler(
                config.keyToOpenOptions,
                onOpenMenuButton
            )
        end
    end

    local scrollViewOffset = 0
    local activeModConfigurationScreen = nil
    onOpenMenuButton = function()
        if (
            activeModConfigurationScreen and
            TheFrontEnd:GetActiveScreen() == activeModConfigurationScreen
        ) then
            dismissModOptionsScreen(activeModConfigurationScreen)
        elseif isDefaultScreen() then
            activeModConfigurationScreen = openModOptionsScreen({
                scrollViewOffset = scrollViewOffset,
                onConfigChanged = function()
                    onConfigChanged()
                    -- Re-add handler in case button changed
                    tryUnbindOpenMenuButton()
                    tryBindOpenMenuButton()
                end,
                onDestroy = function()
                    scrollViewOffset = (
                        activeModConfigurationScreen.options_scroll_list.current_scroll_pos
                    )
                    activeModConfigurationScreen = nil
                end,
            })
        end
    end

    openModOptionsScreen = function(params)
        local screen = ModConfigutationScreen(modname, true)

        screen.options_scroll_list:ScrollToDataIndex(params.scrollViewOffset)

        utils.override(screen, "Apply", function(self, originalFn, ...)
            local willApplyChanges = self:IsDirty()
            local result = originalFn(self, ...)
            if willApplyChanges then
                params.onConfigChanged()
            end
            return result
        end)

        utils.override(screen, "OnDestroy", function(self, originalFn, ...)
            params.onDestroy()
            return originalFn(self, ...)
        end)

        TheFrontEnd:PushScreen(screen)

        return screen
    end

    dismissModOptionsScreen = function(screen)
        screen:MakeDirty(false)
        TheFrontEnd:PopScreen()
    end

    tryBindOpenMenuButton()
end

enableAutoRepeatCraft = function(playerInst)
    utils.overrideToCancelIf(
        playerInst.replica.builder,
        "MakeRecipeFromMenu",
        function(self, recipe, skin)
            if config.isSelectKeyDown() and recipe.placer == nil then
                playerInst.components.modautopilot:RepeatRecipe(recipe, skin)
                return true
            end
        end
    )
end

main()
