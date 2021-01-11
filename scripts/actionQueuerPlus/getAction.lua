local constants = require "actionQueuerPlus/constants"
local utils     = require "actionQueuerPlus/utils"

local function isLeft(context, config)  return not context.right end
local function isRight(context, config) return context.right     end

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

    [ACTIONS.DIG] = function(context, config)
        return not (
            not config.digStumpsAsWerebeaver and
            context.target:HasTag("stump") and
            context.playerInst:HasTag("beaver")
        )
    end,

    [ACTIONS.PICK] = function(context, config)
        local target = context.target
        local cherrypickingOrDeselecting = context.cherrypicking or context.deselecting
        return not (
            context.right or
            -- TODO: also when autocollecting
            -- TODO: move to utils.shouldIgnorePickupTarget?
            testCherryPick(config.pickFlowersMode, cherrypickingOrDeselecting) and (
                target:HasTag("flower") or
                target:HasTag("succulent") or
                target.prefab == "cave_fern"
            ) or
            testCherryPick(config.pickCarrotsMode, cherrypickingOrDeselecting) and (
                target.prefab == "carrot_planted" or
                target.prefab == "carrat_planted"
            ) or
            testCherryPick(config.pickMandrakesMode, cherrypickingOrDeselecting) and (
                target.prefab == "mandrake_planted"
            ) or
            testCherryPick(config.pickMushroomsMode, cherrypickingOrDeselecting) and (
                target.prefab == "red_mushroom" or
                target.prefab == "green_mushroom" or
                target.prefab == "blue_mushroom"
            ) or
            testCherryPick(config.pickTwigsMode, cherrypickingOrDeselecting) and (
                target.prefab == "sapling" or
                target.prefab == "sapling_moon" or
                target.prefab == "marsh_bush"
            )
        )
    end,

    [ACTIONS.SHAVE] = function(context, config)
        return not (context.right or context.target:HasTag("player"))
    end,

    [ACTIONS.HARVEST] = function(context, config)
        return not (context.right or context.target:HasTag("cage"))
    end,

    [ACTIONS.PICKUP] = function(context, config)
        local target = context.target
        local cherrypickingOrDeselecting = context.cherrypicking or context.deselecting
        return not (
            context.right or
            utils.shouldIgnorePickupTarget(target) or
            -- TODO: move to utils.shouldIgnorePickupTarget?
            testCherryPick(config.pickTwigsMode, cherrypickingOrDeselecting) and (
                target.prefab == "twigs"
            ) or
            testCherryPick(config.pickRotMode, cherrypickingOrDeselecting) and (
                target.prefab == "spoiled_food"
            ) or
            testCherryPick(config.pickSeedsMode, cherrypickingOrDeselecting) and (
                target.prefab == "seeds"
            ) or
            testCherryPick(config.pickFlintMode, cherrypickingOrDeselecting) and (
                target.prefab == "flint"
            ) or
            testCherryPick(config.pickRocksMode, cherrypickingOrDeselecting) and (
                target.prefab == "rocks"
            ) or
            testCherryPick(config.pickTreeBlossomMode, cherrypickingOrDeselecting) and (
                target.prefab == "moon_tree_blossom" or
                target.prefab == "moon_tree_blossom_worldgen"
            )
        )
    end,

    [ACTIONS.EAT] = function(context, config)
        return context.cherrypicking or context.deselecting
    end,
}

----------------------------------------------------------------

local function getAction(context, config)
    local pos = context.target:GetPosition()
    local actionPicker = context.playerInst.components.playeractionpicker

    local potentialActions
    if context.right then
        potentialActions = actionPicker:GetRightClickActions(pos, context.target)
    else
        potentialActions = actionPicker:GetLeftClickActions(pos, context.target)
    end

    for _, act in ipairs(potentialActions) do
        if (
            constants.ALLOWED_ACTIONS[act.action] and (
                special_cases[act.action] == nil or
                special_cases[act.action](context, config)
            )
        ) then
            -- Mutation
            act.isRight = context.right
            return act
        end
    end

    return nil
end

return getAction
