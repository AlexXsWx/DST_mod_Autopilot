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
    local optKeyToInterrupt    = keyMap[GetModConfigData("keyToInterrupt")] or nil
    local autoCollect          = GetModConfigData("autoCollect") == "yes"
    local repeatCraft          = GetModConfigData("repeatCraft") == "yes"
    local interruptOnMove      = GetModConfigData("interruptOnMove") == "yes"

    local function isQueiengActive()
        return (
            TheInput:IsKeyDown(keyToQueueActions) or
            altKeyToQueueActions and TheInput:IsKeyDown(altKeyToQueueActions)
        )
    end

    if not playerInst.components.actionqueuerplus then
        playerInst:AddComponent("actionqueuerplus")
        playerInst.components.actionqueuerplus:Configure({
            autoCollect     = autoCollect,
            isQueiengActive = isQueiengActive,
        })
        updateInputHandler(playerInst, isQueiengActive, optKeyToInterrupt, interruptOnMove)
    else
        logger.logWarning("actionqueuerplus component already exists")
    end

    if repeatCraft then
        enableAutoRepeatCraft(playerInst, isQueiengActive)
    end
end

updateInputHandler = function(playerInst, isQueiengActive, optKeyToInterrupt, interruptOnMove)
    logger.logDebug("updateInputHandler")
    utils.overrideToCancelIf(
        playerInst.components.playercontroller,
        "OnControl",
        function(self, ...)
            if playerInst.HUD:IsMapScreenOpen() then
                return false
            end

            if isQueiengActive() then
                return true
            end

            local actionqueuerplus = playerInst.components.actionqueuerplus

            if (
                optKeyToInterrupt and
                TheInput:IsKeyDown(optKeyToInterrupt) and
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

enableAutoRepeatCraft = function(playerInst, isQueiengActive)
    logger.logDebug("enableAutoRepeatCraft")
    utils.overrideToCancelIf(
        playerInst.replica.builder,
        "MakeRecipeFromMenu",
        function(self, recipe, skin)
            if isQueiengActive() and recipe.placer == nil then
                playerInst.components.actionqueuerplus:RepeatRecipe(recipe, skin)
                return true
            end
        end
    )
end

main()
