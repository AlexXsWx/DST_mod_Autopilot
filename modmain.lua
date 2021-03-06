local ModConfigutationScreen = require("screens/redux/modconfigurationscreen")

local inputHelpers    = require "modAutopilot/input/inputHelpers"
local KeyBinder       = require "modAutopilot/input/KeyBinder"
local logger          = require "modAutopilot/utils/logger"
local utils           = require "modAutopilot/utils/utils"
local asyncUtils      = require "modAutopilot/utils/asyncUtils"
local highlightHelper = require "modAutopilot/highlightHelper"

Assets = {
    Asset("ATLAS", "images/selection_square.xml"),
    Asset("IMAGE", "images/selection_square.tex"),
}

_G = GLOBAL
local TheInput      = GLOBAL.TheInput
local KnownModIndex = GLOBAL.KnownModIndex

-- forward declaration --
local onPlayerPostInit
local fixConfig
local initAutopilot
local bindConfigurableShortcut
local changeOnControl
local getOpenMenuFn
local enableAutoRepeatCraft
local isDefaultScreen
local repeatLastCraft
-------------------------

local lastCraft = nil

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
    fixConfig(function()
        local waitUntil = asyncUtils.getWaitUntil(playerInst)
        waitUntil(
            -- condition
            function() return utils.toboolean(playerInst.components.playercontroller) end,
            -- action once the condition is met
            function() initAutopilot(playerInst) end
        )
    end)
end

-- In case configuration in modInfo was changed, make sure people don't have invalid saved data
fixConfig = function(callback)
    local clientConfig = true
    local config = KnownModIndex:LoadModConfigurationOptions(modname, clientConfig)
    local modInfo = KnownModIndex:GetModInfo(modname)
    local clientOnly = modInfo and modInfo.client_only_mod
    local settings = nil

    local needsFix = false

    if config and type(config) == "table" then
        for i,v in ipairs(config) do
            if (
                v.name and
                v.options and
                (v.saved ~= nil or v.default ~= nil) and
                (clientOnly or not v.client or clientConfig)
            ) then
                if not settings then settings = {} end
                local value = v.saved
                if value == nil then value = v.default end
                local found = false
                for _, v2 in pairs(v.options) do
                    if v2.data == value then
                        found = true
                        break
                    end
                end
                if not found then
                    logger.logDebug(
                        v.name .. " has unexpected value " .. tostring(value) ..
                        "; changing back to " .. tostring(v.default)
                    )
                    value = v.default
                    needsFix = true
                end
                table.insert(settings, {
                    name = v.name,
                    label = v.label,
                    options = v.options,
                    default = v.default,
                    saved = value,
                })
            end
        end
    end

    if needsFix then
        KnownModIndex:SaveConfigurationOptions(callback, modname, settings, clientConfig)
    else
        callback()
    end
end

local function updateConfig()
    logger.setDebugEnabled(
        GetModConfigData("logDebugEnabled") == "yes"
    )

    -- modifiers
    config.isSelectKeyDown = inputHelpers.createShortcutsTester(
        GetModConfigData("keyToQueueActions1"),
        GetModConfigData("keyToQueueActions2")
    )
    config.isDeselectKeyDown = inputHelpers.createShortcutsTester(
        GetModConfigData("keyToDeselect")
    )
    -- FIXME: this is not really a modifier, but Ctrl can't be used for addKeyDownHandler
    config.isInterruptKeyDown = inputHelpers.createShortcutsTester(
        GetModConfigData("keyToInterrupt")
    )

    -- bindings
    config.keyToOpenOptions   = GetModConfigData("keyToOpenOptions")
    config.undoKey            = GetModConfigData("keyToUndoInterrupt")
    config.repeatLastCraftKey = GetModConfigData("keyToRepeatLastCraft")

    config.autoCollect           = GetModConfigData("autoCollect")           == "yes"
    config.interruptOnMove       = GetModConfigData("interruptOnMove")       == "yes"
    config.tryMakeDeployPossible = GetModConfigData("tryMakeDeployPossible") == "yes"

    config.doubleClickMaxTimeSeconds    = GetModConfigData("doubleClickMaxTimeSeconds")
    config.doubleClickSearchRadiusTiles = GetModConfigData("doubleClickSearchRadiusTiles")
    config.doubleClickKeepSearching     = GetModConfigData("doubleClickKeepSearching") == "yes"

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
        "allowAttack",
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
        doubleClickKeepSearching     = config.doubleClickKeepSearching,
    })
