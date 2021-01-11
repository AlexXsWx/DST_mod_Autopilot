local constants = require "actionQueuerPlus/constants"
local utils     = require "actionQueuerPlus/utils"

local function isLeft(target, right)  return not right end
local function isRight(target, right) return right     end

local function testCherryPick(mode, cherrypickingOrDeselecting)
    if mode == "no" then return true end
    if mode == "cherryPickOnly" then return not cherrypickingOrDeselecting end
    return false
end

local special_cases = {

    [ACTIONS.HAMMER]     = isRight,
    [ACTIONS.GIVE]       = isLeft,
    [ACTIONS.NET]        = isLeft,
    [ACTIONS.ADDFUEL]    = isLeft,
    [ACTIONS.ADDWETFUEL] = isLeft,
    [ACTIONS.COOK]       = isLeft,
    [ACTIONS.FERTILIZE]  = isLeft,
    [ACTIONS.MINE]       = isLeft,
    [ACTIONS.CHOP]       = isLeft,
    [ACTIONS.DRY]        = isLeft,
    [ACTIONS.PLANT]      = isLeft,

    [ACTIONS.PICK] = function(target, right, cherrypickingOrDeselecting, optConfig)
        return not (
            right or
            -- TODO: also when autocollecting
            -- TODO: move to utils.shouldIgnorePickupTarget?
            optConfig and (
                testCherryPick(optConfig.pickFlowersMode, cherrypickingOrDeselecting) and (
                    target:HasTag("flower") or
                    target:HasTag("succulent") or
                    target.prefab == "cave_fern"
                ) or
                testCherryPick(optConfig.pickCarrotsMode, cherrypickingOrDeselecting) and (
                    target.prefab == "carrot_planted" or
                    target.prefab == "carrat_planted"
                ) or
                testCherryPick(optConfig.pickMandrakesMode, cherrypickingOrDeselecting) and (
                    target.prefab == "mandrake_planted"
                ) or
                testCherryPick(optConfig.pickMushroomsMode, cherrypickingOrDeselecting) and (
                    target.prefab == "red_mushroom" or
                    target.prefab == "green_mushroom" or
                    target.prefab == "blue_mushroom"
                ) or
                testCherryPick(optConfig.pickTwigsMode, cherrypickingOrDeselecting) and (
                    target.prefab == "sapling" or
                    target.prefab == "sapling_moon" or
                    target.prefab == "marsh_bush"
                )
            )
        )
    end,

    [ACTIONS.SHAVE] = function(target, right)
        return not (right or target:HasTag("player"))
    end,

    [ACTIONS.HARVEST] = function(target, right)
        return not (right or target:HasTag("cage"))
    end,

    [ACTIONS.PICKUP] = function(target, right, cherrypickingOrDeselecting, optConfig)
        return not (
            right or
            utils.shouldIgnorePickupTarget(target) or
            -- TODO: move to utils.shouldIgnorePickupTarget?
            testCherryPick(optConfig.pickTwigsMode, cherrypickingOrDeselecting) and (
                target.prefab == "twigs"
            ) or
            testCherryPick(optConfig.pickRotMode, cherrypickingOrDeselecting) and (
                target.prefab == "spoiled_food"
            ) or
            testCherryPick(optConfig.pickSeedsMode, cherrypickingOrDeselecting) and (
                target.prefab == "seeds"
            ) or
            testCherryPick(optConfig.pickFlintMode, cherrypickingOrDeselecting) and (
                target.prefab == "flint"
            ) or
            testCherryPick(optConfig.pickRocksMode, cherrypickingOrDeselecting) and (
                target.prefab == "rocks"
            ) or
            testCherryPick(optConfig.pickTreeBlossomMode, cherrypickingOrDeselecting) and (
                target.prefab == "moon_tree_blossom" or
                target.prefab == "moon_tree_blossom_worldgen"
            )
        )
    end,

    [ACTIONS.EAT] = function(target, right, cherrypickingOrDeselecting, optConfig)
        return cherrypickingOrDeselecting
    end,
}

----------------------------------------------------------------

local function isActionAllowed(
    action, target, right, cherrypickingOrDeselecting, optConfig
)
    return (
        constants.ALLOWED_ACTIONS[action] and (
            special_cases[action] == nil or
            special_cases[action](
                target, right, cherrypickingOrDeselecting, optConfig
            )
        )
    )
end

local function prepareGetAction(playerInst, optConfig)
    local function getAction(target, right, cherrypickingOrDeselecting)

        local pos = target:GetPosition()
        local actionPicker = playerInst.components.playeractionpicker

        local potentialActions
        if right then
            potentialActions = actionPicker:GetRightClickActions(pos, target)
        else
            potentialActions = actionPicker:GetLeftClickActions(pos, target)
        end

        for _, act in ipairs(potentialActions) do
            if isActionAllowed(act.action, target, right, cherrypickingOrDeselecting, optConfig) then
                -- Mutation
                act.isRight = right
                return act
            end
        end

        return nil
    end
    return getAction
end

return prepareGetAction
