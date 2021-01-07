local keyMap     = require "actionQueuerPlus/keyMap"
local constants  = require "actionQueuerPlus/constants"
local log        = require "actionQueuerPlus/log"
local asyncUtils = require "actionQueuerPlus/asyncUtils"
local highlight  = require "actionQueuerPlus/highlight"

--------------------------------------------------------------------

Assets = {
    Asset("ATLAS", "images/selection_square.xml"),
    Asset("IMAGE", "images/selection_square.tex"),
}

--------------------------------------------------------------------

-- forward declaration
local playerPostInit
local updateInputHandler
local enableAutoRepeatCraft

local function main()
    log("main")
    AddPlayerPostInit(playerPostInit)
end

playerPostInit = function(playerInst)
    log("playerPostInit")
    local waitUntil = asyncUtils.getWaitUntil(playerInst)
    waitUntil(
        -- condition
        function()
            -- local playerInst = ThePlayer
            -- local canProceed = playerInst and playerInst.components.playercontroller
            -- return canProceed
            return toboolean(playerInst.components.playercontroller)
        end,
        -- action once the condition is met
        function()
            log("playerPostInit - playercontroller available")

            -- parse config
            local keyToUse          = assert(keyMap[GetModConfigData("keyToUse")])
            local optKeyToInterrupt = keyMap[GetModConfigData("keyToInterrupt")] or nil
            local autoCollect       = GetModConfigData("autoCollect") == "yes"
            local repeatCraft       = GetModConfigData("repeatCraft") == "yes"
            local interruptOnMove   = GetModConfigData("interruptOnMove") == "yes"

            -- local playerInst = ThePlayer

            if not playerInst.components.actionqueuerplus then
                playerInst:AddComponent("actionqueuerplus")
                playerInst.components.actionqueuerplus:Configure({
                    autoCollect = autoCollect,
                    keyToUse    = keyToUse,
                })
                updateInputHandler(playerInst, keyToUse, optKeyToInterrupt, interruptOnMove)
            else
                log("Warning: actionqueuerplus component already exists")
            end

            if repeatCraft then
                enableAutoRepeatCraft(playerInst, keyToUse)
            end

            highlight.applyUnhighlightOverride(playerInst)
        end
    )
end

updateInputHandler = function(playerInst, keyToUse, optKeyToInterrupt, interruptOnMove)
    utils.overrideToCancelIf(
        playerInst.components.playercontroller,
        "OnControl",
        function(self, ...)
            if TheInput:IsKeyDown(keyToUse) then
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
                    TheInput:IsControlPressed(CONTROL_MOVE_UP) or
                    TheInput:IsControlPressed(CONTROL_MOVE_DOWN) or
                    TheInput:IsControlPressed(CONTROL_MOVE_LEFT) or
                    TheInput:IsControlPressed(CONTROL_MOVE_RIGHT)
                ) or
                TheInput:IsControlPressed(CONTROL_PRIMARY) or
                TheInput:IsControlPressed(CONTROL_SECONDARY) or
                TheInput:IsControlPressed(CONTROL_ATTACK)
            )
            then
                actionqueuerplus:Interrupt()
                -- don't prevent action though
            end
        end
    )
end

enableAutoRepeatCraft = function(playerInst, keyToUse)
    if (
        not playerInst or
        not playerInst.replica or
        not playerInst.replica.builder or
        not playerInst.replica.builder.MakeRecipeFromMenu
    ) then
        log("Error: unable to enable auto repeat craft")
        return
    end

    utils.overrideToCancelIf(
        playerInst.replica.builder,
        "MakeRecipeFromMenu",
        function(self, recipe, skin)
            if TheInput:IsKeyDown(keyToUse) and recipe.placer == nil then
                playerInst.components.actionqueuerplus:RepeatRecipe(recipe, skin)
                return true
            end
        end
    )
end

main()