end

initAutopilot = function(playerInst)

    if playerInst.components.modautopilot then
        logger.logWarning("modautopilot component already exists")
        return
    end

    logger.logDebug("initAutopilot")

    highlightHelper.applyUnhighlightOverride(playerInst)

    updateConfig()

    playerInst:AddComponent("modautopilot")
    reconfigureComponent(playerInst.components.modautopilot)

    enableAutoRepeatCraft(playerInst)

    -- Input

    changeOnControl(playerInst)

    -- Key bindings

    local keyBinder = KeyBinder()

    local function onConfigChanged()
        updateConfig()
        reconfigureComponent(playerInst.components.modautopilot)
        keyBinder:update()
    end

    keyBinder:bindConfigurableShortcut(
        config,
        "keyToOpenOptions",
        getOpenMenuFn(onConfigChanged)
    )

    keyBinder:bindConfigurableShortcut(
        config,
        "undoKey",
        function() playerInst.components.modautopilot:UndoInterrupt() end
    )

    keyBinder:bindConfigurableShortcut(
        config,
        "repeatLastCraftKey",
        function() repeatLastCraft(playerInst, not config.isSelectKeyDown()) end
    )
end

--

changeOnControl = function(playerInst)

    utils.overrideAndCancelIf(
        playerInst.components.playercontroller,
        "OnControl",
        function(self, control, down)

            -- Behave as usual in screens like map and etc
            if not isDefaultScreen() then
                return false
            end

            -- Prevent default action if user is doing autopilot stuff
            if config.isSelectKeyDown() or config.isDeselectKeyDown() then
                return true
            end

            local modautopilot = playerInst.components.modautopilot

            -- Check interrupt key
            if (
                config.isInterruptKeyDown() and
                modautopilot:CanInterrupt()
            ) then
                modautopilot:Interrupt()
                return true
            end

            -- Interrupt autopilot if user is doing non-autopilot stuff
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

getOpenMenuFn = function(onConfigChanged)
    -- forward declaration --
    local onOpenMenuButton
    local openModOptionsScreen
    local dismissModOptionsScreen
    -------------------------

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

        -- Small UX/QoL improvement
        screen.options_scroll_list:ScrollToDataIndex(params.scrollViewOffset)

        -- Install a hook to know when we need to re-parse the config
        utils.override(screen, "Apply", function(self, originalFn, ...)
            local willApplyChanges = self:IsDirty()
            local result = originalFn(self, ...)
            if willApplyChanges then
                onConfigChanged()
            end
            return result
        end)

        -- Install a hook to know when this popup is about to be closed
        utils.override(screen, "OnDestroy", function(self, originalFn, ...)
            params.onDestroy()
            return originalFn(self, ...)
        end)

        -- Present the popup
        TheFrontEnd:PushScreen(screen)

        return screen
    end

    dismissModOptionsScreen = function(screen)
        -- Not sure if this is needed, just copying it as it is from the source place
        screen:MakeDirty(false)
        TheFrontEnd:PopScreen()
    end

    return onOpenMenuButton
end

enableAutoRepeatCraft = function(playerInst)
    utils.overrideAndCancelIf(
        playerInst.replica.builder,
        "MakeRecipeFromMenu",
        function(self, recipe, skin)
            lastCraft = nil
            if recipe.placer ~= nil then return end
            lastCraft = {}
            lastCraft.recipe = recipe
            lastCraft.skin   = skin
            if config.isSelectKeyDown() then
                return repeatLastCraft(playerInst)
            end
        end
    )
end

isDefaultScreen = function()
    local screen = TheFrontEnd:GetActiveScreen()
    return utils.toboolean(
        screen and
        screen.name and
        screen.name:find("HUD") ~= nil
    )
end

repeatLastCraft = function(playerInst, optOnce)
    if lastCraft == nil then return false end
    playerInst.components.modautopilot:RepeatRecipe(
        lastCraft.recipe,
        lastCraft.skin,
        optOnce
    )
    return true
end

main()
