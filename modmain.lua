local keyMap           = require "actionQueuerPlus/input/keyMap"
local logger           = require "actionQueuerPlus/utils/logger"
local utils            = require "actionQueuerPlus/utils/utils"
local asyncUtils       = require "actionQueuerPlus/utils/asyncUtils"
local highlightHelper  = require "actionQueuerPlus/highlightHelper"

-- local OptionsScreen = require("screens/actionqueuerplusoptionsscreen")
local OptionsScreen = require("screens/redux/modconfigurationscreen")

Assets = {
    Asset("ATLAS", "images/selection_square.xml"),
    Asset("IMAGE", "images/selection_square.tex"),
}

local TheInput = GLOBAL.TheInput
local assert = GLOBAL.assert

-- forward declaration --
local onPlayerPostInit
local initActionQueuerPlus
local updateInputHandler
local enableAutoRepeatCraft
-------------------------

local config = {}

local function main()
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
        function() initActionQueuerPlus(playerInst) end
    )
end

local function updateConfig()

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
    }
    for _, pickMode in pairs(pickModes) do
        settingsForFilters[pickMode] = GetModConfigData(pickMode)
    end

    config.settingsForFilters = settingsForFilters
end

local function reconfigureComponent(actionqueuerplus)
    actionqueuerplus:Configure({
        autoCollect         = config.autoCollect,
        isSelectKeyDown     = config.isSelectKeyDown,
        isDeselectKeyDown   = config.isDeselectKeyDown,
        settingsForFilters  = config.settingsForFilters,
    })
end

initActionQueuerPlus = function(playerInst)
    logger.logDebug("initActionQueuerPlus")

    highlightHelper.applyUnhighlightOverride(playerInst)

    updateConfig()

    if not playerInst.components.actionqueuerplus then
        playerInst:AddComponent("actionqueuerplus")
        reconfigureComponent(playerInst.components.actionqueuerplus)
        updateInputHandler(playerInst)
    else
        logger.logWarning("actionqueuerplus component already exists")
    end

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
    logger.logDebug("updateInputHandler")
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

            local actionqueuerplus = playerInst.components.actionqueuerplus

            if (
                config.isInterruptKeyDown() and
                actionqueuerplus:CanInterrupt()
            ) then
                actionqueuerplus:Interrupt()
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
                actionqueuerplus:Interrupt()
                -- don't prevent action though
            end
        end
    )

    -- open menu binding

    local scrollViewOffset = 0
    local screen = nil
    local openMenuHandler = nil

    -- forward declaration --
    local tryBindOpenMenu
    local onUpdate
    -------------------------

    tryBindOpenMenu = function()
        if config.keyToOpenOptions == nil then return end
        openMenuHandler = TheInput.onkeydown:AddEventHandler(
            config.keyToOpenOptions,
            function()
                if screen and TheFrontEnd:GetActiveScreen() == screen then
                    -- screen:Close()
                    screen:MakeDirty(false)
                    TheFrontEnd:PopScreen()
                elseif isDefaultScreen() then
                    -- screen = OptionsScreen(modname, scrollViewOffset, onUpdate)
                    screen = OptionsScreen(modname, true)

                    utils.override(screen, "Apply", function(self, originalFn, ...)
                        local dirty = self:IsDirty()
                        local result = originalFn(self, ...)
                        onUpdate(0, dirty)
                        return result
                    end)
                    utils.override(screen, "OnDestroy", function(self, originalFn, ...)
                        scrollViewOffset = self.options_scroll_list.current_scroll_pos
                        screen = nil
                        return originalFn(self, ...)
                    end)
                    screen.options_scroll_list:ScrollToDataIndex(scrollViewOffset)
                    TheFrontEnd:PushScreen(screen)
                end
            end
        )
    end

    onUpdate = function(newScrollViewOffset, optHadEffect)
        -- scrollViewOffset = newScrollViewOffset
        if optHadEffect then
            updateConfig()
            reconfigureComponent(playerInst.components.actionqueuerplus)

            -- Re-add handler in case button changed
            if openMenuHandler then
                TheInput.onkeydown:RemoveHandler(openMenuHandler)
                openMenuHandler = nil
            end
            tryBindOpenMenu()
        end
        screen = nil
    end

    tryBindOpenMenu()
end

enableAutoRepeatCraft = function(playerInst)
    logger.logDebug("enableAutoRepeatCraft")
    utils.overrideToCancelIf(
        playerInst.replica.builder,
        "MakeRecipeFromMenu",
        function(self, recipe, skin)
            if config.isSelectKeyDown() and recipe.placer == nil then
                playerInst.components.actionqueuerplus:RepeatRecipe(recipe, skin)
                return true
            end
        end
    )
end

main()
