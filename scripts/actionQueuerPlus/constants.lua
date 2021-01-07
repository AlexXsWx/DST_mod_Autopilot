local constants = {

    AUTO_COLLECT_RADIUS = 4,

    AUTO_COLLECT_ACTIONS = {
        [ACTIONS.CHOP] = true,
        [ACTIONS.MINE] = true,
        [ACTIONS.HAMMER] = true,
        [ACTIONS.DIG] = true
    },

    MANHATTAN_DISTANCE_TO_START_BOX_SELECTION = 64,

    GET_MOUSE_POS_PERIOD = 0.1,

    SELECTION_BOX_TINT = {1, 1, 1, 0.15}, -- RGBA

    UNSELECTABLE_TAGS = {"FX", "NOCLICK", "DECOR", "INLIMBO"},

    ALLOWED_ACTIONS = {
        [ACTIONS.REPAIR] = true,
        [ACTIONS.CHOP] = true,
        [ACTIONS.COOK] = true,
        [ACTIONS.PICK] = true,
        [ACTIONS.PICKUP] = true,
        [ACTIONS.MINE] = true,
        [ACTIONS.DIG] = true,
        [ACTIONS.GIVE] = true,
        [ACTIONS.DRY] = true,
        [ACTIONS.EXTINGUISH] = true,
        [ACTIONS.BAIT] = true,
        [ACTIONS.CHECKTRAP] = true,
        [ACTIONS.HARVEST] = true,
        [ACTIONS.SHAVE] = true,
        [ACTIONS.NET] = true,
        [ACTIONS.FERTILIZE] = true,
        [ACTIONS.HAMMER] = true,
        [ACTIONS.RESETMINE] = true,
        [ACTIONS.ACTIVATE] = true,
        [ACTIONS.TURNON] = true,
        [ACTIONS.TURNOFF] = true,
        [ACTIONS.USEITEM] = true,
        [ACTIONS.TAKEITEM] = true,
        [ACTIONS.PLANT] = true,
        [ACTIONS.ADDFUEL] = true,
        [ACTIONS.ADDWETFUEL] = true,
        -- TODO: add more actions
        -- [ACTIONS.REPAIR_LEAK] = true,
    },

    ALLOWED_DEPLOY_MODES = {
        [DEPLOYMODE.PLANT] = true,
        [DEPLOYMODE.WALL] = true,
    },

    ALLOWED_DEPLOY_PREFABS = {
        ["trap_teeth"] = true,
        -- TODO: bramble trap?
    },
}

return constants
