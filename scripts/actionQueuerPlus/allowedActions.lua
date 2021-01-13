local utils  = require "actionQueuerPlus/utils/utils"
local logger = require "actionQueuerPlus/utils/logger"

local allowedActions = {}

local function allow(context, config)        return true              end
local function allowIfLeft(context, config)  return not context.right end
local function allowIfRight(context, config) return context.right     end

local function testCherryPick(mode, cherrypickingOrDeselecting)
    if mode == "no" then return true end
    if mode == "cherryPickOnly" then return not cherrypickingOrDeselecting end
    return false
end

local autoCollectAfterActions = {
    [ACTIONS.CHOP] = true,
    [ACTIONS.MINE] = true,
    [ACTIONS.HAMMER] = true,
    [ACTIONS.DIG] = true,
}

local allowedDeployModes = {
    [DEPLOYMODE.PLANT] = true,
    [DEPLOYMODE.WALL] = true,
    -- wormwood planting seeds without turf requirement
    [DEPLOYMODE.CUSTOM] = true,
}

local allowedDeployPrefabs = {
    ["trap_teeth"] = true,
    -- TODO: bramble trap?
}

local isActionAllowedMap = {

    [ACTIONS.TAKEITEM]    = allow,
    [ACTIONS.REPAIR]      = allow,
    [ACTIONS.USEITEM]     = allow,
    [ACTIONS.BAIT]        = allow,
    [ACTIONS.CHECKTRAP]   = allow,
    [ACTIONS.RESETMINE]   = allow,
    [ACTIONS.ACTIVATE]    = allow,
    [ACTIONS.TURNON]      = allow,
    [ACTIONS.TURNOFF]     = allow,
    [ACTIONS.EXTINGUISH]  = allow,
    [ACTIONS.REPAIR_LEAK] = allow,
    -- (e.g. heal abigal using glands)
    [ACTIONS.HEAL]        = allow,

    [ACTIONS.PLANTSOIL] = allow,
    -- talking to plants
    [ACTIONS.INTERACT_WITH] = allowIfRight,
    [ACTIONS.ASSESSPLANTHAPPINESS] = function(context, config)
        return not context.right and context.cherrypicking
    end,

    [ACTIONS.HAMMER] = allowIfRight,

    [ACTIONS.GIVE]       = allowIfLeft,
    [ACTIONS.NET]        = allowIfLeft,
    [ACTIONS.ADDFUEL]    = allowIfLeft,
    [ACTIONS.ADDWETFUEL] = allowIfLeft,
    [ACTIONS.COOK]       = allowIfLeft,
    [ACTIONS.FERTILIZE]  = allowIfLeft,
    [ACTIONS.MINE]       = allowIfLeft,
    [ACTIONS.CHOP]       = allowIfLeft,
    [ACTIONS.DRY]        = allowIfLeft,
    [ACTIONS.PLANT]      = allowIfLeft,

    [ACTIONS.DIG] = function(context, config)
        local cherrypickingOrDeselecting = context.cherrypicking or context.deselecting
        if (
            context.target:HasTag("stump") and
            -- TODO: change to inverse to support optionality of the config
            not config.digStumpsAsWerebeaver and
            context.playerInst:HasTag("beaver")
        ) then
            return false
        end
        if (
            context.target:HasTag("farm_plant") and
            testCherryPick(config.digUpSeeds, cherrypickingOrDeselecting)
        ) then
            return false
        end
        return true
    end,

    [ACTIONS.PICK] = function(context, config)
        local target = context.target
        local cherrypickingOrDeselecting = context.cherrypicking or context.deselecting
        return not (
            context.right or
            -- TODO: also when autocollecting
            -- TODO: move to shouldIgnorePickupTarget?
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
            allowedActions.shouldIgnorePickupTarget(target) or
            -- TODO: move to shouldIgnorePickupTarget?
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

    -- e.g. seeds
    [ACTIONS.EAT] = function(context, config)
        return context.cherrypicking or context.deselecting
    end,
}

function allowedActions.isActionAllowed(action, context, config)
    local testFn = isActionAllowedMap[action.action]
    local allowed = testFn and testFn(context, config) or false
    if not allowed then
        logger.logDebug("Action " .. tostring(action) .. " not allowed")
    end
    return allowed
end

function allowedActions.shouldIgnorePickupTarget(entity)
    return utils.toboolean(
        entity.components.mine and not entity.components.mine.inactive or
        entity.components.trap and not entity.components.trap.isset or
        entity:HasTag("trap")
    )
end

function allowedActions.canAutoCollectAfter(action)
    return utils.toboolean(autoCollectAfterActions[action])
end

function allowedActions.getItemDeployMode(item)
    if item and item.replica then
        local inventoryItem = item.replica.inventoryitem
        if inventoryItem then
            if inventoryItem.inst.components.deployable then
                return inventoryItem.inst.components.deployable.mode
            end
            if inventoryItem.classified and inventoryItem.classified.deploymode then
                return inventoryItem.classified.deploymode:value()
            end
        end
    end
    logger.logError("Unable to get deploy mode")
    return nil
end

function allowedActions.canDeployItem(item)
    if not item then return false end
    local deployMode = allowedActions.getItemDeployMode(item)
    local allowed = utils.toboolean(
        allowedDeployPrefabs[item.prefab] or
        allowedDeployModes[deployMode]
    )
    if not allowed then
        logger.logDebug(
            "Deploy " ..
            item.prefab .. " / " .. deployMode ..
            " not allowed"
        )
    end
    return allowed
end

return allowedActions
