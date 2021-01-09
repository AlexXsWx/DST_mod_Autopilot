local keyMap           = require "actionQueuerPlus/keyMap"
local logger           = require "actionQueuerPlus/logger"
local utils            = require "actionQueuerPlus/utils"
local asyncUtils       = require "actionQueuerPlus/asyncUtils"
local highlightHelper  = require "actionQueuerPlus/highlightHelper"

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

initActionQueuerPlus = function(playerInst)
    logger.logDebug("initActionQueuerPlus")

    highlightHelper.applyUnhighlightOverride(playerInst)

    -- parse config
    local keyToQueueActions    = assert(keyMap[GetModConfigData("keyToQueueActions")])
    local altKeyToQueueActions = keyMap[GetModConfigData("altKeyToQueueActions")] or nil
    local optKeyToDeselect     = keyMap[GetModConfigData("keyToDeselect")] or nil
    local optKeyToInterrupt    = keyMap[GetModConfigData("keyToInterrupt")] or nil
    local altKeyToInterrupt    = keyMap[GetModConfigData("altKeyToInterrupt")] or nil
    local autoCollect          = GetModConfigData("autoCollect") == "yes"
    local interruptOnMove      = GetModConfigData("interruptOnMove") == "yes"
    local pickFlowersMode      = GetModConfigData("pickFlowers")
    local pickCarrotsMode      = GetModConfigData("pickCarrots")
    local pickMandrakesMode    = GetModConfigData("pickMandrakes")

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

    if not playerInst.components.actionqueuerplus then
        playerInst:AddComponent("actionqueuerplus")
        playerInst.components.actionqueuerplus:Configure({
            autoCollect       = autoCollect,
            isSelectKeyDown   = isSelectKeyDown,
            isDeselectKeyDown = isDeselectKeyDown,
            pickFlowersMode   = pickFlowersMode,
            pickCarrotsMode   = pickCarrotsMode,
            pickMandrakesMode = pickMandrakesMode,
        })
        updateInputHandler(
            playerInst,
            isSelectKeyDown,
            isDeselectKeyDown,
            isInterruptKeyDown,
            interruptOnMove
        )
    else
        logger.logWarning("actionqueuerplus component already exists")
    end

    enableAutoRepeatCraft(playerInst, isSelectKeyDown)
end

updateInputHandler = function(
    playerInst,
    isSelectKeyDown,
    isDeselectKeyDown,
    isInterruptKeyDown,
    interruptOnMove
)
    logger.logDebug("updateInputHandler")
    utils.overrideToCancelIf(
        playerInst.components.playercontroller,
        "OnControl",
        function(self, ...)
            if playerInst.HUD:IsMapScreenOpen() then
                return false
            end

            if isSelectKeyDown() or isDeselectKeyDown() then
                return true
            end

            local actionqueuerplus = playerInst.components.actionqueuerplus

            if (
                isInterruptKeyDown() and
                actionqueuerplus:CanInterrupt()
            ) then
                actionqueuerplus:Interrupt()
                return true
            end

            if (
                interruptOnMove and (
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
end

enableAutoRepeatCraft = function(playerInst, isSelectKeyDown)
    logger.logDebug("enableAutoRepeatCraft")
    utils.overrideToCancelIf(
        playerInst.replica.builder,
        "MakeRecipeFromMenu",
        function(self, recipe, skin)
            if isSelectKeyDown() and recipe.placer == nil then
                playerInst.components.actionqueuerplus:RepeatRecipe(recipe, skin)
                return true
            end
        end
    )
end

main()
