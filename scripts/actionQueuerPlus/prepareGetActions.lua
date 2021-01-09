local constants = require "actionQueuerPlus/constants"
local utils     = require "actionQueuerPlus/utils"

local function isLeft(target, right)  return not right end
local function isRight(target, right) return right     end

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

    [ACTIONS.PICK] = function(target, right, cherrypicking, optConfig)
        return not (
            right or
            -- TODO: also when autocollecting
            -- TODO: move to utils.shouldIgnorePickupTarget?
            optConfig and optConfig.dontPickFlowers and (
                target:HasTag("flower") or
                target:HasTag("succulent") or
                target.prefab == "cave_fern"
            )
        )
    end,

    [ACTIONS.SHAVE] = function(target, right)
        return not (right or target:HasTag("player"))
    end,

    [ACTIONS.HARVEST] = function(target, right)
        return not (right or target:HasTag("cage"))
    end,

    [ACTIONS.PICKUP] = function(target, right)
        return not (right or utils.shouldIgnorePickupTarget(target))
    end,

    [ACTIONS.EAT] = function(target, right, cherrypicking, optConfig)
        return cherrypicking
    end,
}

----------------------------------------------------------------

-- WARNING: this also mutates the given actions by setting `isRight` property
local function filterActions(actions, target, right, cherrypicking, optConfig)
    local nactions = {}
    for i, v in ipairs(actions) do
        if (
            v ~= nil and
            constants.ALLOWED_ACTIONS[v.action] and
            (
                special_cases[v.action] == nil or
                special_cases[v.action](target, right, cherrypicking, optConfig)
            )
        ) then
            -- Mutation
            v.isRight = right
            table.insert(nactions, v)
        end
    end
    return nactions
end

local function prepareGetActions(playerInst, optConfig)
    local function getActions(target, right, cherrpicking)
        local actions = nil

        local useitem   = playerInst.replica.inventory:GetActiveItem()
        local equipitem = playerInst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)

        local actionPicker = playerInst.components.playeractionpicker

        if right and target ~= nil and actionPicker.containers[target] then
            actions = actionPicker:GetSceneActions(target, true)
        elseif useitem ~= nil and useitem:IsValid() then
            if target == playerInst then
                actions = actionPicker:GetInventoryActions(useitem, right)
            elseif target ~= nil then
                actions = actionPicker:GetUseItemActions(target, useitem, right)
            end
        elseif target ~= nil and target ~= playerInst then
            if equipitem ~= nil and equipitem:IsValid() then
                actions = actionPicker:GetEquippedItemActions(target, equipitem, right)
            end
            if actions == nil or #actions == 0 then
                actions = actionPicker:GetSceneActions(target, right)
            end
        end
        actions = actions or {}

        return filterActions(actions, target, right, cherrpicking, optConfig)
    end
    return getActions
end

return prepareGetActions
