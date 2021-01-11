local keyMap           = require "actionQueuerPlus/keyMap"
local logger           = require "actionQueuerPlus/logger"
local utils            = require "actionQueuerPlus/utils"
local asyncUtils       = require "actionQueuerPlus/asyncUtils"
local highlightHelper  = require "actionQueuerPlus/highlightHelper"

local OptionsScreen = require("screens/actionqueuerplusoptionsscreen")

Assets = {
    Asset("ATLAS", "images/selection_square.xml"),
    Asset("IMAGE", "images/selection_square.tex"),
}

_G = GLOBAL

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

    config.autoCollect        = GetModConfigData("autoCollect") == "yes"
    config.interruptOnMove    = GetModConfigData("interruptOnMove") == "yes"
    config.pickFlowersMode    = GetModConfigData("pickFlowers")
    config.pickCarrotsMode    = GetModConfigData("pickCarrots")
    config.pickMandrakesMode  = GetModConfigData("pickMandrakes")
    config.isSelectKeyDown    = isSelectKeyDown
    config.isDeselectKeyDown  = isDeselectKeyDown
    config.isInterruptKeyDown = isInterruptKeyDown
end

local function reconfigureComponent(actionqueuerplus)
    actionqueuerplus:Configure({
        autoCollect       = config.autoCollect,
        isSelectKeyDown   = config.isSelectKeyDown,
        isDeselectKeyDown = config.isDeselectKeyDown,
        pickFlowersMode   = config.pickFlowersMode,
        pickCarrotsMode   = config.pickCarrotsMode,
        pickMandrakesMode = config.pickMandrakesMode,
    })
end

initActionQueuerPlus = function(playerInst)
    logger.logDebug("initActionQueuerPlus")

    highlightHelper.applyUnhighlightOverride(playerInst)

    updateConfig()

    if not playerInst.components.actionqueuerplus then
        playerInst:AddComponent("actionqueuerplus")
        reconfigureComponent(playerInst.components.actionqueuerplus)
        updateInputHandler(playerInst, config)
    else
        logger.logWarning("actionqueuerplus component already exists")
    end

    enableAutoRepeatCraft(playerInst, config)
end

updateInputHandler = function(playerInst, config)
    logger.logDebug("updateInputHandler")
    utils.overrideToCancelIf(
        playerInst.components.playercontroller,
        "OnControl",
        function(self, ...)
            if playerInst.HUD:IsMapScreenOpen() then
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
                TheInput:IsControlPressed(GLOBAL.CONTROL_PRIMARY) or
                TheInput:IsControlPressed(GLOBAL.CONTROL_SECONDARY) or
                TheInput:IsControlPressed(GLOBAL.CONTROL_ATTACK)
            )
            then
                actionqueuerplus:Interrupt()
                -- don't prevent action though
            end
        end
    )

    local optionsScreenOpen = false
    local scrollViewOffset = 0
    local onUpdate = function(newScrollViewOffset, optHadEffect)
        optionsScreenOpen = false
        scrollViewOffset = newScrollViewOffset
        if optHadEffect then
            updateConfig()
            reconfigureComponent(playerInst.components.actionqueuerplus)            
        end
    end
    TheInput:AddKeyDownHandler(
        -- FIXME: allow to configure
        GLOBAL.KEY_X,
        function()
            if not optionsScreenOpen then
                optionsScreenOpen = true
                local screen = OptionsScreen(modname, scrollViewOffset, onUpdate)
                GLOBAL.TheFrontEnd:PushScreen(screen)
            end
        end
    )
end

enableAutoRepeatCraft = function(playerInst, config)
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
